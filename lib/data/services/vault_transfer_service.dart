import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/host_entry.dart';
import '../../domain/models/script_entry.dart';
import '../../domain/models/secret_entry.dart';
import 'script_storage_service.dart';

class VaultTransferService {
  static const archiveExtension = '.scriptvault';
  static const _formatVersion = 1;
  static const _manifestPath = 'manifest.json';
  static const _scriptsIndexPath = 'script_index.json';
  static const _hostsIndexPath = 'host_index.json';
  static const _secretsIndexPath = 'secret_index.json';
  static const _scriptsPrefix = 'scripts/';

  final ScriptStorageService _storageService;
  final Random _random;

  VaultTransferService(this._storageService, {Random? random})
    : _random = random ?? Random.secure();

  Future<VaultExportResult> exportVault(String outputPath) async {
    await _storageService.ensureReady();

    final entries = await _storageService.loadEntries();
    final hosts = await _storageService.loadHosts();
    final secretVault = await _storageService.loadSecretVault();
    final archive = Archive();
    final exportedAt = DateTime.now().toUtc();
    final manifest = {
      'format': 'scriptvault.transfer',
      'version': _formatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'counts': {
        'scripts': entries.length,
        'hosts': hosts.length,
        'secrets': secretVault.secrets.length,
      },
    };

    archive.addFile(ArchiveFile.string(_manifestPath, jsonEncode(manifest)));
    archive.addFile(
      ArchiveFile.string(
        _scriptsIndexPath,
        jsonEncode(entries.map((entry) => entry.toJson()).toList()),
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        _hostsIndexPath,
        jsonEncode(hosts.map((host) => host.toJson()).toList()),
      ),
    );
    archive.addFile(
      ArchiveFile.string(_secretsIndexPath, jsonEncode(secretVault.toJson())),
    );

    for (final entry in entries) {
      final file = await _storageService.getScriptFile(entry.fileName);
      if (!file.existsSync()) continue;
      final fileName = _safeArchiveScriptFileName(entry.fileName);
      archive.addFile(
        ArchiveFile.bytes('$_scriptsPrefix$fileName', await file.readAsBytes()),
      );
    }

    final destination = File(_normalizeExportPath(outputPath));
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(ZipEncoder().encode(archive));

    return VaultExportResult(
      path: destination.path,
      scriptCount: entries.length,
      hostCount: hosts.length,
      secretCount: secretVault.secrets.length,
    );
  }

  Future<VaultImportResult> importVault(String archivePath) async {
    final source = File(archivePath);
    if (!source.existsSync()) {
      throw StateError('Import file not found.');
    }

    final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    final bundle = _decodeBundle(archive);

    final existingEntries = await _storageService.loadEntries();
    final existingHosts = await _storageService.loadHosts();
    final existingVault = await _storageService.loadSecretVault();

    final hostMerge = _mergeHosts(existingHosts, bundle.hosts);
    final scriptMerge = await _mergeScripts(
      existingEntries,
      bundle.scripts,
      bundle.scriptContents,
      hostMerge.idMap,
    );
    final secretMerge = _mergeSecrets(existingVault, bundle.secretVault);

    await _writeMergedScripts(
      existingEntries,
      scriptMerge.scripts,
      scriptMerge.scriptContents,
    );
    await _storageService.saveHosts(hostMerge.hosts);
    await _storageService.saveSecretVault(secretMerge.vault);
    await _storageService.saveEntries(scriptMerge.scripts);

    return VaultImportResult(
      importedScripts: scriptMerge.importedCount,
      importedHosts: hostMerge.importedCount,
      importedSecrets: secretMerge.importedCount,
    );
  }

  _DecodedVaultBundle _decodeBundle(Archive archive) {
    _requireManifest(archive);

    final scripts = _decodeList(
      archive,
      _scriptsIndexPath,
      ScriptEntry.fromJson,
    );
    final hosts = _decodeList(archive, _hostsIndexPath, HostEntry.fromJson);
    final secretVault = SecretVault.fromJson(
      _decodeJsonMap(_requireFile(archive, _secretsIndexPath)),
    );
    final scriptContents = <String, List<int>>{};

    for (final entry in scripts) {
      final fileName = _safeArchiveScriptFileName(entry.fileName);
      final file = _requireFile(archive, '$_scriptsPrefix$fileName');
      scriptContents[entry.id] = _readArchiveFileBytes(file);
    }

    return _DecodedVaultBundle(
      scripts: scripts,
      hosts: hosts,
      secretVault: secretVault,
      scriptContents: scriptContents,
    );
  }

  void _requireManifest(Archive archive) {
    final manifest = _decodeJsonMap(_requireFile(archive, _manifestPath));
    if (manifest['format'] != 'scriptvault.transfer') {
      throw StateError('Import file is not a ScriptVault export.');
    }
    if (manifest['version'] != _formatVersion) {
      throw StateError('Unsupported ScriptVault export version.');
    }
  }

