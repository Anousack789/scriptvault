import 'package:go_router/go_router.dart';

import '../ui/scripts/script_editor_view.dart';
import '../ui/scripts/scripts_list_view.dart';

abstract class AppRoutes {
  static const scripts = '/scripts';
  static const newScript = '/scripts/new';
  static const editScript = '/scripts/:id';

  static String editScriptPath(String id) => '/scripts/$id';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.scripts,
  routes: [
    GoRoute(
      path: AppRoutes.scripts,
      builder: (context, state) => const ScriptsListView(),
    ),
    GoRoute(
      path: AppRoutes.newScript,
      builder: (context, state) => const ScriptEditorView(scriptId: null),
    ),
    GoRoute(
      path: AppRoutes.editScript,
      builder: (context, state) {
        return ScriptEditorView(scriptId: state.pathParameters['id']);
      },
    ),
  ],
);
