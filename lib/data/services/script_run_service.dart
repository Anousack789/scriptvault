import 'dart:io';

import '../../domain/models/script_run_result.dart';

class ScriptRunService {
  const ScriptRunService();

  Future<ScriptRunResult> run({
    required String scriptId,
    required File scriptFile,
    required Directory workingDirectory,
    required List<String> arguments,
  }) async {
    final startedAt = DateTime.now();
    final result = await Process.run('/bin/bash', [
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
}
