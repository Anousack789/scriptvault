import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_settings.dart';
import '../hosts/hosts_view.dart';
import '../lock/app_lock_viewmodel.dart';
import '../scripts/scripts_list_view.dart';
import '../settings/app_settings_viewmodel.dart';
import '../settings/settings_dialog.dart';

enum WorkspaceTab { scripts, hosts }

class HomeView extends ConsumerStatefulWidget {
  final WorkspaceTab initialTab;

  const HomeView({super.key, this.initialTab = WorkspaceTab.scripts});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  late var _activeTab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _WorkspaceTabs(
            activeTab: _activeTab,
            onTabChanged: (tab) => setState(() => _activeTab = tab),
            onLock: () => _lock(context),
          ),
          Expanded(
            child: switch (_activeTab) {
              WorkspaceTab.scripts => const ScriptsListView(),
              WorkspaceTab.hosts => const HostsView(),
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _showSettings(
    BuildContext context, {
    bool lockSetupRequired = false,
  }) async {
    final settings =
        ref.read(appSettingsViewModelProvider).value ?? const AppSettings();
    await showDialog<void>(
      context: context,
      builder: (context) => SettingsDialog(
        settings: settings,
        lockSetupRequired: lockSetupRequired,
        onEditorFontSizeSaved: (value) {
          ref
              .read(appSettingsViewModelProvider.notifier)
              .updateEditorFontSize(value);
        },
        onLockPasswordSet: (password) {
          return ref
              .read(appSettingsViewModelProvider.notifier)
              .setLockPassword(password);
        },
        onLockPasswordChanged: (currentPassword, newPassword) {
          return ref
              .read(appSettingsViewModelProvider.notifier)
              .changeLockPassword(
                currentPassword: currentPassword,
                newPassword: newPassword,
              );
        },
        onLockDisabled: (currentPassword) {
          return ref
              .read(appSettingsViewModelProvider.notifier)
              .disableLock(currentPassword);
        },
      ),
    );
    if (!context.mounted) return false;
    return ref.read(appLockViewModelProvider.notifier).lockEnabled();
  }

  Future<void> _lock(BuildContext context) async {
    final locked = await ref.read(appLockViewModelProvider.notifier).lock();
    if (locked || !context.mounted) return;

    final lockEnabled = await _showSettings(context, lockSetupRequired: true);
    if (lockEnabled && context.mounted) {
      await ref.read(appLockViewModelProvider.notifier).lock();
    }
  }
}

class _WorkspaceTabs extends StatelessWidget {
  final WorkspaceTab activeTab;
  final ValueChanged<WorkspaceTab> onTabChanged;
  final VoidCallback onLock;

  const _WorkspaceTabs({
    required this.activeTab,
    required this.onTabChanged,
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
            tooltip: 'Lock',
            onPressed: onLock,
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
    );
  }
}
