import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scriptvault/domain/models/app_settings.dart';
import 'package:scriptvault/domain/models/app_update_info.dart';
import 'package:scriptvault/ui/settings/app_update_viewmodel.dart';
import 'package:scriptvault/ui/settings/settings_dialog.dart';

void main() {
  testWidgets('shows update checking state', (tester) async {
    await _pumpDialog(
      tester,
      const AppUpdateState(status: AppUpdateStatus.checking),
    );

    expect(find.text('Checking...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows no update state', (tester) async {
    await _pumpDialog(
      tester,
      const AppUpdateState(status: AppUpdateStatus.noUpdate),
    );

    expect(find.text('ScriptVault is up to date.'), findsOneWidget);
  });

  testWidgets('shows update available state', (tester) async {
    await _pumpDialog(
      tester,
      AppUpdateState(
        status: AppUpdateStatus.updateAvailable,
        updateInfo: _updateInfo(),
      ),
    );

    expect(find.text('Version v1.0.4 is available.'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('shows update check failure state', (tester) async {
    await _pumpDialog(
      tester,
      const AppUpdateState(
        status: AppUpdateStatus.checkFailed,
        errorMessage: 'GitHub returned 404.',
      ),
    );

    expect(find.text('GitHub returned 404.'), findsOneWidget);
  });

  testWidgets('saves auto save preference', (tester) async {
    var autoSaveEnabled = false;
    await _pumpDialog(
      tester,
      const AppUpdateState(),
      onAutoSaveEnabledSaved: (value) => autoSaveEnabled = value,
    );

    await tester.tap(find.text('Auto save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));

    expect(autoSaveEnabled, isTrue);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester,
  AppUpdateState updateState, {
  ValueChanged<bool>? onAutoSaveEnabledSaved,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: SettingsDialog(
        settings: const AppSettings(),
        updateState: updateState,
        storagePath: '/tmp/scriptvault',
        onEditorFontSizeSaved: (_) {},
        onAutoSaveEnabledSaved: onAutoSaveEnabledSaved ?? (_) {},
        onChooseStorageDirectory: () async => '/tmp/scriptvault',
        onResetStorageDirectory: () async => '/tmp/scriptvault',
        onLockPasswordSet: (_) async {},
        onLockPasswordChanged: (_, _) async => true,
        onLockDisabled: (_) async => true,
        onCheckForUpdates: () async {},
        onOpenUpdateDownload: () async => true,
      ),
    ),
  );
}

AppUpdateInfo _updateInfo() {
  return AppUpdateInfo(
    currentVersion: '1.0.3',
    latestVersion: 'v1.0.4',
    title: 'ScriptVault v1.0.4',
    notes: 'Release notes',
    releaseUrl: Uri.parse(
      'https://github.com/Anousack789/scriptvault/releases/tag/v1.0.4',
    ),
    dmgAssetUrl: Uri.parse('https://example.com/scriptvault.dmg'),
    publishedAt: DateTime.utc(2026, 6, 7),
  );
}
