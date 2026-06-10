import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/host_entry.dart';
import '../../domain/models/script_entry.dart';
import '../../domain/models/secret_entry.dart';
import 'storage_location_service.dart';

class ScriptStorageService {
  final Directory? _rootDirectory;
  final Directory? _defaultRootDirectory;
  final Directory? _legacyRootDirectory;
  final StorageLocationService _locationService;

  ScriptStorageService({
    Directory? rootDirectory,
    Directory? defaultRootDirectory,
    Directory? legacyRootDirectory,
    StorageLocationService locationService = const StorageLocationService(),
  }) : _rootDirectory = rootDirectory,
       _defaultRootDirectory = defaultRootDirectory,
       _legacyRootDirectory = legacyRootDirectory,
       _locationService = locationService;

  Future<Directory> getRootDirectory() async {
    if (_rootDirectory != null) return _rootDirectory;
    final customRootPath = await _locationService.loadCustomRootPath();
    if (customRootPath != null) return Directory(customRootPath);
    return getDefaultRootDirectory();
  }

  Future<Directory> getDefaultRootDirectory() async {
    if (_defaultRootDirectory != null) return _defaultRootDirectory;
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(p.join(supportDirectory.path, 'scriptvault'));
  }

  Future<Directory> getScriptsDirectory() async {
    final root = await getRootDirectory();
    return Directory(p.join(root.path, 'scripts'));
  }

  Future<File> getIndexFile() async {
    final root = await getRootDirectory();
    return File(p.join(root.path, 'script_index.json'));
  }

  Future<File> getHostsIndexFile() async {
    final root = await getRootDirectory();
    return File(p.join(root.path, 'host_index.json'));
  }

  Future<File> getSecretsIndexFile() async {
    final root = await getRootDirectory();
    return File(p.join(root.path, 'secret_index.json'));
  }

  Future<void> ensureReady() async {
    final root = await getRootDirectory();
    final scripts = await getScriptsDirectory();
    await _migrateLegacySandboxStorageIfNeeded(root);
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }
    if (!scripts.existsSync()) {
      await scripts.create(recursive: true);
    }
    final index = await getIndexFile();
    if (!index.existsSync()) {
      await index.writeAsString(jsonEncode(<Map<String, dynamic>>[]));
    }
    final hostsIndex = await getHostsIndexFile();
    if (!hostsIndex.existsSync()) {
      await hostsIndex.writeAsString(jsonEncode(<Map<String, dynamic>>[]));
    }
    final secretsIndex = await getSecretsIndexFile();
    if (!secretsIndex.existsSync()) {
      await secretsIndex.writeAsString(
        jsonEncode(const SecretVault().toJson()),
      );
    }
  }

  Future<void> switchRootDirectory(Directory destination) async {
    final currentRoot = await getRootDirectory();
    if (p.equals(currentRoot.path, destination.path)) return;
    if (p.isWithin(currentRoot.path, destination.path)) {
      throw StateError('Storage folder cannot be inside the current vault.');
    }

    await ensureReady();
    await _validateSwitchDestination(destination);
    await destination.create(recursive: true);
    await _copyDirectoryContents(currentRoot, destination);
    await _locationService.saveCustomRootPath(destination.path);
  }

  Future<void> resetRootDirectoryToDefault() async {
    final currentRoot = await getRootDirectory();
    final defaultRoot = await getDefaultRootDirectory();
    if (p.equals(currentRoot.path, defaultRoot.path)) {
      await _locationService.clearCustomRootPath();
      return;
    }

    await ensureReady();
    await _validateSwitchDestination(defaultRoot);
    await defaultRoot.create(recursive: true);
    await _copyDirectoryContents(currentRoot, defaultRoot);
    await _locationService.clearCustomRootPath();
  }

  Future<void> _validateSwitchDestination(Directory destination) async {
    if (!destination.existsSync()) return;

    final entities = await destination.list(recursive: false).toList();
    if (entities.isEmpty) return;

    throw StateError('Storage folder must be empty.');
  }

  Future<void> _migrateLegacySandboxStorageIfNeeded(Directory root) async {
    final legacyRoot = await _getLegacySandboxRootDirectory();
    if (legacyRoot == null || !legacyRoot.existsSync()) return;
    if (p.equals(root.path, legacyRoot.path)) return;

    final legacyIndex = File(p.join(legacyRoot.path, 'script_index.json'));
    if (!legacyIndex.existsSync()) return;
    if (!await _shouldMigrateTo(root)) return;

    await root.create(recursive: true);
    await _copyDirectoryContents(legacyRoot, root);
  }

  Future<Directory?> _getLegacySandboxRootDirectory() async {
    if (_legacyRootDirectory != null) return _legacyRootDirectory;
    if (_rootDirectory != null ||
        _defaultRootDirectory != null ||
        !Platform.isMacOS) {
      return null;
    }

    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;

    return Directory(
      p.join(
        home,
        'Library',
        'Containers',
        'com.nonostack.scriptvault',
        'Data',
        'Library',
        'Application Support',
        'com.nonostack.scriptvault',
        'scriptvault',
      ),
    );
  }

  Future<bool> _shouldMigrateTo(Directory root) async {
    final index = File(p.join(root.path, 'script_index.json'));
    if (!index.existsSync()) return true;

    try {
      final decoded = jsonDecode(await index.readAsString());
      return decoded is List && decoded.isEmpty;
    } on FormatException {
      return false;
    }
  }

  Future<void> _copyDirectoryContents(
    Directory source,
    Directory target,
  ) async {
    await for (final entity in source.list(recursive: false)) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectoryContents(entity, Directory(targetPath));
      } else if (entity is File) {
        final targetFile = File(targetPath);
        await targetFile.parent.create(recursive: true);
        await entity.copy(targetFile.path);
      }
    }
  }

  Future<List<ScriptEntry>> loadEntries() async {
    await ensureReady();
    final index = await getIndexFile();
    final raw = await index.readAsString();
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(ScriptEntry.fromJson)
        .toList();
  }

  Future<void> saveEntries(List<ScriptEntry> entries) async {
    await ensureReady();
    final index = await getIndexFile();
    final encoded = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    await index.writeAsString(encoded);
  }

  Future<List<HostEntry>> loadHosts() async {
    await ensureReady();
    final index = await getHostsIndexFile();
    final raw = await index.readAsString();
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(HostEntry.fromJson)
        .toList();
  }

  Future<void> saveHosts(List<HostEntry> hosts) async {
    await ensureReady();
    final index = await getHostsIndexFile();
    final encoded = jsonEncode(hosts.map((host) => host.toJson()).toList());
    await index.writeAsString(encoded);
  }

  Future<SecretVault> loadSecretVault() async {
    await ensureReady();
    final index = await getSecretsIndexFile();
    final raw = await index.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return const SecretVault();
    }
    return SecretVault.fromJson(decoded as Map<String, dynamic>);
  }

  Future<void> saveSecretVault(SecretVault vault) async {
    await ensureReady();
    final index = await getSecretsIndexFile();
    await index.writeAsString(jsonEncode(vault.toJson()));
  }

  Future<File> getScriptFile(String fileName) async {
    final scripts = await getScriptsDirectory();
    return File(p.join(scripts.path, fileName));
  }

  Future<String> readScript(String fileName) async {
    final file = await getScriptFile(fileName);
    if (!file.existsSync()) return '';
    return file.readAsString();
  }

  Future<void> writeScript(String fileName, String content) async {
    await ensureReady();
    final file = await getScriptFile(fileName);
    await file.writeAsString(content);
  }

  Future<void> deleteScript(String fileName) async {
    final file = await getScriptFile(fileName);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
