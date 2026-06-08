import 'package:flutter/material.dart';

import '../script_editor_viewmodel.dart';
import 'bound_text_field.dart';
import 'host_selector.dart';
import '../../theme/script_vault_style.dart';

enum _InspectorTab { details, run, history }

class InspectorPane extends StatefulWidget {
  final ScriptEditorState data;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onHostChanged;
  final ValueChanged<String> onTargetPathChanged;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String> onArgumentsChanged;
  final VoidCallback onManageHosts;
  final VoidCallback onDelete;

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
    required this.onDelete,
  });

  @override
  State<InspectorPane> createState() => _InspectorPaneState();
}

class _InspectorPaneState extends State<InspectorPane> {
  var _activeTab = _InspectorTab.details;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ScriptVaultStyle.appBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabs(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              children: switch (_activeTab) {
                _InspectorTab.details => _buildDetails(context),
                _InspectorTab.run => _buildRun(context),
                _InspectorTab.history => _buildHistory(context),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ScriptVaultStyle.border)),
      ),
      child: Row(
        children: [
          _tabButton('Details', _InspectorTab.details),
          const SizedBox(width: 28),
          _tabButton('Run', _InspectorTab.run),
          const SizedBox(width: 28),
          _tabButton('History', _InspectorTab.history),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _InspectorTab tab) {
    final selected = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        height: 66,
        alignment: Alignment.center,
        decoration: selected
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ScriptVaultStyle.primary, width: 2),
                ),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? ScriptVaultStyle.primary : ScriptVaultStyle.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetails(BuildContext context) {
    return [
      _sectionTitle(context, 'Script'),
      const SizedBox(height: 18),
      BoundTextField(
        value: widget.data.name,
        label: 'Name',
        onChanged: widget.onNameChanged,
      ),
      const SizedBox(height: 14),
      BoundTextField(
        value: widget.data.group,
        label: 'Group',
        onChanged: widget.onGroupChanged,
      ),
      const SizedBox(height: 14),
      BoundTextField(
        value: widget.data.tagsText,
        label: 'Tags',
        helperText: 'Comma-separated',
        onChanged: widget.onTagsChanged,
      ),
      const SizedBox(height: 24),
      const Divider(color: ScriptVaultStyle.border),
      const SizedBox(height: 20),
      _sectionTitle(context, 'Host'),
      const SizedBox(height: 18),
      HostSelector(
        value: widget.data.host,
        hosts: widget.data.hosts,
        onChanged: widget.onHostChanged,
        onManageHosts: widget.onManageHosts,
      ),
      const SizedBox(height: 14),
      BoundTextField(
        value: widget.data.targetPath,
        label: 'Target path',
        onChanged: widget.onTargetPathChanged,
      ),
      const SizedBox(height: 8),
      Text(
        'Where the script will run.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: ScriptVaultStyle.muted),
      ),
      const SizedBox(height: 24),
      const Divider(color: ScriptVaultStyle.border),
      const SizedBox(height: 20),
      Text(
        'Danger zone',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.redAccent,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: widget.onDelete,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFB91C1C),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete script'),
      ),
    ];
  }

  List<Widget> _buildRun(BuildContext context) {
    return [
      _sectionTitle(context, 'Run'),
      const SizedBox(height: 18),
      TextField(
        style: const TextStyle(color: ScriptVaultStyle.text),
        decoration: ScriptVaultStyle.inputDecoration(label: 'Arguments'),
        onChanged: widget.onArgumentsChanged,
      ),
      const SizedBox(height: 12),
      Text(
        widget.data.isRunning
            ? 'Script is running.'
            : widget.data.lastRunResult == null
            ? 'Run output appears below the editor.'
            : 'Last exit code ${widget.data.lastRunResult!.exitCode}.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: ScriptVaultStyle.muted),
      ),
    ];
  }

  List<Widget> _buildHistory(BuildContext context) {
    return [
      _sectionTitle(context, 'History'),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: ScriptVaultStyle.panelDecoration(),
        child: Text(
          'Run history is not stored yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: ScriptVaultStyle.muted),
        ),
      ),
    ];
  }

  Widget _sectionTitle(BuildContext context, String value) {
    return Text(
      value,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: ScriptVaultStyle.muted,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
