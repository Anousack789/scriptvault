import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/script_service_provider.dart';
import 'host_repository.dart';

final hostRepositoryProvider = Provider<HostRepository>((ref) {
  return HostRepository(
    ref.watch(scriptStorageServiceProvider),
    ref.watch(scriptRunServiceProvider),
  );
});
