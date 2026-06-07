import 'package:flutter/material.dart';

import '../workspace_tab.dart';

class WorkspaceTabs extends StatelessWidget {
  final WorkspaceTab activeTab;
  final ValueChanged<WorkspaceTab> onTabChanged;
  final VoidCallback onSettings;
  final VoidCallback onLock;

  const WorkspaceTabs({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.onSettings,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D30))),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal, size: 20),
          const SizedBox(width: 10),
          Text('ScriptVault', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 18),
          SegmentedButton<WorkspaceTab>(
            segments: const [
              ButtonSegment(
                value: WorkspaceTab.scripts,
                icon: Icon(Icons.code),
                label: Text('Scripts', key: ValueKey('scripts-tab-label')),
              ),
              ButtonSegment(
                value: WorkspaceTab.hosts,
                icon: Icon(Icons.dns_outlined),
                label: Text('Hosts', key: ValueKey('hosts-tab-label')),
              ),
            ],
            selected: {activeTab},
            onSelectionChanged: (selection) => onTabChanged(selection.single),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Lock',
            onPressed: onLock,
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
    );
  }
}
