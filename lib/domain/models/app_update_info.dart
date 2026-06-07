class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String title;
  final String notes;
  final Uri releaseUrl;
  final Uri? dmgAssetUrl;
  final DateTime? publishedAt;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.title,
    required this.notes,
    required this.releaseUrl,
    required this.dmgAssetUrl,
    required this.publishedAt,
  });

  Uri get downloadUrl {
    return dmgAssetUrl ?? releaseUrl;
  }
}
