class HostEntry {
  final String id;
  final String name;
  final String address;
  final String username;
  final int port;
  final String authType;
  final String password;
  final String keyPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HostEntry({
    required this.id,
    required this.name,
    required this.address,
    required this.username,
    required this.port,
    required this.authType,
    required this.password,
    required this.keyPath,
    required this.createdAt,
    required this.updatedAt,
  });

  String get destination {
    final cleanedUsername = username.trim();
    final cleanedAddress = address.trim();
    if (cleanedUsername.isEmpty) return cleanedAddress;
    return '$cleanedUsername@$cleanedAddress';
  }

  String get authLabel => authType == 'password' ? 'Password' : 'Public key';

  HostEntry copyWith({
    String? id,
    String? name,
    String? address,
    String? username,
    int? port,
    String? authType,
    String? password,
    String? keyPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HostEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      username: username ?? this.username,
      port: port ?? this.port,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      keyPath: keyPath ?? this.keyPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory HostEntry.fromJson(Map<String, dynamic> json) {
    return HostEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      username: json['username'] as String? ?? '',
      port: json['port'] as int? ?? 22,
      authType: json['authType'] as String? ?? 'key',
      password: json['password'] as String? ?? '',
      keyPath: json['keyPath'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'username': username,
      'port': port,
      'authType': authType,
      'password': password,
      'keyPath': keyPath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
