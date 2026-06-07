import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scriptvault/data/repositories/host_repository.dart';
import 'package:scriptvault/data/repositories/script_repository.dart';
import 'package:scriptvault/data/services/app_settings_service.dart';
import 'package:scriptvault/data/services/script_run_service.dart';
import 'package:scriptvault/data/services/script_service_provider.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';
import 'package:scriptvault/ui/scripts/scripts_list_viewmodel.dart';

void main() {
  late Directory tempDirectory;
  late ScriptStorageService storageService;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'scriptvault_list_vm_',
    );
    storageService = ScriptStorageService(rootDirectory: tempDirectory);
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('loads scripts and persists collapsed groups', () async {
    final hostRepository = HostRepository(
      storageService,
      const ScriptRunService(),
    );
    final repository = ScriptRepository(
      storageService,
      const ScriptRunService(),
      hostRepository,
    );
    await repository.createScript(
      name: 'Clean Cache',
      group: 'Maintenance',
      host: '',
      targetPath: '',
      tags: const [],
      content: 'echo clean',
    );

    final container = ProviderContainer(
      overrides: [
        scriptStorageServiceProvider.overrideWith((ref) => storageService),
      ],
    );
    addTearDown(container.dispose);

    final initialState = await container.read(
      scriptsListViewModelProvider.future,
    );

    expect(initialState.scripts.single.name, 'Clean Cache');
    expect(initialState.collapsedGroups, isEmpty);

    await container
        .read(scriptsListViewModelProvider.notifier)
        .toggleGroupCollapsed('Maintenance');

    final collapsedState = container.read(scriptsListViewModelProvider).value!;
    expect(collapsedState.collapsedGroups, {'Maintenance'});

    final settings = await AppSettingsService(storageService).loadSettings();
    expect(settings.collapsedScriptGroups, ['Maintenance']);

    await container
        .read(scriptsListViewModelProvider.notifier)
        .toggleGroupCollapsed('Maintenance');

    final expandedState = container.read(scriptsListViewModelProvider).value!;
    expect(expandedState.collapsedGroups, isEmpty);
  });

  test('keeps tag options available when a tag filter is selected', () async {
    final hostRepository = HostRepository(
      storageService,
      const ScriptRunService(),
    );
    final repository = ScriptRepository(
      storageService,
      const ScriptRunService(),
      hostRepository,
    );
    await _createScript(
      repository,
      name: 'Clean Cache',
      tags: const ['cleanup'],
    );
    await _createScript(repository, name: 'Ship Release', tags: const ['ship']);

    final container = ProviderContainer(
      overrides: [
        scriptStorageServiceProvider.overrideWith((ref) => storageService),
      ],
    );
    addTearDown(container.dispose);
    await container.read(scriptsListViewModelProvider.future);

    await container
        .read(scriptsListViewModelProvider.notifier)
        .updateTag('cleanup');

    final state = container.read(scriptsListViewModelProvider).value!;
    expect(state.scripts.map((script) => script.name), ['Clean Cache']);
    expect(state.tags, ['cleanup', 'ship']);
  });

  test('narrows tag options by search query, not selected tag', () async {
    final hostRepository = HostRepository(
      storageService,
      const ScriptRunService(),
    );
    final repository = ScriptRepository(
      storageService,
      const ScriptRunService(),
      hostRepository,
    );
    await _createScript(
      repository,
      name: 'Backup Database',
      tags: const ['database'],
      content: 'echo backup',
    );
    await _createScript(
      repository,
      name: 'Backup Files',
      tags: const ['files'],
      content: 'echo backup',
    );
    await _createScript(
      repository,
      name: 'Deploy App',
      tags: const ['deploy'],
      content: 'echo release',
    );

    final container = ProviderContainer(
      overrides: [
        scriptStorageServiceProvider.overrideWith((ref) => storageService),
      ],
    );
    addTearDown(container.dispose);
    await container.read(scriptsListViewModelProvider.future);

    final viewModel = container.read(scriptsListViewModelProvider.notifier);
    await viewModel.updateTag('database');
    await viewModel.updateQuery('backup');

    final state = container.read(scriptsListViewModelProvider).value!;
    expect(state.scripts.map((script) => script.name), ['Backup Database']);
    expect(state.tags, ['database', 'files']);
  });
}

Future<void> _createScript(
  ScriptRepository repository, {
  required String name,
  required List<String> tags,
  String content = 'echo ok',
}) {
  return repository.createScript(
    name: name,
    group: 'Scripts',
    host: '',
    targetPath: '',
    tags: tags,
    content: content,
  );
}
