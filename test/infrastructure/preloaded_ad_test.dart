import 'dart:async';

import 'package:coin/infrastructure/ads/preloaded_ad.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in network: each load waits until the test resolves it.
final class FakeNetwork {
  final pending = <Completer<String>>[];
  final released = <String>[];
  var _n = 0;

  Future<String> load() {
    final c = Completer<String>();
    pending.add(c);
    return c.future;
  }

  void fill() => pending.removeAt(0).complete('ad${_n++}');
  void fail() => pending.removeAt(0).completeError(StateError('no fill'));
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeNetwork net;
  late DateTime now;

  PreloadedAd<String> slot({Duration backoff = const Duration(seconds: 4)}) =>
      PreloadedAd<String>(
        name: 'test',
        load: net.load,
        release: net.released.add,
        ttl: const Duration(hours: 1),
        baseBackoff: backoff,
        now: () => now,
      );

  setUp(() {
    net = FakeNetwork();
    now = DateTime(2026, 10, 26, 12);
  });

  test('does nothing until enabled, then preloads one ad', () async {
    final s = slot();
    s.ensureLoaded();
    expect(net.pending, isEmpty);
    s
      ..enable()
      ..ensureLoaded()
      ..ensureLoaded();
    expect(net.pending, hasLength(1), reason: 'single load in flight');
    net.fill();
    await pump();
    expect(s.isReady, isTrue);
  });

  test('take hands over the ad and waits for ensureLoaded to refill', () async {
    final s = slot()..enable();
    net.fill();
    await pump();
    expect(s.take(), 'ad0');
    expect(s.isReady, isFalse);
    expect(net.pending, isEmpty);
    s.ensureLoaded();
    expect(net.pending, hasLength(1));
  });

  test('take on an empty slot returns null and starts a load', () {
    final s = slot();
    expect(s.take(), isNull);
    expect(net.pending, isEmpty, reason: 'disabled slots never load');
    s.enable();
    net.pending.clear();
    expect(s.take(), isNull);
  });

  test('a stale ad is released and replaced', () async {
    final s = slot()..enable();
    net.fill();
    await pump();
    now = now.add(const Duration(hours: 1, minutes: 1));
    expect(s.isReady, isFalse);
    expect(s.take(), isNull);
    expect(net.released, ['ad0']);
    expect(net.pending, hasLength(1));
  });

  test('failures back off exponentially up to the cap', () {
    final s = slot();
    expect(s.backoffFor(1), const Duration(seconds: 4));
    expect(s.backoffFor(2), const Duration(seconds: 8));
    expect(s.backoffFor(3), const Duration(seconds: 16));
    expect(s.backoffFor(20), const Duration(minutes: 2));
  });

  test('a failed load retries after the backoff', () async {
    final s = slot(backoff: const Duration(milliseconds: 10))..enable();
    net.fail();
    await pump();
    s.ensureLoaded();
    expect(net.pending, isEmpty, reason: 'no retry before backoff');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(net.pending, hasLength(1));
    net.fill();
    await pump();
    expect(s.isReady, isTrue);
  });

  test('disable releases the cached ad and discards a late load', () async {
    final s = slot()..enable();
    net.fill();
    await pump();
    s.disable();
    expect(net.released, ['ad0']);

    s.enable();
    s.disable();
    net.fill();
    await pump();
    expect(net.released, ['ad0', 'ad1']);
    expect(s.isReady, isFalse);
  });

  test('waitUntilReady resolves on load, or false on timeout', () async {
    final s = slot()..enable();
    final ready = s.waitUntilReady(const Duration(seconds: 5));
    net.fill();
    expect(await ready, isTrue);

    final s2 = slot()..enable();
    expect(await s2.waitUntilReady(const Duration(milliseconds: 20)), isFalse);
  });
}
