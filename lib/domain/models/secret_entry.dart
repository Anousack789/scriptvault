class SecretEntry {
  final String id;
  final String name;
  final String encryptedValue;
  final String nonce;
  final String mac;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SecretEntry({
    required this.id,
    required this.name,
    required this.encryptedValue,
    required this.nonce,
    required this.mac,
    required this.createdAt,
    required this.updatedAt,
  });

  SecretEntry copyWith({
    String? id,
    String? name,
    String? encryptedValue,
    String? nonce,
    String? mac,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SecretEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      encryptedValue: encryptedValue ?? this.encryptedValue,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SecretEntry.fromJson(Map<String, dynamic> json) {
    return SecretEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      encryptedValue: json['encryptedValue'] as String? ?? '',
      nonce: json['nonce'] as String? ?? '',
      mac: json['mac'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'encryptedValue': encryptedValue,
      'nonce': nonce,
      'mac': mac,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class SecretKeyWrapper {
  final String type;
  final String salt;
  final String nonce;
  final String encryptedKey;
  final String mac;

  const SecretKeyWrapper({
    required this.type,
    required this.salt,
    required this.nonce,
    required this.encryptedKey,
    required this.mac,
  });

  factory SecretKeyWrapper.fromJson(Map<String, dynamic> json) {
    return SecretKeyWrapper(
      type: json['type'] as String? ?? 'password',
      salt: json['salt'] as String? ?? '',
      nonce: json['nonce'] as String? ?? '',
      encryptedKey: json['encryptedKey'] as String? ?? '',
      mac: json['mac'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'salt': salt,
      'nonce': nonce,
      'encryptedKey': encryptedKey,
      'mac': mac,
    };
  }
}

class SecretVault {
  final int version;
  final List<SecretKeyWrapper> keyWrappers;
  final List<SecretEntry> secrets;

  const SecretVault({
    this.version = 1,
    this.keyWrappers = const [],
    this.secrets = const [],
  });

  bool get isConfigured => keyWrappers.isNotEmpty;

  SecretVault copyWith({
    int? version,
    List<SecretKeyWrapper>? keyWrappers,
    List<SecretEntry>? secrets,
  }) {
    return SecretVault(
      version: version ?? this.version,
      keyWrappers: keyWrappers ?? this.keyWrappers,
      secrets: secrets ?? this.secrets,
    );
  }

  factory SecretVault.fromJson(Map<String, dynamic> json) {
    return SecretVault(
      version: json['version'] as int? ?? 1,
      keyWrappers: (json['keyWrappers'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SecretKeyWrapper.fromJson)
          .toList(),
      secrets: (json['secrets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SecretEntry.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'keyWrappers': keyWrappers.map((wrapper) => wrapper.toJson()).toList(),
      'secrets': secrets.map((secret) => secret.toJson()).toList(),
    };
  }
}
