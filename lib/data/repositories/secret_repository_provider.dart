import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/script_service_provider.dart';
import 'secret_repository.dart';

final secretRepositoryProvider = Provider<SecretRepository>((ref) {
  return SecretRepository(
    ref.watch(scriptStorageServiceProvider),
    ref.watch(secretCryptoServiceProvider),
  );
});
