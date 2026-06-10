class AppSettings {
  static const defaultEditorFontSize = 14.0;
  static const minEditorFontSize = 10.0;
  static const maxEditorFontSize = 28.0;

  final double editorFontSize;
  final bool autoSaveEnabled;
  final List<String> collapsedScriptGroups;
  final String? lockPasswordHash;
  final String? lockPasswordSalt;

  const AppSettings({
    this.editorFontSize = defaultEditorFontSize,
    this.autoSaveEnabled = false,
    this.collapsedScriptGroups = const [],
    this.lockPasswordHash,
    this.lockPasswordSalt,
  });

  bool get lockEnabled {
    return lockPasswordHash != null && lockPasswordSalt != null;
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final lockPasswordHash = _normalizeLockValue(json['lockPasswordHash']);
    final lockPasswordSalt = _normalizeLockValue(json['lockPasswordSalt']);
    return AppSettings(
      editorFontSize: _normalizeFontSize(json['editorFontSize']),
      autoSaveEnabled: json['autoSaveEnabled'] == true,
      collapsedScriptGroups: _normalizeCollapsedScriptGroups(
        json['collapsedScriptGroups'],
      ),
      lockPasswordHash: lockPasswordHash != null && lockPasswordSalt != null
          ? lockPasswordHash
          : null,
      lockPasswordSalt: lockPasswordHash != null && lockPasswordSalt != null
          ? lockPasswordSalt
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'editorFontSize': editorFontSize,
      'autoSaveEnabled': autoSaveEnabled,
      'collapsedScriptGroups': collapsedScriptGroups,
      if (lockPasswordHash != null) 'lockPasswordHash': lockPasswordHash,
      if (lockPasswordSalt != null) 'lockPasswordSalt': lockPasswordSalt,
    };
  }

  AppSettings copyWith({
    double? editorFontSize,
    bool? autoSaveEnabled,
    List<String>? collapsedScriptGroups,
    String? lockPasswordHash,
    String? lockPasswordSalt,
    bool clearLockPassword = false,
  }) {
    return AppSettings(
      editorFontSize: editorFontSize ?? this.editorFontSize,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
      collapsedScriptGroups:
          collapsedScriptGroups ?? this.collapsedScriptGroups,
      lockPasswordHash: clearLockPassword
          ? null
          : lockPasswordHash ?? this.lockPasswordHash,
      lockPasswordSalt: clearLockPassword
          ? null
          : lockPasswordSalt ?? this.lockPasswordSalt,
    );
  }

  static double normalizeEditorFontSize(double value) {
    return value.clamp(minEditorFontSize, maxEditorFontSize).roundToDouble();
  }

  static double _normalizeFontSize(Object? value) {
    if (value is num) {
      return normalizeEditorFontSize(value.toDouble());
    }
    return defaultEditorFontSize;
  }

  static List<String> _normalizeCollapsedScriptGroups(Object? value) {
    if (value is! List) return const [];

    final groups = value
        .whereType<String>()
        .map((group) => group.trim())
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList();
    groups.sort();
    return groups;
  }

  static String? _normalizeLockValue(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
