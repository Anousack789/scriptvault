import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/host_connection_result.dart';
import '../../domain/models/host_entry.dart';
import '../scripts/script_editor_viewmodel.dart';
import '../scripts/scripts_list_viewmodel.dart';
import 'hosts_viewmodel.dart';

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
              child: _HostsSidebar(
                hosts: data.hosts,
                selectedHostId: _selectedHost?.id,
                isBusy: data.isSaving || data.isTesting,
                onNewHost: _newHost,
                onHostSelected: _selectHost,
              ),
            ),
            Container(width: 1, color: const Color(0xFF2D2D30)),
            Expanded(
              child: _HostForm(
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

class _HostsSidebar extends StatelessWidget {
  final List<HostEntry> hosts;
  final String? selectedHostId;
  final bool isBusy;
  final VoidCallback onNewHost;
  final ValueChanged<HostEntry> onHostSelected;

  const _HostsSidebar({
    required this.hosts,
    required this.selectedHostId,
    required this.isBusy,
    required this.onNewHost,
    required this.onHostSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252526),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2D2D30))),
            ),
            child: Row(
              children: [
                const Icon(Icons.dns_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hosts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'New host',
                  onPressed: isBusy ? null : onNewHost,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: hosts.isEmpty
                ? const Center(child: Text('No hosts found.'))
                : ListView.builder(
                    itemCount: hosts.length,
                    itemBuilder: (context, index) {
                      final host = hosts[index];
                      return ListTile(
                        selected: host.id == selectedHostId,
                        leading: const Icon(Icons.computer_outlined),
                        title: Text(
                          host.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          host.destination,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: isBusy ? null : () => onHostSelected(host),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HostForm extends StatelessWidget {
  final HostEntry? selectedHost;
  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController usernameController;
  final TextEditingController portController;
  final TextEditingController passwordController;
  final TextEditingController keyPathController;
  final String authType;
  final HostConnectionResult? result;
  final bool isSaving;
  final bool isTesting;
  final ValueChanged<String> onAuthTypeChanged;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final VoidCallback onTest;

  const _HostForm({
    required this.selectedHost,
    required this.nameController,
    required this.addressController,
    required this.usernameController,
    required this.portController,
    required this.passwordController,
    required this.keyPathController,
    required this.authType,
    required this.result,
    required this.isSaving,
    required this.isTesting,
    required this.onAuthTypeChanged,
    required this.onSave,
    required this.onDelete,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = isSaving || isTesting;
    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            selectedHost == null ? 'New host' : selectedHost!.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
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
                        controller: usernameController,
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
                        controller: portController,
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
                  selected: {authType},
                  onSelectionChanged: isBusy
                      ? null
                      : (selection) => onAuthTypeChanged(selection.single),
                ),
                const SizedBox(height: 12),
                if (authType == 'password')
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  TextField(
                    controller: keyPathController,
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
                      onPressed: isBusy ? null : onSave,
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(selectedHost == null ? 'Create' : 'Save'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: isBusy ? null : onTest,
                      icon: isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cable_outlined),
                      label: const Text('Test'),
                    ),
                    const SizedBox(width: 8),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: isBusy ? null : onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                  ],
                ),
                if (result != null) ...[
                  const SizedBox(height: 12),
                  _HostConnectionResultBanner(result: result!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
