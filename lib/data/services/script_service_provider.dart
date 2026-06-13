import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'app_update_service.dart';
import 'app_settings_service.dart';
import 'password_hash_service.dart';
import 'secret_crypto_service.dart';
import 'script_run_service.dart';
import 'script_storage_service.dart';
import 'storage_location_service.dart';
import 'vault_transfer_service.dart';

final storageLocationServiceProvider = Provider<StorageLocationService>((ref) {
  return const StorageLocationService();
});

final scriptStorageServiceProvider = Provider<ScriptStorageService>((ref) {
  return ScriptStorageService(
    locationService: ref.watch(storageLocationServiceProvider),
  );
});

final currentStorageRootProvider = FutureProvider<String>((ref) async {
  return ref
      .watch(scriptStorageServiceProvider)
      .getRootDirectory()
      .then((directory) => directory.path);
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

final secretCryptoServiceProvider = Provider<SecretCryptoService>((ref) {
  return SecretCryptoService();
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(client: ref.watch(httpClientProvider));
});

final vaultTransferServiceProvider = Provider<VaultTransferService>((ref) {
  return VaultTransferService(ref.watch(scriptStorageServiceProvider));
});
