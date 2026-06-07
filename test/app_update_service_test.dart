import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scriptvault/data/services/app_update_service.dart';

void main() {
  group('AppVersion', () {
    test('detects patch update', () {
      expect(
        AppVersion.tryParse('1.0.4')!.compareTo(AppVersion.tryParse('1.0.3')!),
        greaterThan(0),
      );
    });

    test('detects minor update', () {
      expect(
        AppVersion.tryParse('1.1.0')!.compareTo(AppVersion.tryParse('1.0.9')!),
        greaterThan(0),
      );
    });

    test('detects major update', () {
      expect(
        AppVersion.tryParse('2.0.0')!.compareTo(AppVersion.tryParse('1.9.9')!),
        greaterThan(0),
      );
    });

    test('treats the same version as equal', () {
      expect(
        AppVersion.tryParse('v1.0.3')!.compareTo(AppVersion.tryParse('1.0.3')!),
        0,
      );
    });

    test('rejects invalid version tags', () {
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.tryParse(''), isNull);
    });
  });

  group('GitHubRelease', () {
    test('parses release metadata and dmg asset', () {
      final release = GitHubRelease.fromJson({
        'tag_name': 'v1.0.4',
        'name': 'ScriptVault 1.0.4',
        'body': 'Release notes',
        'html_url':
            'https://github.com/Anousack789/scriptvault/releases/v1.0.4',
        'published_at': '2026-06-07T10:00:00Z',
        'assets': [
          {
            'name': 'scriptvault-1.0.4.zip',
            'browser_download_url': 'https://example.com/app.zip',
          },
          {
            'name': 'scriptvault-1.0.4.dmg',
            'browser_download_url': 'https://example.com/app.dmg',
          },
        ],
      });

      expect(release.latestVersion, 'v1.0.4');
      expect(release.title, 'ScriptVault 1.0.4');
      expect(release.notes, 'Release notes');
      expect(release.releaseUrl.host, 'github.com');
      expect(release.dmgAssetUrl, Uri.parse('https://example.com/app.dmg'));
      expect(release.publishedAt, DateTime.parse('2026-06-07T10:00:00Z'));
    });

    test('tolerates missing body and assets', () {
      final release = GitHubRelease.fromJson({
        'tag_name': '1.0.4',
        'html_url':
            'https://github.com/Anousack789/scriptvault/releases/v1.0.4',
      });

      expect(release.title, '1.0.4');
      expect(release.notes, isEmpty);
      expect(release.dmgAssetUrl, isNull);
    });
  });

  group('AppUpdateService', () {
    test('returns update available when GitHub has a newer version', () async {
      final service = _serviceWithRelease(
        currentVersion: '1.0.3',
        releaseJson: _releaseJson(tagName: 'v1.0.4'),
      );

      final result = await service.checkForUpdates();

      expect(result.hasUpdate, isTrue);
      expect(result.updateInfo?.currentVersion, '1.0.3');
      expect(result.updateInfo?.latestVersion, 'v1.0.4');
    });

    test('returns no update for the same version', () async {
      final service = _serviceWithRelease(
        currentVersion: '1.0.3',
        releaseJson: _releaseJson(tagName: 'v1.0.3'),
      );

      final result = await service.checkForUpdates();

      expect(result.hasUpdate, isFalse);
      expect(result.failed, isFalse);
    });

    test('returns failure for invalid release tag', () async {
      final service = _serviceWithRelease(
        currentVersion: '1.0.3',
        releaseJson: _releaseJson(tagName: 'latest'),
      );

      final result = await service.checkForUpdates();

      expect(result.hasUpdate, isFalse);
      expect(result.failed, isTrue);
    });
  });
}

AppUpdateService _serviceWithRelease({
  required String currentVersion,
  required String releaseJson,
}) {
  return AppUpdateService(
    client: MockClient((request) async {
      expect(request.url, AppUpdateService.latestReleaseUri);
      return http.Response(releaseJson, 200);
    }),
    packageInfoLoader: () async => PackageInfo(
      appName: 'ScriptVault',
      packageName: 'com.nonostack.scriptvault',
      version: currentVersion,
      buildNumber: '1',
    ),
  );
}

String _releaseJson({required String tagName}) {
  return '''
{
  "tag_name": "$tagName",
  "name": "ScriptVault $tagName",
  "body": "Release notes",
  "html_url": "https://github.com/Anousack789/scriptvault/releases/tag/$tagName",
  "assets": []
}
''';
}
