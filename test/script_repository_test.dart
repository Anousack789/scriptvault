import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scriptvault/data/repositories/host_repository.dart';
import 'package:scriptvault/data/repositories/secret_repository.dart';
import 'package:scriptvault/data/repositories/script_repository.dart';
import 'package:scriptvault/data/services/secret_crypto_service.dart';
import 'package:scriptvault/data/services/script_run_service.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';

void main() {
  late Directory tempDirectory;
  late ScriptRepository repository;
  late ScriptStorageService storageService;
  late HostRepository hostRepository;
  late SecretRepository secretRepository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('scriptvault_repo_');
    storageService = ScriptStorageService(rootDirectory: tempDirectory);
    hostRepository = HostRepository(storageService, const ScriptRunService());
    secretRepository = SecretRepository(storageService, SecretCryptoService());
    repository = ScriptRepository(
      storageService,
      const ScriptRunService(),
      hostRepository,
      secretRepository: secretRepository,
    );
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('creates, updates, and deletes a script', () async {
    final created = await repository.createScript(
      name: 'List Files',
      group: 'Maintenance',
      host: ' app.example.com ',
      targetPath: ' /var/www/app ',
      tags: ['files', ' daily ', 'files'],
      content: 'ls -la',
    );

    expect(created.entry.name, 'List Files');
    expect(created.entry.group, 'Maintenance');
    expect(created.entry.host, 'app.example.com');
    expect(created.entry.targetPath, '/var/www/app');
    expect(created.entry.tags, ['daily', 'files']);
    expect((await repository.listScripts()).length, 1);

    final updated = await repository.updateScript(
      id: created.entry.id,
      name: 'List Root',
      group: 'Inspection',
      host: 'db.example.com',
      targetPath: '/srv/db',
      tags: ['root'],
      content: 'ls /',
    );

    expect(updated.entry.name, 'List Root');
    expect(updated.entry.host, 'db.example.com');
    expect(updated.entry.targetPath, '/srv/db');
    expect(updated.content, 'ls /');
    expect((await repository.getScript(created.entry.id))!.content, 'ls /');

    await repository.deleteScript(created.entry.id);

    expect(await repository.listScripts(), isEmpty);
    expect(await repository.getScript(created.entry.id), isNull);
  });

  test('imports a script file into managed storage', () async {
    final sourceFile = File(p.join(tempDirectory.path, 'daily-backup.sh'));
    await sourceFile.writeAsString('echo backup');

    final imported = await repository.importScriptFile(sourceFile.path);

    expect(imported.entry.name, 'daily-backup');
    expect(imported.entry.group, 'General');
    expect(imported.entry.host, isEmpty);
    expect(imported.entry.targetPath, isEmpty);
    expect(imported.entry.tags, isEmpty);
    expect(imported.content, 'echo backup');
    expect(
      (await repository.getScript(imported.entry.id))!.content,
      'echo backup',
    );
  });

  test('migrates scripts from legacy sandbox storage', () async {
    final newRoot = Directory(p.join(tempDirectory.path, 'new'));
    final legacyRoot = Directory(p.join(tempDirectory.path, 'legacy'));
    final legacyStorage = ScriptStorageService(rootDirectory: legacyRoot);
    final legacyRepository = ScriptRepository(
      legacyStorage,
      const ScriptRunService(),
      HostRepository(legacyStorage, const ScriptRunService()),
    );
    await legacyRepository.createScript(
      name: 'Database Dump',
      group: 'Backup',
      host: '',
      targetPath: '',
      tags: ['postgres'],
      content: 'pg_dump example',
    );

    final migratedStorage = ScriptStorageService(
      rootDirectory: newRoot,
      legacyRootDirectory: legacyRoot,
    );
    final migratedRepository = ScriptRepository(
      migratedStorage,
      const ScriptRunService(),
      HostRepository(migratedStorage, const ScriptRunService()),
    );

    final scripts = await migratedRepository.listScripts();

    expect(scripts.single.name, 'Database Dump');
    expect(
      (await migratedRepository.getScript(scripts.single.id))!.content,
      'pg_dump example',
    );
  });

  test(
    'searches by name, group, host, target path, tag, and content',
    () async {
      await repository.createScript(
        name: 'Clean Cache',
        group: 'Maintenance',
        host: 'cache.example.com',
        targetPath: '/tmp/cache',
        tags: ['cleanup'],
        content: 'echo clearing cache',
      );
      await repository.createScript(
        name: 'Deploy App',
        group: 'Release',
        host: 'web.example.com',
        targetPath: '/var/www/app',
        tags: ['ship'],
        content: 'echo deploy',
      );

      expect(
        (await repository.searchScripts(query: 'cache')).single.name,
        'Clean Cache',
      );
      expect(
        (await repository.searchScripts(group: 'Release')).single.name,
        'Deploy App',
      );
      expect(
        (await repository.searchScripts(tag: 'cleanup')).single.name,
        'Clean Cache',
      );
      expect(
        (await repository.searchScripts(query: 'web.example.com')).single.name,
        'Deploy App',
      );
      expect(
        (await repository.searchScripts(query: '/tmp/cache')).single.name,
        'Clean Cache',
      );
      expect(
        (await repository.searchScripts(query: 'deploy')).single.name,
        'Deploy App',
      );
    },
  );

  test('searches by managed host metadata', () async {
    final host = await hostRepository.createHost(
      name: 'Production VPS',
      address: '203.0.113.10',
      username: 'deploy',
      port: 22,
      authType: 'key',
      password: '',
      keyPath: '',
    );
    final script = await repository.createScript(
      name: 'Deploy',
      group: 'Release',
      host: host.id,
      targetPath: '/srv/app',
      tags: ['ship'],
      content: 'echo deploy',
    );

    expect(
      (await repository.searchScripts(query: 'production')).single.id,
      script.entry.id,
    );
    expect(
      (await repository.searchScripts(query: '203.0.113.10')).single.id,
      script.entry.id,
    );
  });

  test('runs a script and passes arguments', () async {
    final script = await repository.createScript(
      name: 'Echo Args',
      group: 'Test',
      host: '',
      targetPath: '',
      tags: ['args'],
      content: 'echo "\$1|\$2"',
    );

    final result = await repository.runScript(
      id: script.entry.id,
      argumentsText: 'one "two words"',
    );

    expect(result.exitCode, 0);
    expect(result.stdout.trim(), 'one|two words');
    expect(
      (await repository.getScript(script.entry.id))!.entry.lastRunAt,
      isNotNull,
    );
  });

  test('runs a script with unlocked secret environment variables', () async {
    await secretRepository.setupVault('secret-password');
    await secretRepository.createSecret(
      name: 'db password',
      value: 'super-secret',
    );
    final script = await repository.createScript(
      name: 'Echo Secret',
      group: 'Test',
      host: '',
      targetPath: '',
      tags: ['secret'],
      content: 'echo "\$DB_PASSWORD"',
    );

    final result = await repository.runScript(
      id: script.entry.id,
      argumentsText: '',
    );

    expect(result.exitCode, 0);
    expect(result.stdout.trim(), 'super-secret');
  });

  test('detects dangerous commands', () {
    expect(repository.hasDangerousCommands('echo ok'), isFalse);
    expect(repository.hasDangerousCommands('sudo rm -rf /tmp/example'), isTrue);
    expect(repository.parseArguments('one "two words" three'), [
      'one',
      'two words',
      'three',
    ]);
  });

  test('detects IPv4 hosts for SSH execution', () {
    const runService = ScriptRunService();

    expect(runService.isIpAddress('172.12.12.1'), isTrue);
    expect(runService.isIpAddress(' 10.0.0.5 '), isTrue);
    expect(runService.isIpAddress('app.example.com'), isFalse);
    expect(runService.isIpAddress('localhost'), isFalse);
    expect(runService.isIpAddress('999.12.12.1'), isFalse);
  });
}
