import 'dart:convert';

import 'package:coin/application/state/save_data.dart';
import 'package:crypto/crypto.dart';
import 'package:coin/data/save/file_save_store.dart';
import 'package:coin/data/save/save_repository.dart';
import 'package:flutter_test/flutter_test.dart';

SaveData sample(int gilt) => SaveData.fresh().copyWith(
  profile: SaveData.fresh().profile.copyWith(gilt: gilt),
);

void main() {
  test('first launch yields a fresh profile', () async {
    final r = await SaveRepository(MemorySaveStore()).load();
    expect(r.recovery, LoadRecovery.fresh);
    expect(r.data.profile.gilt, 0);
  });

  test('save then load round-trips', () async {
    final store = MemorySaveStore();
    await SaveRepository(store).save(sample(42));
    final r = await SaveRepository(store).load();
    expect(r.recovery, LoadRecovery.none);
    expect(r.data.profile.gilt, 42);
  });

  test(
    'corrupt main falls back to last-known-good backup and keeps the raw file',
    () async {
      final store = MemorySaveStore();
      final repo = SaveRepository(store);
      await repo.save(sample(1));
      await repo.save(sample(2));
      store.files[SaveRepository.mainFile] = store
          .files[SaveRepository.mainFile]!
          .substring(0, 40);
      final r = await SaveRepository(store).load();
      expect(r.recovery, LoadRecovery.fromBackup);
      expect(r.data.profile.gilt, 1);
      expect(store.files[SaveRepository.corruptFile], isNotNull);
    },
  );

  test('checksum mismatch is detected', () async {
    final store = MemorySaveStore();
    await SaveRepository(store).save(sample(5));
    final env = (jsonDecode(store.files[SaveRepository.mainFile]!) as Map)
        .cast<String, Object?>();
    env['payload'] = (env['payload']! as String).replaceFirst(
      '"gilt":5',
      '"gilt":999',
    );
    store.files[SaveRepository.mainFile] = jsonEncode(env);
    final r = await SaveRepository(store).load();
    expect(r.recovery, isNot(LoadRecovery.none));
    expect(r.data.profile.gilt, isNot(999));
  });

  test(
    'both copies unreadable: fresh profile, nothing silently overwritten',
    () async {
      final store = MemorySaveStore()
        ..files[SaveRepository.mainFile] = 'garbage'
        ..files[SaveRepository.backupFile] = 'also garbage';
      final r = await SaveRepository(store).load();
      expect(r.recovery, LoadRecovery.reset);
      expect(store.files[SaveRepository.corruptFile], 'garbage');
    },
  );

  test('write failure keeps previous valid files and reports health', () async {
    final store = MemorySaveStore();
    final repo = SaveRepository(store);
    await repo.save(sample(7));
    final good = store.files[SaveRepository.mainFile];
    store.failWrites = true;
    await repo.save(sample(8));
    expect(repo.health, SaveHealth.writeFailed);
    expect(store.files[SaveRepository.mainFile], good);
    store.failWrites = false;
    await repo.flush();
    expect(repo.health, SaveHealth.clean);
    expect((await SaveRepository(store).load()).data.profile.gilt, 8);
  });

  test('sequential migrations run from old schema versions', () async {
    final store = MemorySaveStore();
    // Simulate a schema-0 save whose profile stored balance as "coins".
    final legacy = {
      'profile': {'coins': 30},
      'settings': <String, Object?>{},
    };
    final payload = jsonEncode(legacy);
    store.files[SaveRepository.mainFile] = jsonEncode({
      'schema': 0,
      'checksum': _sha(payload),
      'payload': payload,
    });
    final repo = SaveRepository(
      store,
      migrations: {
        0: (j) {
          final p = (j['profile']! as Map).cast<String, Object?>();
          return {
            ...j,
            'profile': {
              ...SaveData.fresh().profile.toJson(),
              'gilt': p['coins'],
            },
          };
        },
      },
    );
    final r = await repo.load();
    expect(r.recovery, LoadRecovery.none);
    expect(r.data.profile.gilt, 30);
  });

  test('a save from a newer app version is not misread', () async {
    final store = MemorySaveStore();
    const payload = '{}';
    store.files[SaveRepository.mainFile] = jsonEncode({
      'schema': 99,
      'checksum': _sha(payload),
      'payload': payload,
    });
    final r = await SaveRepository(store).load();
    expect(r.errorCode, 'schema_from_future_99');
  });
}

/// Same algorithm as the repository: sha256 of the payload text.
String _sha(String s) => sha256.convert(utf8.encode(s)).toString();
