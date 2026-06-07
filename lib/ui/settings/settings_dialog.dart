import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/app_settings.dart';
import 'app_update_viewmodel.dart';
import 'widgets/existing_lock_fields.dart';
import 'widgets/new_lock_fields.dart';

class SettingsDialog extends StatefulWidget {
  final AppSettings settings;
  final AppUpdateState updateState;
  final ValueChanged<double> onEditorFontSizeSaved;
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
    required this.onEditorFontSizeSaved,
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
  late final TextEditingController _fontSizeController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  var _isSaving = false;
  String? _lockErrorText;

  @override
  void initState() {
    super.initState();
    _editorFontSize = widget.settings.editorFontSize;
    _fontSizeController = TextEditingController(
      text: _formatFontSize(_editorFontSize),
    );
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
