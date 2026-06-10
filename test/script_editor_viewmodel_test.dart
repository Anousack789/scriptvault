import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scriptvault/data/repositories/host_repository.dart';
import 'package:scriptvault/data/repositories/script_repository.dart';
import 'package:scriptvault/data/services/script_run_service.dart';
import 'package:scriptvault/data/services/script_service_provider.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';
import 'package:scriptvault/ui/scripts/script_editor_viewmodel.dart';

void main() {
  late Directory tempDirectory;
  late ScriptStorageService storageService;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'scriptvault_editor_vm_',
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

  ScriptRepository createRepository() {
    return ScriptRepository(
      storageService,
      const ScriptRunService(),
      HostRepository(storageService, const ScriptRunService()),
    );
  }

  test(
    'marks existing script dirty and clears dirty state after save',
    () async {
      final repository = createRepository();
      final detail = await repository.createScript(
        name: 'Deploy',
        group: 'Release',
        host: '',
        targetPath: '',
        tags: const [],
        content: 'echo old',
      );
      final container = createContainer();
      final provider = scriptEditorViewModelProvider(detail.entry.id);

      await container.read(provider.future);
      container.read(provider.notifier).updateContent('echo new');

      expect(container.read(provider).value!.hasUnsavedChanges, isTrue);

      await container.read(provider.notifier).save();

      final state = container.read(provider).value!;
      expect(state.hasUnsavedChanges, isFalse);
      expect(state.isSaving, isFalse);
      expect(
        (await repository.getScript(detail.entry.id))!.content,
        'echo new',
      );
    },
  );

  test('creates new script on save and clears dirty state', () async {
    final repository = createRepository();
    final container = createContainer();
    final provider = scriptEditorViewModelProvider(null);

    await container.read(provider.future);
    container.read(provider.notifier).updateContent('echo draft');

    final id = await container.read(provider.notifier).save();

    final state = container.read(provider).value!;
    expect(state.id, id);
    expect(state.name, 'Untitled Script');
    expect(state.hasUnsavedChanges, isFalse);
    expect((await repository.listScripts()).single.id, id);
  });
}
