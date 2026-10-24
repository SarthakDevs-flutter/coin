import 'package:coin/application/ads/ad_policy.dart';
import 'package:coin/domain/economy/economy.dart';
import 'package:coin/domain/model/level.dart';
import 'package:coin/domain/model/move.dart';
import 'package:coin/domain/model/objective.dart';
import 'package:coin/domain/progression/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_boards.dart';

final now = DateTime.utc(2026, 10, 24, 12);

LevelDefinition lvl(String id, {bool tutorial = false}) => LevelDefinition(
  id: id,
  number: 1,
  chapter: 1,
  version: 1,
  difficulty: 'easy',
  initialState: board(['J']),
  objective: const ClearBoardObjective(),
  reward: 20,
  parMoves: 1,
  tutorial: tutorial
      ? const [TutorialStep(messageKey: 'x', move: MoveCommand('s0', 's1'))]
      : const [],
);

void main() {
  test('level reward is granted exactly once', () {
    var p = PlayerProfile.fresh();
    final a = Economy.completeLevel(p, lvl('a'), moves: 9, now: now);
    expect(a.granted, 20);
    p = a.profile;
    final again = Economy.completeLevel(p, lvl('a'), moves: 5, now: now);
    expect(again.granted, 0);
    expect(again.profile.gilt, 20);
    expect(again.profile.completions['a']!.bestMoves, 5);
    expect(again.profile.ledger, hasLength(1));
  });

  test('tutorial grants bonus hints once and marks tutorial done', () {
    final r = Economy.completeLevel(
      PlayerProfile.fresh(),
      lvl('t', tutorial: true),
      moves: 3,
      now: now,
    );
    expect(r.profile.tutorialDone, isTrue);
    expect(r.profile.count(InventoryItem.hint), 3 + Economy.tutorialHintBonus);
    final r2 = Economy.completeLevel(
      r.profile,
      lvl('t', tutorial: true),
      moves: 3,
      now: now,
    );
    expect(r2.profile.count(InventoryItem.hint), 3 + Economy.tutorialHintBonus);
  });

  test('shop purchase needs funds and is idempotent per tx id', () {
    var p = PlayerProfile.fresh();
    expect(
      Economy.buy(p, ShopOffer.hintPack, txId: 'x', now: now).error,
      EconomyError.insufficientFunds,
    );
    p = p.copyWith(gilt: 100);
    final r = Economy.buy(p, ShopOffer.hintPack, txId: 'x', now: now);
    expect(r.profile.gilt, 40);
    expect(r.profile.count(InventoryItem.hint), 6);
    expect(
      Economy.buy(r.profile, ShopOffer.hintPack, txId: 'x', now: now).error,
      EconomyError.alreadyApplied,
    );
  });

  test('consume never goes negative', () {
    final p = PlayerProfile.fresh().copyWith(
      inventory: {InventoryItem.hint: 0},
    );
    expect(Economy.consume(p, InventoryItem.hint).isOk, isFalse);
  });

  test('rewarded grant applies once per ad token', () {
    final p = PlayerProfile.fresh();
    final r = Economy.grantItem(p, InventoryItem.hint, 1, txId: 'ad:1');
    expect(r.profile.count(InventoryItem.hint), 4);
    expect(
      Economy.grantItem(r.profile, InventoryItem.hint, 1, txId: 'ad:1').isOk,
      isFalse,
    );
  });

  test('entitlement is idempotent; unknown products are rejected', () {
    final p = PlayerProfile.fresh();
    final r = Economy.applyEntitlement(p, 'remove_ads', txId: 'T1');
    expect(r.profile.removeAds, isTrue);
    expect(
      Economy.applyEntitlement(r.profile, 'remove_ads', txId: 'T1').isOk,
      isFalse,
    );
    expect(Economy.applyEntitlement(p, 'mystery', txId: 'T2').isOk, isFalse);
  });

  test('daily stipend once per local day, no streak', () {
    final p = PlayerProfile.fresh();
    final r = Economy.claimStipend(p, now: now);
    expect(r.granted, Economy.stipendAmount);
    expect(Economy.claimStipend(r.profile, now: now).isOk, isFalse);
    expect(
      Economy.claimStipend(
        r.profile,
        now: now.add(const Duration(days: 3)),
      ).isOk,
      isTrue,
    );
  });

  test('finishes are cosmetic purchases', () {
    final p = PlayerProfile.fresh().copyWith(gilt: 200);
    final r = Economy.buyFinish(p, CoinFinish.satin, now: now);
    expect(r.profile.activeFinish, 'satin');
    expect(
      Economy.buyFinish(r.profile, CoinFinish.satin, now: now).error,
      EconomyError.alreadyOwned,
    );
  });

  test('profile JSON round-trips', () {
    var p = Economy.completeLevel(
      PlayerProfile.fresh(),
      lvl('a'),
      moves: 2,
      now: now,
    ).profile;
    p = p.copyWith(discoveredFamilies: {'jade'}, seenIntroductions: {'forge'});
    final back = PlayerProfile.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
  });

  group('interstitial policy', () {
    const policy = InterstitialPolicy();
    PlayerProfile withLevels(int n, {int since = 10, bool removeAds = false}) {
      var p = PlayerProfile.fresh().copyWith(
        tutorialDone: true,
        removeAds: removeAds,
        levelsCompletedSinceInterstitial: since,
      );
      for (var i = 0; i < n; i++) {
        p = Economy.completeLevel(p, lvl('l$i'), moves: 1, now: now).profile;
      }
      return p.copyWith(levelsCompletedSinceInterstitial: since);
    }

    test('never before 3 completed levels or within cadence', () {
      expect(policy.shouldShow(withLevels(2), shownThisSession: 0), isFalse);
      expect(
        policy.shouldShow(withLevels(5, since: 2), shownThisSession: 0),
        isFalse,
      );
      expect(policy.shouldShow(withLevels(5), shownThisSession: 0), isTrue);
    });

    test('respects session cap and remove-ads', () {
      expect(policy.shouldShow(withLevels(5), shownThisSession: 2), isFalse);
      expect(
        policy.shouldShow(withLevels(5, removeAds: true), shownThisSession: 0),
        isFalse,
      );
    });

    test('never before tutorial is done', () {
      final p = withLevels(5).copyWith(tutorialDone: false);
      expect(policy.shouldShow(p, shownThisSession: 0), isFalse);
    });
  });
}
