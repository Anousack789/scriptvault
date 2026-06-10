import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/secret_entry.dart';
import '../settings/app_settings_viewmodel.dart';
import '../theme/script_vault_style.dart';
import 'secrets_viewmodel.dart';

class SecretsView extends ConsumerStatefulWidget {
  const SecretsView({super.key});

  @override
  ConsumerState<SecretsView> createState() => _SecretsViewState();
}

class _SecretsViewState extends ConsumerState<SecretsView> {
  SecretEntry? _selectedSecret;
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _setupPasswordController = TextEditingController();
  final _unlockController = TextEditingController();
  var _unlockWithRestoreKey = false;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _setupPasswordController.dispose();
    _unlockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(secretsViewModelProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (data) {
        _syncSelection(data.secrets);
        return Container(
          color: ScriptVaultStyle.appBackground,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 300, child: _buildSidebar(context, data)),
              Container(width: 1, color: ScriptVaultStyle.border),
              Expanded(child: _buildContent(context, data)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, SecretsState data) {
    return Material(
      color: ScriptVaultStyle.appBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: FilledButton.icon(
              style: ScriptVaultStyle.toolbarButtonStyle(),
              onPressed: data.isUnlocked && !data.isSaving ? _newSecret : null,
              icon: const Icon(Icons.add, size: 19),
              label: const Text('New secret'),
            ),
          ),
          Expanded(
            child: data.secrets.isEmpty
                ? Center(
                    child: Text(
                      'No secrets found.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ScriptVaultStyle.muted,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: data.secrets.length,
                    itemBuilder: (context, index) {
                      final secret = data.secrets[index];
                      final selected = secret.id == _selectedSecret?.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: data.isSaving
                                ? null
                                : () => _selectSecret(secret),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: ScriptVaultStyle.panelDecoration(
                                selected: selected,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: ScriptVaultStyle.panelRaised,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: ScriptVaultStyle.border,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.key_outlined,
                                      size: 18,
                                      color: selected
                                          ? ScriptVaultStyle.primary
                                          : ScriptVaultStyle.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      secret.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: ScriptVaultStyle.text,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.circle,
                                    size: 9,
                                    color: selected
                                        ? ScriptVaultStyle.success
                                        : ScriptVaultStyle.subtle,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SecretsState data) {
    if (!data.isConfigured) return _buildSetup(context, data);
    if (!data.isUnlocked) return _buildUnlock(context, data);
    return _buildForm(context, data);
  }

  Widget _buildSetup(BuildContext context, SecretsState data) {
    final lockEnabled =
        ref.watch(appSettingsViewModelProvider).value?.lockEnabled ?? false;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _sectionTitle(context, 'Secret lock'),
        const SizedBox(height: 16),
        TextField(
          controller: _setupPasswordController,
          obscureText: true,
          style: const TextStyle(color: ScriptVaultStyle.text),
          decoration: ScriptVaultStyle.inputDecoration(
            label: lockEnabled ? 'App or secrets password' : 'Secrets password',
          ),
          onSubmitted: (_) => _setupVault(),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: ScriptVaultStyle.toolbarButtonStyle(emphasized: true),
          onPressed: data.isSaving ? null : _setupVault,
          icon: data.isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_outline),
          label: const Text('Create secret lock'),
        ),
      ],
    );
  }

  Widget _buildUnlock(BuildContext context, SecretsState data) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _sectionTitle(context, 'Unlock secrets'),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
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
              value: false,
              icon: Icon(Icons.password_outlined),
              label: Text('Password'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.restore_outlined),
              label: Text('Restore key'),
            ),
          ],
          selected: {_unlockWithRestoreKey},
          onSelectionChanged: data.isSaving
              ? null
              : (selection) {
                  setState(() => _unlockWithRestoreKey = selection.single);
                },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _unlockController,
          obscureText: !_unlockWithRestoreKey,
          style: const TextStyle(color: ScriptVaultStyle.text),
          decoration: ScriptVaultStyle.inputDecoration(
            label: _unlockWithRestoreKey ? 'Restore key' : 'Password',
          ),
          onSubmitted: (_) => _unlock(),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: ScriptVaultStyle.toolbarButtonStyle(emphasized: true),
          onPressed: data.isSaving ? null : _unlock,
          icon: data.isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_open_outlined),
          label: const Text('Unlock'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, SecretsState data) {
    final selected = _selectedSecret;
    final revealed = selected == null ? null : data.revealedValues[selected.id];
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(context, 'Secret')),
            TextButton.icon(
              onPressed: data.isSaving
                  ? null
                  : () => ref.read(secretsViewModelProvider.notifier).lock(),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Lock'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: ScriptVaultStyle.text),
          decoration: ScriptVaultStyle.inputDecoration(label: 'Env var name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _valueController,
          obscureText: true,
          style: const TextStyle(color: ScriptVaultStyle.text),
          decoration: ScriptVaultStyle.inputDecoration(
            label: selected == null ? 'Value' : 'New value',
            helperText: selected == null ? null : 'Leave blank to keep current',
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: ScriptVaultStyle.panelDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    revealed ?? '************',
                    maxLines: 3,
                    style: const TextStyle(color: ScriptVaultStyle.text),
                  ),
                ),
                IconButton(
                  tooltip: revealed == null ? 'Reveal value' : 'Hide value',
                  onPressed: data.isSaving
                      ? null
                      : () {
                          ref
                              .read(secretsViewModelProvider.notifier)
                              .revealSecret(selected.id);
                        },
                  icon: Icon(
                    revealed == null
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              style: ScriptVaultStyle.toolbarButtonStyle(emphasized: true),
              onPressed: data.isSaving ? null : _save,
              icon: data.isSaving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(selected == null ? 'Create' : 'Save'),
            ),
            if (selected != null)
              TextButton.icon(
                onPressed: data.isSaving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
          ],
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

  void _syncSelection(List<SecretEntry> secrets) {
    final selected = _selectedSecret;
    if (selected == null) return;
    final updated = secrets
        .where((secret) => secret.id == selected.id)
        .firstOrNull;
    if (updated == null) {
      _selectedSecret = null;
      return;
    }
    if (updated.updatedAt != selected.updatedAt) {
      _selectedSecret = updated;
      _setForm(updated);
    }
  }

  void _newSecret() {
    setState(() {
      _selectedSecret = null;
      _nameController.clear();
      _valueController.clear();
    });
  }

  void _selectSecret(SecretEntry secret) {
    setState(() {
      _selectedSecret = secret;
      _setForm(secret);
    });
  }

  void _setForm(SecretEntry secret) {
    _nameController.text = secret.name;
    _valueController.clear();
  }

  Future<void> _setupVault() async {
    final restoreKey = await ref
        .read(secretsViewModelProvider.notifier)
        .setupVault(_setupPasswordController.text);
    _setupPasswordController.clear();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore key'),
        content: SizedBox(
          width: 460,
          child: SelectableText(
            restoreKey,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _unlock() async {
    final viewModel = ref.read(secretsViewModelProvider.notifier);
    final unlocked = _unlockWithRestoreKey
        ? await viewModel.unlockWithRestoreKey(_unlockController.text)
        : await viewModel.unlockWithPassword(_unlockController.text);
    if (!unlocked && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to unlock secrets.')),
      );
      return;
    }
    _unlockController.clear();
  }

  Future<void> _save() async {
    final secret = await ref
        .read(secretsViewModelProvider.notifier)
        .saveSecret(
          id: _selectedSecret?.id,
          name: _nameController.text,
          value: _valueController.text,
        );
    _valueController.clear();
    _selectSecret(secret);
  }

  Future<void> _delete() async {
    final selected = _selectedSecret;
    if (selected == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete secret?'),
        content: Text('This removes ${selected.name}.'),
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

    await ref.read(secretsViewModelProvider.notifier).deleteSecret(selected.id);
    _newSecret();
  }
}
