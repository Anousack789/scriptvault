import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scriptvault/data/services/script_service_provider.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';
import 'package:scriptvault/ui/scripts/scripts_list_view.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'scriptvault_widget_',
    );
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('renders the script list shell', (tester) async {
    final storageService = ScriptStorageService(rootDirectory: tempDirectory);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scriptStorageServiceProvider.overrideWith((ref) => storageService),
        ],
        child: const MaterialApp(home: ScriptsListView()),
      ),
    );

    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();

    expect(find.text('ScriptVault'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
