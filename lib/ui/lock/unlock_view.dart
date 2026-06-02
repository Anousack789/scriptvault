import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_viewmodel.dart';

class UnlockView extends ConsumerStatefulWidget {
  const UnlockView({super.key});

  @override
  ConsumerState<UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends ConsumerState<UnlockView> {
  final _passwordController = TextEditingController();
  var _isUnlocking = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 44),
                const SizedBox(height: 18),
                Text(
                  'ScriptVault',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  autofocus: true,
                  obscureText: true,
                  enabled: !_isUnlocking,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: _errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isUnlocking ? null : _unlock,
                    icon: _isUnlocking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open),
                    label: const Text('Unlock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _errorText = 'Enter your password.';
      });
      return;
    }

    setState(() {
      _isUnlocking = true;
      _errorText = null;
    });

    final unlocked = await ref
        .read(appLockViewModelProvider.notifier)
        .unlock(password);
    if (!mounted) return;

    setState(() {
      _isUnlocking = false;
      _errorText = unlocked ? null : 'Incorrect password.';
    });
  }
}
