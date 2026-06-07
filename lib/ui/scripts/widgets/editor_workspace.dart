import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs2015.dart';

import '../script_editor_viewmodel.dart';
import 'editor_toolbar.dart';
import 'inspector_pane.dart';

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
  final VoidCallback onSettings;
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
    required this.onSettings,
    required this.onClose,
    required this.embedded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EditorToolbar(
          title: scriptId == null ? 'New script' : data.name,
          subtitle: scriptId == null ? 'Unsaved script' : data.group,
          onSave: onSave,
          onDelete: onDelete,
          onRun: onRun,
          onSettings: onSettings,
          onClose: onClose,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: CodeTheme(
                      data: CodeThemeData(styles: vs2015Theme),
                      child: CodeField(
                        controller: codeController,
                        textStyle: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: editorFontSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, color: const Color(0xFF2D2D30)),
              SizedBox(
                width: embedded ? 320 : 360,
                child: InspectorPane(
                  data: data,
                  onNameChanged: onNameChanged,
                  onGroupChanged: onGroupChanged,
                  onHostChanged: onHostChanged,
                  onTargetPathChanged: onTargetPathChanged,
                  onTagsChanged: onTagsChanged,
                  onArgumentsChanged: onArgumentsChanged,
                  onManageHosts: onManageHosts,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
