import 'dart:io';

import '../../domain/models/host_connection_result.dart';
import '../../domain/models/host_entry.dart';
import '../../domain/models/script_run_result.dart';

class ScriptRunService {
  final Map<String, String>? _platformEnvironment;

  const ScriptRunService({Map<String, String>? platformEnvironment})
    : _platformEnvironment = platformEnvironment;

  Future<ScriptRunResult> run({
    required String scriptId,
    required File scriptFile,
    required Directory workingDirectory,
    required String host,
    required HostEntry? remoteHost,
    required String targetPath,
    required List<String> arguments,
    Map<String, String> environment = const {},
  }) async {
    final startedAt = DateTime.now();
    final result = remoteHost != null
        ? await _runRemote(
            host: remoteHost,
            targetPath: targetPath,
            scriptFile: scriptFile,
            arguments: arguments,
            environment: environment,
          )
        : isIpAddress(host)
        ? await _runLegacyRemote(
            host: host,
            targetPath: targetPath,
            scriptFile: scriptFile,
            arguments: arguments,
            environment: environment,
          )
        : await Process.run(
            '/bin/bash',
            [scriptFile.path, ...arguments],
            workingDirectory: workingDirectory.path,
            environment: _localEnvironment(environment),
          );
    final endedAt = DateTime.now();

    return ScriptRunResult(
      scriptId: scriptId,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
      exitCode: result.exitCode,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }

  bool isIpAddress(String value) {
    final octets = value.trim().split('.');
    if (octets.length != 4) return false;

    for (final octet in octets) {
      if (octet.isEmpty || !RegExp(r'^\d+$').hasMatch(octet)) {
        return false;
      }
      final number = int.parse(octet);
      if (number < 0 || number > 255) return false;
    }
    return true;
  }

  Map<String, String> _localEnvironment(Map<String, String> environment) {
    return {
      ...environment,
      'PATH': _localPath(environment['PATH'] ?? _baseEnvironment['PATH']),
    };
  }

  String _localPath(String? currentPath) {
    final paths = [
      if (currentPath != null && currentPath.trim().isNotEmpty)
        ...currentPath.split(':'),
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
    ];
    final uniquePaths = <String>[];
    for (final path in paths) {
      final cleanedPath = path.trim();
      if (cleanedPath.isNotEmpty && !uniquePaths.contains(cleanedPath)) {
        uniquePaths.add(cleanedPath);
      }
    }
    return uniquePaths.join(':');
  }

  Future<HostConnectionResult> testHostConnection(HostEntry host) async {
    final startedAt = DateTime.now();
    final sshArgs = _sshArgs(
      host: host,
      remoteCommand: 'echo scriptvault-host-ok',
      connectTimeoutSeconds: 10,
    );
    final passwordSsh = host.authType == 'password'
        ? await _passwordSshConfig(host.password)
        : null;
    final executable = passwordSsh?.executable ?? _resolveExecutable('ssh');
    final args = passwordSsh == null ? sshArgs : [...sshArgs];
    final processEnvironment =
        passwordSsh?.environment ?? _processEnvironment();

    try {
      final result = await Process.run(
        executable,
        args,
        environment: processEnvironment,
      );
      final endedAt = DateTime.now();
      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString();
      final success =
          result.exitCode == 0 && stdout.contains('scriptvault-host-ok');
      return HostConnectionResult(
        success: success,
        stdout: stdout,
        stderr: success
            ? stderr
            : _guidedSshStderr(
                stderr,
                authType: host.authType,
                destination: host.destination,
                port: host.port,
              ),
        exitCode: result.exitCode,
        startedAt: startedAt,
        endedAt: endedAt,
      );
    } on ProcessException catch (error) {
      final endedAt = DateTime.now();
      return HostConnectionResult(
        success: false,
        stdout: '',
        stderr: _sshLaunchFailureMessage(error),
        exitCode: 127,
        startedAt: startedAt,
        endedAt: endedAt,
      );
    } finally {
      await passwordSsh?.dispose();
    }
  }

  Future<ProcessResult> _runRemote({
    required HostEntry host,
    required String targetPath,
    required File scriptFile,
    required List<String> arguments,
    required Map<String, String> environment,
  }) async {
    final sshArgs = _sshArgs(
      host: host,
      remoteCommand: _remoteCommand(
        targetPath: targetPath,
        arguments: arguments,
        environment: environment,
      ),
    );

    final passwordSsh = host.authType == 'password'
        ? await _passwordSshConfig(host.password)
        : null;
    final executable = passwordSsh?.executable ?? _resolveExecutable('ssh');
    final args = passwordSsh == null ? sshArgs : [...sshArgs];
    final processEnvironment =
        passwordSsh?.environment ?? _processEnvironment();

    try {
      final result = await _streamScriptToRemote(
        executable: executable,
        args: args,
        environment: processEnvironment,
        scriptFile: scriptFile,
      );
      return ProcessResult(
        result.pid,
        result.exitCode,
        result.stdout,
        _guidedSshStderr(
          result.stderr.toString(),
          authType: host.authType,
          destination: host.destination,
          port: host.port,
        ),
      );
    } on ProcessException catch (error) {
      return ProcessResult(0, 127, '', _sshLaunchFailureMessage(error));
    } finally {
      await passwordSsh?.dispose();
    }
  }

  List<String> _sshArgs({
    required HostEntry host,
    required String remoteCommand,
    int? connectTimeoutSeconds,
  }) {
    return [
      '-p',
      host.port.toString(),
      if (connectTimeoutSeconds != null) ...[
        '-o',
        'ConnectTimeout=$connectTimeoutSeconds',
      ],
      if (host.authType == 'key') ...[
        '-o',
        'BatchMode=yes',
        if (host.keyPath.trim().isNotEmpty) ...['-i', host.keyPath.trim()],
      ],
      host.destination,
      remoteCommand,
    ];
  }

  Future<ProcessResult> _runLegacyRemote({
    required String host,
    required String targetPath,
    required File scriptFile,
    required List<String> arguments,
    required Map<String, String> environment,
  }) {
    return _streamScriptToRemote(
      executable: _resolveExecutable('ssh'),
      args: [
        host.trim(),
        _remoteCommand(
          targetPath: targetPath,
          arguments: arguments,
          environment: environment,
        ),
      ],
      environment: _processEnvironment(),
      scriptFile: scriptFile,
    );
  }

  Future<ProcessResult> _streamScriptToRemote({
    required String executable,
    required List<String> args,
    required File scriptFile,
    Map<String, String>? environment,
  }) async {
    final process = await Process.start(
      executable,
      args,
      environment: environment,
    );
    process.stdin.write(await scriptFile.readAsString());
    await process.stdin.close();

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout
        .transform(const SystemEncoding().decoder)
        .forEach(stdoutBuffer.write);
    final stderrDone = process.stderr
        .transform(const SystemEncoding().decoder)
        .forEach(stderrBuffer.write);
    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);

    return ProcessResult(
      process.pid,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  }

  String _remoteCommand({
    required String targetPath,
    required List<String> arguments,
    required Map<String, String> environment,
  }) {
    final command = StringBuffer();
    final cleanedTargetPath = targetPath.trim();
    if (cleanedTargetPath.isNotEmpty) {
      command.write('cd ${_shellQuote(cleanedTargetPath)} && ');
    }
    if (environment.isEmpty) {
      command.write('/bin/bash -s --');
    } else {
      command.write('env');
      for (final entry in environment.entries) {
        command.write(' ${entry.key}=${_shellQuote(entry.value)}');
      }
      command.write(' /bin/bash -s --');
    }
    for (final argument in arguments) {
      command.write(' ${_shellQuote(argument)}');
    }
    return command.toString();
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  Map<String, String> get _baseEnvironment {
    return _platformEnvironment ?? Platform.environment;
  }

  Map<String, String> _processEnvironment([
    Map<String, String> environment = const {},
  ]) {
    return {
      ...environment,
      'PATH': _localPath(environment['PATH'] ?? _baseEnvironment['PATH']),
    };
  }

  String _resolveExecutable(String executable) {
    if (executable.contains('/')) return executable;
    for (final directory in _localPath(_baseEnvironment['PATH']).split(':')) {
      final cleanedDirectory = directory.trim();
      if (cleanedDirectory.isEmpty) continue;
      final candidate = '$cleanedDirectory/$executable';
      if (File(candidate).existsSync()) return candidate;
    }
    return executable;
  }

  Future<_PasswordSshConfig> _passwordSshConfig(String password) async {
    final directory = await Directory.systemTemp.createTemp(
      'scriptvault_askpass_',
    );
    final helper = File('${directory.path}/askpass.sh');
    await helper.writeAsString('''
#!/bin/sh
printf '%s\\n' "\$SCRIPTVAULT_SSH_PASSWORD"
''');
    await Process.run('/bin/chmod', ['700', helper.path]);

    return _PasswordSshConfig(
      executable: _resolveExecutable('ssh'),
      environment: _processEnvironment({
        'SCRIPTVAULT_SSH_PASSWORD': password,
        'SSH_ASKPASS': helper.path,
        'SSH_ASKPASS_REQUIRE': 'force',
        'DISPLAY': 'scriptvault',
      }),
      directory: directory,
    );
  }

  String _guidedSshStderr(
    String stderr, {
    required String authType,
    required String destination,
    required int port,
  }) {
    final guidance = _sshFailureGuidance(
      stderr,
      authType: authType,
      destination: destination,
      port: port,
    );
    if (guidance == null) return stderr;

    final cleaned = stderr.trim();
    if (cleaned.isEmpty) return guidance;
    return '$cleaned\n\n$guidance';
  }

  String? _sshFailureGuidance(
    String stderr, {
    required String authType,
    required String destination,
    required int port,
  }) {
    final normalized = stderr.toLowerCase();
    if (normalized.contains('host key verification failed') ||
        normalized.contains("can't be established")) {
      return 'Resolve: run "ssh -p $port $destination" in Terminal once, '
          'accept the host key, then retry in ScriptVault.';
    }
    if (normalized.contains('permission denied')) {
      if (authType == 'password') {
        return 'Resolve: check the username and password, and make sure the '
            'server allows password login. If the server only allows keys, '
            'switch this host to Public key.';
      }
      return 'Resolve: check the username and private key path, or leave the '
          'key path blank to use your default SSH keys.';
    }
    if (normalized.contains('connection timed out') ||
        normalized.contains('operation timed out')) {
      return 'Resolve: check the address, port, firewall, and whether the '
          'server is reachable from this Mac.';
    }
    if (normalized.contains('connection refused')) {
      return 'Resolve: check that SSH is running on the server and that the '
          'configured port is correct.';
    }
    if (normalized.contains('no route to host') ||
        normalized.contains('could not resolve hostname')) {
      return 'Resolve: check the host address and your network connection.';
    }
    return null;
  }

  String _sshLaunchFailureMessage(ProcessException error) {
    final message = error.toString();
    if (message.toLowerCase().contains('no such file or directory')) {
      return 'OpenSSH is required to test or run remote scripts. Install '
          'Apple command line tools with "xcode-select --install", or make '
          'sure ssh is available on PATH.\n$message';
    }
    return message;
  }
}

class _PasswordSshConfig {
  final String executable;
  final Map<String, String> environment;
  final Directory directory;

  const _PasswordSshConfig({
    required this.executable,
    required this.environment,
    required this.directory,
  });

  Future<void> dispose() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