  List<T> _decodeList<T>(
    Archive archive,
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final decoded = jsonDecode(
      utf8.decode(_readArchiveFileBytes(_requireFile(archive, path))),
    );
    if (decoded is! List) {
      throw StateError('Import file has invalid $path.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  Map<String, dynamic> _decodeJsonMap(ArchiveFile file) {
    final decoded = jsonDecode(utf8.decode(_readArchiveFileBytes(file)));
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Import file has invalid ${file.name}.');
    }
    return decoded;
  }

  ArchiveFile _requireFile(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null || !file.isFile) {
      throw StateError('Import file is missing $path.');
    }
    return file;
  }

  List<int> _readArchiveFileBytes(ArchiveFile file) {
    final bytes = file.readBytes();
    if (bytes == null) {
      throw StateError('Import file has unreadable ${file.name}.');
    }
    return bytes;
  }

  _HostMerge _mergeHosts(List<HostEntry> existing, List<HostEntry> imported) {
    final usedIds = existing.map((host) => host.id).toSet();
    final hosts = [...existing];
    final idMap = <String, String>{};
    var importedCount = 0;

    for (final host in imported) {
      final matching = existing.where((candidate) {
        return candidate.name == host.name &&
            candidate.address == host.address &&
            candidate.username == host.username &&
            candidate.port == host.port &&
            candidate.authType == host.authType &&
            candidate.password == host.password &&
            candidate.keyPath == host.keyPath;
      }).firstOrNull;
      if (matching != null) {
        idMap[host.id] = matching.id;
        continue;
      }

      final id = usedIds.add(host.id) ? host.id : _newId(usedIds);
      idMap[host.id] = id;
      hosts.add(host.copyWith(id: id));
      importedCount++;
    }

    return _HostMerge(hosts: hosts, idMap: idMap, importedCount: importedCount);
  }

  Future<_ScriptMerge> _mergeScripts(
    List<ScriptEntry> existing,
    List<ScriptEntry> imported,
    Map<String, List<int>> importedContents,
    Map<String, String> hostIdMap,
  ) async {
    final scripts = [...existing];
    final existingById = {for (final script in existing) script.id: script};
    final existingContents = <String, List<int>>{};
    final usedIds = existing.map((script) => script.id).toSet();
    final usedFileNames = existing.map((script) => script.fileName).toSet();
    final scriptContents = <String, List<int>>{};
    var importedCount = 0;

    for (final script in imported) {
      final importedFileName = _safeArchiveScriptFileName(script.fileName);
      final content = importedContents[script.id];
      if (content == null) {
        throw StateError('Import file is missing script ${script.name}.');
      }

      final existingScript = existingById[script.id];
      if (existingScript != null) {
        if (!existingContents.containsKey(existingScript.id)) {
          final file = await _storageService.getScriptFile(
            existingScript.fileName,
          );
          existingContents[existingScript.id] = file.existsSync()
              ? await file.readAsBytes()
              : const <int>[];
        }
        if (_sameScript(existingScript, script) &&
            _sameBytes(existingContents[existingScript.id]!, content)) {
          continue;
        }
      }

      final id = usedIds.add(script.id) ? script.id : _newId(usedIds);
      final fileName = usedFileNames.add(importedFileName)
          ? importedFileName
          : _uniqueScriptFileName(importedFileName, usedFileNames);
      final host = script.host.isEmpty ? '' : hostIdMap[script.host] ?? '';
      final mergedScript = script.copyWith(
        id: id,
        fileName: fileName,
        host: host,
      );
      scripts.add(mergedScript);
      scriptContents[mergedScript.id] = content;
      importedCount++;
    }

    return _ScriptMerge(
      scripts: scripts,
      scriptContents: scriptContents,
      importedCount: importedCount,
    );
  }

  _SecretMerge _mergeSecrets(SecretVault existing, SecretVault imported) {
    if (!existing.isConfigured) {
      return _SecretMerge(
        vault: imported,
        importedCount: imported.secrets.length,
      );
    }
    if (!imported.isConfigured || imported.secrets.isEmpty) {
      return _SecretMerge(vault: existing, importedCount: 0);
    }

    final hasSharedWrapper = existing.keyWrappers.any((existingWrapper) {
      return imported.keyWrappers.any(
        (importedWrapper) => _sameWrapper(existingWrapper, importedWrapper),
      );
    });
    if (!hasSharedWrapper) {
      throw StateError(
        'Cannot merge encrypted secrets from a different secret vault. '
        'Import into a vault without configured secrets first.',
      );
    }

    final keyWrappers = [...existing.keyWrappers];
    for (final wrapper in imported.keyWrappers) {
      if (!keyWrappers.any((candidate) => _sameWrapper(candidate, wrapper))) {
        keyWrappers.add(wrapper);
      }
    }

    final usedIds = existing.secrets.map((secret) => secret.id).toSet();
    final usedNames = existing.secrets.map((secret) => secret.name).toSet();
    final secrets = [...existing.secrets];
    var importedCount = 0;

    for (final secret in imported.secrets) {
      final existingSecret = existing.secrets
          .where((candidate) => candidate.id == secret.id)
          .firstOrNull;
      if (existingSecret != null && _sameSecret(existingSecret, secret)) {
        continue;
      }

      final id = usedIds.add(secret.id) ? secret.id : _newId(usedIds);
      final name = usedNames.add(secret.name)
          ? secret.name
          : _uniqueSecretName(secret.name, usedNames);
      secrets.add(secret.copyWith(id: id, name: name));
      importedCount++;
    }

    return _SecretMerge(
      vault: existing.copyWith(
        version: max(existing.version, imported.version),
        keyWrappers: keyWrappers,
        secrets: secrets,
      ),
      importedCount: importedCount,
    );
  }

