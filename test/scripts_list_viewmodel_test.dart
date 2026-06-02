import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    final repository = ScriptRepository(
      storageService,
      const ScriptRunService(),
    );
    await repository.createScript(
      name: 'Clean Cache',
      group: 'Maintenance',
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
}
