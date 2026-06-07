class HostConnectionResult {
  final bool success;
  final String stdout;
  final String stderr;
  final int exitCode;
  final DateTime startedAt;
  final DateTime endedAt;

  const HostConnectionResult({
    required this.success,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.startedAt,
    required this.endedAt,
  });

  String get message {
    final output = success ? stdout : stderr;
    final cleaned = output.trim();
    if (cleaned.isNotEmpty) return cleaned;
    return success ? 'Connection succeeded.' : 'Connection failed.';
  }
}
