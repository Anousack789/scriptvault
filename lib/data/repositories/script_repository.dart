import 'dart:math';

import '../../domain/models/script_detail.dart';
import '../../domain/models/script_entry.dart';
import '../../domain/models/script_run_result.dart';
import '../services/script_run_service.dart';
import '../services/script_storage_service.dart';

class ScriptRepository {
  final ScriptStorageService _storageService;
  final ScriptRunService _runService;
  final Random _random;

  ScriptRepository(this._storageService, this._runService, {Random? random})
    : _random = random ?? Random.secure();

  Future<List<ScriptEntry>> listScripts() async {
    final entries = await _storageService.loadEntries();
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Future<ScriptDetail?> getScript(String id) async {
    final entries = await _storageService.loadEntries();
    final entry = entries.where((candidate) => candidate.id == id).firstOrNull;
    if (entry == null) return null;

    return ScriptDetail(
      entry: entry,
      content: await _storageService.readScript(entry.fileName),
    );
  }

  Future<ScriptDetail> createScript({
    required String name,
    required String group,
    required List<String> tags,
    required String content,
  }) async {
    final entries = await _storageService.loadEntries();
    final now = DateTime.now();
    final id = _newId();
    final entry = ScriptEntry(
      id: id,
      name: _cleanName(name),
      fileName: '${_slug(name)}-$id.sh',
      group: _cleanGroup(group),
      tags: _cleanTags(tags),
      createdAt: now,
      updatedAt: now,
    );

    await _storageService.writeScript(entry.fileName, content);
    await _storageService.saveEntries([...entries, entry]);
    return ScriptDetail(entry: entry, content: content);
  }

  Future<ScriptDetail> updateScript({
    required String id,
    required String name,
    required String group,
    required List<String> tags,
    required String content,
  }) async {
    final entries = await _storageService.loadEntries();
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      throw StateError('Script not found');
    }

    final current = entries[index];
    final updated = current.copyWith(
      name: _cleanName(name),
      group: _cleanGroup(group),
      tags: _cleanTags(tags),
      updatedAt: DateTime.now(),
    );
    entries[index] = updated;

    await _storageService.writeScript(updated.fileName, content);
    await _storageService.saveEntries(entries);
    return ScriptDetail(entry: updated, content: content);
  }

  Future<void> deleteScript(String id) async {
    final entries = await _storageService.loadEntries();
    final entry = entries.where((candidate) => candidate.id == id).firstOrNull;
    if (entry == null) return;

    await _storageService.deleteScript(entry.fileName);
    await _storageService.saveEntries(
      entries.where((candidate) => candidate.id != id).toList(),
    );
  }

  Future<List<ScriptEntry>> searchScripts({
    String query = '',
    String? group,
    String? tag,
  }) async {
    final entries = await listScripts();
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedGroup = group?.trim().toLowerCase();
    final normalizedTag = tag?.trim().toLowerCase();
    final matches = <ScriptEntry>[];

    for (final entry in entries) {
      if (normalizedGroup != null &&
          normalizedGroup.isNotEmpty &&
          entry.group.toLowerCase() != normalizedGroup) {
        continue;
      }
      if (normalizedTag != null &&
          normalizedTag.isNotEmpty &&
          !entry.tags.map((tag) => tag.toLowerCase()).contains(normalizedTag)) {
        continue;
      }
      if (normalizedQuery.isEmpty) {
        matches.add(entry);
        continue;
      }

      final content = await _storageService.readScript(entry.fileName);
      final haystack = [
        entry.name,
        entry.group,
        entry.tags.join(' '),
        content,
      ].join(' ').toLowerCase();
      if (haystack.contains(normalizedQuery)) {
        matches.add(entry);
      }
    }

    return matches;
  }

  Future<ScriptRunResult> runScript({
    required String id,
    required String argumentsText,
  }) async {
    final entries = await _storageService.loadEntries();
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      throw StateError('Script not found');
    }

    final entry = entries[index];
    final scriptFile = await _storageService.getScriptFile(entry.fileName);
    final result = await _runService.run(
      scriptId: id,
      scriptFile: scriptFile,
      workingDirectory: await _storageService.getScriptsDirectory(),
      arguments: parseArguments(argumentsText),
    );

    entries[index] = entry.copyWith(lastRunAt: DateTime.now());
    await _storageService.saveEntries(entries);
    return result;
  }

  Future<bool> isDangerous(String id) async {
    final detail = await getScript(id);
    if (detail == null) return false;
    return hasDangerousCommands(detail.content);
  }

  bool hasDangerousCommands(String content) {
    final dangerous = RegExp(
      r'(^|\s)(sudo|rm|mv|chmod|chown|curl|wget)(\s|$)',
      multiLine: true,
    );
    return dangerous.hasMatch(content);
  }

  List<String> parseArguments(String text) {
    final args = <String>[];
    final buffer = StringBuffer();
    var quote = '';
    var escaping = false;

    for (final codeUnit in text.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (escaping) {
        buffer.write(char);
        escaping = false;
        continue;
      }
      if (char == r'\') {
        escaping = true;
        continue;
      }
      if (quote.isNotEmpty) {
        if (char == quote) {
          quote = '';
        } else {
          buffer.write(char);
        }
        continue;
      }
      if (char == '"' || char == "'") {
        quote = char;
        continue;
      }
      if (char.trim().isEmpty) {
        if (buffer.isNotEmpty) {
          args.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      args.add(buffer.toString());
    }
    return args;
  }

  String _newId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix = _random.nextInt(1 << 32).toRadixString(36);
    return '$timestamp$suffix';
  }

  String _cleanName(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return 'Untitled Script';
    return cleaned;
  }

  String _cleanGroup(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return 'General';
    return cleaned;
  }

  List<String> _cleanTags(List<String> values) {
    final normalized = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    normalized.sort();
    return normalized;
  }

  String _slug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) return 'script';
    return slug;
  }
}
