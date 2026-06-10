import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scriptvault/data/repositories/secret_repository.dart';
import 'package:scriptvault/data/services/secret_crypto_service.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';

void main() {
  late Directory tempDirectory;
  late ScriptStorageService storageService;
  late SecretRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'scriptvault_secrets_',
    );
    storageService = ScriptStorageService(rootDirectory: tempDirectory);
    repository = SecretRepository(storageService, SecretCryptoService());
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'sets up, unlocks, creates, reveals, updates, and deletes secrets',
    () async {
      final restoreKey = await repository.setupVault('secret-password');
      final created = await repository.createSecret(
        name: ' db-password ',
        value: 'super-secret',
      );

      expect(created.name, 'DB_PASSWORD');
      expect(await repository.revealSecret(created.id), 'super-secret');

      repository.lock();
      expect(repository.isUnlocked, isFalse);
      expect(await repository.unlockWithPassword('wrong'), isFalse);
      expect(await repository.unlockWithPassword('secret-password'), isTrue);

      final renamed = await repository.updateSecret(
        id: created.id,
        name: 'deploy key',
      );
      expect(renamed.name, 'DEPLOY_KEY');
      expect(await repository.revealSecret(created.id), 'super-secret');

      repository.lock();
      expect(await repository.unlockWithRestoreKey(restoreKey), isTrue);
      await repository.deleteSecret(created.id);
      expect(await repository.listSecrets(), isEmpty);
    },
  );

  test('does not store plaintext secret values', () async {
    await repository.setupVault('secret-password');
    await repository.createSecret(name: 'TOKEN', value: 'plain-token-value');

    final raw = await File(
      p.join(tempDirectory.path, 'secret_index.json'),
    ).readAsString();

    expect(raw, isNot(contains('plain-token-value')));
    expect(raw, contains('TOKEN'));
  });
}
