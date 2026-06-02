import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/script_service_provider.dart';
import '../../domain/models/app_settings.dart';

class AppLockState {
  final bool isLocked;
  final bool lockEnabled;

  const AppLockState({required this.isLocked, required this.lockEnabled});

  const AppLockState.unlocked() : isLocked = false, lockEnabled = false;

  AppLockState copyWith({bool? isLocked, bool? lockEnabled}) {
    return AppLockState(
      isLocked: isLocked ?? this.isLocked,
      lockEnabled: lockEnabled ?? this.lockEnabled,
    );
  }
}

class AppLockViewModel extends AsyncNotifier<AppLockState> {
  @override
  Future<AppLockState> build() async {
    final settings = await ref.watch(appSettingsServiceProvider).loadSettings();
    return AppLockState(
      isLocked: settings.lockEnabled,
      lockEnabled: settings.lockEnabled,
    );
  }

  Future<bool> lock() async {
    final settings = await ref.read(appSettingsServiceProvider).loadSettings();
    if (!settings.lockEnabled) {
      state = const AsyncData(AppLockState.unlocked());
      return false;
    }

    state = const AsyncData(AppLockState(isLocked: true, lockEnabled: true));
    return true;
  }

  Future<bool> unlock(String password) async {
    final settings = await ref.read(appSettingsServiceProvider).loadSettings();
    if (!settings.lockEnabled) {
      state = const AsyncData(AppLockState.unlocked());
      return true;
    }

    if (!_verifyPassword(settings, password)) return false;

    state = const AsyncData(AppLockState(isLocked: false, lockEnabled: true));
    return true;
  }

  Future<bool> lockEnabled() async {
    final settings = await ref.read(appSettingsServiceProvider).loadSettings();
    state = AsyncData(
      (state.value ?? const AppLockState.unlocked()).copyWith(
        lockEnabled: settings.lockEnabled,
      ),
    );
    return settings.lockEnabled;
  }

  bool _verifyPassword(AppSettings settings, String password) {
    final hash = settings.lockPasswordHash;
    final salt = settings.lockPasswordSalt;
    if (hash == null || salt == null) return false;
    return ref
        .read(passwordHashServiceProvider)
        .verify(password: password, hash: hash, salt: salt);
  }
}

final appLockViewModelProvider =
    AsyncNotifierProvider<AppLockViewModel, AppLockState>(AppLockViewModel.new);
