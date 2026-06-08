import 'package:flutter/material.dart';

import '../../theme/script_vault_style.dart';

class EditorToolbar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSave;
  final VoidCallback? onRun;
  final VoidCallback? onClose;

  const EditorToolbar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSave,
    required this.onRun,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: ScriptVaultStyle.appBackground,
        border: Border(bottom: BorderSide(color: ScriptVaultStyle.border)),
      ),
      child: Row(
        children: [
          if (onClose != null)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: onClose,
            ),
          const Icon(Icons.terminal, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Untitled script' : title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9DA5B4),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Run',
            icon: const Icon(Icons.play_arrow),
            onPressed: onRun,
          ),
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save_outlined),
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
