import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/bash.dart';

import '../../domain/models/app_settings.dart';
import '../../router/router.dart';
import '../lock/app_lock_viewmodel.dart';
import '../settings/app_settings_viewmodel.dart';
import '../settings/settings_dialog.dart';
import 'script_editor_viewmodel.dart';
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
  late final CodeController _codeController;
  var _syncingFromState = false;

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(language: bash);
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
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
        return EditorWorkspace(
          scriptId: widget.scriptId,
          data: data,
          editorFontSize:
              settings.value?.editorFontSize ??
              AppSettings.defaultEditorFontSize,
          codeController: _codeController,
          onNameChanged: viewModel.updateName,
          onGroupChanged: viewModel.updateGroup,
          onHostChanged: viewModel.updateHost,
          onTargetPathChanged: viewModel.updateTargetPath,
          onTagsChanged: viewModel.updateTags,
          onArgumentsChanged: viewModel.updateArguments,
          onManageHosts: () => _manageHosts(context, viewModel),
          onSave: () => _save(context, viewModel),
          onDelete: widget.scriptId == null
              ? null
              : () => _delete(context, viewModel),
          onRun: data.canRun ? () => _run(context, viewModel) : null,
          onSettings: () => _showSettings(context),
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
    final id = await viewModel.save();
    if (!context.mounted) return;
    if (widget.embedded) {
      widget.onSaved?.call(id);
    } else {
      context.go(AppRoutes.editScriptPath(id));
    }
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
}
