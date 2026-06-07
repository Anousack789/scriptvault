import 'package:flutter/material.dart';

class ExistingLockFields extends StatelessWidget {
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final String? errorText;
  final bool enabled;
  final VoidCallback onDisable;

  const ExistingLockFields({
    super.key,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.errorText,
    required this.enabled,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: currentPasswordController,
          enabled: enabled,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Current password',
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: newPasswordController,
          enabled: enabled,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: confirmPasswordController,
          enabled: enabled,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirm password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: enabled ? onDisable : null,
          icon: const Icon(Icons.lock_open_outlined),
          label: const Text('Disable app lock'),
        ),
      ],
    );
  }
}
