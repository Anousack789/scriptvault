import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scriptvault/data/repositories/script_repository.dart';
import 'package:scriptvault/data/services/script_run_service.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';

void main() {
  late Directory tempDirectory;
  late ScriptRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('scriptvault_repo_');
    repository = ScriptRepository(
      ScriptStorageService(rootDirectory: tempDirectory),
      const ScriptRunService(),
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

  test('migrates scripts from legacy sandbox storage', () async {
    final newRoot = Directory(p.join(tempDirectory.path, 'new'));
    final legacyRoot = Directory(p.join(tempDirectory.path, 'legacy'));
    final legacyStorage = ScriptStorageService(rootDirectory: legacyRoot);
    final legacyRepository = ScriptRepository(
      legacyStorage,
      const ScriptRunService(),
    );
    await legacyRepository.createScript(
      name: 'Database Dump',
      group: 'Backup',
      host: '',
      targetPath: '',
      tags: ['postgres'],
      content: 'pg_dump example',
    );

    final migratedRepository = ScriptRepository(
      ScriptStorageService(
        rootDirectory: newRoot,
        legacyRootDirectory: legacyRoot,
      ),
      const ScriptRunService(),
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
