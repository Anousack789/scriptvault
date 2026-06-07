import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/models/app_update_info.dart';

class AppUpdateCheck {
  final AppUpdateInfo? updateInfo;
  final String? errorMessage;

  const AppUpdateCheck._({this.updateInfo, this.errorMessage});

  const AppUpdateCheck.updateAvailable(AppUpdateInfo updateInfo)
    : this._(updateInfo: updateInfo);

  const AppUpdateCheck.noUpdate() : this._();

  const AppUpdateCheck.failed(String errorMessage)
    : this._(errorMessage: errorMessage);

  bool get hasUpdate {
    return updateInfo != null;
  }

  bool get failed {
    return errorMessage != null;
  }
}

class GitHubRelease {
  final String latestVersion;
  final String title;
  final String notes;
  final Uri releaseUrl;
  final Uri? dmgAssetUrl;
  final DateTime? publishedAt;

  const GitHubRelease({
    required this.latestVersion,
    required this.title,
    required this.notes,
    required this.releaseUrl,
    required this.dmgAssetUrl,
    required this.publishedAt,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final tagName = _stringValue(json['tag_name']);
    final releaseUrl = Uri.tryParse(_stringValue(json['html_url']));
    if (tagName.isEmpty || releaseUrl == null) {
      throw const FormatException('GitHub release is missing a tag or URL.');
    }

    return GitHubRelease(
      latestVersion: tagName,
      title: _stringValue(json['name']).isEmpty
          ? tagName
          : _stringValue(json['name']),
      notes: _stringValue(json['body']),
      releaseUrl: releaseUrl,
      dmgAssetUrl: _findDmgAssetUrl(json['assets']),
      publishedAt: DateTime.tryParse(_stringValue(json['published_at'])),
    );
  }

  static String _stringValue(Object? value) {
    return value is String ? value.trim() : '';
  }

  static Uri? _findDmgAssetUrl(Object? assets) {
    if (assets is! List) return null;

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = _stringValue(asset['name']).toLowerCase();
      final url = Uri.tryParse(_stringValue(asset['browser_download_url']));
      if (name.endsWith('.dmg') && url != null) {
        return url;
      }
    }

    return null;
  }
}

class AppUpdateService {
  static final latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/Anousack789/scriptvault/releases/latest',
  );

  final http.Client _client;
  final Future<PackageInfo> Function() _packageInfoLoader;

  const AppUpdateService({
    required http.Client client,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : _client = client,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  Future<AppUpdateCheck> checkForUpdates() async {
    try {
      final packageInfo = await _packageInfoLoader();
      final response = await _client.get(
        latestReleaseUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'ScriptVault update checker',
        },
      );

      if (response.statusCode != 200) {
        return AppUpdateCheck.failed('GitHub returned ${response.statusCode}.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const AppUpdateCheck.failed('GitHub returned invalid JSON.');
      }

      final release = GitHubRelease.fromJson(decoded);
      final currentVersion = AppVersion.tryParse(packageInfo.version);
      final latestVersion = AppVersion.tryParse(release.latestVersion);
      if (currentVersion == null || latestVersion == null) {
        return const AppUpdateCheck.failed('Release version is invalid.');
      }

      if (latestVersion.compareTo(currentVersion) <= 0) {
        return const AppUpdateCheck.noUpdate();
      }

      return AppUpdateCheck.updateAvailable(
        AppUpdateInfo(
          currentVersion: packageInfo.version,
          latestVersion: release.latestVersion,
          title: release.title,
          notes: release.notes,
          releaseUrl: release.releaseUrl,
          dmgAssetUrl: release.dmgAssetUrl,
          publishedAt: release.publishedAt,
        ),
      );
    } on FormatException catch (error) {
      return AppUpdateCheck.failed(error.message);
    } catch (_) {
      return const AppUpdateCheck.failed('Unable to check for updates.');
    }
  }
}

class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;
  final List<int> build;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = const [],
  });

  static AppVersion? tryParse(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(?:[-][0-9A-Za-z.-]+)?(?:\+([0-9.]+))?$',
    ).firstMatch(normalized);
    if (match == null) return null;

    return AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: _parseBuild(match.group(4)),
    );
  }

  static List<int> _parseBuild(String? value) {
    if (value == null || value.isEmpty) return const [];
    return value.split('.').map(int.parse).toList(growable: false);
  }

  @override
  int compareTo(AppVersion other) {
    final core = _compareValues(
      [major, minor, patch],
      [other.major, other.minor, other.patch],
    );
    if (core != 0) return core;
    return _compareBuild(other);
  }

  int _compareBuild(AppVersion other) {
    if (build.isEmpty && other.build.isEmpty) return 0;
    if (build.isEmpty) return -1;
    if (other.build.isEmpty) return 1;
    return _compareValues(build, other.build);
  }

  static int _compareValues(List<int> left, List<int> right) {
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final leftValue = i < left.length ? left[i] : 0;
      final rightValue = i < right.length ? right[i] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }
}
