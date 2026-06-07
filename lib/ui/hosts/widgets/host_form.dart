import 'package:flutter/material.dart';

import '../../../domain/models/host_connection_result.dart';
import '../../../domain/models/host_entry.dart';
import '../../widgets/host_connection_result_banner.dart';

class HostForm extends StatelessWidget {
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

  const HostForm({
    super.key,
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
                  HostConnectionResultBanner(result: result!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
