import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/bash.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/host_connection_result.dart';
import '../../domain/models/host_entry.dart';
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
  final ValueChanged<String> onHostChanged;
  final ValueChanged<String> onTargetPathChanged;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String> onArgumentsChanged;
  final VoidCallback onManageHosts;
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
    required this.onHostChanged,
    required this.onTargetPathChanged,
    required this.onTagsChanged,
    required this.onArgumentsChanged,
    required this.onManageHosts,
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
                  onHostChanged: onHostChanged,
                  onTargetPathChanged: onTargetPathChanged,
                  onTagsChanged: onTagsChanged,
                  onArgumentsChanged: onArgumentsChanged,
                  onManageHosts: onManageHosts,
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
  final ValueChanged<String> onHostChanged;
  final ValueChanged<String> onTargetPathChanged;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String> onArgumentsChanged;
  final VoidCallback onManageHosts;

  const _InspectorPane({
    required this.data,
    required this.onNameChanged,
    required this.onGroupChanged,
    required this.onHostChanged,
    required this.onTargetPathChanged,
    required this.onTagsChanged,
    required this.onArgumentsChanged,
    required this.onManageHosts,
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
          _HostSelector(
            value: data.host,
            hosts: data.hosts,
            onChanged: onHostChanged,
            onManageHosts: onManageHosts,
          ),
          const SizedBox(height: 12),
          _BoundTextField(
            value: data.targetPath,
            label: 'Target path',
            onChanged: onTargetPathChanged,
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

class _HostSelector extends StatelessWidget {
  final String value;
  final List<HostEntry> hosts;
  final ValueChanged<String> onChanged;
  final VoidCallback onManageHosts;

  const _HostSelector({
    required this.value,
    required this.hosts,
    required this.onChanged,
    required this.onManageHosts,
  });

  @override
  Widget build(BuildContext context) {
    final knownHostIds = hosts.map((host) => host.id).toSet();
    final selectedValue = value.isEmpty || knownHostIds.contains(value)
        ? value
        : '__legacy_host__';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedValue,
            decoration: const InputDecoration(
              labelText: 'Host',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Local machine')),
              for (final host in hosts)
                DropdownMenuItem(
                  value: host.id,
                  child: Text(
                    '${host.name} (${host.destination})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (selectedValue == '__legacy_host__')
                DropdownMenuItem(
                  value: selectedValue,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (next) {
              if (next == null || next == '__legacy_host__') return;
              onChanged(next);
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Manage hosts',
          icon: const Icon(Icons.dns_outlined),
          onPressed: onManageHosts,
        ),
      ],
    );
  }
}

class HostManagementDialog extends StatefulWidget {
  final List<HostEntry> initialHosts;
  final Future<HostEntry> Function({
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
  })
  onCreate;
  final Future<HostEntry> Function({
    required String id,
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
  })
  onUpdate;
  final Future<void> Function(String id) onDelete;
  final Future<HostConnectionResult> Function({
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
  })
  onTest;

  const HostManagementDialog({
    super.key,
    required this.initialHosts,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
    required this.onTest,
  });

  @override
  State<HostManagementDialog> createState() => _HostManagementDialogState();
}

class _HostManagementDialogState extends State<HostManagementDialog> {
  late List<HostEntry> _hosts;
  HostEntry? _selectedHost;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _passwordController = TextEditingController();
  final _keyPathController = TextEditingController();
  var _authType = 'key';
  var _saving = false;
  var _testing = false;
  HostConnectionResult? _testResult;

  @override
  void initState() {
    super.initState();
    _hosts = [...widget.initialHosts];
    if (_hosts.isNotEmpty) {
      _selectHost(_hosts.first);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _usernameController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    _keyPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hosts'),
      content: SizedBox(
        width: 760,
        height: 460,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : _newHost,
                    icon: const Icon(Icons.add),
                    label: const Text('New host'),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _hosts.isEmpty
                        ? const Center(child: Text('No hosts yet.'))
                        : ListView.builder(
                            itemCount: _hosts.length,
                            itemBuilder: (context, index) {
                              final host = _hosts[index];
                              return ListTile(
                                selected: host.id == _selectedHost?.id,
                                leading: const Icon(Icons.computer_outlined),
                                title: Text(
                                  host.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  host.destination,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: _saving ? null : () => _selectHost(host),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(child: _buildForm(context)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListView(
      children: [
        Text('Connection', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'key',
              icon: Icon(Icons.key_outlined),
              label: Text('Public key'),
            ),
            ButtonSegment(
              value: 'password',
              icon: Icon(Icons.password_outlined),
              label: Text('Password'),
            ),
          ],
          selected: {_authType},
          onSelectionChanged: _saving
              ? null
              : (selection) => setState(() => _authType = selection.single),
        ),
        const SizedBox(height: 12),
        if (_authType == 'password')
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          )
        else
          TextField(
            controller: _keyPathController,
            decoration: const InputDecoration(
              labelText: 'Private key path',
              helperText: 'Leave blank to use your default SSH keys',
              border: OutlineInputBorder(),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_selectedHost == null ? 'Create' : 'Save'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _saving || _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cable_outlined),
              label: const Text('Test'),
            ),
            const SizedBox(width: 8),
            if (_selectedHost != null)
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
          ],
        ),
        if (_testResult != null) ...[
          const SizedBox(height: 12),
          _HostConnectionResultBanner(result: _testResult!),
        ],
      ],
    );
  }

  void _newHost() {
    setState(() {
      _selectedHost = null;
      _nameController.clear();
      _addressController.clear();
      _usernameController.clear();
      _portController.text = '22';
      _passwordController.clear();
      _keyPathController.clear();
      _authType = 'key';
      _testResult = null;
    });
  }

  void _selectHost(HostEntry host) {
    setState(() {
      _selectedHost = host;
      _nameController.text = host.name;
      _addressController.text = host.address;
      _usernameController.text = host.username;
      _portController.text = host.port.toString();
      _passwordController.text = host.password;
      _keyPathController.text = host.keyPath;
      _authType = host.authType;
      _testResult = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final port = int.tryParse(_portController.text.trim()) ?? 22;
      final selected = _selectedHost;
      final host = selected == null
          ? await widget.onCreate(
              name: _nameController.text,
              address: _addressController.text,
              username: _usernameController.text,
              port: port,
              authType: _authType,
              password: _passwordController.text,
              keyPath: _keyPathController.text,
            )
          : await widget.onUpdate(
              id: selected.id,
              name: _nameController.text,
              address: _addressController.text,
              username: _usernameController.text,
              port: port,
              authType: _authType,
              password: _passwordController.text,
              keyPath: _keyPathController.text,
            );
      setState(() {
        final index = _hosts.indexWhere((candidate) => candidate.id == host.id);
        if (index == -1) {
          _hosts.add(host);
        } else {
          _hosts[index] = host;
        }
        _hosts.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        _selectedHost = host;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final selected = _selectedHost;
    if (selected == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete host?'),
        content: Text('Scripts using ${selected.name} will switch to local.'),
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

    setState(() => _saving = true);
    try {
      await widget.onDelete(selected.id);
      final remaining = _hosts.where((host) => host.id != selected.id).toList();
      if (remaining.isEmpty) {
        setState(() {
          _hosts = remaining;
          _selectedHost = null;
          _nameController.clear();
          _addressController.clear();
          _usernameController.clear();
          _portController.text = '22';
          _passwordController.clear();
          _keyPathController.clear();
          _authType = 'key';
        });
      } else {
        _hosts = remaining;
        _selectHost(remaining.first);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final result = await widget.onTest(
        name: _nameController.text,
        address: _addressController.text,
        username: _usernameController.text,
        port: int.tryParse(_portController.text.trim()) ?? 22,
        authType: _authType,
        password: _passwordController.text,
        keyPath: _keyPathController.text,
      );
      if (mounted) {
        setState(() => _testResult = result);
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }
}

class _HostConnectionResultBanner extends StatelessWidget {
  final HostConnectionResult result;

  const _HostConnectionResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.success
        ? const Color(0xFF2E7D32)
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.success ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
