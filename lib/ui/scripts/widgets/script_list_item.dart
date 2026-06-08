import 'package:flutter/material.dart';

import '../../../domain/models/script_entry.dart';
import '../../theme/script_vault_style.dart';

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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: ScriptVaultStyle.panelDecoration(selected: selected),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      script.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ScriptVaultStyle.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (script.tags
                      .map((tag) => tag.toLowerCase())
                      .contains('starred'))
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 1),
                      child: Icon(
                        Icons.star,
                        size: 18,
                        color: ScriptVaultStyle.folder,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Chip(label: script.group),
                  for (final tag in script.tags.take(2)) _Chip(label: tag),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 9,
                    color: script.lastRunAt == null
                        ? ScriptVaultStyle.subtle
                        : ScriptVaultStyle.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: script.lastRunAt == null
                            ? ScriptVaultStyle.muted
                            : ScriptVaultStyle.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _lastRunText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ScriptVaultStyle.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Select script',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: ScriptVaultStyle.panelRaised,
                      foregroundColor: ScriptVaultStyle.text,
                      side: const BorderSide(color: ScriptVaultStyle.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: onTap,
                    icon: const Icon(Icons.play_arrow, size: 18),
                  ),
                ],
              ),
              if (_metadata.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _metadata,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ScriptVaultStyle.subtle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _statusText {
    if (script.lastRunAt == null) return 'Not run yet';
    return 'Success';
  }

  String get _lastRunText {
    final lastRunAt = script.lastRunAt;
    if (lastRunAt == null) return '';
    final elapsed = DateTime.now().difference(lastRunAt);
    if (elapsed.inDays >= 1) return '${elapsed.inDays}d ago';
    if (elapsed.inHours >= 1) return '${elapsed.inHours}h ago';
    if (elapsed.inMinutes >= 1) return '${elapsed.inMinutes}m ago';
    return 'now';
  }

  String get _metadata {
    final location = [
      if (script.host.isNotEmpty) script.host,
      if (script.targetPath.isNotEmpty) script.targetPath,
    ].join(' ');
    return location;
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ScriptVaultStyle.panelSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ScriptVaultStyle.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
