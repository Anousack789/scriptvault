import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/host_repository_provider.dart';
import '../../domain/models/host_connection_result.dart';
import '../../domain/models/host_entry.dart';

class HostsState {
  final List<HostEntry> hosts;
  final HostConnectionResult? testResult;
  final bool isSaving;
  final bool isTesting;

  const HostsState({
    this.hosts = const [],
    this.testResult,
    this.isSaving = false,
    this.isTesting = false,
  });

  HostsState copyWith({
    List<HostEntry>? hosts,
    HostConnectionResult? testResult,
    bool? isSaving,
    bool? isTesting,
    bool clearTestResult = false,
  }) {
    return HostsState(
      hosts: hosts ?? this.hosts,
      testResult: clearTestResult ? null : testResult ?? this.testResult,
      isSaving: isSaving ?? this.isSaving,
      isTesting: isTesting ?? this.isTesting,
    );
  }
}

class HostsViewModel extends AsyncNotifier<HostsState> {
  @override
  Future<HostsState> build() async {
    final hosts = await ref.read(hostRepositoryProvider).listHosts();
    return HostsState(hosts: hosts);
  }

  Future<void> refresh() async {
    final current = state.value ?? const HostsState();
    final hosts = await ref.read(hostRepositoryProvider).listHosts();
    state = AsyncData(current.copyWith(hosts: hosts));
  }

  Future<HostEntry> saveHost({
    required String? id,
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
  }) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true, clearTestResult: true));
    try {
      final repository = ref.read(hostRepositoryProvider);
      final host = id == null
          ? await repository.createHost(
              name: name,
              address: address,
              username: username,
              port: port,
              authType: authType,
              password: password,
              keyPath: keyPath,
            )
          : await repository.updateHost(
              id: id,
              name: name,
              address: address,
              username: username,
              port: port,
              authType: authType,
              password: password,
              keyPath: keyPath,
            );
      final hosts = await repository.listHosts();
      state = AsyncData(
        state.requireValue.copyWith(hosts: hosts, isSaving: false),
      );
      return host;
    } catch (_) {
      state = AsyncData(state.requireValue.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<void> deleteHost(String id) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true, clearTestResult: true));
    try {
      final repository = ref.read(hostRepositoryProvider);
      await repository.deleteHost(id);
      state = AsyncData(
        state.requireValue.copyWith(
          hosts: await repository.listHosts(),
          isSaving: false,
        ),
      );
    } catch (_) {
      state = AsyncData(state.requireValue.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<HostConnectionResult> testConnection({
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
  }) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isTesting: true, clearTestResult: true));
    try {
      final result = await ref
          .read(hostRepositoryProvider)
          .testConnection(
            name: name,
            address: address,
            username: username,
            port: port,
            authType: authType,
            password: password,
            keyPath: keyPath,
          );
      state = AsyncData(
        state.requireValue.copyWith(testResult: result, isTesting: false),
      );
      return result;
    } catch (_) {
      state = AsyncData(state.requireValue.copyWith(isTesting: false));
      rethrow;
    }
  }
}

final hostsViewModelProvider =
    AsyncNotifierProvider<HostsViewModel, HostsState>(HostsViewModel.new);
