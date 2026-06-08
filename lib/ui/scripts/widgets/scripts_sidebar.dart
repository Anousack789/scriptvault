import 'package:flutter/material.dart';

import '../../../domain/models/script_entry.dart';
import '../scripts_list_viewmodel.dart';
import 'script_group.dart';
import 'script_group_section.dart';

class ScriptsSidebar extends StatelessWidget {
  final ScriptsListState data;
  final List<String> tags;
  final bool isLoading;
  final Object? error;
  final String? selectedScriptId;
  final VoidCallback onNewScript;
  final VoidCallback onImportScript;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String> onGroupToggled;
  final ValueChanged<String> onScriptSelected;

  const ScriptsSidebar({
    super.key,
    required this.data,
    required this.tags,
    required this.isLoading,
    required this.error,
    required this.selectedScriptId,
    required this.onNewScript,
    required this.onImportScript,
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
                IconButton(
                  tooltip: 'Import script',
                  onPressed: onImportScript,
                  icon: const Icon(Icons.file_open_outlined),
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
                      return ScriptGroupSection(
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

  List<ScriptGroup> _groupScripts(List<ScriptEntry> scripts) {
    final grouped = <String, List<ScriptEntry>>{};
    for (final script in scripts) {
      grouped.putIfAbsent(script.group, () => []).add(script);
    }

    final groupNames = grouped.keys.toList()..sort();
    return [
      for (final groupName in groupNames)
        ScriptGroup(name: groupName, scripts: grouped[groupName]!),
    ];
  }
}
