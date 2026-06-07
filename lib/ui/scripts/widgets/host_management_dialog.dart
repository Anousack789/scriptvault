import 'package:flutter/material.dart';

import '../../../domain/models/host_connection_result.dart';
import '../../../domain/models/host_entry.dart';
import '../../widgets/host_connection_result_banner.dart';

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
          HostConnectionResultBanner(result: _testResult!),
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
