import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_settings.dart';
import '../hosts/hosts_view.dart';
import '../lock/app_lock_viewmodel.dart';
import '../scripts/scripts_list_view.dart';
import '../settings/app_settings_viewmodel.dart';
import '../settings/app_update_viewmodel.dart';
import '../settings/settings_dialog.dart';
import 'workspace_tab.dart';
import 'widgets/workspace_tabs.dart';

export 'workspace_tab.dart';

class HomeView extends ConsumerStatefulWidget {
  final WorkspaceTab initialTab;

  const HomeView({super.key, this.initialTab = WorkspaceTab.scripts});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  late var _activeTab = widget.initialTab;
  var _startupUpdateCheckStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesOnStartup();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          WorkspaceTabs(
            activeTab: _activeTab,
            onTabChanged: (tab) => setState(() => _activeTab = tab),
            onSettings: () => _showSettings(context),
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
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final updateState = ref.watch(appUpdateViewModelProvider);
          return SettingsDialog(
            settings: settings,
            updateState: updateState,
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
            onCheckForUpdates: () => _checkForUpdates(dialogContext),
            onOpenUpdateDownload: () {
              return ref
                  .read(appUpdateViewModelProvider.notifier)
                  .openDownload();
            },
          );
        },
      ),
    );
    if (!context.mounted) return false;
    return ref.read(appLockViewModelProvider.notifier).lockEnabled();
  }

  Future<void> _checkForUpdatesOnStartup() async {
    if (_startupUpdateCheckStarted || !mounted) return;
    _startupUpdateCheckStarted = true;

    final state = await ref
        .read(appUpdateViewModelProvider.notifier)
        .checkForUpdates(silent: true);
    if (!mounted || state.status != AppUpdateStatus.updateAvailable) return;
    await _showUpdateAvailableDialog(context);
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final state = await ref
        .read(appUpdateViewModelProvider.notifier)
        .checkForUpdates();
    if (!context.mounted || state.status != AppUpdateStatus.updateAvailable) {
      return;
    }
    await _showUpdateAvailableDialog(context);
  }

  Future<void> _showUpdateAvailableDialog(BuildContext context) async {
    final updateInfo = ref.read(appUpdateViewModelProvider).updateInfo;
    if (updateInfo == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update available'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ScriptVault ${updateInfo.latestVersion} is available. '
                'You have ${updateInfo.currentVersion}.',
              ),
              if (updateInfo.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(child: Text(updateInfo.notes)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await ref
                  .read(appUpdateViewModelProvider.notifier)
                  .openDownload();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download'),
          ),
        ],
      ),
    );
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
