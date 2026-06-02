import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/script_repository_provider.dart';
import '../../data/services/script_service_provider.dart';
import '../../domain/models/script_entry.dart';

class ScriptsListState {
  final List<ScriptEntry> scripts;
  final List<String> availableTags;
  final String query;
  final String? groupFilter;
  final String? tagFilter;
  final Set<String> collapsedGroups;

  const ScriptsListState({
    this.scripts = const [],
    this.availableTags = const [],
    this.query = '',
    this.groupFilter,
    this.tagFilter,
    this.collapsedGroups = const {},
  });

  List<String> get groups {
    final values = scripts.map((script) => script.group).toSet().toList();
    values.sort();
    return values;
  }

  List<String> get tags {
    final values = availableTags.toSet().toList();
    values.sort();
    return values;
  }

  ScriptsListState copyWith({
    List<ScriptEntry>? scripts,
    List<String>? availableTags,
    String? query,
    String? groupFilter,
    String? tagFilter,
    Set<String>? collapsedGroups,
    bool clearGroupFilter = false,
    bool clearTagFilter = false,
  }) {
    return ScriptsListState(
      scripts: scripts ?? this.scripts,
      availableTags: availableTags ?? this.availableTags,
      query: query ?? this.query,
      groupFilter: clearGroupFilter ? null : groupFilter ?? this.groupFilter,
      tagFilter: clearTagFilter ? null : tagFilter ?? this.tagFilter,
      collapsedGroups: collapsedGroups ?? this.collapsedGroups,
    );
  }
}

class ScriptsListViewModel extends AsyncNotifier<ScriptsListState> {
  @override
  Future<ScriptsListState> build() async {
    final scripts = await ref.read(scriptRepositoryProvider).searchScripts();
    final settings = await ref.read(appSettingsServiceProvider).loadSettings();
    return ScriptsListState(
      scripts: scripts,
      availableTags: _tagsFromScripts(scripts),
      collapsedGroups: settings.collapsedScriptGroups.toSet(),
    );
  }

  Future<void> refresh() async {
    final current = state.value ?? const ScriptsListState();
    final repository = ref.read(scriptRepositoryProvider);
    final scripts = await repository.searchScripts(
      query: current.query,
      group: current.groupFilter,
      tag: current.tagFilter,
    );
    final tagOptionScripts = await repository.searchScripts(
      query: current.query,
    );
    state = AsyncData(
      current.copyWith(
        scripts: scripts,
        availableTags: _tagsFromScripts(tagOptionScripts),
      ),
    );
  }

  Future<void> updateQuery(String value) async {
    final current = state.value ?? const ScriptsListState();
    state = AsyncData(current.copyWith(query: value));
    await refresh();
  }

  Future<void> updateGroup(String? value) async {
    final current = state.value ?? const ScriptsListState();
    state = AsyncData(
      current.copyWith(groupFilter: value, clearGroupFilter: value == null),
    );
    await refresh();
  }

  Future<void> updateTag(String? value) async {
    final current = state.value ?? const ScriptsListState();
    state = AsyncData(
      current.copyWith(tagFilter: value, clearTagFilter: value == null),
    );
    await refresh();
  }

  Future<void> toggleGroupCollapsed(String group) async {
    final current = state.value ?? const ScriptsListState();
    final collapsedGroups = {...current.collapsedGroups};
    if (!collapsedGroups.add(group)) {
      collapsedGroups.remove(group);
    }

    final next = current.copyWith(collapsedGroups: collapsedGroups);
    state = AsyncData(next);

    final service = ref.read(appSettingsServiceProvider);
    final settings = await service.loadSettings();
    final sortedGroups = collapsedGroups.toList()..sort();
    await service.saveSettings(
      settings.copyWith(collapsedScriptGroups: sortedGroups),
    );
  }

  List<String> _tagsFromScripts(List<ScriptEntry> scripts) {
    final tags = scripts.expand((script) => script.tags).toSet().toList();
    tags.sort();
    return tags;
  }
}

final scriptsListViewModelProvider =
    AsyncNotifierProvider<ScriptsListViewModel, ScriptsListState>(
      ScriptsListViewModel.new,
    );
