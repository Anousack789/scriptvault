import 'dart:io';

import '../../domain/models/host_connection_result.dart';
import '../../domain/models/host_entry.dart';
import '../../domain/models/script_run_result.dart';

class ScriptRunService {
  const ScriptRunService();

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
      'PATH': _localPath(environment['PATH'] ?? Platform.environment['PATH']),
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
    final executable = host.authType == 'password' ? 'sshpass' : 'ssh';
    final args = host.authType == 'password'
        ? ['-e', 'ssh', ...sshArgs]
        : sshArgs;
    final processEnvironment = host.authType == 'password'
        ? {'SSHPASS': host.password}
        : null;

    try {
      final result = await Process.run(
        executable,
        args,
        environment: processEnvironment,
      );
      final endedAt = DateTime.now();
      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString();
      return HostConnectionResult(
        success: result.exitCode == 0 && stdout.contains('scriptvault-host-ok'),
        stdout: stdout,
        stderr: stderr,
        exitCode: result.exitCode,
        startedAt: startedAt,
        endedAt: endedAt,
      );
    } on ProcessException catch (error) {
      final endedAt = DateTime.now();
      final message = host.authType == 'password'
          ? 'Password SSH requires sshpass to be installed and available on PATH.\n$error'
          : error.toString();
      return HostConnectionResult(
        success: false,
        stdout: '',
        stderr: message,
        exitCode: 127,
        startedAt: startedAt,
        endedAt: endedAt,
      );
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

    final executable = host.authType == 'password' ? 'sshpass' : 'ssh';
    final args = host.authType == 'password'
        ? ['-e', 'ssh', ...sshArgs]
        : sshArgs;
    final processEnvironment = host.authType == 'password'
        ? {'SSHPASS': host.password}
        : null;

    try {
      return _streamScriptToRemote(
        executable: executable,
        args: args,
        environment: processEnvironment,
        scriptFile: scriptFile,
      );
    } on ProcessException catch (error) {
      if (host.authType == 'password') {
        return ProcessResult(
          0,
          127,
          '',
          'Password SSH requires sshpass to be installed and available on PATH.\n$error',
        );
      }
      rethrow;
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
      executable: 'ssh',
      args: [
        host.trim(),
        _remoteCommand(
          targetPath: targetPath,
          arguments: arguments,
          environment: environment,
        ),
      ],
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
}
