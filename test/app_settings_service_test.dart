import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scriptvault/data/services/app_settings_service.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';
import 'package:scriptvault/domain/models/app_settings.dart';

void main() {
  late Directory tempDirectory;
  late AppSettingsService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'scriptvault_settings_',
    );
    service = AppSettingsService(
      ScriptStorageService(rootDirectory: tempDirectory),
    );
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('loads defaults when settings file is missing', () async {
    final settings = await service.loadSettings();

    expect(settings.editorFontSize, AppSettings.defaultEditorFontSize);
    expect(settings.collapsedScriptGroups, isEmpty);
    expect(settings.lockEnabled, isFalse);
  });

  test('saves and loads settings', () async {
    await service.saveSettings(
      const AppSettings(
        editorFontSize: 18,
        collapsedScriptGroups: ['Maintenance'],
        lockPasswordHash: 'hash',
        lockPasswordSalt: 'salt',
      ),
    );

    final settings = await service.loadSettings();

    expect(settings.editorFontSize, 18);
    expect(settings.collapsedScriptGroups, ['Maintenance']);
    expect(settings.lockPasswordHash, 'hash');
    expect(settings.lockPasswordSalt, 'salt');
    expect(settings.lockEnabled, isTrue);
  });

  test('normalizes invalid editor font sizes from storage', () async {
    await tempDirectory.create(recursive: true);
    await File(
      p.join(tempDirectory.path, 'app_settings.json'),
    ).writeAsString('{"editorFontSize": 100}');

    final settings = await service.loadSettings();

    expect(settings.editorFontSize, AppSettings.maxEditorFontSize);
  });

  test('loads defaults when collapsed groups are missing', () async {
    await tempDirectory.create(recursive: true);
    await File(
      p.join(tempDirectory.path, 'app_settings.json'),
    ).writeAsString('{"editorFontSize": 16}');

    final settings = await service.loadSettings();

    expect(settings.editorFontSize, 16);
    expect(settings.collapsedScriptGroups, isEmpty);
  });

  test('normalizes invalid collapsed groups from storage', () async {
    await tempDirectory.create(recursive: true);
    await File(p.join(tempDirectory.path, 'app_settings.json')).writeAsString(
      '{"collapsedScriptGroups": ["Release", "", 1, " Release ", "Build"]}',
    );

    final settings = await service.loadSettings();

    expect(settings.collapsedScriptGroups, ['Build', 'Release']);
  });

  test('ignores partial lock settings from storage', () async {
    await tempDirectory.create(recursive: true);
    await File(
      p.join(tempDirectory.path, 'app_settings.json'),
    ).writeAsString('{"lockPasswordHash": "hash"}');

    final settings = await service.loadSettings();

    expect(settings.lockPasswordHash, isNull);
    expect(settings.lockPasswordSalt, isNull);
    expect(settings.lockEnabled, isFalse);
  });
}
