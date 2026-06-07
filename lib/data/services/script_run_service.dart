import 'dart:io';

import '../../domain/models/script_run_result.dart';

class ScriptRunService {
  const ScriptRunService();

  Future<ScriptRunResult> run({
    required String scriptId,
    required File scriptFile,
    required Directory workingDirectory,
    required String host,
    required String targetPath,
    required List<String> arguments,
  }) async {
    final startedAt = DateTime.now();
    final result = isIpAddress(host)
        ? await _runRemote(
            host: host,
            targetPath: targetPath,
            scriptFile: scriptFile,
            arguments: arguments,
          )
        : await Process.run('/bin/bash', [
            scriptFile.path,
            ...arguments,
          ], workingDirectory: workingDirectory.path);
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

  Future<ProcessResult> _runRemote({
    required String host,
    required String targetPath,
    required File scriptFile,
    required List<String> arguments,
  }) async {
    final process = await Process.start('ssh', [
      host.trim(),
      _remoteCommand(targetPath: targetPath, arguments: arguments),
    ]);
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
  }) {
    final command = StringBuffer();
    final cleanedTargetPath = targetPath.trim();
    if (cleanedTargetPath.isNotEmpty) {
      command.write('cd ${_shellQuote(cleanedTargetPath)} && ');
    }
    command.write('/bin/bash -s --');
    for (final argument in arguments) {
      command.write(' ${_shellQuote(argument)}');
    }
    return command.toString();
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }
}
