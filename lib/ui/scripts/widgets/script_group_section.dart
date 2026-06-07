import 'package:flutter/material.dart';

import 'script_group.dart';
import 'script_list_item.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFF252526),
          child: InkWell(
            onTap: onToggle,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_right
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: const Color(0xFF9DA5B4),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    collapsed ? Icons.folder_outlined : Icons.folder_open,
                    size: 18,
                    color: const Color(0xFFD7BA7D),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    group.scripts.length.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9DA5B4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!collapsed)
          for (final script in group.scripts)
            ScriptListItem(
              script: script,
              selected: script.id == selectedScriptId,
              onTap: () => onScriptSelected(script.id),
            ),
      ],
    );
  }
}