  Future<void> _writeMergedScripts(
    List<ScriptEntry> existing,
    List<ScriptEntry> merged,
    Map<String, List<int>> importedContents,
  ) async {
    final existingIds = existing.map((script) => script.id).toSet();
    for (final script in merged) {
      if (existingIds.contains(script.id)) continue;
      final content = importedContents[script.id];
      if (content == null) continue;
      final file = await _storageService.getScriptFile(script.fileName);
      await file.writeAsBytes(content);
    }
  }

  bool _sameScript(ScriptEntry left, ScriptEntry right) {
    return left.name == right.name &&
        left.fileName == right.fileName &&
        left.group == right.group &&
        left.host == right.host &&
        left.targetPath == right.targetPath &&
        _sameStringList(left.tags, right.tags) &&
        left.createdAt == right.createdAt &&
        left.updatedAt == right.updatedAt &&
        left.lastRunAt == right.lastRunAt;
  }

  bool _sameSecret(SecretEntry left, SecretEntry right) {
    return left.name == right.name &&
        left.encryptedValue == right.encryptedValue &&
        left.nonce == right.nonce &&
        left.mac == right.mac &&
        left.createdAt == right.createdAt &&
        left.updatedAt == right.updatedAt;
  }

  bool _sameWrapper(SecretKeyWrapper left, SecretKeyWrapper right) {
    return left.type == right.type &&
        left.salt == right.salt &&
        left.nonce == right.nonce &&
        left.encryptedKey == right.encryptedKey &&
        left.mac == right.mac;
  }

  bool _sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  String _normalizeExportPath(String outputPath) {
    final cleaned = outputPath.trim();
    if (cleaned.isEmpty) throw StateError('Export path is required.');
    if (p.extension(cleaned).toLowerCase() == archiveExtension) return cleaned;
    return '$cleaned$archiveExtension';
  }

  String _safeArchiveScriptFileName(String fileName) {
    final baseName = p.basename(fileName);
    if (baseName.isEmpty || baseName == '.' || baseName == '..') {
      throw StateError('Script has an invalid file name.');
    }
    return baseName;
  }

  String _uniqueScriptFileName(String fileName, Set<String> usedFileNames) {
    final extension = p.extension(fileName);
    final stem = p.basenameWithoutExtension(fileName);
    var index = 1;
    while (true) {
      final candidate = '$stem-imported-$index$extension';
      if (usedFileNames.add(candidate)) return candidate;
      index++;
    }
  }

  String _uniqueSecretName(String name, Set<String> usedNames) {
    var index = 1;
    while (true) {
      final candidate = '${name}_IMPORTED_$index';
      if (usedNames.add(candidate)) return candidate;
      index++;
    }
  }

  String _newId(Set<String> usedIds) {
    while (true) {
      final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      final suffix = _random.nextInt(1 << 32).toRadixString(36);
      final id = '$timestamp$suffix';
      if (usedIds.add(id)) return id;
    }
  }
}

class VaultExportResult {
  final String path;
  final int scriptCount;
  final int hostCount;
  final int secretCount;

  const VaultExportResult({
    required this.path,
    required this.scriptCount,
    required this.hostCount,
    required this.secretCount,
  });
}

class VaultImportResult {
  final int importedScripts;
  final int importedHosts;
  final int importedSecrets;

  const VaultImportResult({
    required this.importedScripts,
    required this.importedHosts,
    required this.importedSecrets,
  });
}

class _DecodedVaultBundle {
  final List<ScriptEntry> scripts;
  final List<HostEntry> hosts;
  final SecretVault secretVault;
  final Map<String, List<int>> scriptContents;

  const _DecodedVaultBundle({
    required this.scripts,
    required this.hosts,
    required this.secretVault,
    required this.scriptContents,
  });
}

class _HostMerge {
  final List<HostEntry> hosts;
  final Map<String, String> idMap;
  final int importedCount;

  const _HostMerge({
    required this.hosts,
    required this.idMap,
    required this.importedCount,
  });
}

class _ScriptMerge {
  final List<ScriptEntry> scripts;
  final Map<String, List<int>> scriptContents;
  final int importedCount;

  const _ScriptMerge({
    required this.scripts,
    required this.scriptContents,
    required this.importedCount,
  });
}

class _SecretMerge {
  final SecretVault vault;
  final int importedCount;

  const _SecretMerge({required this.vault, required this.importedCount});
}
