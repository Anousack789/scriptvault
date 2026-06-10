import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/bash.dart';

import '../../data/services/script_service_provider.dart';
import '../../domain/models/app_settings.dart';
import '../../router/router.dart';
import '../hosts/hosts_viewmodel.dart';
import '../lock/app_lock_viewmodel.dart';
import '../settings/app_settings_viewmodel.dart';
import '../settings/app_update_viewmodel.dart';
import 'script_editor_viewmodel.dart';
import 'scripts_list_viewmodel.dart';
import 'widgets/editor_workspace.dart';
import 'widgets/host_management_dialog.dart';

class ScriptEditorView extends ConsumerStatefulWidget {
  final String? scriptId;
  final bool embedded;
  final ValueChanged<String>? onSaved;
  final VoidCallback? onDeleted;
  final VoidCallback? onClose;

  const ScriptEditorView({
    super.key,
    required this.scriptId,
    this.embedded = false,
    this.onSaved,
    this.onDeleted,
    this.onClose,
  });

  @override
  ConsumerState<ScriptEditorView> createState() => _ScriptEditorViewState();
}

class _ScriptEditorViewState extends ConsumerState<ScriptEditorView> {
  static const _filePanelChannel = MethodChannel('scriptvault/save_panel');

  late final CodeController _codeController;
  var _syncingFromState = false;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(language: bash);
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _codeController
      ..removeListener(_onCodeChanged)
      ..dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_syncingFromState) return;
    ref
        .read(scriptEditorViewModelProvider(widget.scriptId).notifier)
        .updateContent(_codeController.text);
    _scheduleAutoSave();
  }

  @override
  Widget build(BuildContext context) {
    final provider = scriptEditorViewModelProvider(widget.scriptId);
    final state = ref.watch(provider);
    final settings = ref.watch(appSettingsViewModelProvider);
    final viewModel = ref.read(provider.notifier);

    final content = state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (data) {
        _syncEditor(data.content);
        if (data.hasUnsavedChanges && !data.isSaving) {
          _ensureAutoSaveScheduled();
        }
        return EditorWorkspace(
          scriptId: widget.scriptId,
          data: data,
          editorFontSize:
              settings.value?.editorFontSize ??
              AppSettings.defaultEditorFontSize,
          codeController: _codeController,
          onNameChanged: (value) =>
              _updateAndScheduleAutoSave(() => viewModel.updateName(value)),
          onGroupChanged: (value) =>
              _updateAndScheduleAutoSave(() => viewModel.updateGroup(value)),
          onHostChanged: (value) =>
              _updateAndScheduleAutoSave(() => viewModel.updateHost(value)),
          onTargetPathChanged: (value) => _updateAndScheduleAutoSave(
            () => viewModel.updateTargetPath(value),
          ),
          onTagsChanged: (value) =>
              _updateAndScheduleAutoSave(() => viewModel.updateTags(value)),
          onArgumentsChanged: viewModel.updateArguments,
          onManageHosts: () => _manageHosts(context, viewModel),
          onSave: () => _save(context, viewModel),
          onDelete: widget.scriptId == null
              ? null
              : () => _delete(context, viewModel),
          onRun: data.canRun ? () => _run(context, viewModel) : null,
          onClose: widget.embedded
              ? widget.onClose
              : () => context.go(AppRoutes.scripts),
          embedded: widget.embedded,
        );
      },
    );

    if (widget.embedded) return content;

    return Scaffold(body: content);
  }

  void _syncEditor(String content) {
    if (_codeController.text == content) return;
    _syncingFromState = true;
    _codeController.text = content;
    _syncingFromState = false;
  }

  Future<void> _save(
    BuildContext context,
    ScriptEditorViewModel viewModel,
  ) async {
    _autoSaveTimer?.cancel();
    final id = await viewModel.save();
    if (!context.mounted) return;
    if (widget.embedded) {
      widget.onSaved?.call(id);
    } else {
      context.go(AppRoutes.editScriptPath(id));
    }
  }

  void _updateAndScheduleAutoSave(VoidCallback update) {
    update();
    _scheduleAutoSave();
  }

  void _ensureAutoSaveScheduled() {
    if (_autoSaveTimer?.isActive ?? false) return;
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    if (!_autoSaveEnabled) return;
    final data = ref.read(scriptEditorViewModelProvider(widget.scriptId)).value;
    if (data == null ||
        data.isSaving ||
        !data.hasUnsavedChanges ||
        data.saveError != null) {
      return;
    }

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(
      const Duration(milliseconds: 800),
      () => _autoSave(),
    );
  }

  bool get _autoSaveEnabled {
    return ref.read(appSettingsViewModelProvider).value?.autoSaveEnabled ??
        false;
  }

  Future<void> _autoSave() async {
    if (!mounted || !_autoSaveEnabled) return;

    final provider = scriptEditorViewModelProvider(widget.scriptId);
    final data = ref.read(provider).value;
    if (data == null || data.isSaving || !data.hasUnsavedChanges) return;

    final wasNew = data.id == null;
    final viewModel = ref.read(provider.notifier);
    try {
      final id = await viewModel.save();
      if (!mounted) return;

      if (wasNew) {
        if (widget.embedded) {
          widget.onSaved?.call(id);
        } else {
          context.go(AppRoutes.editScriptPath(id));
        }
        return;
      }

      final latest = ref.read(provider).value;
      if (latest != null && latest.hasUnsavedChanges && !latest.isSaving) {
        _scheduleAutoSave();
      }
    } catch (_) {}
  }

  Future<void> _delete(
    BuildContext context,
    ScriptEditorViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete script?'),
        content: const Text('This removes the script file and metadata.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _autoSaveTimer?.cancel();
    await viewModel.delete();
    if (!context.mounted) return;
    if (widget.embedded) {
      widget.onDeleted?.call();
    } else {
      context.go(AppRoutes.scripts);
    }
  }

  Future<void> _run(
    BuildContext context,
    ScriptEditorViewModel viewModel,
  ) async {
    final requiresConfirmation = await viewModel.requiresRunConfirmation();
    if (requiresConfirmation && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Run script?'),
          content: const Text(
            'This script includes commands that can modify files, permissions, or use network access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Run'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await viewModel.run();
  }

  Future<void> _manageHosts(
    BuildContext context,
    ScriptEditorViewModel viewModel,
  ) async {
    final data = ref.read(scriptEditorViewModelProvider(widget.scriptId)).value;
    await showDialog<void>(
      context: context,
      builder: (context) => HostManagementDialog(
        initialHosts: data?.hosts ?? const [],
        onCreate: viewModel.createHost,
        onUpdate: viewModel.updateHostEntry,
        onDelete: viewModel.deleteHost,
        onTest: viewModel.testHostConnection,
      ),
    );
  }

  Future<String?> chooseStorageDirectory(BuildContext context) async {
    try {
      final path = await _filePanelChannel.invokeMethod<String>(
        'chooseStorageDirectory',
      );
      if (path == null || path.isEmpty) return null;
      if (!context.mounted) return null;

      final confirmed = await _confirmStorageChange(
        context,
        'Use this storage folder?',
        'Current ScriptVault data will be copied into the selected folder.',
      );
      if (confirmed != true) return null;

      await ref
          .read(scriptStorageServiceProvider)
          .switchRootDirectory(Directory(path));
    } on StateError catch (error) {
      throw StateError(error.message);
    } on MissingPluginException {
      throw StateError('Storage folder dialog is unavailable.');
    }

    _refreshStorageBackedProviders();
    return ref
        .read(scriptStorageServiceProvider)
        .getRootDirectory()
        .then((directory) => directory.path);
  }

  Future<String?> resetStorageDirectory(BuildContext context) async {
    final confirmed = await _confirmStorageChange(
      context,
      'Reset storage folder?',
      'Current ScriptVault data will be copied into the default app storage folder.',
    );
    if (confirmed != true) return null;

    await ref.read(scriptStorageServiceProvider).resetRootDirectoryToDefault();
    _refreshStorageBackedProviders();
    return ref
        .read(scriptStorageServiceProvider)
        .getRootDirectory()
        .then((directory) => directory.path);
  }

  Future<bool?> _confirmStorageChange(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _refreshStorageBackedProviders() {
    _autoSaveTimer?.cancel();
    ref.invalidate(currentStorageRootProvider);
    ref.invalidate(appSettingsViewModelProvider);
    ref.invalidate(appLockViewModelProvider);
    ref.invalidate(scriptsListViewModelProvider);
    ref.invalidate(hostsViewModelProvider);
    ref.invalidate(scriptEditorViewModelProvider(widget.scriptId));
  }

  Future<void> checkForUpdates(BuildContext context) async {
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
}
