import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/bash.dart';
import 'package:scriptvault/domain/models/script_entry.dart';
import 'package:scriptvault/ui/scripts/script_editor_viewmodel.dart';
import 'package:scriptvault/ui/scripts/scripts_list_viewmodel.dart';
import 'package:scriptvault/ui/scripts/widgets/editor_workspace.dart';
import 'package:scriptvault/ui/scripts/widgets/empty_editor_pane.dart';
import 'package:scriptvault/ui/scripts/widgets/scripts_sidebar.dart';

void main() {
  testWidgets('sidebar renders grouped scripts and selected state', (
    tester,
  ) async {
    var selectedScript = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ScriptsSidebar(
              data: ScriptsListState(
                scripts: [
                  _script(
                    id: 'selected',
                    name: 'DB fast pos backup',
                    group: 'Database',
                    tags: const ['DB', 'Starred'],
                    lastRunAt: DateTime.now().subtract(
                      const Duration(hours: 2),
                    ),
                  ),
                  _script(
                    id: 'other',
                    name: 'Log access of Coolify',
                    group: 'Database',
                    tags: const ['DB'],
                  ),
                ],
              ),
              tags: const ['DB', 'Starred'],
              isLoading: false,
              error: null,
              selectedScriptId: 'selected',
              onNewScript: () {},
              onImportScript: () {},
              onQueryChanged: (_) {},
              onTagChanged: (_) {},
              onGroupToggled: (_) {},
              onScriptSelected: (id) => selectedScript = id,
              onHostsSelected: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Database'), findsWidgets);
    expect(find.text('DB fast pos backup'), findsWidgets);
    expect(find.text('Log access of Coolify'), findsOneWidget);
    expect(find.text('Success'), findsOneWidget);

    await tester.tap(find.text('Log access of Coolify'));
    expect(selectedScript, 'other');
  });

  testWidgets('editor workspace shows actions, inspector, and output panel', (
    tester,
  ) async {
    final controller = CodeController(language: bash, text: 'echo ok\n');
    addTearDown(controller.dispose);
    var saved = false;
    var ran = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 820,
            child: EditorWorkspace(
              scriptId: 'script-1',
              data: const ScriptEditorState(
                id: 'script-1',
                name: 'DB fast pos backup',
                group: 'Database',
                targetPath: '/opt/backups',
                tagsText: 'DB, Starred',
                content: 'echo ok\n',
              ),
              editorFontSize: 14,
              codeController: controller,
              onNameChanged: (_) {},
              onGroupChanged: (_) {},
              onHostChanged: (_) {},
              onTargetPathChanged: (_) {},
              onTagsChanged: (_) {},
              onArgumentsChanged: (_) {},
              onManageHosts: () {},
              onSave: () => saved = true,
              onDelete: () {},
              onRun: () => ran = true,
              onClose: () {},
              embedded: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('DB fast pos backup'), findsWidgets);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Output'), findsOneWidget);
    expect(find.text('Target path'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Run'));
    expect(saved, isTrue);
    expect(ran, isTrue);
  });

  testWidgets('empty editor state remains available', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmptyEditorPane())),
    );

    expect(find.text('Select a script'), findsOneWidget);
    expect(
      find.text('Choose a script from the left sidebar or create a new one.'),
      findsOneWidget,
    );
  });
}

ScriptEntry _script({
  required String id,
  required String name,
  required String group,
  required List<String> tags,
  DateTime? lastRunAt,
}) {
  final now = DateTime(2026, 6, 8);
  return ScriptEntry(
    id: id,
    name: name,
    fileName: '$id.sh',
    group: group,
    host: '',
    targetPath: '',
    tags: tags,
    createdAt: now,
    updatedAt: now,
    lastRunAt: lastRunAt,
  );
}
