import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/app_settings.dart';
import 'app_update_viewmodel.dart';
import 'widgets/existing_lock_fields.dart';
import 'widgets/new_lock_fields.dart';

class SettingsDialog extends StatefulWidget {
  final AppSettings settings;
  final AppUpdateState updateState;
  final String storagePath;
  final ValueChanged<double> onEditorFontSizeSaved;
  final ValueChanged<bool> onAutoSaveEnabledSaved;
  final Future<String?> Function() onChooseStorageDirectory;
  final Future<String?> Function() onResetStorageDirectory;
  final Future<String?> Function() onExportVault;
  final Future<String?> Function() onImportVault;
  final Future<void> Function(String password) onLockPasswordSet;
  final Future<bool> Function(String currentPassword, String newPassword)
  onLockPasswordChanged;
  final Future<bool> Function(String currentPassword) onLockDisabled;
  final Future<void> Function() onCheckForUpdates;
  final Future<bool> Function() onOpenUpdateDownload;
  final bool lockSetupRequired;

  const SettingsDialog({
    super.key,
    required this.settings,
    required this.updateState,
    required this.storagePath,
    required this.onEditorFontSizeSaved,
    required this.onAutoSaveEnabledSaved,
    required this.onChooseStorageDirectory,
    required this.onResetStorageDirectory,
    required this.onExportVault,
    required this.onImportVault,
    required this.onLockPasswordSet,
    required this.onLockPasswordChanged,
    required this.onLockDisabled,
    required this.onCheckForUpdates,
    required this.onOpenUpdateDownload,
    this.lockSetupRequired = false,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late double _editorFontSize;
  late bool _autoSaveEnabled;
  late final TextEditingController _fontSizeController;
  late String _storagePath;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  var _isSaving = false;
  String? _lockErrorText;
  String? _storageErrorText;
  String? _storageStatusText;

  @override
  void initState() {
    super.initState();
    _editorFontSize = widget.settings.editorFontSize;
    _autoSaveEnabled = widget.settings.autoSaveEnabled;
    _fontSizeController = TextEditingController(
      text: _formatFontSize(_editorFontSize),
    );
    _storagePath = widget.storagePath;
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _fontSizeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editor font size',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: AppSettings.minEditorFontSize,
                      max: AppSettings.maxEditorFontSize,
                      divisions:
                          (AppSettings.maxEditorFontSize -
                                  AppSettings.minEditorFontSize)
                              .round(),
                      value: _editorFontSize,
                      label: _formatFontSize(_editorFontSize),
                      onChanged: _setEditorFontSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 76,
                    child: TextField(
                      controller: _fontSizeController,
                      decoration: const InputDecoration(
                        suffixText: 'pt',
                        border: OutlineInputBorder(),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      onChanged: _setEditorFontSizeFromText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto save'),
                subtitle: const Text('Save script edits automatically.'),
                value: _autoSaveEnabled,
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _autoSaveEnabled = value),
              ),
              const SizedBox(height: 24),
              Text('Storage', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF3C3C3C)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        _storagePath,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_storageErrorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _storageErrorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (_storageStatusText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _storageStatusText!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : _chooseStorageDirectory,
                            icon: const Icon(Icons.folder_open_outlined),
                            label: const Text('Choose folder'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : _resetStorageDirectory,
                            icon: const Icon(Icons.restore_outlined),
                            label: const Text('Reset default'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isSaving ? null : _exportVault,
                            icon: const Icon(Icons.ios_share_outlined),
                            label: const Text('Export vault'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isSaving ? null : _importVault,
                            icon: const Icon(Icons.archive_outlined),
                            label: const Text('Import vault'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('App lock', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              if (widget.settings.lockEnabled)
                ExistingLockFields(
                  currentPasswordController: _currentPasswordController,
                  newPasswordController: _newPasswordController,
                  confirmPasswordController: _confirmPasswordController,
                  errorText: _lockErrorText,
                  enabled: !_isSaving,
                  onDisable: _disableLock,
                )
              else
                NewLockFields(
                  newPasswordController: _newPasswordController,
                  confirmPasswordController: _confirmPasswordController,
                  errorText: _lockErrorText,
                  enabled: !_isSaving,
                  autofocus: widget.lockSetupRequired,
                ),
              const SizedBox(height: 24),
              Text('Updates', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              _UpdateSection(
                state: widget.updateState,
                onCheckForUpdates: widget.onCheckForUpdates,
                onOpenUpdateDownload: widget.onOpenUpdateDownload,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _setEditorFontSize(double value) {
    final normalized = AppSettings.normalizeEditorFontSize(value);
    setState(() {
      _editorFontSize = normalized;
      _fontSizeController.text = _formatFontSize(normalized);
    });
  }

  void _setEditorFontSizeFromText(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    final normalized = AppSettings.normalizeEditorFontSize(parsed);
    setState(() {
      _editorFontSize = normalized;
    });
  }

  String _formatFontSize(double value) {
    return value.round().toString();
  }

  Future<void> _chooseStorageDirectory() async {
    await _runStorageChange(widget.onChooseStorageDirectory);
  }

  Future<void> _resetStorageDirectory() async {
    await _runStorageChange(widget.onResetStorageDirectory);
  }

  Future<void> _exportVault() async {
    await _runStorageAction(widget.onExportVault);
  }

  Future<void> _importVault() async {
    await _runStorageAction(widget.onImportVault);
  }

  Future<void> _runStorageChange(Future<String?> Function() change) async {
    setState(() {
      _isSaving = true;
      _storageErrorText = null;
      _storageStatusText = null;
    });

    try {
      final path = await change();
      if (!mounted) return;
      if (path != null && path.isNotEmpty) {
        setState(() => _storagePath = path);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _storageErrorText = _formatStorageError(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _runStorageAction(Future<String?> Function() action) async {
    setState(() {
      _isSaving = true;
      _storageErrorText = null;
      _storageStatusText = null;
    });

    try {
      final message = await action();
      if (!mounted) return;
      if (message != null && message.isNotEmpty) {
        setState(() => _storageStatusText = message);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _storageErrorText = _formatStorageError(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatStorageError(Object error) {
    if (error is StateError) return error.message;
    return error.toString();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _lockErrorText = null;
    });

    final saved = await _saveLockChangeIfNeeded();
    if (!mounted) return;

    if (!saved) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    widget.onEditorFontSizeSaved(_editorFontSize);
    widget.onAutoSaveEnabledSaved(_autoSaveEnabled);
    Navigator.of(context).pop();
  }

  Future<bool> _saveLockChangeIfNeeded() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final hasPasswordInput =
        currentPassword.isNotEmpty ||
        newPassword.isNotEmpty ||
        confirmPassword.isNotEmpty;

    if (!widget.settings.lockEnabled && !hasPasswordInput) {
      if (widget.lockSetupRequired) {
        _setLockError('Enter a password to enable app lock.');
        return false;
      }
      return true;
    }

    if (!widget.settings.lockEnabled) {
      if (!_validateNewPassword(newPassword, confirmPassword)) return false;
      await widget.onLockPasswordSet(newPassword);
      return true;
    }

    if (!hasPasswordInput) return true;
    if (currentPassword.isEmpty) {
      _setLockError('Enter your current password.');
      return false;
    }
    if (!_validateNewPassword(newPassword, confirmPassword)) return false;

    final changed = await widget.onLockPasswordChanged(
      currentPassword,
      newPassword,
    );
    if (!changed) {
      _setLockError('Current password is incorrect.');
    }
    return changed;
  }

  Future<void> _disableLock() async {
    final currentPassword = _currentPasswordController.text;
    if (currentPassword.isEmpty) {
      setState(() {
        _lockErrorText = 'Enter your current password to disable app lock.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _lockErrorText = null;
    });

    final disabled = await widget.onLockDisabled(currentPassword);
    if (!mounted) return;

    if (!disabled) {
      setState(() {
        _isSaving = false;
        _lockErrorText = 'Current password is incorrect.';
      });
      return;
    }

    widget.onEditorFontSizeSaved(_editorFontSize);
    widget.onAutoSaveEnabledSaved(_autoSaveEnabled);
    Navigator.of(context).pop();
  }

  bool _validateNewPassword(String password, String confirmation) {
    if (password.isEmpty) {
      _setLockError('Enter a new password.');
      return false;
    }
    if (confirmation.isEmpty) {
      _setLockError('Confirm the new password.');
      return false;
    }
    if (password != confirmation) {
      _setLockError('Passwords do not match.');
      return false;
    }
    return true;
  }

  void _setLockError(String value) {
    setState(() {
      _lockErrorText = value;
    });
  }
}

class _UpdateSection extends StatelessWidget {
  final AppUpdateState state;
  final Future<void> Function() onCheckForUpdates;
  final Future<bool> Function() onOpenUpdateDownload;

  const _UpdateSection({
    required this.state,
    required this.onCheckForUpdates,
    required this.onOpenUpdateDownload,
  });

  @override
  Widget build(BuildContext context) {
    final updateInfo = state.updateInfo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.status == AppUpdateStatus.noUpdate)
          Text(
            'ScriptVault is up to date.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else if (state.status == AppUpdateStatus.checkFailed)
          Text(
            state.errorMessage ?? 'Unable to check for updates.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (updateInfo != null)
          Text(
            'Version ${updateInfo.latestVersion} is available.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Text(
            'Check GitHub Releases for a newer version.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: state.isChecking ? null : onCheckForUpdates,
              icon: state.isChecking
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                state.isChecking ? 'Checking...' : 'Check for Updates',
              ),
            ),
            if (updateInfo != null) ...[
              TextButton.icon(
                onPressed: onOpenUpdateDownload,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
