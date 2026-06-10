import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/secret_repository_provider.dart';
import '../../domain/models/secret_entry.dart';
import '../scripts/script_editor_viewmodel.dart';

class SecretsState {
  final List<SecretEntry> secrets;
  final Map<String, String> revealedValues;
  final bool isConfigured;
  final bool isUnlocked;
  final bool isSaving;

  const SecretsState({
    this.secrets = const [],
    this.revealedValues = const {},
    this.isConfigured = false,
    this.isUnlocked = false,
    this.isSaving = false,
  });

  SecretsState copyWith({
    List<SecretEntry>? secrets,
    Map<String, String>? revealedValues,
    bool? isConfigured,
    bool? isUnlocked,
    bool? isSaving,
  }) {
    return SecretsState(
      secrets: secrets ?? this.secrets,
      revealedValues: revealedValues ?? this.revealedValues,
      isConfigured: isConfigured ?? this.isConfigured,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class SecretsViewModel extends AsyncNotifier<SecretsState> {
  @override
  Future<SecretsState> build() async {
    final repository = ref.read(secretRepositoryProvider);
    return SecretsState(
      secrets: await repository.listSecrets(),
      isConfigured: await repository.isConfigured(),
      isUnlocked: repository.isUnlocked,
    );
  }

  Future<String> setupVault(String password) async {
    final current = state.value ?? const SecretsState();
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      final repository = ref.read(secretRepositoryProvider);
      final restoreKey = await repository.setupVault(password);
      state = AsyncData(
        state.requireValue.copyWith(
          secrets: await repository.listSecrets(),
          isConfigured: true,
          isUnlocked: true,
          isSaving: false,
        ),
      );
      ref.invalidate(scriptEditorViewModelProvider);
      return restoreKey;
    } catch (_) {
      state = AsyncData(state.requireValue.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<bool> unlockWithPassword(String password) {
    return _unlock(() {
      return ref.read(secretRepositoryProvider).unlockWithPassword(password);
    });
  }

  Future<bool> unlockWithRestoreKey(String restoreKey) {
    return _unlock(() {
      return ref
          .read(secretRepositoryProvider)
          .unlockWithRestoreKey(restoreKey);
    });
  }

  Future<bool> _unlock(Future<bool> Function() unlocker) async {
    final current = state.value ?? const SecretsState();
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      final unlocked = await unlocker();
      final repository = ref.read(secretRepositoryProvider);
      state = AsyncData(
        state.requireValue.copyWith(
          isUnlocked: repository.isUnlocked,
          isSaving: false,
        ),
      );
      return unlocked;
    } catch (_) {
      state = AsyncData(state.requireValue.copyWith(isSaving: false));
      rethrow;
    }
  }

  void lock() {
    ref.read(secretRepositoryProvider).lock();
    final current = state.value ?? const SecretsState();
    state = AsyncData(
      current.copyWith(isUnlocked: false, revealedValues: const {}),
    );
  }

  Future<SecretEntry> saveSecret({
    required String? id,
    required String name,
    required String value,
  }) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      final repository = ref.read(secretRepositoryProvider);
      final secret = id == null
          ? await repository.createSecret(name: name, value: value)
          : await repository.updateSecret(
              id: id,
              name: name,
              value: value.isEmpty ? null : value,
            );
      final revealed = {...state.requireValue.revealedValues}
        ..removeWhere((secretId, _) => secretId == secret.id);
      state = AsyncData(
        state.requireValue.copyWith(
          secrets: await repository.listSecrets(),
          revealedValues: revealed,
          isSaving: false,
        ),
      );
      ref.invalidate(scriptEditorViewModelProvider);
      return secret;
    } catch (_) {
      state = AsyncData(state.requireValue.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<void> deleteSecret(String id) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      final repository = ref.read(secretRepositoryProvider);
      await repository.deleteSecret(id);
      final revealed = {...state.requireValue.revealedValues}..remove(id);
      state = AsyncData(
        state.requireValue.copyWith(
          secrets: await repository.listSecrets(),
          revealedValues: revealed,
          isSaving: false,
        ),
      );
      ref.invalidate(scriptEditorViewModelProvider);
    } catch (_) {
      state = AsyncData(state.requireValue.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<void> revealSecret(String id) async {
    final current = state.requireValue;
    if (current.revealedValues.containsKey(id)) {
      final revealed = {...current.revealedValues}..remove(id);
      state = AsyncData(current.copyWith(revealedValues: revealed));
      return;
    }

    final value = await ref.read(secretRepositoryProvider).revealSecret(id);
    state = AsyncData(
      current.copyWith(revealedValues: {...current.revealedValues, id: value}),
    );
  }
}

final secretsViewModelProvider =
    AsyncNotifierProvider<SecretsViewModel, SecretsState>(SecretsViewModel.new);
