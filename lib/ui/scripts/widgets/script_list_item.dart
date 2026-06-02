import 'package:flutter/material.dart';

import '../../../domain/models/script_entry.dart';

class ScriptListItem extends StatelessWidget {
  final ScriptEntry script;
  final VoidCallback onTap;
  final bool selected;

  const ScriptListItem({
    super.key,
    required this.script,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF37373D) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: selected
                ? const Border(
                    right: BorderSide(color: Color(0xFF4FC3F7), width: 3),
                    bottom: BorderSide(color: Color(0xFF37373D), width: 1),
                  )
                : const Border(
                    bottom: BorderSide(color: Color(0xFF37373D), width: 1),
                  ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      script.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _metadata,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9DA5B4),
                      ),
                    ),
                  ],
                ),
              ),
              if (script.lastRunAt != null)
                const Icon(Icons.play_circle_outline, size: 17),
            ],
          ),
        ),
      ),
    );
  }

  String get _metadata {
    final tags = script.tags.map((tag) => '#$tag').join(' ');
    return tags;
  }
}
