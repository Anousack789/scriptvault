import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/script_repository_provider.dart';
import '../../router/router.dart';
import 'script_editor_view.dart';
import 'script_editor_viewmodel.dart';
import 'scripts_list_viewmodel.dart';
import 'widgets/empty_editor_pane.dart';
import 'widgets/scripts_sidebar.dart';
import '../theme/script_vault_style.dart';

class ScriptsListView extends ConsumerStatefulWidget {
  final VoidCallback? onHostsSelected;

  const ScriptsListView({super.key, this.onHostsSelected});

  @override
  ConsumerState<ScriptsListView> createState() => _ScriptsListViewState();
}

class _ScriptsListViewState extends ConsumerState<ScriptsListView> {
  static const _filePanelChannel = MethodChannel('scriptvault/save_panel');

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

    return Container(
      color: ScriptVaultStyle.appBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: isWide ? 300 : MediaQuery.sizeOf(context).width,
            child: ScriptsSidebar(
              data: data,
              tags: tags,
              isLoading: state.isLoading && !state.hasValue,
              error: state.hasError && !state.hasValue ? state.error : null,
              selectedScriptId: _isCreatingScript ? null : _selectedScriptId,
              onNewScript: () => _newScript(isWide),
              onImportScript: () => _importScript(isWide),
              onQueryChanged: viewModel.updateQuery,
              onTagChanged: viewModel.updateTag,
              onGroupToggled: viewModel.toggleGroupCollapsed,
              onScriptSelected: (scriptId) =>
                  _selectScript(scriptId: scriptId, isWide: isWide),
              onHostsSelected: widget.onHostsSelected ?? () {},
            ),
          ),
          if (isWide) ...[
            Container(width: 1, color: ScriptVaultStyle.border),
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
                  : const EmptyEditorPane(),
            ),
          ],
        ],
      ),
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

  Future<void> _importScript(bool isWide) async {
    try {
      final path = await _filePanelChannel.invokeMethod<String>(
        'chooseScriptFile',
      );
      if (path == null || path.isEmpty) return;

      final detail = await ref
          .read(scriptRepositoryProvider)
          .importScriptFile(path);
      await ref.read(scriptsListViewModelProvider.notifier).refresh();
      if (!mounted) return;

      if (!isWide) {
        context.go(AppRoutes.editScriptPath(detail.entry.id));
        return;
      }

      setState(() {
        _isCreatingScript = false;
        _selectedScriptId = detail.entry.id;
      });
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import dialog is unavailable.')),
      );
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Script file must be UTF-8 text.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }
}
