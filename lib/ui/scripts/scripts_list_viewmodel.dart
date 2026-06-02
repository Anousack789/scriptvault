import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/script_repository_provider.dart';
import '../../data/services/script_service_provider.dart';
import '../../domain/models/script_entry.dart';

class ScriptsListState {
  final List<ScriptEntry> scripts;
  final String query;
  final String? groupFilter;
  final String? tagFilter;
  final Set<String> collapsedGroups;

  const ScriptsListState({
    this.scripts = const [],
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
    final values = scripts.expand((script) => script.tags).toSet().toList();
    values.sort();
    return values;
  }

  ScriptsListState copyWith({
    List<ScriptEntry>? scripts,
    String? query,
    String? groupFilter,
    String? tagFilter,
    Set<String>? collapsedGroups,
    bool clearGroupFilter = false,
    bool clearTagFilter = false,
  }) {
    return ScriptsListState(
      scripts: scripts ?? this.scripts,
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
      collapsedGroups: settings.collapsedScriptGroups.toSet(),
    );
  }

  Future<void> refresh() async {
    final current = state.value ?? const ScriptsListState();
    final scripts = await ref
        .read(scriptRepositoryProvider)
        .searchScripts(
          query: current.query,
          group: current.groupFilter,
          tag: current.tagFilter,
        );
    state = AsyncData(current.copyWith(scripts: scripts));
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
}

final scriptsListViewModelProvider =
    AsyncNotifierProvider<ScriptsListViewModel, ScriptsListState>(
      ScriptsListViewModel.new,
    );
