import 'package:flutter/material.dart';

import '../script_editor_viewmodel.dart';
import 'bound_text_field.dart';
import 'host_selector.dart';
import 'script_run_output.dart';

class InspectorPane extends StatelessWidget {
  final ScriptEditorState data;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onHostChanged;
  final ValueChanged<String> onTargetPathChanged;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String> onArgumentsChanged;
  final VoidCallback onManageHosts;

  const InspectorPane({
    super.key,
    required this.data,
    required this.onNameChanged,
    required this.onGroupChanged,
    required this.onHostChanged,
    required this.onTargetPathChanged,
    required this.onTagsChanged,
    required this.onArgumentsChanged,
    required this.onManageHosts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252526),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Details', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          BoundTextField(
            value: data.name,
            label: 'Script name',
            onChanged: onNameChanged,
          ),
          const SizedBox(height: 12),
          BoundTextField(
            value: data.group,
            label: 'Group',
            onChanged: onGroupChanged,
          ),
          const SizedBox(height: 12),
          HostSelector(
            value: data.host,
            hosts: data.hosts,
            onChanged: onHostChanged,
            onManageHosts: onManageHosts,
          ),
          const SizedBox(height: 12),
          BoundTextField(
            value: data.targetPath,
            label: 'Target path',
            onChanged: onTargetPathChanged,
          ),
          const SizedBox(height: 12),
          BoundTextField(
            value: data.tagsText,
            label: 'Tags',
            helperText: 'Comma-separated',
            onChanged: onTagsChanged,
          ),
          const SizedBox(height: 20),
          Text('Run', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Arguments',
              border: OutlineInputBorder(),
            ),
            onChanged: onArgumentsChanged,
          ),
          const SizedBox(height: 16),
          ScriptRunOutput(
            result: data.lastRunResult,
            isRunning: data.isRunning,
          ),
        ],
      ),
    );
  }
}
