import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/script_run_result.dart';
import 'output_block.dart';

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

  @override
  Widget build(BuildContext context) {
    if (widget.isRunning) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Running script...'),
          ],
        ),
      );
    }

    if (widget.result == null) {
      return const Text('Run output will appear here.');
    }

    final result = widget.result!;
    final color = result.succeeded
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Exit code ${result.exitCode}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: color),
              ),
            ),
            IconButton(
              tooltip: 'Expand output',
              icon: const Icon(Icons.open_in_full),
              onPressed: () => _expandOutput(context, result),
            ),
            IconButton(
              tooltip: 'Copy output',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => _copyOutput(context, result),
            ),
            IconButton(
              tooltip: 'Save output',
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt_outlined),
              onPressed: _isSaving ? null : () => _saveOutput(context, result),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutputBlock(title: 'stdout', value: result.stdout),
        const SizedBox(height: 12),
        OutputBlock(title: 'stderr', value: result.stderr),
      ],
    );
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Run output',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy output',
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () => _copyOutput(context, result),
                    ),
                    IconButton(
                      tooltip: 'Save output',
                      icon: const Icon(Icons.save_alt_outlined),
                      onPressed: () => _saveOutput(context, result),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(
                    result.outputText,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
