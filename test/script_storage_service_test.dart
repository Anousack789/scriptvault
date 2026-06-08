import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scriptvault/data/repositories/host_repository.dart';
import 'package:scriptvault/data/repositories/script_repository.dart';
import 'package:scriptvault/data/services/app_settings_service.dart';
import 'package:scriptvault/data/services/script_run_service.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';
import 'package:scriptvault/data/services/storage_location_service.dart';
import 'package:scriptvault/domain/models/app_settings.dart';

void main() {
  late Directory tempDirectory;
  late Directory bootstrapDirectory;
  late Directory defaultRoot;
  late StorageLocationService locationService;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'scriptvault_storage_',
    );
    bootstrapDirectory = Directory(p.join(tempDirectory.path, 'bootstrap'));
    defaultRoot = Directory(p.join(tempDirectory.path, 'default'));
    locationService = StorageLocationService(
      bootstrapDirectory: bootstrapDirectory,
    );
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'loads, saves, clears, and falls back to default storage location',
    () async {
      final service = ScriptStorageService(
        defaultRootDirectory: defaultRoot,
        locationService: locationService,
      );

      expect(await locationService.loadCustomRootPath(), isNull);
      expect((await service.getRootDirectory()).path, defaultRoot.path);

      final customRoot = Directory(p.join(tempDirectory.path, 'custom'));
      await locationService.saveCustomRootPath(customRoot.path);

      expect(await locationService.loadCustomRootPath(), customRoot.path);
      expect((await service.getRootDirectory()).path, customRoot.path);

      await locationService.clearCustomRootPath();

      expect(await locationService.loadCustomRootPath(), isNull);
      expect((await service.getRootDirectory()).path, defaultRoot.path);
    },
  );

  test(
    'copies scripts, hosts, and settings before switching storage',
    () async {
      final storageService = ScriptStorageService(
        defaultRootDirectory: defaultRoot,
        locationService: locationService,
      );
      final hostRepository = HostRepository(
        storageService,
        const ScriptRunService(),
      );
      final scriptRepository = ScriptRepository(
        storageService,
        const ScriptRunService(),
        hostRepository,
      );
      final settingsService = AppSettingsService(storageService);

      final host = await hostRepository.createHost(
        name: 'Production',
        address: '203.0.113.5',
        username: 'deploy',
        port: 22,
        authType: 'key',
        password: '',
        keyPath: '~/.ssh/prod',
      );
      final script = await scriptRepository.createScript(
        name: 'Deploy App',
        group: 'Release',
        host: host.id,
        targetPath: '/srv/app',
        tags: ['ship'],
        content: 'echo deploy',
      );
      await settingsService.saveSettings(
        const AppSettings(
          editorFontSize: 18,
          collapsedScriptGroups: ['Release'],
        ),
      );

      final customRoot = Directory(p.join(tempDirectory.path, 'custom'));
      await storageService.switchRootDirectory(customRoot);

      expect((await storageService.getRootDirectory()).path, customRoot.path);
      expect((await scriptRepository.listScripts()).single.id, script.entry.id);
      expect(
        (await scriptRepository.getScript(script.entry.id))!.content,
        'echo deploy',
      );
      expect((await hostRepository.listHosts()).single.name, 'Production');
      expect((await settingsService.loadSettings()).editorFontSize, 18);
    },
  );

  test('rejects non-empty storage switch destination', () async {
    final storageService = ScriptStorageService(
      defaultRootDirectory: defaultRoot,
      locationService: locationService,
    );
    final destination = Directory(p.join(tempDirectory.path, 'destination'));
    await destination.create(recursive: true);
    await File(p.join(destination.path, 'existing.txt')).writeAsString('data');

    expect(
      () => storageService.switchRootDirectory(destination),
      throwsStateError,
    );
  });
}
