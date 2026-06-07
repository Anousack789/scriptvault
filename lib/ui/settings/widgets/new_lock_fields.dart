import 'package:flutter/material.dart';

class NewLockFields extends StatelessWidget {
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final String? errorText;
  final bool enabled;
  final bool autofocus;

  const NewLockFields({
    super.key,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.errorText,
    required this.enabled,
    required this.autofocus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: newPasswordController,
          autofocus: autofocus,
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
          decoration: InputDecoration(
            labelText: 'Confirm password',
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
