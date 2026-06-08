import 'package:flutter/material.dart';

import '../../../domain/models/script_run_result.dart';

class TerminalOutputPane extends StatelessWidget {
  final ScriptRunResult? result;
  final bool isRunning;
  final double? maxHeight;

  const TerminalOutputPane({
    super.key,
    required this.result,
    required this.isRunning,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final terminal = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF26313F)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );

    if (maxHeight == null) return terminal;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight!),
      child: terminal,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = isRunning
        ? 'running'
        : result == null
        ? 'idle'
        : 'exit ${result!.exitCode}';
    final statusColor = result == null
        ? const Color(0xFF9CA3AF)
        : result!.succeeded
        ? const Color(0xFF4ADE80)
        : colorScheme.error;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF151B23),
        border: Border(bottom: BorderSide(color: Color(0xFF26313F))),
      ),
      child: Row(
        children: [
          _windowDot(const Color(0xFFFF5F57)),
          const SizedBox(width: 6),
          _windowDot(const Color(0xFFFFBD2E)),
          const SizedBox(width: 6),
          _windowDot(const Color(0xFF28C840)),
          const Spacer(),
          Icon(Icons.terminal, size: 15, color: statusColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: statusColor,
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: SelectableText.rich(
          TextSpan(
            style: const TextStyle(
              color: Color(0xFFE5EDF5),
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.38,
            ),
            children: _buildOutputSpans(context),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildOutputSpans(BuildContext context) {
    const promptStyle = TextStyle(color: Color(0xFF7DD3FC));
    const mutedStyle = TextStyle(color: Color(0xFF94A3B8));
    const stdoutStyle = TextStyle(color: Color(0xFFE5EDF5));
    final stderrStyle = TextStyle(color: Theme.of(context).colorScheme.error);

    if (isRunning) {
      return const [
        TextSpan(text: r'$ ', style: promptStyle),
        TextSpan(text: 'running script...\n', style: stdoutStyle),
        TextSpan(text: 'waiting for output _', style: mutedStyle),
      ];
    }

    final currentResult = result;
    if (currentResult == null) {
      return const [
        TextSpan(text: r'$ ', style: promptStyle),
        TextSpan(text: 'run output will appear here', style: mutedStyle),
      ];
    }

    return [
      const TextSpan(text: r'$ ', style: promptStyle),
      TextSpan(
        text: 'completed with exit code ${currentResult.exitCode}\n',
        style: currentResult.succeeded ? stdoutStyle : stderrStyle,
      ),
      const TextSpan(text: '\nstdout\n', style: mutedStyle),
      TextSpan(text: _terminalValue(currentResult.stdout), style: stdoutStyle),
      const TextSpan(text: '\n\nstderr\n', style: mutedStyle),
      TextSpan(text: _terminalValue(currentResult.stderr), style: stderrStyle),
    ];
  }

  static String _terminalValue(String value) {
    if (value.isEmpty) return '(empty)';
    return value.endsWith('\n') ? value.trimRight() : value;
  }

  Widget _windowDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
