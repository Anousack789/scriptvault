import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../domain/models/secret_entry.dart';
import '../services/secret_crypto_service.dart';
import '../services/script_storage_service.dart';

class SecretRepository {
  static const passwordWrapperType = 'password';
  static const restoreWrapperType = 'restore';

  final ScriptStorageService _storageService;
  final SecretCryptoService _cryptoService;
  final Random _random;
  SecretKey? _dataKey;

  SecretRepository(this._storageService, this._cryptoService, {Random? random})
    : _random = random ?? Random.secure();

  bool get isUnlocked => _dataKey != null;

  Future<bool> isConfigured() async {
    final vault = await _storageService.loadSecretVault();
    return vault.isConfigured;
  }

  Future<List<SecretEntry>> listSecrets() async {
    final vault = await _storageService.loadSecretVault();
    final secrets = [...vault.secrets];
    secrets.sort((a, b) => a.name.compareTo(b.name));
    return secrets;
  }

  Future<String> setupVault(String password) async {
    final cleanedPassword = password.trim();
    if (cleanedPassword.isEmpty) {
      throw StateError('Password is required');
    }

    final current = await _storageService.loadSecretVault();
    if (current.isConfigured) {
      throw StateError('Secrets are already configured');
    }

    final dataKey = await _cryptoService.newDataKey();
    final restoreKey = _cryptoService.newRestoreKey();
    final passwordWrapper = await _cryptoService.wrapDataKey(
      dataKey: dataKey,
      password: cleanedPassword,
      type: passwordWrapperType,
    );
    final restoreWrapper = await _cryptoService.wrapDataKey(
      dataKey: dataKey,
      password: restoreKey,
      type: restoreWrapperType,
    );

    await _storageService.saveSecretVault(
      current.copyWith(
        keyWrappers: [passwordWrapper.wrapper, restoreWrapper.wrapper],
      ),
    );
    _dataKey = dataKey;
    return restoreKey;
  }

  Future<bool> unlockWithPassword(String password) async {
    final vault = await _storageService.loadSecretVault();
    final key = await _cryptoService.unwrapDataKey(
      wrappers: vault.keyWrappers
          .where((wrapper) => wrapper.type == passwordWrapperType)
          .toList(),
      password: password,
    );
    if (key == null) return false;
    _dataKey = key;
    return true;
  }

  Future<bool> unlockWithRestoreKey(String restoreKey) async {
    final vault = await _storageService.loadSecretVault();
    final key = await _cryptoService.unwrapDataKey(
      wrappers: vault.keyWrappers
          .where((wrapper) => wrapper.type == restoreWrapperType)
          .toList(),
      password: restoreKey.trim(),
    );
    if (key == null) return false;
    _dataKey = key;
    return true;
  }

  void lock() {
    _dataKey = null;
  }

  Future<SecretEntry> createSecret({
    required String name,
    required String value,
  }) async {
    final vault = await _storageService.loadSecretVault();
    final secret = await _buildSecret(
      id: _newId(),
      name: name,
      value: value,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      existing: vault.secrets,
    );

    await _storageService.saveSecretVault(
      vault.copyWith(secrets: [...vault.secrets, secret]),
    );
    return secret;
  }

  Future<SecretEntry> updateSecret({
    required String id,
    required String name,
    String? value,
  }) async {
    final vault = await _storageService.loadSecretVault();
    final index = vault.secrets.indexWhere((secret) => secret.id == id);
    if (index == -1) {
      throw StateError('Secret not found');
    }

    final current = vault.secrets[index];
    final existing = vault.secrets.where((secret) => secret.id != id).toList();
    final updated = value == null
        ? _renameSecret(current, name, existing)
        : await _buildSecret(
            id: current.id,
            name: name,
            value: value,
            createdAt: current.createdAt,
            updatedAt: DateTime.now(),
            existing: existing,
          );
    final secrets = [...vault.secrets];
    secrets[index] = updated;
    await _storageService.saveSecretVault(vault.copyWith(secrets: secrets));
    return updated;
  }

  Future<void> deleteSecret(String id) async {
    final vault = await _storageService.loadSecretVault();
    await _storageService.saveSecretVault(
      vault.copyWith(
        secrets: vault.secrets.where((secret) => secret.id != id).toList(),
      ),
    );
  }

  Future<String> revealSecret(String id) async {
    final vault = await _storageService.loadSecretVault();
    final secret = vault.secrets
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (secret == null) {
      throw StateError('Secret not found');
    }
    return _decryptSecret(secret);
  }

  Future<Map<String, String>> environment() async {
    final key = _requireDataKey();
    final vault = await _storageService.loadSecretVault();
    final values = <String, String>{};
    for (final secret in vault.secrets) {
      values[secret.name] = await _decryptSecret(secret, dataKey: key);
    }
    return values;
  }

  Future<SecretEntry> _buildSecret({
    required String id,
    required String name,
    required String value,
    required DateTime createdAt,
    required DateTime updatedAt,
    required List<SecretEntry> existing,
  }) async {
    final cleanedName = _cleanName(name);
    if (existing.any((secret) => secret.name == cleanedName)) {
      throw StateError('Secret name already exists');
    }
    final encrypted = await _cryptoService.encryptString(
      value,
      _requireDataKey(),
    );
    return SecretEntry(
      id: id,
      name: cleanedName,
      encryptedValue: encrypted.cipherText,
      nonce: encrypted.nonce,
      mac: encrypted.mac,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  SecretEntry _renameSecret(
    SecretEntry current,
    String name,
    List<SecretEntry> existing,
  ) {
    final cleanedName = _cleanName(name);
    if (existing.any((secret) => secret.name == cleanedName)) {
      throw StateError('Secret name already exists');
    }
    return current.copyWith(name: cleanedName, updatedAt: DateTime.now());
  }

  Future<String> _decryptSecret(SecretEntry secret, {SecretKey? dataKey}) {
    return _cryptoService.decryptString(
      EncryptedPayload(
        cipherText: secret.encryptedValue,
        nonce: secret.nonce,
        mac: secret.mac,
      ),
      dataKey ?? _requireDataKey(),
    );
  }

  SecretKey _requireDataKey() {
    final key = _dataKey;
    if (key == null) {
      throw StateError('Secrets are locked');
    }
    return key;
  }

  String _newId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix = _random.nextInt(1 << 32).toRadixString(36);
    return '$timestamp$suffix';
  }

  String _cleanName(String value) {
    final cleaned = value.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9_]+'),
      '_',
    );
    final collapsed = cleaned
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final prefixed = RegExp(r'^[A-Z_]').hasMatch(collapsed)
        ? collapsed
        : 'SECRET_$collapsed';
    if (prefixed.isEmpty || prefixed == 'SECRET_') return 'SECRET';
    return prefixed;
  }
}
