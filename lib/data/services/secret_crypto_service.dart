import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../domain/models/secret_entry.dart';

class SecretDecryptionException implements Exception {
  const SecretDecryptionException();
}

class EncryptedPayload {
  final String cipherText;
  final String nonce;
  final String mac;

  const EncryptedPayload({
    required this.cipherText,
    required this.nonce,
    required this.mac,
  });
}

class WrappedSecretKey {
  final SecretKeyWrapper wrapper;
  final String plainKey;

  const WrappedSecretKey({required this.wrapper, required this.plainKey});
}

class SecretCryptoService {
  static const _saltLength = 16;
  static const _restoreKeyLength = 32;
  static const _pbkdf2Iterations = 100000;

  final Cipher _cipher;
  final Pbkdf2 _pbkdf2;
  final Random _random;

  SecretCryptoService({Random? random})
    : _cipher = AesGcm.with256bits(),
      _pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _pbkdf2Iterations,
        bits: 256,
      ),
      _random = random ?? Random.secure();

  Future<SecretKey> newDataKey() {
    return _cipher.newSecretKey();
  }

  String newRestoreKey() {
    return _base64UrlNoPadding(_secureBytes(_restoreKeyLength));
  }

  Future<WrappedSecretKey> wrapDataKey({
    required SecretKey dataKey,
    required String password,
    required String type,
  }) async {
    final plainDataKey = await dataKey.extractBytes();
    final wrapperKey = await _deriveWrapperKey(password);
    final payload = await _encryptBytes(plainDataKey, wrapperKey.key);
    return WrappedSecretKey(
      wrapper: SecretKeyWrapper(
        type: type,
        salt: wrapperKey.salt,
        nonce: payload.encrypted.nonce,
        encryptedKey: payload.encrypted.cipherText,
        mac: payload.encrypted.mac,
      ),
      plainKey: password,
    );
  }

  Future<SecretKey?> unwrapDataKey({
    required List<SecretKeyWrapper> wrappers,
    required String password,
    String? type,
  }) async {
    for (final wrapper in wrappers) {
      if (type != null && wrapper.type != type) continue;
      try {
        final wrapperKey = await _deriveWrapperKey(
          password,
          salt: _decode(wrapper.salt),
        );
        final keyBytes = await _decryptBytes(
          EncryptedPayload(
            cipherText: wrapper.encryptedKey,
            nonce: wrapper.nonce,
            mac: wrapper.mac,
          ),
          wrapperKey.key,
        );
        return SecretKey(keyBytes);
      } on Object {
        continue;
      }
    }
    return null;
  }

  Future<EncryptedPayload> encryptString(
    String value,
    SecretKey dataKey,
  ) async {
    return _encryptBytes(
      utf8.encode(value),
      dataKey,
    ).then((payload) => payload.encrypted);
  }

  Future<String> decryptString(
    EncryptedPayload payload,
    SecretKey dataKey,
  ) async {
    final bytes = await _decryptBytes(payload, dataKey);
    return utf8.decode(bytes);
  }

  Future<_SaltedPayload> _encryptBytes(List<int> value, SecretKey key) async {
    final nonce = _secureBytes(12);
    final box = await _cipher.encrypt(value, secretKey: key, nonce: nonce);
    return _SaltedPayload(
      salt: '',
      encrypted: EncryptedPayload(
        cipherText: base64Encode(box.cipherText),
        nonce: base64Encode(box.nonce),
        mac: base64Encode(box.mac.bytes),
      ),
    );
  }

  Future<List<int>> _decryptBytes(
    EncryptedPayload payload,
    SecretKey key,
  ) async {
    try {
      return _cipher.decrypt(
        SecretBox(
          base64Decode(payload.cipherText),
          nonce: base64Decode(payload.nonce),
          mac: Mac(base64Decode(payload.mac)),
        ),
        secretKey: key,
      );
    } on Object {
      throw const SecretDecryptionException();
    }
  }

  Future<_DerivedKey> _deriveWrapperKey(
    String password, {
    List<int>? salt,
  }) async {
    final actualSalt = salt ?? _secureBytes(_saltLength);
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: actualSalt,
    );
    return _DerivedKey(secretKey, base64Encode(actualSalt));
  }

  List<int> _secureBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  String _base64UrlNoPadding(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  List<int> _decode(String value) {
    return base64Decode(value);
  }
}

class _SaltedPayload {
  final String salt;
  final EncryptedPayload encrypted;

  const _SaltedPayload({required this.salt, required this.encrypted});
}

class _DerivedKey {
  final SecretKey key;
  final String salt;

  const _DerivedKey(this.key, this.salt);
}
