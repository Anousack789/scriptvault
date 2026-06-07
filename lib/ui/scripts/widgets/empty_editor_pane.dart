import 'package:flutter/material.dart';

class EmptyEditorPane extends StatelessWidget {
  const EmptyEditorPane({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.code, size: 44, color: Color(0xFF6B7280)),
            const SizedBox(height: 14),
            Text(
              'Select a script',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a script from the left sidebar or create a new one.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9DA5B4)),
            ),
          ],
        ),
      ),
    );
  }
}
