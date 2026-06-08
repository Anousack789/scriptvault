import 'package:flutter/material.dart';

import 'script_group.dart';
import 'script_list_item.dart';
import '../../theme/script_vault_style.dart';

class ScriptGroupSection extends StatelessWidget {
  final ScriptGroup group;
  final bool collapsed;
  final String? selectedScriptId;
  final VoidCallback onToggle;
  final ValueChanged<String> onScriptSelected;

  const ScriptGroupSection({
    super.key,
    required this.group,
    required this.collapsed,
    required this.selectedScriptId,
    required this.onToggle,
    required this.onScriptSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: ScriptVaultStyle.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggle,
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                child: Row(
                  children: [
                    Icon(
                      collapsed
                          ? Icons.keyboard_arrow_right
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: ScriptVaultStyle.muted,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      collapsed ? Icons.folder_outlined : Icons.folder_open,
                      size: 18,
                      color: ScriptVaultStyle.folder,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ScriptVaultStyle.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ScriptVaultStyle.panelSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        group.scripts.length.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ScriptVaultStyle.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 14),
            for (final script in group.scripts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ScriptListItem(
                  script: script,
                  selected: script.id == selectedScriptId,
                  onTap: () => onScriptSelected(script.id),
                ),
              ),
          ],
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
