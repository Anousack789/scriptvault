import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scriptvault/data/repositories/host_repository.dart';
import 'package:scriptvault/data/repositories/secret_repository.dart';
import 'package:scriptvault/data/repositories/script_repository.dart';
import 'package:scriptvault/data/services/secret_crypto_service.dart';
import 'package:scriptvault/data/services/script_run_service.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';
import 'package:scriptvault/data/services/vault_transfer_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'scriptvault_transfer_',
    );
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('exports and imports scripts, hosts, and encrypted secrets', () async {
    final source = _TestVault(Directory(p.join(tempDirectory.path, 'source')));
    final destination = _TestVault(
      Directory(p.join(tempDirectory.path, 'destination')),
    );

    final host = await source.hostRepository.createHost(
      name: 'Production',
      address: '203.0.113.10',
      username: 'deploy',
      port: 22,
      authType: 'key',
      password: '',
      keyPath: '~/.ssh/prod',
    );
    final script = await source.scriptRepository.createScript(
      name: 'Deploy App',
      group: 'Release',
      host: host.id,
      targetPath: '/srv/app',
      tags: ['ship'],
      content: 'echo deploy',
    );
    await source.secretRepository.setupVault('secret-password');
    await source.secretRepository.createSecret(
      name: 'DB_PASSWORD',
      value: 'super-secret',
    );

    final exportPath = p.join(tempDirectory.path, 'backup.scriptvault');
    final exportResult = await source.transferService.exportVault(exportPath);
    final importResult = await destination.transferService.importVault(
      exportResult.path,
    );

    expect(importResult.importedScripts, 1);
    expect(importResult.importedHosts, 1);
    expect(importResult.importedSecrets, 1);
    expect((await destination.hostRepository.listHosts()).single.id, host.id);
    expect(
      (await destination.scriptRepository.getScript(script.entry.id))!.content,
      'echo deploy',
    );
    expect(
      await destination.secretRepository.unlockWithPassword('secret-password'),
      isTrue,
    );
    expect(
      await destination.secretRepository.revealSecret(
        (await destination.secretRepository.listSecrets()).single.id,
      ),
      'super-secret',
    );
  });

  test('merges imports without overwriting existing scripts', () async {
    final source = _TestVault(Directory(p.join(tempDirectory.path, 'source')));
    final destination = _TestVault(
      Directory(p.join(tempDirectory.path, 'destination')),
    );

    await source.scriptRepository.createScript(
      name: 'Remote Backup',
      group: 'Ops',
      host: '',
      targetPath: '',
      tags: const [],
      content: 'echo remote',
    );
    final local = await destination.scriptRepository.createScript(
      name: 'Local Cleanup',
      group: 'Ops',
      host: '',
      targetPath: '',
      tags: const [],
      content: 'echo local',
    );

    final exportPath = p.join(tempDirectory.path, 'merge.scriptvault');
    await source.transferService.exportVault(exportPath);
    final result = await destination.transferService.importVault(exportPath);

    final scripts = await destination.scriptRepository.listScripts();
    expect(result.importedScripts, 1);
    expect(scripts.map((script) => script.name), contains('Local Cleanup'));
    expect(scripts.map((script) => script.name), contains('Remote Backup'));
    expect(
      (await destination.scriptRepository.getScript(local.entry.id))!.content,
      'echo local',
    );
  });

  test('remaps colliding host ids, script ids, and script filenames', () async {
    final source = _TestVault(Directory(p.join(tempDirectory.path, 'source')));
    final destination = _TestVault(
      Directory(p.join(tempDirectory.path, 'destination')),
    );

    final sourceHost = await source.hostRepository.createHost(
      name: 'Production',
      address: '203.0.113.10',
      username: 'deploy',
      port: 22,
      authType: 'key',
      password: '',
      keyPath: '~/.ssh/prod',
    );
    final sourceScript = await source.scriptRepository.createScript(
      name: 'Deploy App',
      group: 'Release',
      host: sourceHost.id,
      targetPath: '/srv/app',
      tags: ['ship'],
      content: 'echo source',
    );
    await source.transferService.exportVault(
      p.join(tempDirectory.path, 'collision.scriptvault'),
    );

    await destination.storageService.saveHosts([
      sourceHost.copyWith(address: '198.51.100.5'),
    ]);
    await destination.storageService.writeScript(
      sourceScript.entry.fileName,
      'echo destination',
    );
    await destination.storageService.saveEntries([
      sourceScript.entry.copyWith(name: 'Local Deploy'),
    ]);

    await destination.transferService.importVault(
      p.join(tempDirectory.path, 'collision.scriptvault'),
    );

    final hosts = await destination.hostRepository.listHosts();
    final scripts = await destination.scriptRepository.listScripts();
    final importedScript = scripts.singleWhere(
      (script) => script.name == 'Deploy App',
    );
    final importedHost = hosts.singleWhere(
      (host) => host.address == '203.0.113.10',
    );

    expect(hosts, hasLength(2));
    expect(scripts, hasLength(2));
    expect(importedHost.id, isNot(sourceHost.id));
    expect(importedScript.id, isNot(sourceScript.entry.id));
    expect(importedScript.fileName, isNot(sourceScript.entry.fileName));
    expect(importedScript.host, importedHost.id);
    expect(
      (await destination.scriptRepository.getScript(
        importedScript.id,
      ))!.content,
      'echo source',
    );
  });

  test('rejects malformed imports without changing storage', () async {
    final destination = _TestVault(
      Directory(p.join(tempDirectory.path, 'destination')),
    );
    final script = await destination.scriptRepository.createScript(
      name: 'Keep Me',
      group: 'Ops',
      host: '',
      targetPath: '',
      tags: const [],
      content: 'echo keep',
    );
    final malformed = File(p.join(tempDirectory.path, 'broken.scriptvault'));
    await malformed.writeAsBytes([1, 2, 3]);

    expect(
      () => destination.transferService.importVault(malformed.path),
      throwsA(anything),
    );
    expect((await destination.scriptRepository.listScripts()), hasLength(1));
    expect(
      (await destination.scriptRepository.getScript(script.entry.id))!.content,
      'echo keep',
    );
  });
}

class _TestVault {
  final Directory root;
  late final ScriptStorageService storageService;
  late final HostRepository hostRepository;
  late final SecretRepository secretRepository;
  late final ScriptRepository scriptRepository;
  late final VaultTransferService transferService;

  _TestVault(this.root) {
    storageService = ScriptStorageService(rootDirectory: root);
    hostRepository = HostRepository(storageService, const ScriptRunService());
    secretRepository = SecretRepository(storageService, SecretCryptoService());
    scriptRepository = ScriptRepository(
      storageService,
      const ScriptRunService(),
      hostRepository,
      secretRepository: secretRepository,
    );
    transferService = VaultTransferService(storageService);
  }
}
