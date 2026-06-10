import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/script_service_provider.dart';
import 'host_repository_provider.dart';
import 'secret_repository_provider.dart';
import 'script_repository.dart';

final scriptRepositoryProvider = Provider<ScriptRepository>((ref) {
  return ScriptRepository(
    ref.watch(scriptStorageServiceProvider),
    ref.watch(scriptRunServiceProvider),
    ref.watch(hostRepositoryProvider),
    secretRepository: ref.watch(secretRepositoryProvider),
  );
});
