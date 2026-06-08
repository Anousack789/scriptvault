import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs2015.dart';

import '../script_editor_viewmodel.dart';
import 'inspector_pane.dart';
import 'script_run_output.dart';
import '../../theme/script_vault_style.dart';

class EditorWorkspace extends StatelessWidget {
  final String? scriptId;
  final ScriptEditorState data;
  final double editorFontSize;
  final CodeController codeController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onHostChanged;
  final ValueChanged<String> onTargetPathChanged;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String> onArgumentsChanged;
  final VoidCallback onManageHosts;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onRun;
  final VoidCallback? onClose;
  final bool embedded;

  const EditorWorkspace({
    super.key,
    required this.scriptId,
    required this.data,
    required this.editorFontSize,
    required this.codeController,
    required this.onNameChanged,
    required this.onGroupChanged,
    required this.onHostChanged,
    required this.onTargetPathChanged,
    required this.onTagsChanged,
    required this.onArgumentsChanged,
    required this.onManageHosts,
    required this.onSave,
    required this.onDelete,
    required this.onRun,
    required this.onClose,
    required this.embedded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ScriptVaultStyle.appBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 14),
                  Expanded(child: _buildEditorPanel(context)),
                  const SizedBox(height: 14),
                  SizedBox(height: 264, child: _buildOutputPanel()),
                ],
              ),
            ),
          ),
          Container(width: 1, color: ScriptVaultStyle.border),
          SizedBox(
            width: embedded ? 354 : 380,
            child: InspectorPane(
              data: data,
              onNameChanged: onNameChanged,
              onGroupChanged: onGroupChanged,
              onHostChanged: onHostChanged,
              onTargetPathChanged: onTargetPathChanged,
              onTagsChanged: onTagsChanged,
              onArgumentsChanged: onArgumentsChanged,
              onManageHosts: onManageHosts,
              onDelete: onDelete ?? () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = data.name.trim().isEmpty ? 'Untitled script' : data.name;
    final hostLabel = _hostLabel;

    return SizedBox(
      height: 58,
      child: Row(
        children: [
          if (onClose != null) ...[
            IconButton(
              tooltip: 'Back',
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showMeta = constraints.maxWidth >= 240;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: ScriptVaultStyle.text,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_tags
                            .map((tag) => tag.toLowerCase())
                            .contains('starred'))
                          const Icon(
                            Icons.star,
                            size: 20,
                            color: ScriptVaultStyle.folder,
                          ),
                      ],
                    ),
                    if (showMeta) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _metaItem(Icons.folder_outlined, data.group),
                          _metaItem(Icons.computer_outlined, hostLabel),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          FilledButton.icon(
            style: ScriptVaultStyle.toolbarButtonStyle(emphasized: true),
            onPressed: onRun,
            icon: data.isRunning
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, size: 19),
            label: const Text('Run'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            style: ScriptVaultStyle.toolbarButtonStyle(),
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPanel(BuildContext context) {
    return Container(
      decoration: ScriptVaultStyle.panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: ScriptVaultStyle.panel,
              border: Border(top: BorderSide(color: ScriptVaultStyle.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _statusText('Bash'),
                  _dot(),
                  _statusText(_hostLabel),
                  _dot(),
                  _statusText(
                    '${codeController.text.split('\n').length} lines',
                  ),
                  _dot(),
                  _statusText('LF'),
                  _dot(),
                  _statusText('UTF-8'),
                  _dot(),
                  Icon(
                    data.isNew ? Icons.circle_outlined : Icons.check_circle,
                    size: 15,
                    color: data.isNew
                        ? ScriptVaultStyle.warning
                        : ScriptVaultStyle.success,
                  ),
                  const SizedBox(width: 6),
                  _statusText(data.isNew ? 'Unsaved' : 'Saved'),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: ScriptVaultStyle.editor,
              child: CodeTheme(
                data: CodeThemeData(styles: vs2015Theme),
                child: CodeField(
                  controller: codeController,
                  expands: true,
                  textStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: editorFontSize,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputPanel() {
    return Container(
      decoration: ScriptVaultStyle.panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ScriptVaultStyle.border),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _outputTab(label: 'Output', selected: true),
                  const SizedBox(width: 26),
                  _outputTab(label: 'Errors', selected: false),
                  const SizedBox(width: 26),
                  _outputTab(label: 'Logs', selected: false),
                  const SizedBox(width: 42),
                  const Icon(
                    Icons.access_time,
                    size: 15,
                    color: ScriptVaultStyle.muted,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Latest run',
                    style: TextStyle(
                      color: ScriptVaultStyle.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ScriptRunOutput(
                result: data.lastRunResult,
                isRunning: data.isRunning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: ScriptVaultStyle.muted),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            label.isEmpty ? 'Not set' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ScriptVaultStyle.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: ScriptVaultStyle.muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _dot() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Text('-', style: TextStyle(color: ScriptVaultStyle.subtle)),
    );
  }

  Widget _outputTab({required String label, required bool selected}) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 42,
        padding: const EdgeInsets.only(top: 12),
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
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String get _hostLabel {
    if (data.host.isEmpty) return 'Local machine';
    final host = data.hosts.where((host) => host.id == data.host).firstOrNull;
    return host?.name ?? data.host;
  }

  List<String> get _tags {
    return data.tagsText
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }
}
