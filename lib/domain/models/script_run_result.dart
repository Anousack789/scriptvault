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
}
