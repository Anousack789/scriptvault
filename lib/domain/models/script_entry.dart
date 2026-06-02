class ScriptEntry {
  final String id;
  final String name;
  final String fileName;
  final String group;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastRunAt;

  const ScriptEntry({
    required this.id,
    required this.name,
    required this.fileName,
    required this.group,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.lastRunAt,
  });

  ScriptEntry copyWith({
    String? id,
    String? name,
    String? fileName,
    String? group,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRunAt,
    bool clearLastRunAt = false,
  }) {
    return ScriptEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      fileName: fileName ?? this.fileName,
      group: group ?? this.group,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRunAt: clearLastRunAt ? null : lastRunAt ?? this.lastRunAt,
    );
  }

  factory ScriptEntry.fromJson(Map<String, dynamic> json) {
    return ScriptEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      fileName: json['fileName'] as String,
      group: json['group'] as String,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastRunAt: json['lastRunAt'] == null
          ? null
          : DateTime.parse(json['lastRunAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fileName': fileName,
      'group': group,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastRunAt': lastRunAt?.toIso8601String(),
    };
  }
}
