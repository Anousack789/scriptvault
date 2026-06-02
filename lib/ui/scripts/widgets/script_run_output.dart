import 'package:flutter/material.dart';

import '../../../domain/models/script_run_result.dart';

class ScriptRunOutput extends StatelessWidget {
  final ScriptRunResult? result;
  final bool isRunning;

  const ScriptRunOutput({
    super.key,
    required this.result,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    if (isRunning) {
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

    if (result == null) {
      return const Text('Run output will appear here.');
    }

    final color = result!.succeeded
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exit code ${result!.exitCode}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: color),
        ),
        const SizedBox(height: 12),
        _OutputBlock(title: 'stdout', value: result!.stdout),
        const SizedBox(height: 12),
        _OutputBlock(title: 'stderr', value: result!.stderr),
      ],
    );
  }
}

class _OutputBlock extends StatelessWidget {
  final String title;
  final String value;

  const _OutputBlock({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            value.isEmpty ? '(empty)' : value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
