import 'package:flutter/material.dart';

import '../../../domain/models/script_entry.dart';
import '../scripts_list_viewmodel.dart';
import 'script_group.dart';
import 'script_group_section.dart';
import '../../theme/script_vault_style.dart';

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
  final VoidCallback onHostsSelected;

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
    required this.onHostsSelected,
  });

  @override
  Widget build(BuildContext context) {
    final groupedScripts = _groupScripts(data.scripts);

    return Container(
      color: ScriptVaultStyle.appBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: ScriptVaultStyle.toolbarButtonStyle(),
                        onPressed: onNewScript,
                        icon: const Icon(Icons.add, size: 19),
                        label: const Text('New script'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'Import script',
                      onPressed: onImportScript,
                      icon: const Icon(Icons.note_add_outlined, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  style: const TextStyle(color: ScriptVaultStyle.text),
                  decoration:
                      ScriptVaultStyle.inputDecoration(
                        label: 'Search scripts...',
                        prefixIcon: Icons.search,
                      ).copyWith(
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                      ),
                  onChanged: onQueryChanged,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: data.tagFilter,
                  dropdownColor: ScriptVaultStyle.panelRaised,
                  decoration:
                      ScriptVaultStyle.inputDecoration(
                        label: 'All tags',
                      ).copyWith(
                        floatingLabelBehavior: FloatingLabelBehavior.never,
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
          Expanded(
            child: error != null
                ? Center(child: Text('Error: $error'))
                : isLoading
                ? const Center(child: CircularProgressIndicator())
                : data.scripts.isEmpty
                ? const Center(child: Text('No scripts found.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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
