import 'package:flutter/material.dart';

import '../../../domain/models/host_connection_result.dart';
import '../../../domain/models/host_entry.dart';
import '../../theme/script_vault_style.dart';
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
      color: ScriptVaultStyle.appBackground,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        children: [
          _header(context),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: ScriptVaultStyle.panelDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle(context, 'Connection'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: ScriptVaultStyle.text),
                    decoration: ScriptVaultStyle.inputDecoration(label: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    style: const TextStyle(color: ScriptVaultStyle.text),
                    decoration: ScriptVaultStyle.inputDecoration(
                      label: 'Address',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: usernameController,
                          style: const TextStyle(color: ScriptVaultStyle.text),
                          decoration: ScriptVaultStyle.inputDecoration(
                            label: 'Username',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: portController,
                          style: const TextStyle(color: ScriptVaultStyle.text),
                          decoration: ScriptVaultStyle.inputDecoration(
                            label: 'Port',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(context, 'Authentication'),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? ScriptVaultStyle.panelSoft
                            : ScriptVaultStyle.panel,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? ScriptVaultStyle.primary
                            : ScriptVaultStyle.muted,
                      ),
                    ),
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
                      style: const TextStyle(color: ScriptVaultStyle.text),
                      obscureText: true,
                      decoration: ScriptVaultStyle.inputDecoration(
                        label: 'Password',
                      ),
                    )
                  else
                    TextField(
                      controller: keyPathController,
                      style: const TextStyle(color: ScriptVaultStyle.text),
                      decoration: ScriptVaultStyle.inputDecoration(
                        label: 'Private key path',
                        helperText: 'Leave blank to use your default SSH keys',
                      ),
                    ),
                  const SizedBox(height: 20),
                  _actions(isBusy),
                  if (result != null) ...[
                    const SizedBox(height: 14),
                    HostConnectionResultBanner(result: result!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final title = selectedHost == null ? 'New host' : selectedHost!.name;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ScriptVaultStyle.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Configure where scripts can run remotely.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: ScriptVaultStyle.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String value) {
    return Text(
      value,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: ScriptVaultStyle.muted,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _actions(bool isBusy) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          style: ScriptVaultStyle.toolbarButtonStyle(emphasized: true),
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
        FilledButton.icon(
          style: ScriptVaultStyle.toolbarButtonStyle(),
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
        if (onDelete != null)
          TextButton.icon(
            onPressed: isBusy ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
      ],
    );
  }
}
