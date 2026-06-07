import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scriptvault/data/repositories/host_repository.dart';
import 'package:scriptvault/data/repositories/script_repository.dart';
import 'package:scriptvault/data/services/script_run_service.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';

void main() {
  late Directory tempDirectory;
  late ScriptStorageService storageService;
  late HostRepository hostRepository;
  late ScriptRepository scriptRepository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('scriptvault_host_');
    storageService = ScriptStorageService(rootDirectory: tempDirectory);
    hostRepository = HostRepository(storageService, const ScriptRunService());
    scriptRepository = ScriptRepository(
      storageService,
      const ScriptRunService(),
      hostRepository,
    );
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('creates, updates, and deletes hosts', () async {
    final host = await hostRepository.createHost(
      name: 'Production VPS',
      address: ' 203.0.113.10 ',
      username: ' deploy ',
      port: 2222,
      authType: 'key',
      password: '',
      keyPath: ' ~/.ssh/prod ',
    );

    expect(host.name, 'Production VPS');
    expect(host.address, '203.0.113.10');
    expect(host.username, 'deploy');
    expect(host.port, 2222);
    expect(host.keyPath, '~/.ssh/prod');
    expect((await hostRepository.listHosts()).single.id, host.id);

    final updated = await hostRepository.updateHost(
      id: host.id,
      name: 'Staging VPS',
      address: 'staging.example.com',
      username: 'ubuntu',
      port: 70000,
      authType: 'password',
      password: 'secret',
      keyPath: '',
    );

    expect(updated.name, 'Staging VPS');
    expect(updated.port, 22);
    expect(updated.authType, 'password');
    expect(updated.password, 'secret');

    await hostRepository.deleteHost(host.id);

    expect(await hostRepository.listHosts(), isEmpty);
  });

  test('clears deleted hosts from scripts', () async {
    final host = await hostRepository.createHost(
      name: 'Production VPS',
      address: '203.0.113.10',
      username: 'deploy',
      port: 22,
      authType: 'key',
      password: '',
      keyPath: '',
    );
    final script = await scriptRepository.createScript(
      name: 'Deploy',
      group: 'Release',
      host: host.id,
      targetPath: '/srv/app',
      tags: ['ship'],
      content: 'echo deploy',
    );

    await hostRepository.deleteHost(host.id);

    expect((await scriptRepository.getScript(script.entry.id))!.entry.host, '');
  });

  test(
    'returns a failed result when password SSH helper is unavailable',
    () async {
      final result = await hostRepository.testConnection(
        name: 'Password Host',
        address: '127.0.0.1',
        username: 'deploy',
        port: 22,
        authType: 'password',
        password: 'secret',
        keyPath: '',
      );

      expect(result.success, isFalse);
      expect(result.exitCode, isNot(0));
    },
  );
}
