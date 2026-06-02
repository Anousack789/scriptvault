import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/bash.dart';

import '../../domain/models/app_settings.dart';
import '../../router/router.dart';
import '../lock/app_lock_viewmodel.dart';
import '../settings/app_settings_viewmodel.dart';
import '../settings/settings_dialog.dart';
import 'script_editor_viewmodel.dart';
import 'widgets/script_run_output.dart';

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
        return _EditorWorkspace(
          scriptId: widget.scriptId,
          data: data,
          editorFontSize:
              settings.value?.editorFontSize ??
              AppSettings.defaultEditorFontSize,
          codeController: _codeController,
          onNameChanged: viewModel.updateName,
          onGroupChanged: viewModel.updateGroup,
          onTagsChanged: viewModel.updateTags,
          onArgumentsChanged: viewModel.updateArguments,
          onSave: () => _save(context, viewModel),
          onDelete: widget.scriptId == null
              ? null
              : () => _delete(context, viewModel),
          onRun: data.canRun ? () => _run(context, viewModel) : null,
          onSettings: () => _showSettings(context),
          onLock: () => _lock(context),
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

class _EditorWorkspace extends StatelessWidget {
  final String? scriptId;
  final ScriptEditorState data;
  final double editorFontSize;
  final CodeController codeController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String> onArgumentsChanged;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onRun;
  final VoidCallback onSettings;
  final VoidCallback onLock;
  final VoidCallback? onClose;
  final bool embedded;

  const _EditorWorkspace({
    required this.scriptId,
    required this.data,
    required this.editorFontSize,
    required this.codeController,
    required this.onNameChanged,
    required this.onGroupChanged,
    required this.onTagsChanged,
    required this.onArgumentsChanged,
    required this.onSave,
    required this.onDelete,
    required this.onRun,
    required this.onSettings,
    required this.onLock,
    required this.onClose,
    required this.embedded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EditorToolbar(
          title: scriptId == null ? 'New script' : data.name,
          subtitle: scriptId == null ? 'Unsaved script' : data.group,
          onSave: onSave,
          onDelete: onDelete,
          onRun: onRun,
          onSettings: onSettings,
          onLock: onLock,
          onClose: onClose,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: CodeTheme(
                      data: CodeThemeData(styles: vs2015Theme),
                      child: CodeField(
                        controller: codeController,
                        textStyle: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: editorFontSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, color: const Color(0xFF2D2D30)),
              SizedBox(
                width: embedded ? 320 : 360,
                child: _InspectorPane(
                  data: data,
                  onNameChanged: onNameChanged,
                  onGroupChanged: onGroupChanged,
                  onTagsChanged: onTagsChanged,
                  onArgumentsChanged: onArgumentsChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onRun;
  final VoidCallback onSettings;
  final VoidCallback onLock;
  final VoidCallback? onClose;

  const _EditorToolbar({
    required this.title,
    required this.subtitle,
    required this.onSave,
    required this.onDelete,
    required this.onRun,
    required this.onSettings,
    required this.onLock,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D30))),
      ),
      child: Row(
        children: [
          if (onClose != null)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: onClose,
            ),
          const Icon(Icons.terminal, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Untitled script' : title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9DA5B4),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Run',
            icon: const Icon(Icons.play_arrow),
            onPressed: onRun,
          ),
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save_outlined),
            onPressed: onSave,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: onSettings,
          ),
          IconButton(
            tooltip: 'Lock',
            icon: const Icon(Icons.lock_outline),
            onPressed: onLock,
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _InspectorPane extends StatelessWidget {
  final ScriptEditorState data;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String> onArgumentsChanged;

  const _InspectorPane({
    required this.data,
    required this.onNameChanged,
    required this.onGroupChanged,
    required this.onTagsChanged,
    required this.onArgumentsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252526),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Details', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          _BoundTextField(
            value: data.name,
            label: 'Script name',
            onChanged: onNameChanged,
          ),
          const SizedBox(height: 12),
          _BoundTextField(
            value: data.group,
            label: 'Group',
            onChanged: onGroupChanged,
          ),
          const SizedBox(height: 12),
          _BoundTextField(
            value: data.tagsText,
            label: 'Tags',
            helperText: 'Comma-separated',
            onChanged: onTagsChanged,
          ),
          const SizedBox(height: 20),
          Text('Run', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Arguments',
              border: OutlineInputBorder(),
            ),
            onChanged: onArgumentsChanged,
          ),
          const SizedBox(height: 16),
          ScriptRunOutput(
            result: data.lastRunResult,
            isRunning: data.isRunning,
          ),
        ],
      ),
    );
  }
}

class _BoundTextField extends StatefulWidget {
  final String value;
  final String label;
  final String? helperText;
  final ValueChanged<String> onChanged;

  const _BoundTextField({
    required this.value,
    required this.label,
    this.helperText,
    required this.onChanged,
  });

  @override
  State<_BoundTextField> createState() => _BoundTextFieldState();
}

class _BoundTextFieldState extends State<_BoundTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _BoundTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}
