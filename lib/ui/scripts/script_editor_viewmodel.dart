import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/host_repository_provider.dart';
import '../../data/repositories/secret_repository_provider.dart';
import '../../data/repositories/script_repository_provider.dart';
import '../../domain/models/host_connection_result.dart';
import '../../domain/models/host_entry.dart';
import '../../domain/models/secret_entry.dart';
import '../../domain/models/script_run_result.dart';

class ScriptEditorState {
  final String? id;
  final String name;
  final String group;
  final String host;
  final String targetPath;
  final String tagsText;
  final String content;
  final String argumentsText;
  final List<HostEntry> hosts;
  final List<SecretEntry> secrets;
  final ScriptRunResult? lastRunResult;
  final bool isRunning;
  final bool hasUnsavedChanges;
  final bool isSaving;
  final String? saveError;

  const ScriptEditorState({
    this.id,
    this.name = '',
    this.group = 'General',
    this.host = '',
    this.targetPath = '',
    this.tagsText = '',
    this.content = '#!/usr/bin/env bash\n\n',
    this.argumentsText = '',
    this.hosts = const [],
    this.secrets = const [],
    this.lastRunResult,
    this.isRunning = false,
    this.hasUnsavedChanges = false,
    this.isSaving = false,
    this.saveError,
  });

  bool get isNew => id == null;
  bool get canRun => id != null && !isRunning && !isSaving;

  ScriptEditorState copyWith({
    String? id,
    String? name,
    String? group,
    String? host,
    String? targetPath,
    String? tagsText,
    String? content,
    String? argumentsText,
    List<HostEntry>? hosts,
    List<SecretEntry>? secrets,
    ScriptRunResult? lastRunResult,
    bool? isRunning,
    bool? hasUnsavedChanges,
    bool? isSaving,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return ScriptEditorState(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      host: host ?? this.host,
      targetPath: targetPath ?? this.targetPath,
      tagsText: tagsText ?? this.tagsText,
      content: content ?? this.content,
      argumentsText: argumentsText ?? this.argumentsText,
      hosts: hosts ?? this.hosts,
      secrets: secrets ?? this.secrets,
      lastRunResult: lastRunResult ?? this.lastRunResult,
      isRunning: isRunning ?? this.isRunning,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isSaving: isSaving ?? this.isSaving,
      saveError: clearSaveError ? null : saveError ?? this.saveError,
    );
  }
}

class ScriptEditorViewModel extends AsyncNotifier<ScriptEditorState> {
  final String? scriptId;

  ScriptEditorViewModel(this.scriptId);

  @override
  Future<ScriptEditorState> build() async {
    final hosts = await ref.read(hostRepositoryProvider).listHosts();
    final secrets = await ref.read(secretRepositoryProvider).listSecrets();
    if (scriptId == null) {
      return ScriptEditorState(hosts: hosts, secrets: secrets);
    }

    final detail = await ref
        .read(scriptRepositoryProvider)
        .getScript(scriptId!);
    if (detail == null) {
      throw StateError('Script not found');
    }

    return ScriptEditorState(
      id: detail.entry.id,
      name: detail.entry.name,
      group: detail.entry.group,
      host: detail.entry.host,
      targetPath: detail.entry.targetPath,
      tagsText: detail.entry.tags.join(', '),
      content: detail.content,
      hosts: hosts,
      secrets: secrets,
    );
  }

  void updateName(String value) {
    final current = state.value ?? const ScriptEditorState();
    state = AsyncData(_markDirty(current.copyWith(name: value)));
  }

  void updateGroup(String value) {
    final current = state.value ?? const ScriptEditorState();
    state = AsyncData(_markDirty(current.copyWith(group: value)));
  }

  void updateHost(String value) {
    final current = state.value ?? const ScriptEditorState();
    state = AsyncData(_markDirty(current.copyWith(host: value)));
  }

  Future<void> refreshHosts() async {
    final current = state.value ?? const ScriptEditorState();
    final hosts = await ref.read(hostRepositoryProvider).listHosts();
    state = AsyncData(current.copyWith(hosts: hosts));
  }

  Future<void> refreshSecrets() async {
    final current = state.value ?? const ScriptEditorState();
    final secrets = await ref.read(secretRepositoryProvider).listSecrets();
    state = AsyncData(current.copyWith(secrets: secrets));
  }

  Future<HostEntry> createHost({
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
  }) async {
    final host = await ref
        .read(hostRepositoryProvider)
        .createHost(
          name: name,
          address: address,
          username: username,
          port: port,
          authType: authType,
          password: password,
          keyPath: keyPath,
        );
    await refreshHosts();
    updateHost(host.id);
    return host;
  }

