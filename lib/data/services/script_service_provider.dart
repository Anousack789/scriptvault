import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_service.dart';
import 'password_hash_service.dart';
import 'script_run_service.dart';
import 'script_storage_service.dart';

final scriptStorageServiceProvider = Provider<ScriptStorageService>((ref) {
  return ScriptStorageService();
});

final scriptRunServiceProvider = Provider<ScriptRunService>((ref) {
  return const ScriptRunService();
});

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService(ref.watch(scriptStorageServiceProvider));
});

final passwordHashServiceProvider = Provider<PasswordHashService>((ref) {
  return const PasswordHashService();
});
