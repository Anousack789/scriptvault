import 'package:flutter_test/flutter_test.dart';
import 'package:scriptvault/data/services/password_hash_service.dart';

void main() {
  test('verifies correct password and rejects wrong password', () {
    const service = PasswordHashService();
    final passwordHash = service.createHash('secret');

    expect(
      service.verify(
        password: 'secret',
        hash: passwordHash.hash,
        salt: passwordHash.salt,
      ),
      isTrue,
    );
    expect(
      service.verify(
        password: 'wrong',
        hash: passwordHash.hash,
        salt: passwordHash.salt,
      ),
      isFalse,
    );
  });

  test('generates different salts for separate hashes', () {
    const service = PasswordHashService();
    final first = service.createHash('secret');
    final second = service.createHash('secret');

    expect(first.salt, isNot(second.salt));
    expect(first.hash, isNot(second.hash));
  });
}
