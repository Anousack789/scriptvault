import 'package:flutter/material.dart';

import '../../theme/script_vault_style.dart';
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
      height: 60,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      decoration: const BoxDecoration(
        color: ScriptVaultStyle.appBackground,
        border: Border(bottom: BorderSide(color: ScriptVaultStyle.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              _navButton(
                icon: Icons.code,
                label: 'Scripts',
                selected: activeTab == WorkspaceTab.scripts,
                onTap: () => onTabChanged(WorkspaceTab.scripts),
              ),
              const SizedBox(width: 6),
              _navButton(
                icon: Icons.dns_outlined,
                label: 'Hosts',
                selected: activeTab == WorkspaceTab.hosts,
                onTap: () => onTabChanged(WorkspaceTab.hosts),
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
          );
        },
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? ScriptVaultStyle.primary
            : ScriptVaultStyle.muted,
        backgroundColor: selected ? ScriptVaultStyle.panelSoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
