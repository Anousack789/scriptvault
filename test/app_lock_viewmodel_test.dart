import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scriptvault/data/services/app_settings_service.dart';
import 'package:scriptvault/data/services/password_hash_service.dart';
import 'package:scriptvault/data/services/script_service_provider.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';
import 'package:scriptvault/domain/models/app_settings.dart';
import 'package:scriptvault/ui/lock/app_lock_viewmodel.dart';
import 'package:scriptvault/ui/settings/app_settings_viewmodel.dart';

void main() {
  late Directory tempDirectory;
  late ScriptStorageService storageService;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'scriptvault_lock_vm_',
    );
    storageService = ScriptStorageService(rootDirectory: tempDirectory);
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        scriptStorageServiceProvider.overrideWith((ref) => storageService),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts unlocked when no password exists', () async {
    final container = createContainer();

    final state = await container.read(appLockViewModelProvider.future);

    expect(state.isLocked, isFalse);
    expect(state.lockEnabled, isFalse);
  });

  test('starts locked and unlocks with the correct password', () async {
    const passwordService = PasswordHashService();
    final passwordHash = passwordService.createHash('secret');
    await AppSettingsService(storageService).saveSettings(
      AppSettings(
        lockPasswordHash: passwordHash.hash,
        lockPasswordSalt: passwordHash.salt,
      ),
    );
    final container = createContainer();

    final initial = await container.read(appLockViewModelProvider.future);
    expect(initial.isLocked, isTrue);
    expect(initial.lockEnabled, isTrue);

    final wrongPassword = await container
        .read(appLockViewModelProvider.notifier)
        .unlock('wrong');
    expect(wrongPassword, isFalse);
    expect(container.read(appLockViewModelProvider).value!.isLocked, isTrue);

    final correctPassword = await container
        .read(appLockViewModelProvider.notifier)
        .unlock('secret');
    expect(correctPassword, isTrue);
    expect(container.read(appLockViewModelProvider).value!.isLocked, isFalse);
  });

  test('settings view model changes and disables lock password', () async {
    final container = createContainer();
    await container.read(appSettingsViewModelProvider.future);

    await container
        .read(appSettingsViewModelProvider.notifier)
        .setLockPassword('secret');
    var settings = await AppSettingsService(storageService).loadSettings();
    expect(settings.lockEnabled, isTrue);

    final rejected = await container
        .read(appSettingsViewModelProvider.notifier)
        .changeLockPassword(currentPassword: 'wrong', newPassword: 'changed');
    expect(rejected, isFalse);

    final changed = await container
        .read(appSettingsViewModelProvider.notifier)
        .changeLockPassword(currentPassword: 'secret', newPassword: 'changed');
    expect(changed, isTrue);

    final disabled = await container
        .read(appSettingsViewModelProvider.notifier)
        .disableLock('changed');
    expect(disabled, isTrue);

    settings = await AppSettingsService(storageService).loadSettings();
    expect(settings.lockEnabled, isFalse);
  });
}
