import 'package:flutter/material.dart';

import '../../theme/script_vault_style.dart';

class EmptyEditorPane extends StatelessWidget {
  const EmptyEditorPane({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ScriptVaultStyle.appBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: ScriptVaultStyle.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ScriptVaultStyle.border),
              ),
              child: const Icon(
                Icons.code,
                size: 34,
                color: ScriptVaultStyle.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Select a script',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: ScriptVaultStyle.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a script from the left sidebar or create a new one.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: ScriptVaultStyle.muted),
            ),
          ],
        ),
      ),
    );
  }
}