  Future<HostEntry> updateHostEntry({
    required String id,
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
  }) async {
    final host = await ref
        .read(hostRepositoryProvider)
        .updateHost(
          id: id,
          name: name,
          address: address,
          username: username,
          port: port,
          authType: authType,
          password: password,
          keyPath: keyPath,
        );
    await refreshHosts();
    return host;
  }

  Future<void> deleteHost(String id) async {
    await ref.read(hostRepositoryProvider).deleteHost(id);
    await refreshHosts();
    final current = state.requireValue;
    if (current.host == id) {
      updateHost('');
    }
  }

  Future<HostConnectionResult> testHostConnection({
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
  }) {
    return ref
        .read(hostRepositoryProvider)
        .testConnection(
          name: name,
          address: address,
          username: username,
          port: port,
          authType: authType,
          password: password,
          keyPath: keyPath,
        );
  }

  void updateTargetPath(String value) {
    final current = state.value ?? const ScriptEditorState();
    state = AsyncData(_markDirty(current.copyWith(targetPath: value)));
  }

  void updateTags(String value) {
    final current = state.value ?? const ScriptEditorState();
    state = AsyncData(_markDirty(current.copyWith(tagsText: value)));
  }

  void updateContent(String value) {
    final current = state.value ?? const ScriptEditorState();
    state = AsyncData(_markDirty(current.copyWith(content: value)));
  }

  void updateArguments(String value) {
    final current = state.value ?? const ScriptEditorState();
    state = AsyncData(current.copyWith(argumentsText: value));
  }

  Future<String> save() async {
    final current = state.requireValue;
    final repository = ref.read(scriptRepositoryProvider);
    final tags = _parseTags(current.tagsText);

    state = AsyncData(current.copyWith(isSaving: true, clearSaveError: true));
    try {
      final detail = current.id == null
          ? await repository.createScript(
              name: current.name,
              group: current.group,
              host: current.host,
              targetPath: current.targetPath,
              tags: tags,
              content: current.content,
            )
          : await repository.updateScript(
              id: current.id!,
              name: current.name,
              group: current.group,
              host: current.host,
              targetPath: current.targetPath,
              tags: tags,
              content: current.content,
            );

      final latest = state.value ?? current;
      final editedDuringSave = !_hasSameEditableValues(current, latest);
      state = AsyncData(
        latest.copyWith(
          id: detail.entry.id,
          name: editedDuringSave ? latest.name : detail.entry.name,
          group: editedDuringSave ? latest.group : detail.entry.group,
          host: editedDuringSave ? latest.host : detail.entry.host,
          targetPath: editedDuringSave
              ? latest.targetPath
              : detail.entry.targetPath,
          tagsText: editedDuringSave
              ? latest.tagsText
              : detail.entry.tags.join(', '),
          content: editedDuringSave ? latest.content : detail.content,
          hosts: latest.hosts,
          secrets: latest.secrets,
          hasUnsavedChanges: editedDuringSave,
          isSaving: false,
          clearSaveError: true,
        ),
      );
      return detail.entry.id;
    } catch (error) {
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          hasUnsavedChanges: true,
          isSaving: false,
          saveError: error.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> delete() async {
    final id = state.requireValue.id;
    if (id == null) return;
    await ref.read(scriptRepositoryProvider).deleteScript(id);
  }

  Future<bool> requiresRunConfirmation() async {
    final id = state.requireValue.id;
    if (id == null) return false;
    return ref.read(scriptRepositoryProvider).isDangerous(id);
  }

  Future<void> run() async {
    final current = state.requireValue;
    if (current.id == null) return;

    state = AsyncData(current.copyWith(isRunning: true));
    final result = await ref
        .read(scriptRepositoryProvider)
        .runScript(id: current.id!, argumentsText: current.argumentsText);
    state = AsyncData(
      state.requireValue.copyWith(isRunning: false, lastRunResult: result),
    );
  }

  List<String> _parseTags(String value) {
    return value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  ScriptEditorState _markDirty(ScriptEditorState state) {
    return state.copyWith(hasUnsavedChanges: true, clearSaveError: true);
  }

  bool _hasSameEditableValues(ScriptEditorState left, ScriptEditorState right) {
    return left.name == right.name &&
        left.group == right.group &&
        left.host == right.host &&
        left.targetPath == right.targetPath &&
        left.tagsText == right.tagsText &&
        left.content == right.content;
  }
}

final scriptEditorViewModelProvider =
    AsyncNotifierProvider.family<
      ScriptEditorViewModel,
      ScriptEditorState,
      String?
    >(ScriptEditorViewModel.new);
