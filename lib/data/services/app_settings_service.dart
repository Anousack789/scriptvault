import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/app_settings.dart';
import 'script_storage_service.dart';

class AppSettingsService {
  final ScriptStorageService _storageService;

  const AppSettingsService(this._storageService);

  Future<File> getSettingsFile() async {
    final root = await _storageService.getRootDirectory();
    return File(p.join(root.path, 'app_settings.json'));
  }

  Future<AppSettings> loadSettings() async {
    await _storageService.ensureReady();
    final file = await getSettingsFile();
    if (!file.existsSync()) {
      return const AppSettings();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
    } on FormatException {
      return const AppSettings();
    }

    return const AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _storageService.ensureReady();
    final file = await getSettingsFile();
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}
