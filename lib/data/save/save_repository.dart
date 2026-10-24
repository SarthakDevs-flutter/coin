import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../application/ports/ports.dart';
import '../../application/state/save_data.dart';

enum SaveHealth { clean, dirty, writing, writeFailed }

enum LoadRecovery {
  /// Main save was valid (possibly migrated).
  none,

  /// No save existed: first launch.
  fresh,

  /// Main save was corrupt; restored from last-known-good backup.
  fromBackup,

  /// Both copies unusable; a new profile was created. Raw data preserved.
  reset,
}

final class LoadResult {
  const LoadResult(this.data, this.recovery, {this.errorCode});

  final SaveData data;
  final LoadRecovery recovery;

  /// Non-sensitive diagnostic code (never contains save content).
  final String? errorCode;
}

typedef Migration = Map<String, Object?> Function(Map<String, Object?> payload);

/// Versioned, checksummed, backed-up local save (architecture.md §10).
///
/// File layout: `save.json` (current), `save.bak` (last known good),
/// `save.corrupt` (diagnostic copy of the most recent unreadable save).
final class SaveRepository {
  SaveRepository(this._store, {Map<int, Migration>? migrations})
    : _migrations = migrations ?? defaultMigrations;

  static const int schemaVersion = 1;
  static const mainFile = 'save.json';
  static const backupFile = 'save.bak';
  static const corruptFile = 'save.corrupt';

  /// Sequential migrations: key N upgrades a payload from schema N to N+1.
  static const Map<int, Migration> defaultMigrations = {};

  final SaveStore _store;
  final Map<int, Migration> _migrations;

  SaveHealth _health = SaveHealth.clean;
  SaveHealth get health => _health;

  final _healthController = StreamController<SaveHealth>.broadcast();
  Stream<SaveHealth> get healthChanges => _healthController.stream;

  /// Envelope text of the last save known to be valid (loaded or written).
  String? _lastGood;
  Future<void> _chain = Future.value();
  SaveData? _pending;

  Future<LoadResult> load() async {
    final main = await _safeRead(mainFile);
    if (main == null) {
      final backup = await _safeRead(backupFile);
      if (backup == null) {
        return LoadResult(SaveData.fresh(), LoadRecovery.fresh);
      }
      final restored = _decode(backup);
      if (restored.data != null) {
        _lastGood = backup;
        return LoadResult(
          restored.data!,
          LoadRecovery.fromBackup,
          errorCode: 'main_missing',
        );
      }
      return LoadResult(
        SaveData.fresh(),
        LoadRecovery.reset,
        errorCode: restored.error,
      );
    }
    final decoded = _decode(main);
    if (decoded.data != null) {
      _lastGood = main;
      return LoadResult(decoded.data!, LoadRecovery.none);
    }
    // Preserve the unreadable file for diagnostics before anything else.
    await _safeWrite(corruptFile, main);
    final backup = await _safeRead(backupFile);
    if (backup != null) {
      final b = _decode(backup);
      if (b.data != null) {
        _lastGood = backup;
        return LoadResult(
          b.data!,
          LoadRecovery.fromBackup,
          errorCode: decoded.error,
        );
      }
    }
    return LoadResult(
      SaveData.fresh(),
      LoadRecovery.reset,
      errorCode: decoded.error,
    );
  }

  /// Queues a write. Writes are serialised; bursts coalesce to the latest.
  Future<void> save(SaveData data) {
    _pending = data;
    _setHealth(SaveHealth.dirty);
    return _chain = _chain.then((_) => _flushPending());
  }

  Future<void> _flushPending() async {
    final data = _pending;
    if (data == null) return;
    _pending = null;
    _setHealth(SaveHealth.writing);
    final text = encode(data);
    try {
      // Rotate the previous valid save into the backup slot first, so a
      // failure below can never leave us without a good copy.
      if (_lastGood != null) await _store.write(backupFile, _lastGood!);
      await _store.write(mainFile, text);
      _lastGood = text;
      _setHealth(_pending == null ? SaveHealth.clean : SaveHealth.dirty);
    } on Object {
      _setHealth(SaveHealth.writeFailed);
      // Keep the data so the next save/flush retries it.
      _pending ??= data;
    }
  }

  Future<void> flush() => _chain = _chain.then((_) => _flushPending());

  Future<void> wipe() async {
    _lastGood = null;
    _pending = null;
    await _store.delete(mainFile);
    await _store.delete(backupFile);
  }

  static String encode(SaveData data) {
    final payload = jsonEncode(data.toJson());
    return jsonEncode({
      'schema': schemaVersion,
      'checksum': _checksum(payload),
      'payload': payload,
    });
  }

  ({SaveData? data, String? error}) _decode(String text) {
    try {
      final env = (jsonDecode(text) as Map).cast<String, Object?>();
      final schema = env['schema'];
      final payload = env['payload'];
      if (schema is! int || payload is! String) {
        return (data: null, error: 'bad_envelope');
      }
      if (_checksum(payload) != env['checksum']) {
        return (data: null, error: 'checksum_mismatch');
      }
      if (schema > schemaVersion) {
        return (data: null, error: 'schema_from_future_$schema');
      }
      var json = (jsonDecode(payload) as Map).cast<String, Object?>();
      for (var v = schema; v < schemaVersion; v++) {
        final m = _migrations[v];
        if (m == null) return (data: null, error: 'no_migration_$v');
        json = m(json);
      }
      return (data: SaveData.fromJson(json), error: null);
    } on Object catch (e) {
      return (data: null, error: 'parse_${e.runtimeType}');
    }
  }

  Future<String?> _safeRead(String name) async {
    try {
      return await _store.read(name);
    } on Object {
      return null;
    }
  }

  Future<void> _safeWrite(String name, String text) async {
    try {
      await _store.write(name, text);
    } on Object {
      // Diagnostic copy only; never block loading on it.
    }
  }

  void _setHealth(SaveHealth h) {
    _health = h;
    _healthController.add(h);
  }

  static String _checksum(String payload) =>
      sha256.convert(utf8.encode(payload)).toString();
}
