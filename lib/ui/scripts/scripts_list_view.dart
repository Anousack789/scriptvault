import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/script_entry.dart';
import '../../router/router.dart';
import 'script_editor_view.dart';
import 'script_editor_viewmodel.dart';
import 'scripts_list_viewmodel.dart';
import 'widgets/script_list_item.dart';

class ScriptsListView extends ConsumerStatefulWidget {
  const ScriptsListView({super.key});

  @override
  ConsumerState<ScriptsListView> createState() => _ScriptsListViewState();
}

class _ScriptsListViewState extends ConsumerState<ScriptsListView> {
  String? _selectedScriptId;
  var _isCreatingScript = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scriptsListViewModelProvider);
    final viewModel = ref.read(scriptsListViewModelProvider.notifier);
    final data = state.value ?? const ScriptsListState();
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final tags = {
      ...data.tags,
      if (data.tagFilter != null) data.tagFilter!,
    }.toList()..sort();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: isWide ? 320 : MediaQuery.sizeOf(context).width,
          child: _ScriptsSidebar(
            data: data,
            tags: tags,
            isLoading: state.isLoading && !state.hasValue,
            error: state.hasError && !state.hasValue ? state.error : null,
            selectedScriptId: _isCreatingScript ? null : _selectedScriptId,
            onNewScript: () => _newScript(isWide),
            onQueryChanged: viewModel.updateQuery,
            onTagChanged: viewModel.updateTag,
            onGroupToggled: viewModel.toggleGroupCollapsed,
            onScriptSelected: (scriptId) =>
                _selectScript(scriptId: scriptId, isWide: isWide),
          ),
        ),
        if (isWide) ...[
          Container(width: 1, color: const Color(0xFF2D2D30)),
          Expanded(
            child: _isCreatingScript || _selectedScriptId != null
                ? ScriptEditorView(
                    key: ValueKey(
                      _isCreatingScript
                          ? 'new-script'
                          : 'script-$_selectedScriptId',
                    ),
                    scriptId: _isCreatingScript ? null : _selectedScriptId,
                    embedded: true,
                    onSaved: (scriptId) async {
                      setState(() {
                        _isCreatingScript = false;
                        _selectedScriptId = scriptId;
                      });
                      await viewModel.refresh();
                    },
                    onDeleted: () async {
                      setState(() {
                        _selectedScriptId = null;
                        _isCreatingScript = false;
                      });
                      await viewModel.refresh();
                    },
                    onClose: () {
                      setState(() {
                        _selectedScriptId = null;
                        _isCreatingScript = false;
                      });
                    },
                  )
                : const _EmptyEditorPane(),
          ),
        ],
      ],
    );
  }

  void _newScript(bool isWide) {
    if (!isWide) {
      context.go(AppRoutes.newScript);
      return;
    }

    ref.invalidate(scriptEditorViewModelProvider(null));
    setState(() {
      _selectedScriptId = null;
      _isCreatingScript = true;
    });
  }

  void _selectScript({required String scriptId, required bool isWide}) {
    if (!isWide) {
      context.go(AppRoutes.editScriptPath(scriptId));
      return;
    }

    setState(() {
      _selectedScriptId = scriptId;
      _isCreatingScript = false;
    });
  }
}

class _ScriptsSidebar extends StatelessWidget {
  final ScriptsListState data;
  final List<String> tags;
  final bool isLoading;
  final Object? error;
  final String? selectedScriptId;
  final VoidCallback onNewScript;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String> onGroupToggled;
  final ValueChanged<String> onScriptSelected;

  const _ScriptsSidebar({
    required this.data,
    required this.tags,
    required this.isLoading,
    required this.error,
    required this.selectedScriptId,
    required this.onNewScript,
    required this.onQueryChanged,
    required this.onTagChanged,
    required this.onGroupToggled,
    required this.onScriptSelected,
  });

  @override
  Widget build(BuildContext context) {
    final groupedScripts = _groupScripts(data.scripts);

    return Container(
      color: const Color(0xFF252526),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2D2D30))),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Scripts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'New script',
                  onPressed: onNewScript,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search scripts',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: onQueryChanged,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: data.tagFilter,
                  decoration: const InputDecoration(
                    labelText: 'Tag',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All tags'),
                    ),
                    for (final tag in tags)
                      DropdownMenuItem(value: tag, child: Text(tag)),
                  ],
                  onChanged: onTagChanged,
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFF2D2D30)),
          Expanded(
            child: error != null
                ? Center(child: Text('Error: $error'))
                : isLoading
                ? const Center(child: CircularProgressIndicator())
                : data.scripts.isEmpty
                ? const Center(child: Text('No scripts found.'))
                : ListView.builder(
                    itemCount: groupedScripts.length,
                    itemBuilder: (context, index) {
                      final group = groupedScripts[index];
                      final isCollapsed = data.collapsedGroups.contains(
                        group.name,
                      );
                      return _ScriptGroupSection(
                        group: group,
                        collapsed: isCollapsed,
                        selectedScriptId: selectedScriptId,
                        onToggle: () => onGroupToggled(group.name),
                        onScriptSelected: onScriptSelected,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<_ScriptGroup> _groupScripts(List<ScriptEntry> scripts) {
    final grouped = <String, List<ScriptEntry>>{};
    for (final script in scripts) {
      grouped.putIfAbsent(script.group, () => []).add(script);
    }

    final groupNames = grouped.keys.toList()..sort();
    return [
      for (final groupName in groupNames)
        _ScriptGroup(name: groupName, scripts: grouped[groupName]!),
    ];
  }
}

class _ScriptGroup {
  final String name;
  final List<ScriptEntry> scripts;

  const _ScriptGroup({required this.name, required this.scripts});
}

class _ScriptGroupSection extends StatelessWidget {
  final _ScriptGroup group;
  final bool collapsed;
  final String? selectedScriptId;
  final VoidCallback onToggle;
  final ValueChanged<String> onScriptSelected;

  const _ScriptGroupSection({
    required this.group,
    required this.collapsed,
    required this.selectedScriptId,
    required this.onToggle,
    required this.onScriptSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFF252526),
          child: InkWell(
            onTap: onToggle,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_right
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: const Color(0xFF9DA5B4),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    collapsed ? Icons.folder_outlined : Icons.folder_open,
                    size: 18,
                    color: const Color(0xFFD7BA7D),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    group.scripts.length.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9DA5B4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!collapsed)
          for (final script in group.scripts)
            ScriptListItem(
              script: script,
              selected: script.id == selectedScriptId,
              onTap: () => onScriptSelected(script.id),
            ),
      ],
    );
  }
}

class _EmptyEditorPane extends StatelessWidget {
  const _EmptyEditorPane();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.code, size: 44, color: Color(0xFF6B7280)),
            const SizedBox(height: 14),
            Text(
              'Select a script',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a script from the left sidebar or create a new one.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9DA5B4)),
            ),
          ],
        ),
      ),
    );
  }
}
