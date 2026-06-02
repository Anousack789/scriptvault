import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PasswordHash {
  final String hash;
  final String salt;

  const PasswordHash({required this.hash, required this.salt});
}

class PasswordHashService {
  static const iterations = 100000;
  static const keyLength = 32;
  static const saltLength = 16;

  const PasswordHashService();

  PasswordHash createHash(String password) {
    final saltBytes = _secureBytes(saltLength);
    final hashBytes = _pbkdf2(
      passwordBytes: utf8.encode(password),
      saltBytes: saltBytes,
      iterations: iterations,
      keyLength: keyLength,
    );
    return PasswordHash(
      hash: base64Encode(hashBytes),
      salt: base64Encode(saltBytes),
    );
  }

  bool verify({
    required String password,
    required String hash,
    required String salt,
  }) {
    try {
      final expected = base64Decode(hash);
      final actual = _pbkdf2(
        passwordBytes: utf8.encode(password),
        saltBytes: base64Decode(salt),
        iterations: iterations,
        keyLength: expected.length,
      );
      return _constantTimeEquals(expected, actual);
    } on FormatException {
      return false;
    }
  }

  List<int> _secureBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  List<int> _pbkdf2({
    required List<int> passwordBytes,
    required List<int> saltBytes,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, passwordBytes);
    final blocks = (keyLength / hmac.convert(const []).bytes.length).ceil();
    final derived = BytesBuilder(copy: false);

    for (var blockIndex = 1; blockIndex <= blocks; blockIndex++) {
      var block = hmac.convert([
        ...saltBytes,
        ..._int32Bytes(blockIndex),
      ]).bytes;
      final output = Uint8List.fromList(block);

      for (var iteration = 1; iteration < iterations; iteration++) {
        block = hmac.convert(block).bytes;
        for (var byteIndex = 0; byteIndex < output.length; byteIndex++) {
          output[byteIndex] ^= block[byteIndex];
        }
      }

      derived.add(output);
    }

    return derived.toBytes().take(keyLength).toList();
  }

  List<int> _int32Bytes(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var result = 0;
    for (var index = 0; index < left.length; index++) {
      result |= left[index] ^ right[index];
    }
    return result == 0;
  }
}
