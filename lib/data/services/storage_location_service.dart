import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageLocationService {
  final Directory? _bootstrapDirectory;

  const StorageLocationService({Directory? bootstrapDirectory})
    : _bootstrapDirectory = bootstrapDirectory;

  Future<File> getBootstrapFile() async {
    final directory =
        _bootstrapDirectory ?? await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'scriptvault_storage.json'));
  }

  Future<String?> loadCustomRootPath() async {
    final file = await getBootstrapFile();
    if (!file.existsSync()) return null;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final path = decoded['customRootPath'];
      if (path is! String) return null;
      final trimmed = path.trim();
      return trimmed.isEmpty ? null : trimmed;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveCustomRootPath(String path) async {
    final cleaned = path.trim();
    if (cleaned.isEmpty) {
      await clearCustomRootPath();
      return;
    }

    final file = await getBootstrapFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'customRootPath': cleaned}));
  }

  Future<void> clearCustomRootPath() async {
    final file = await getBootstrapFile();
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
