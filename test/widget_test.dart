import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scriptvault/data/services/app_update_service.dart';
import 'package:scriptvault/data/services/script_service_provider.dart';
import 'package:scriptvault/data/services/script_storage_service.dart';
import 'package:scriptvault/ui/hosts/hosts_view.dart';
import 'package:scriptvault/ui/home/home_view.dart';
import 'package:scriptvault/ui/secrets/secrets_view.dart';

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

  testWidgets('renders the home shell with scripts tab', (tester) async {
    final storageService = ScriptStorageService(rootDirectory: tempDirectory);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scriptStorageServiceProvider.overrideWith((ref) => storageService),
          appUpdateServiceProvider.overrideWith((ref) => _noUpdateService()),
        ],
        child: const MaterialApp(home: HomeView()),
      ),
    );

    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();

    expect(find.text('Scripts'), findsWidgets);
    expect(find.text('Hosts'), findsWidgets);
    expect(find.text('Secrets'), findsWidgets);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byTooltip('Import script'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders the hosts tab', (tester) async {
    final storageService = ScriptStorageService(rootDirectory: tempDirectory);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scriptStorageServiceProvider.overrideWith((ref) => storageService),
          appUpdateServiceProvider.overrideWith((ref) => _noUpdateService()),
        ],
        child: const MaterialApp(
          home: HomeView(initialTab: WorkspaceTab.hosts),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Hosts'), findsWidgets);
    expect(find.byType(HostsView), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders the secrets tab', (tester) async {
    final storageService = ScriptStorageService(rootDirectory: tempDirectory);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scriptStorageServiceProvider.overrideWith((ref) => storageService),
          appUpdateServiceProvider.overrideWith((ref) => _noUpdateService()),
        ],
        child: const MaterialApp(
          home: HomeView(initialTab: WorkspaceTab.secrets),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Secrets'), findsWidgets);
    expect(find.byType(SecretsView), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

AppUpdateService _noUpdateService() {
  return AppUpdateService(
    client: MockClient((request) async {
      return http.Response('''
{
  "tag_name": "v1.0.3",
  "html_url": "https://github.com/Anousack789/scriptvault/releases/tag/v1.0.3",
  "assets": []
}
''', 200);
    }),
    packageInfoLoader: () async => PackageInfo(
      appName: 'ScriptVault',
      packageName: 'com.nonostack.scriptvault',
      version: '1.0.3',
      buildNumber: '4',
    ),
  );
}
