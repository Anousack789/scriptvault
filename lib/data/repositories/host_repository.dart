import 'dart:math';

import '../../domain/models/host_connection_result.dart';
import '../../domain/models/host_entry.dart';
import '../../domain/models/script_entry.dart';
import '../services/script_run_service.dart';
import '../services/script_storage_service.dart';

class HostRepository {
  final ScriptStorageService _storageService;
  final ScriptRunService _runService;
  final Random _random;

  HostRepository(this._storageService, this._runService, {Random? random})
    : _random = random ?? Random.secure();

  Future<List<HostEntry>> listHosts() async {
    final hosts = await _storageService.loadHosts();
    hosts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return hosts;
  }

  Future<HostEntry?> getHost(String id) async {
    final hosts = await _storageService.loadHosts();
    return hosts.where((host) => host.id == id).firstOrNull;
  }

  Future<HostEntry> createHost({
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
  }) async {
    final hosts = await _storageService.loadHosts();
    final now = DateTime.now();
    final host = _buildHost(
      id: _newId(),
      name: name,
      address: address,
      username: username,
      port: port,
      authType: authType,
      password: password,
      keyPath: keyPath,
      createdAt: now,
      updatedAt: now,
    );

    await _storageService.saveHosts([...hosts, host]);
    return host;
  }

  Future<HostEntry> updateHost({
    required String id,
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
  }) async {
    final hosts = await _storageService.loadHosts();
    final index = hosts.indexWhere((host) => host.id == id);
    if (index == -1) {
      throw StateError('Host not found');
    }

    final current = hosts[index];
    final updated = _buildHost(
      id: current.id,
      name: name,
      address: address,
      username: username,
      port: port,
      authType: authType,
      password: password,
      keyPath: keyPath,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    hosts[index] = updated;

    await _storageService.saveHosts(hosts);
    return updated;
  }

  Future<void> deleteHost(String id) async {
    final hosts = await _storageService.loadHosts();
    await _storageService.saveHosts(
      hosts.where((host) => host.id != id).toList(),
    );
    await _clearHostFromScripts(id);
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
    final now = DateTime.now();
    final host = _buildHost(
      id: 'connection-test',
      name: name,
      address: address,
      username: username,
      port: port,
      authType: authType,
      password: password,
      keyPath: keyPath,
      createdAt: now,
      updatedAt: now,
    );
    return _runService.testHostConnection(host);
  }

  Future<void> _clearHostFromScripts(String id) async {
    final entries = await _storageService.loadEntries();
    var changed = false;
    final updatedEntries = <ScriptEntry>[];
    for (final entry in entries) {
      if (entry.host == id) {
        changed = true;
        updatedEntries.add(entry.copyWith(host: '', updatedAt: DateTime.now()));
      } else {
        updatedEntries.add(entry);
      }
    }
    if (changed) {
      await _storageService.saveEntries(updatedEntries);
    }
  }

  HostEntry _buildHost({
    required String id,
    required String name,
    required String address,
    required String username,
    required int port,
    required String authType,
    required String password,
    required String keyPath,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return HostEntry(
      id: id,
      name: _cleanHostName(name, address),
      address: _cleanRequiredText(address, fallback: 'localhost'),
      username: _cleanOptionalText(username),
      port: _cleanPort(port),
      authType: _cleanAuthType(authType),
      password: _cleanOptionalText(password),
      keyPath: _cleanOptionalText(keyPath),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String _newId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix = _random.nextInt(1 << 32).toRadixString(36);
    return '$timestamp$suffix';
  }

  String _cleanOptionalText(String value) {
    return value.trim();
  }

  String _cleanRequiredText(String value, {required String fallback}) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return fallback;
    return cleaned;
  }

  String _cleanHostName(String name, String address) {
    final cleanedName = name.trim();
    if (cleanedName.isNotEmpty) return cleanedName;
    final cleanedAddress = address.trim();
    if (cleanedAddress.isNotEmpty) return cleanedAddress;
    return 'New Host';
  }

  int _cleanPort(int value) {
    if (value < 1 || value > 65535) return 22;
    return value;
  }

  String _cleanAuthType(String value) {
    return value == 'password' ? 'password' : 'key';
  }
}
