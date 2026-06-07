class ScriptRunResult {
  final String scriptId;
  final String stdout;
  final String stderr;
  final int exitCode;
  final DateTime startedAt;
  final DateTime endedAt;

  const ScriptRunResult({
    required this.scriptId,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.startedAt,
    required this.endedAt,
  });

  bool get succeeded => exitCode == 0;

  String get outputText {
    final buffer = StringBuffer()
      ..writeln('Exit code: $exitCode')
      ..writeln('Started: ${startedAt.toIso8601String()}')
      ..writeln('Ended: ${endedAt.toIso8601String()}')
      ..writeln()
      ..writeln('stdout:')
      ..write(stdout.isEmpty ? '(empty)' : stdout)
      ..writeln()
      ..writeln()
      ..writeln('stderr:')
      ..write(stderr.isEmpty ? '(empty)' : stderr);

    return buffer.toString();
  }
}
