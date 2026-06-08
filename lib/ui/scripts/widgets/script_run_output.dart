import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/script_run_result.dart';
import '../../theme/script_vault_style.dart';

class ScriptRunOutput extends StatefulWidget {
  final ScriptRunResult? result;
  final bool isRunning;

  const ScriptRunOutput({
    super.key,
    required this.result,
    required this.isRunning,
  });

  @override
  State<ScriptRunOutput> createState() => _ScriptRunOutputState();
}

class _ScriptRunOutputState extends State<ScriptRunOutput> {
  static const _savePanelChannel = MethodChannel('scriptvault/save_panel');

  var _isSaving = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final statusColor = _statusColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(_statusIcon, size: 18, color: statusColor),
              const SizedBox(width: 8),
              Text(
                _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ScriptVaultStyle.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ScriptVaultStyle.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (result != null) ...[
                _actionButton(
                  tooltip: 'Expand output',
                  icon: Icons.open_in_full,
                  onPressed: () => _expandOutput(context, result),
                ),
                _actionButton(
                  tooltip: 'Copy output',
                  icon: Icons.copy_outlined,
                  onPressed: () => _copyOutput(context, result),
                ),
                _actionButton(
                  tooltip: 'Save output',
                  icon: Icons.save_alt_outlined,
                  busy: _isSaving,
                  onPressed: _isSaving
                      ? null
                      : () => _saveOutput(context, result),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _OutputText(
            result: result,
            isRunning: widget.isRunning,
            scrollController: _scrollController,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    bool busy = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: ScriptVaultStyle.muted,
        disabledForegroundColor: ScriptVaultStyle.subtle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      onPressed: onPressed,
    );
  }

  Color _statusColor(BuildContext context) {
    if (widget.isRunning) return ScriptVaultStyle.primary;
    final result = widget.result;
    if (result == null) return ScriptVaultStyle.muted;
    return result.succeeded
        ? ScriptVaultStyle.success
        : Theme.of(context).colorScheme.error;
  }

  IconData get _statusIcon {
    if (widget.isRunning) return Icons.sync;
    final result = widget.result;
    if (result == null) return Icons.terminal;
    return result.succeeded ? Icons.check_circle_outline : Icons.error_outline;
  }

  String get _title {
    if (widget.isRunning) return 'Running';
    final result = widget.result;
    if (result == null) return 'Ready';
    return result.succeeded ? 'Success' : 'Failed';
  }

  String get _subtitle {
    if (widget.isRunning) return 'Waiting for script output...';
    final result = widget.result;
    if (result == null) return 'Run output will appear here.';
    final duration = result.endedAt.difference(result.startedAt);
    return 'Exit code ${result.exitCode} - ${_formatDuration(duration)}';
  }

  Future<void> _copyOutput(BuildContext context, ScriptRunResult result) async {
    await Clipboard.setData(ClipboardData(text: result.outputText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Output copied')));
  }

  Future<void> _saveOutput(BuildContext context, ScriptRunResult result) async {
    setState(() => _isSaving = true);
    try {
      final path = await _savePanelChannel
          .invokeMethod<String>('chooseOutputPath', {
            'defaultName':
                'script-output-${result.startedAt.millisecondsSinceEpoch}.txt',
          });
      if (path == null || path.isEmpty) return;

      await File(path).writeAsString(result.outputText);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Output saved to $path')));
    } on MissingPluginException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save dialog is unavailable.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _expandOutput(BuildContext context, ScriptRunResult result) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: ScriptVaultStyle.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ScriptVaultStyle.border),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Run output',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: ScriptVaultStyle.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _actionButton(
                      tooltip: 'Copy output',
                      icon: Icons.copy_outlined,
                      onPressed: () => _copyOutput(context, result),
                    ),
                    _actionButton(
                      tooltip: 'Save output',
                      icon: Icons.save_alt_outlined,
                      busy: _isSaving,
                      onPressed: _isSaving
                          ? null
                          : () => _saveOutput(context, result),
                    ),
                    _actionButton(
                      tooltip: 'Close',
                      icon: Icons.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _OutputText(result: result, isRunning: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes >= 1) return '${duration.inMinutes}m';
    if (duration.inSeconds >= 1) return '${duration.inSeconds}s';
    return '${duration.inMilliseconds}ms';
  }
}

class _OutputText extends StatefulWidget {
  final ScriptRunResult? result;
  final bool isRunning;
  final ScrollController? scrollController;

  const _OutputText({
    required this.result,
    required this.isRunning,
    this.scrollController,
  });

  @override
  State<_OutputText> createState() => _OutputTextState();
}

class _OutputTextState extends State<_OutputText> {
  late final ScrollController _controller =
      widget.scrollController ?? ScrollController();

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        padding: const EdgeInsets.fromLTRB(2, 4, 12, 12),
        child: SelectableText.rich(
          TextSpan(
            style: const TextStyle(
              color: ScriptVaultStyle.text,
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.42,
            ),
            children: _outputSpans(context),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _outputSpans(BuildContext context) {
    const mutedStyle = TextStyle(color: ScriptVaultStyle.muted);
    const stdoutStyle = TextStyle(color: ScriptVaultStyle.text);
    final stderrStyle = TextStyle(color: Theme.of(context).colorScheme.error);

    if (widget.isRunning) {
      return const [
        TextSpan(text: 'running script...\n', style: stdoutStyle),
        TextSpan(text: 'waiting for output _', style: mutedStyle),
      ];
    }

    final result = widget.result;
    if (result == null) {
      return const [
        TextSpan(text: 'run output will appear here', style: mutedStyle),
      ];
    }

    if (result.stdout.isEmpty && result.stderr.isEmpty) {
      return const [TextSpan(text: '(no output)', style: mutedStyle)];
    }

    if (result.succeeded && result.stdout.isEmpty) {
      return [
        TextSpan(text: _terminalValue(result.stderr), style: stdoutStyle),
      ];
    }

    final stderrOutputStyle = result.succeeded ? stdoutStyle : stderrStyle;
    final stderrLabel = result.succeeded ? 'diagnostics' : 'stderr';
    return [
      if (result.stdout.isNotEmpty) ...[
        const TextSpan(text: 'stdout\n', style: mutedStyle),
        TextSpan(text: _terminalValue(result.stdout), style: stdoutStyle),
      ],
      if (result.stderr.isNotEmpty) ...[
        if (result.stdout.isNotEmpty) const TextSpan(text: '\n\n'),
        TextSpan(text: '$stderrLabel\n', style: mutedStyle),
        TextSpan(text: _terminalValue(result.stderr), style: stderrOutputStyle),
      ],
    ];
  }

  static String _terminalValue(String value) {
    if (value.isEmpty) return '(empty)';
    return value.endsWith('\n') ? value.trimRight() : value;
  }
}
