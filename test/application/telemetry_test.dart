import 'dart:ui' show Locale;

import 'package:coin/application/ports/ports.dart';
import 'package:coin/application/telemetry/player_snapshot.dart';
import 'package:coin/application/telemetry/sync_throttle.dart';
import 'package:coin/domain/model/level_pack.dart';
import 'package:coin/domain/progression/player_profile.dart';
import 'package:coin/infrastructure/analytics/firebase_analytics_adapter.dart';
import 'package:coin/infrastructure/update/firestore_app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sync throttle', () {
    test('sends the first value at once, then at most once per gap', () async {
      final sent = <int>[];
      final t = SyncThrottle<int>(
        sent.add,
        minGap: const Duration(milliseconds: 40),
      );
      t
        ..offer(1)
        ..offer(2)
        ..offer(3);
      expect(sent, [1]);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sent, [1, 3], reason: 'burst collapses to the newest value');
    });

    test('drops repeats and flushes pending work on demand', () {
      final sent = <int>[];
      final t = SyncThrottle<int>(sent.add, minGap: const Duration(hours: 1))
        ..offer(1)
        ..offer(1)
        ..offer(2);
      expect(sent, [1]);
      t.flush();
      expect(sent, [1, 2]);
      t
        ..offer(2)
        ..flush();
      expect(sent, [1, 2]);
    });

    test('reset forgets the last value', () {
      final sent = <int>[];
      final t = SyncThrottle<int>(sent.add)..offer(1);
      t
        ..reset()
        ..offer(1);
      expect(sent, [1, 1]);
    });
  });

  group('update gate', () {
    UpdateUrgency at(int build) => FirestoreAppUpdate.evaluate(
      build: build,
      minBuild: 10,
      latestBuild: 12,
    ).urgency;

    test('below min is required, below latest optional', () {
      expect(at(9), UpdateUrgency.required);
      expect(at(10), UpdateUrgency.optional);
      expect(at(12), UpdateUrgency.none);
    });

    test('a latest lower than min is treated as min', () {
      final info = FirestoreAppUpdate.evaluate(
        build: 5,
        minBuild: 8,
        latestBuild: 3,
      );
      expect(info.urgency, UpdateUrgency.required);
      expect(info.latestBuild, 8);
    });
  });

  test('snapshot carries region, highest level and bucketed counts', () {
    const pack = LevelPack(packVersion: 1, levels: []);
    final p = PlayerProfile.fresh().copyWith(tutorialDone: true);
    final s = snapshotOf(
      p,
      pack,
      platform: 'android',
      appVersion: '1.2.0',
      build: 7,
      deviceLocale: const Locale('en', 'in'),
    );
    expect(s.country, 'IN');
    expect(s.locale, 'en-in');
    expect(s.highestLevel, 0);
    expect(userPropertiesOf(s)['levels_done'], '0');
    expect(
      s,
      snapshotOf(
        p,
        pack,
        platform: 'android',
        appVersion: '1.2.0',
        build: 7,
        deviceLocale: const Locale('en', 'in'),
      ),
      reason: 'value equality lets the throttle drop repeats',
    );
  });

  group('firebase event mapping', () {
    test('uses GA4 recommended names where they exist', () {
      final (name, extra) = FirebaseAnalyticsAdapter.eventName(
        AnalyticsEvent.levelCompleted,
        {'level': 'c1-03'},
      );
      expect(name, 'level_end');
      expect(extra, {'level_name': 'c1-03', 'success': 1});
      expect(
        FirebaseAnalyticsAdapter.eventName(AnalyticsEvent.adShown, {}).$1,
        'ad_shown',
      );
    });

    test('params become strings or numbers', () {
      expect(FirebaseAnalyticsAdapter.paramValue(true), 1);
      expect(FirebaseAnalyticsAdapter.paramValue(3), 3);
      expect(FirebaseAnalyticsAdapter.paramValue('x' * 150), hasLength(100));
    });
  });
}
