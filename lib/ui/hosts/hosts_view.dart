import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/host_entry.dart';
import '../scripts/script_editor_viewmodel.dart';
import '../scripts/scripts_list_viewmodel.dart';
import 'hosts_viewmodel.dart';
import 'widgets/host_form.dart';
import 'widgets/hosts_sidebar.dart';

class HostsView extends ConsumerStatefulWidget {
  const HostsView({super.key});

  @override
  ConsumerState<HostsView> createState() => _HostsViewState();
}

class _HostsViewState extends ConsumerState<HostsView> {
  HostEntry? _selectedHost;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _passwordController = TextEditingController();
  final _keyPathController = TextEditingController();
  var _authType = 'key';

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
    final state = ref.watch(hostsViewModelProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (data) {
        _syncSelection(data.hosts);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 320,
              child: HostsSidebar(
                hosts: data.hosts,
                selectedHostId: _selectedHost?.id,
                isBusy: data.isSaving || data.isTesting,
                onNewHost: _newHost,
                onHostSelected: _selectHost,
              ),
            ),
            Container(width: 1, color: const Color(0xFF2D2D30)),
            Expanded(
              child: HostForm(
                selectedHost: _selectedHost,
                nameController: _nameController,
                addressController: _addressController,
                usernameController: _usernameController,
                portController: _portController,
                passwordController: _passwordController,
                keyPathController: _keyPathController,
                authType: _authType,
                result: data.testResult,
                isSaving: data.isSaving,
                isTesting: data.isTesting,
                onAuthTypeChanged: (value) => setState(() => _authType = value),
                onSave: _save,
                onDelete: _selectedHost == null ? null : _delete,
                onTest: _testConnection,
              ),
            ),
          ],
        );
      },
    );
  }

  void _syncSelection(List<HostEntry> hosts) {
    final selected = _selectedHost;
    if (selected == null) return;
    final updated = hosts.where((host) => host.id == selected.id).firstOrNull;
    if (updated == null) {
      _selectedHost = null;
      return;
    }
    if (updated.updatedAt != selected.updatedAt) {
      _selectedHost = updated;
      _setForm(updated);
    }
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
    });
  }

  void _selectHost(HostEntry host) {
    setState(() {
      _selectedHost = host;
      _setForm(host);
    });
  }

  void _setForm(HostEntry host) {
    _nameController.text = host.name;
    _addressController.text = host.address;
    _usernameController.text = host.username;
    _portController.text = host.port.toString();
    _passwordController.text = host.password;
    _keyPathController.text = host.keyPath;
    _authType = host.authType;
  }

  Future<void> _save() async {
    final host = await ref
        .read(hostsViewModelProvider.notifier)
        .saveHost(
          id: _selectedHost?.id,
          name: _nameController.text,
          address: _addressController.text,
          username: _usernameController.text,
          port: int.tryParse(_portController.text.trim()) ?? 22,
          authType: _authType,
          password: _passwordController.text,
          keyPath: _keyPathController.text,
        );
    _selectHost(host);
    _refreshScriptHostConsumers();
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

    await ref.read(hostsViewModelProvider.notifier).deleteHost(selected.id);
    _newHost();
    _refreshScriptHostConsumers();
  }

  Future<void> _testConnection() {
    return ref
        .read(hostsViewModelProvider.notifier)
        .testConnection(
          name: _nameController.text,
          address: _addressController.text,
          username: _usernameController.text,
          port: int.tryParse(_portController.text.trim()) ?? 22,
          authType: _authType,
          password: _passwordController.text,
          keyPath: _keyPathController.text,
        );
  }

  void _refreshScriptHostConsumers() {
    ref.invalidate(scriptsListViewModelProvider);
    ref.invalidate(scriptEditorViewModelProvider(null));
  }
}
