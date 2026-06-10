import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/script_service_provider.dart';
import '../../domain/models/app_settings.dart';

class AppSettingsViewModel extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(appSettingsServiceProvider).loadSettings();
  }

  Future<void> updateEditorFontSize(double value) async {
    final current = state.value ?? const AppSettings();
    final settings = current.copyWith(
      editorFontSize: AppSettings.normalizeEditorFontSize(value),
    );
    state = AsyncData(settings);
    await ref.read(appSettingsServiceProvider).saveSettings(settings);
  }

  Future<void> updateAutoSaveEnabled(bool value) async {
    final current = state.value ?? const AppSettings();
    final settings = current.copyWith(autoSaveEnabled: value);
    state = AsyncData(settings);
    await ref.read(appSettingsServiceProvider).saveSettings(settings);
  }

  Future<void> setLockPassword(String password) async {
    final current =
        state.value ??
        await ref.read(appSettingsServiceProvider).loadSettings();
    final passwordHash = ref
        .read(passwordHashServiceProvider)
        .createHash(password);
    final settings = current.copyWith(
      lockPasswordHash: passwordHash.hash,
      lockPasswordSalt: passwordHash.salt,
    );
    state = AsyncData(settings);
    await ref.read(appSettingsServiceProvider).saveSettings(settings);
  }

  Future<bool> changeLockPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current =
        state.value ??
        await ref.read(appSettingsServiceProvider).loadSettings();
    if (!_verifyPassword(current, currentPassword)) return false;

    final passwordHash = ref
        .read(passwordHashServiceProvider)
        .createHash(newPassword);
    final settings = current.copyWith(
      lockPasswordHash: passwordHash.hash,
      lockPasswordSalt: passwordHash.salt,
    );
    state = AsyncData(settings);
    await ref.read(appSettingsServiceProvider).saveSettings(settings);
    return true;
  }

  Future<bool> disableLock(String currentPassword) async {
    final current =
        state.value ??
        await ref.read(appSettingsServiceProvider).loadSettings();
    if (!_verifyPassword(current, currentPassword)) return false;

    final settings = current.copyWith(clearLockPassword: true);
    state = AsyncData(settings);
    await ref.read(appSettingsServiceProvider).saveSettings(settings);
    return true;
  }

  bool verifyLockPassword(String password) {
    final current = state.value;
    if (current == null) return false;
    return _verifyPassword(current, password);
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

final appSettingsViewModelProvider =
    AsyncNotifierProvider<AppSettingsViewModel, AppSettings>(
      AppSettingsViewModel.new,
    );
