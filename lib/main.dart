import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/router_provider.dart';
import 'ui/lock/app_lock_viewmodel.dart';
import 'ui/lock/unlock_view.dart';
import 'ui/theme/script_vault_style.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockState = ref.watch(appLockViewModelProvider);
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: ScriptVaultStyle.primary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: ScriptVaultStyle.appBackground,
      dividerColor: ScriptVaultStyle.border,
      iconTheme: const IconThemeData(color: ScriptVaultStyle.muted),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: ScriptVaultStyle.text,
        displayColor: ScriptVaultStyle.text,
      ),
      useMaterial3: true,
    );

    return lockState.when(
      loading: () => MaterialApp(
        title: 'ScriptVault',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) => MaterialApp(
        title: 'ScriptVault',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(body: Center(child: Text('Error: $error'))),
      ),
      data: (data) {
        if (data.isLocked) {
          return MaterialApp(
            title: 'ScriptVault',
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const UnlockView(),
          );
        }

        return MaterialApp.router(
          title: 'ScriptVault',
          debugShowCheckedModeBanner: false,
          theme: theme,
          routerConfig: ref.watch(routerProvider),
        );
      },
    );
  }
}
