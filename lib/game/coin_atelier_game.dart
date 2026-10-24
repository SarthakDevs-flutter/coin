import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';

import '../application/ports/board_presenter.dart';
import '../application/ports/ports.dart';
import '../application/session/game_session.dart';
import '../domain/model/board.dart';
import '../domain/model/coin.dart';
import '../domain/model/events.dart';
import '../domain/model/objective.dart';
import 'board_layout.dart';
import 'components/board_frame_component.dart';
import 'components/burst_component.dart';
import 'components/coin_component.dart';
import 'components/particle_layer.dart';
import 'components/tray_component.dart';
import 'render/coin_art.dart';
import 'render/coin_sprite_cache.dart';
import 'render/theme/coin_theme.dart';
import 'render/theme/coin_themes.dart';

final class BoardVisualSettings {
  const BoardVisualSettings({
    this.finish = 'enamel',
    this.colorBlind = false,
    this.reducedMotion = false,
    this.theme = CoinThemes.atelier,
  });

  final String finish;
  final bool colorBlind;
  final bool reducedMotion;
  final CoinTheme theme;
}

/// Hooks from the Flutter shell: where the deal button and goal tiles are
/// (in game coordinates) and where to report goal/chain moments.
final class GameShellHooks {
  const GameShellHooks({
    this.dealOrigin,
    this.goalTarget,
    this.onGoalLaunch,
    this.onGoalHit,
    this.onChain,
  });

  final Offset? Function()? dealOrigin;
  final Offset? Function(String key)? goalTarget;
  final void Function(String key)? onGoalLaunch;
  final void Function(String key)? onGoalHit;
  final void Function(int chain)? onChain;
}

/// Goal-tile key for a sealed set (clear-board) or a forged coin (forge).
String goalKeyForFamily(String family) => 'family:$family';
String goalKeyForTier(int tier) => 'tier:$tier';

/// Flame renderer for the board. Implements [BoardPresenter]: it receives
/// committed state and event logs and animates them. It owns no rules; taps
/// go to [onStackTap] and the application decides what happens.
///
/// Motion follows design spec v2 §2.3.
final class CoinAtelierGame extends FlameGame implements BoardPresenter {
  CoinAtelierGame({
    required this.onStackTap,
    required this.audio,
    this.hooks = const GameShellHooks(),
    this.visuals = const BoardVisualSettings(),
    double pixelRatio = 2,
  }) : _cache = CoinSpriteCache(pixelRatio: pixelRatio);

  final void Function(String stackId) onStackTap;
  final AudioPort audio;
  GameShellHooks hooks;
  BoardVisualSettings visuals;
  final CoinSpriteCache _cache;

  /// Number of top-row workshop positions to reserve (0 hides the row).
  int get workshopRow => _workshopRow;
  int _workshopRow = 0;
  set workshopRow(int v) {
    if (v == _workshopRow) return;
    _workshopRow = v;
    if (_board != null && isLoaded && size.x > 0 && !_tlActive) {
      _rebuild(animate: false);
    }
  }

  /// Rects of every workshop position, for the Flutter lock cards.
  List<Rect> get workshopRects => _layout?.workshopRects ?? const [];

  int _workshopCapacity(BoardState b) {
    for (final s in b.stacks) {
      if (s.isWorkshop) return s.capacity;
    }
    final largest = b.stacks
        .where((s) => !s.isAuxiliary)
        .fold<int>(b.rules.mergeThreshold, (m, s) => math.max(m, s.capacity));
    final k = b.rules.mergeThreshold;
    if (b.rules.fillToSeal) return largest;
    return largest < 6 ? largest : math.max(k, 6);
  }

  /// Objective of the current level (decides which events fly to goals).
  ObjectiveDefinition? objective;

  /// Area the board may occupy, in game coordinates. Null = whole canvas.
  Rect? _boardArea;

  BoardState? _board;
  BoardLayout? _layout;
  Rect? _layoutArea;
  List<(String, int, bool)> _layoutKey = const [];
  final Map<String, TrayComponent> _trays = {};
  BoardFrameComponent? _frame;
  final Map<String, CoinComponent> _coins = {};
  final ParticleLayer _particles = ParticleLayer();
  BoardHighlights _highlights = BoardHighlights.none;

  double _tlTime = 0;
  double _tlEnd = 0;
  bool _tlActive = false;
  final List<(double, void Function())> _cues = [];
  final List<String> _pendingGoals = [];
  Completer<void>? _settled;

  double fps = 60;

  CoinLook get _look => CoinLook(
    finish: visuals.finish,
    colorBlind: visuals.colorBlind,
    theme: visuals.theme,
  );

  bool get _rm => visuals.reducedMotion;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    add(_particles);
    add(_DimLayer(this));
    _particles.density = _rm ? 0 : 1;
    if (_board != null) _rebuild(animate: false);
  }

  Vector2? _lastSize;

  /// Flame calls this on every parent rebuild, not only on real resizes, so
  /// react only when the size actually changed and never mid-animation.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final last = _lastSize;
    if (last != null &&
        (last.x - size.x).abs() < 0.5 &&
        (last.y - size.y).abs() < 0.5) {
      return;
    }
    _lastSize = size.clone();
    if (_board != null && isLoaded) {
      if (_tlActive) {
        _pendingArea ??= _boardArea ?? Rect.fromLTWH(0, 0, size.x, size.y);
        return;
      }
      _rebuild(animate: false);
    }
  }

  @override
  void onRemove() {
    _settled?.complete();
    _settled = null;
    _warmUp.clear();
    _cache.clear();
    super.onRemove();
  }

  /// Sets the region reserved for the board (between HUD and controls).
  /// Never interrupts a running animation: the change is applied once the
  /// timeline settles.
  void setBoardArea(Rect area) {
    final current = _pendingArea ?? _boardArea;
    if (current != null && _close(current, area)) return;
    if (_tlActive) {
      _pendingArea = area;
      return;
    }
    _applyArea(area);
  }

  Rect? _pendingArea;

  void _applyArea(Rect area) {
    _boardArea = area;
    _pendingArea = null;
    if (_board != null && isLoaded && size.x > 0) {
      _rebuild(animate: false);
    }
  }

  static bool _close(Rect a, Rect b) =>
      (a.left - b.left).abs() < 0.5 &&
      (a.top - b.top).abs() < 0.5 &&
      (a.width - b.width).abs() < 0.5 &&
      (a.height - b.height).abs() < 0.5;

  // ---- BoardPresenter -----------------------------------------------------

  @override
  void showBoard(BoardState state, {required bool animate}) {
    if (animate) {
      _interrupt();
    } else {
      fastForward();
    }
    _board = state;
    if (isLoaded && size.x > 0) _rebuild(animate: animate);
  }

  @override
  Future<void> playTransition(SessionTransition transition) {
    // A move arriving mid-animation glides the board into place instead of
    // snapping it, so rapid play never pops.
    _interrupt();
    _board = transition.to;
    if (!isLoaded || size.x <= 0 || _layout == null) {
      if (isLoaded && size.x > 0) _rebuild(animate: false);
      return Future.value();
    }
    if (!_sameStacks(transition.from, transition.to)) {
      _rebuild(animate: true);
      return Future.value();
    }
    _buildTimeline(transition);
    return (_settled = Completer<void>()).future;
  }

  @override
  void setHighlights(BoardHighlights highlights) {
    _highlights = highlights;
    _applyHighlights();
  }

  @override
  void nudge(String stackId) => _trays[stackId]?.nudge();

  @override
  void fastForward() {
    if (!_tlActive) return;
    _tlActive = false;
    _cues.clear();
    for (final c in _coins.values) {
      c.clearMotions();
    }
    // Remove transient flight components (tokens, dealt-in-flight).
    for (final c in children.whereType<CoinComponent>().toList()) {
      if (!_coins.containsValue(c)) c.removeFromParent();
    }
    _reconcile(animate: false);
    _flushGoals();
    _complete();
  }

  /// Soft fast-forward: stops the running timeline but lets every coin glide
  /// from wherever it is to its committed slot (and lets reward tokens finish
  /// their flight). Used when a new transition interrupts the current one.
  void _interrupt() {
    if (!_tlActive) return;
    _tlActive = false;
    _cues.clear();
    // Transient coins (ghosts, consumed) still in the tree are not in _coins:
    // tokens keep flying to the HUD, anything else fades out.
    for (final c in children.whereType<CoinComponent>().toList()) {
      if (_coins.containsValue(c) || c.priority >= 950) continue;
      c
        ..removing = true
        ..clearMotions()
        ..fadeTo(0, 0, 0.12)
        ..callAt(0.12, (c) => c.removeFromParent());
    }
    _reconcile(animate: true, settleTime: _rm ? 0.08 : 0.16);
    _flushGoals();
    _complete();
  }

  void updateVisuals(BoardVisualSettings v) {
    final themeChanged = v.theme.id != visuals.theme.id;
    final lookChanged =
        v.finish != visuals.finish ||
        v.colorBlind != visuals.colorBlind ||
        themeChanged;
    visuals = v;
    final frame = _frame;
    if (themeChanged && frame != null) {
      frame.removeFromParent();
      add(_frame = frame.restyled(v.theme.board));
    }
    _particles.density = v.reducedMotion ? 0 : 1;
    for (final t in _trays.values) {
      t.reducedMotion = v.reducedMotion;
    }
    if (lookChanged) {
      _cache.clear();
      final look = _look;
      for (final c in children.whereType<CoinComponent>()) {
        c.look = look;
      }
      _queueWarmUp();
    }
  }

  /// Tap areas per stack in game coordinates (for the accessibility layer).
  Map<String, Rect> get trayRects => {
    for (final t in _trays.values)
      t.stackId: Rect.fromLTWH(t.position.x, t.position.y, t.size.x, t.size.y),
  };

  // ---- frame loop ---------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    if (dt > 0) fps = fps * 0.92 + (1 / dt) * 0.08;
    for (final c in _coins.values) {
      c.nudgeX = _trays[c.stackId]?.nudgeX ?? 0;
    }
    _warmUpStep();
    if (!_tlActive) return;
    _tlTime += dt;
    while (_cues.isNotEmpty && _cues.first.$1 <= _tlTime) {
      _cues.removeAt(0).$2();
    }
    final busy = children.whereType<CoinComponent>().any(
      (c) => c.isAnimating && !c.removing,
    );
    if (_tlTime >= _tlEnd && !busy) {
      _tlActive = false;
      _cues.clear();
      _reconcile(animate: false, onlyIdle: true);
      _flushGoals();
      _complete();
    }
  }

  // ---- building -----------------------------------------------------------

  Rect get _area {
    final a = _boardArea ?? Rect.fromLTWH(0, 0, size.x, size.y);
    return a.deflate(8);
  }

  void _rebuild({required bool animate}) {
    final board = _board!;
    final area = _area;
    final key = [
      for (final s in board.stacks) (s.id, s.capacity, s.isBonus),
      ('#row', workshopRow, false),
    ];
    if (!_listEq(key, _layoutKey) || _layoutArea != area || _layout == null) {
      final previousD = _layout?.diameter;
      _layout = BoardLayout.compute(
        area,
        [
          for (final s in board.stacks)
            StackSlotSpec(
              capacity: s.capacity,
              workshopSlot: s.isWorkshop
                  ? int.tryParse(s.id.substring(1))
                  : null,
            ),
        ],
        workshopRow: workshopRow,
        workshopCapacity: _workshopCapacity(board),
      );
      _layoutArea = area;
      _layoutKey = key;
      if (previousD != null && previousD != _layout!.diameter) _cache.clear();
      for (final t in _trays.values) {
        t.removeFromParent();
      }
      _trays.clear();
      final layout = _layout!;
      _frame?.removeFromParent();
      add(
        _frame = BoardFrameComponent(
          rect: layout.frameRect,
          unit: layout.diameter,
          pixelRatio: _cache.pixelRatio,
          style: visuals.theme.board,
          wells: [
            for (var i = 0; i < board.stacks.length; i++)
              (
                rect: layout.trayRects[i],
                capacity: board.stacks[i].capacity,
                aux: board.stacks[i].isAuxiliary,
              ),
          ],
        ),
      );
      for (var i = 0; i < board.stacks.length; i++) {
        final s = board.stacks[i];
        final tray =
            TrayComponent(
                stackId: s.id,
                onTap: onStackTap,
                trayRect: layout.trayRects[i],
                hitRect: layout.hitRects[i],
                capacity: s.capacity,
                diameter: layout.diameter,
                isBonus: s.isBonus,
                isWorkshop: s.isWorkshop,
              )
              ..priority = 0
              ..reducedMotion = _rm;
        _trays[s.id] = tray;
        add(tray);
      }
      for (final c in _coins.values) {
        c.diameter = layout.diameter;
      }
      _queueWarmUp();
    }
    _reconcile(animate: animate);
    _applyHighlights();
  }

  // ---- sprite warm-up -----------------------------------------------------

  /// Sprites still to rasterise, a few per frame, so the first flight, flip
  /// or fuse of a coin never stalls on a cache miss.
  final List<void Function()> _warmUp = [];
  static const _warmPerFrame = 3;

  void _queueWarmUp() {
    final board = _board;
    final layout = _layout;
    if (board == null || layout == null) return;
    _warmUp.clear();
    final d = layout.diameter;
    final look = _look;
    final seen = <String>{};
    void want(String family, int tier, int frost, bool revealed) {
      if (tier < 1 || tier > board.rules.maxTier) return;
      final key = '$family|$tier|$frost|$revealed';
      if (!seen.add(key)) return;
      _warmUp.add(() {
        _cache
          ..disc(
            family: family,
            tier: tier,
            diameter: d,
            finish: look.finish,
            colorBlind: look.colorBlind,
            hidden: !revealed,
            frost: frost,
            theme: look.theme,
          )
          ..face(
            family: family,
            tier: tier,
            diameter: d,
            finish: look.finish,
            colorBlind: look.colorBlind,
            hidden: !revealed,
            frost: frost,
            theme: look.theme,
          );
      });
    }

    void coin(CoinState c) {
      want(c.familyId, c.tier, c.frost, c.isRevealed);
      // Every state this coin can reach: thawed steps, its reveal, and the
      // coin a fuse would forge from it.
      for (var f = c.frost - 1; f >= 0; f--) {
        want(c.familyId, c.tier, f, c.isRevealed);
      }
      if (!c.isRevealed) want(c.familyId, c.tier, 0, true);
      want(c.familyId, c.tier + 1, 0, true);
    }

    for (final s in board.stacks) {
      s.coins.forEach(coin);
    }
    for (var i = board.dealIndex; i < board.deals.length; i++) {
      board.deals[i].coins.forEach(coin);
    }
  }

  void _warmUpStep() {
    if (_warmUp.isEmpty) return;
    // Front first: coins on the board come before deals and fuse results.
    // Trickle while coins are flying so the warm-up never competes with them.
    final n = math.min(_tlActive ? 1 : _warmPerFrame, _warmUp.length);
    for (var i = 0; i < n; i++) {
      _warmUp.removeAt(0)();
    }
  }

  Vector2 _slot(int stack, int slot) {
    final o = _layout!.slot(stack, slot);
    return Vector2(o.dx, o.dy);
  }

  int _priorityFor(int stack, int slot) => 10 + slot;

  CoinComponent _newCoin(CoinState coin, Vector2 at) => CoinComponent(
    coin: coin,
    diameter: _layout!.diameter,
    cache: _cache,
    look: _look,
    at: at,
  );

  void _reconcile({
    required bool animate,
    bool onlyIdle = false,
    double? settleTime,
  }) {
    final board = _board;
    final layout = _layout;
    if (board == null || layout == null) return;
    final glide = settleTime ?? (_rm ? 0.1 : 0.22);
    final live = <String>{};
    for (var i = 0; i < board.stacks.length; i++) {
      final stack = board.stacks[i];
      for (var j = 0; j < stack.coins.length; j++) {
        final coin = stack.coins[j];
        live.add(coin.id);
        final home = _slot(i, j);
        var comp = _coins[coin.id];
        if (comp == null || comp.removing) {
          comp?.removeFromParent();
          comp = _newCoin(coin, home);
          _coins[coin.id] = comp;
          add(comp);
          if (animate && !_rm) {
            comp
              ..size_ = 0.4
              ..opacity = 0
              ..scaleTo(0, 1, 0.24)
              ..fadeTo(0, 1, 0.16);
          }
        } else {
          if (onlyIdle && comp.isAnimating) continue;
          comp.coin = coin;
          if (animate) {
            comp.settle(home, glide);
          } else {
            comp.snap(home);
          }
        }
        comp
          ..diameter = layout.diameter
          ..stackId = stack.id
          ..priority = _priorityFor(i, j);
      }
    }
    for (final id in _coins.keys.toList()) {
      if (live.contains(id)) continue;
      final comp = _coins.remove(id)!;
      if (animate && !_rm) {
        comp
          ..removing = true
          ..clearMotions()
          ..fadeTo(0, 0, 0.18)
          ..callAt(0.18, (c) => c.removeFromParent());
      } else {
        comp.removeFromParent();
      }
    }
    _applyLift();
  }

  void _buildTimeline(SessionTransition t) {
    final d = _layout!.diameter;
    // Tight stagger: the run peels off as one ribbon (slinky), each coin
    // rolling over on its own arc.
    final stagger = _rm ? 0.015 : 0.034;
    final index = {
      for (var i = 0; i < t.to.stacks.length; i++) t.to.stacks[i].id: i,
    };
    var time = 0.0;
    var fuses = 0;
    _cues.clear();
    // Coins about to fly keep their lift until their own flight starts, so
    // a staggered run never sags before take-off.
    final flying = {
      for (final e in t.events)
        if (e is CoinsMoved) ...e.coinIds,
    };
    for (final c in _coins.entries) {
      c.value.bob = false;
      if (!flying.contains(c.key)) c.value.targetLift = 0;
    }

    for (final e in t.events) {
      switch (e) {
        case CoinsMoved():
          final di = index[e.toStack]!;
          // The top coin leaves first and lands lowest: a natural stream.
          final ids = e.coinIds.reversed.toList();
          // Coins already resting in the destination feel each landing.
          final below = [
            for (final c in _coins.values)
              if (c.stackId == e.toStack && !ids.contains(c.coin.id)) c,
          ];
          var end = time;
          for (var k = 0; k < ids.length; k++) {
            final c = _coins[ids[k]];
            if (c == null) continue;
            final target = _slot(di, e.toIndex + k);
            final start = time + k * stagger;
            final dist = (target - c.position).length;
            // Longer hops take a little longer; the pace stays even.
            final flight = _rm
                ? 0.12
                : (0.34 + dist / (d * 18)).clamp(0.36, 0.5).toDouble();
            c
              ..priority = 500 + k
              ..stackId = e.toStack
              ..flyTo(
                start,
                target,
                flight,
                arc: _rm ? 0 : d * 0.55 + dist * 0.16,
                flips: _rm ? 0 : 1,
                landSquash: !_rm,
              )
              ..callAt(start + flight, (c) => c.priority = 10 + e.toIndex + k);
            final landed = [
              ...below,
              for (var j = 0; j < k; j++) ?_coins[ids[j]],
            ];
            _cue(start + flight, () {
              audio.playLanding(k);
              if (!_rm) {
                for (final b in landed) {
                  b.impact();
                }
              }
            });
            end = math.max(end, start + flight);
          }
          if (ids.isNotEmpty) _cue(time, () => audio.play(Sfx.whoosh));
          time = end;
        case CoinsDealt():
          final origin = hooks.dealOrigin?.call();
          final from = origin == null
              ? Vector2(size.x / 2, size.y + d)
              : Vector2(origin.dx, origin.dy);
          // Interleave drops so the batch fans out across trays.
          final flights = <(String id, int stack, int slot)>[];
          final maxLen = e.drops.fold<int>(
            0,
            (m, dr) => math.max(m, dr.coinIds.length),
          );
          for (var k = 0; k < maxLen; k++) {
            for (final dr in e.drops) {
              if (k < dr.coinIds.length) {
                flights.add((
                  dr.coinIds[k],
                  index[dr.stackId]!,
                  dr.toIndex + k,
                ));
              }
            }
          }
          _cue(time, () => audio.play(Sfx.deal));
          final dealFlight = _rm ? 0.14 : 0.42;
          final dealStagger = _rm ? 0.01 : 0.05;
          for (var k = 0; k < flights.length; k++) {
            final (id, si, slot) = flights[k];
            final coin = _dealtCoins(t, id).first;
            final comp = _coins[id] ?? _newCoin(coin, from.clone());
            if (!_coins.containsKey(id)) {
              _coins[id] = comp;
              add(comp);
            }
            comp
              ..coin = coin
              ..shownRevealed = coin.isRevealed
              ..shownFrost = coin.frost
              ..position.setFrom(from)
              ..stackId = t.to.stacks[si].id
              ..priority = 600 + k
              ..opacity = 0
              ..size_ = 0.7;
            final start = time + k * dealStagger;
            comp
              ..fadeTo(start, 1, 0.01)
              ..scaleTo(start, 1, dealFlight, curve: Curves.easeOut)
              ..flyTo(
                start,
                _slot(si, slot),
                dealFlight,
                arc: _rm ? 0 : d * 0.9,
                flips: _rm ? 0 : 2,
                spinTurns: _rm ? 0 : (k.isEven ? 0.25 : -0.25),
                landSquash: !_rm,
              )
              ..callAt(start + dealFlight, (c) => c.priority = 10 + slot);
            _cue(start + dealFlight, () => audio.playLanding(k % 3));
          }
          time += dealFlight + math.max(0, flights.length - 1) * dealStagger;
        case CoinsFused():
          fuses++;
          final chain = fuses;
          final si = index[e.stackId]!;
          final base = _slot(si, e.atIndex);
          final tray = _trays[e.stackId];
          // Charge → whiten sweep → gather → burst → pop (luxury v2).
          final glow = _rm ? 0.0 : 0.16;
          final sweep = _rm ? 0.0 : 0.16;
          final compress = _rm ? 0.08 : 0.2;
          final burstAt = time + glow + sweep + compress;
          final consumed = [for (final id in e.consumedIds) ?_coins[id]];
          final heap = consumed.isEmpty
              ? base
              : consumed
                    .map((c) => c.position)
                    .reduce((a, b) => a.y < b.y ? a : b);
          final mid = (base + heap) / 2;
          _cue(time, () {
            tray?.fullGlow = glow + sweep + compress + 0.1;
            if (!_rm) {
              add(
                AuraComponent(
                  at: mid.clone(),
                  radius: d * (e.isSeal ? 1.2 : 0.95),
                  duration: glow + sweep + compress + 0.25,
                ),
              );
            }
          });
          for (var k = 0; k < consumed.length; k++) {
            final c = consumed[k]
              ..removing = true
              ..priority = 400 + k;
            if (!_rm) {
              // Light runs down the stack from the top coin.
              final order = consumed.length - 1 - k;
              c.whitenTo(
                time + glow + order * (sweep / consumed.length),
                1,
                0.1,
              );
              c.scaleTo(
                time + glow + sweep,
                0.8,
                compress,
                curve: Curves.easeIn,
              );
            }
            c.moveTo(time + glow + sweep, base, compress);
          }
          final familyColor = CoinArt.style(
            consumed.isEmpty ? 'pearl' : consumed.first.coin.familyId,
            visuals.theme,
          ).light;
          _cue(burstAt, () {
            audio.play(e.isSeal ? Sfx.seal : Sfx.fuse);
            if (!_rm) {
              add(
                BurstComponent(
                  at: base.clone(),
                  radius: d * (e.isSeal ? 1.05 : 0.8),
                  color: CoinArt.brassBase,
                  stars: e.isSeal ? 16 : 11,
                  duration: e.isSeal ? 0.85 : 0.65,
                ),
              );
              _particles
                ..burst(
                  Offset(base.x, base.y),
                  [familyColor, CoinArt.brassLight, CoinArt.ivory],
                  count: e.isSeal ? 22 : 12,
                  speed: d * 3.4,
                  size: d * 0.05,
                )
                ..shower(
                  Offset(base.x, base.y),
                  count: e.isSeal ? 14 : 7,
                  speed: d * 4.2,
                  size: d * 0.085,
                );
            }
            if (chain >= 2) hooks.onChain?.call(chain);
          });
          // Consumed coins vanish at the burst, except one token that flies
          // to the goal tile for seals.
          final goalKey = e.isSeal && consumed.isNotEmpty
              ? goalKeyForFamily(consumed.first.coin.familyId)
              : null;
          for (var k = 0; k < consumed.length; k++) {
            final c = consumed[k];
            final isToken = goalKey != null && k == consumed.length - 1;
            if (isToken) {
              _launchToken(c, goalKey, burstAt, base);
            } else {
              c
                ..fadeTo(burstAt, 0, 0.04)
                ..callAt(burstAt + 0.05, (c) => c.removeFromParent());
            }
          }
          final produced = e.produced;
          if (produced != null) {
            final comp = _newCoin(produced, base.clone())
              ..stackId = e.stackId
              ..priority = 450
              ..size_ = 0;
            if (_rm) {
              comp.scaleTo(burstAt, 1, 0.1);
            } else {
              // Pops past full size, spins once to show its face, glints.
              comp
                ..scaleTo(burstAt, 1.22, 0.16, curve: Curves.easeOut)
                ..scaleTo(burstAt + 0.16, 1, 0.2, curve: Curves.easeOutBack)
                ..glint(burstAt + 0.4, 0.42);
              comp.flipReveal(burstAt, 0.32);
            }
            comp.callAt(burstAt + 0.37, (c) => c.priority = 10 + e.atIndex);
            _coins[produced.id] = comp;
            add(comp);
            final target = objective;
            if (target is ForgeObjective && produced.tier == target.tier) {
              final ghost = _newCoin(produced, base.clone())
                ..priority = 950
                ..opacity = 0;
              add(ghost);
              ghost.fadeTo(burstAt + 0.2, 0.9, 0.01);
              _launchToken(
                ghost,
                goalKeyForTier(produced.tier),
                burstAt + 0.2,
                base,
              );
            }
          }
          time = burstAt + (_rm ? 0.12 : 0.38);
        case CoinThawed():
          final c = _coins[e.coinId];
          final at = time;
          c?.callAt(at, (c) => c.shownFrost = e.remaining);
          _cue(at, () {
            audio.play(Sfx.thaw);
            if (c != null) {
              _particles.burst(
                Offset(c.position.x, c.position.y),
                const [Color(0xFFE6F7FF), Color(0xFFB8E4F5)],
                count: 8,
                speed: d * 2,
                size: d * 0.05,
              );
            }
          });
          time += 0.05;
        case CoinRevealed():
          final c = _coins[e.coin.id];
          if (c == null) continue;
          c.coin = e.coin;
          if (_rm) {
            c.callAt(time, (c) => c.shownRevealed = true);
          } else {
            c.flipReveal(time, 0.24);
          }
          _cue(time, () => audio.play(Sfx.reveal));
        case ObjectiveCompleted():
          _cue(time + 0.1, () {
            final r = _boardRect();
            _particles.rain(Rect.fromLTWH(r.left, 0, r.width, 10), const [
              CoinArt.brassBase,
              CoinArt.brassLight,
              Color(0xFF21B7A5),
              CoinArt.ivory,
            ]);
          });
      }
    }
    _cues.sort((a, b) => a.$1.compareTo(b.$1));
    _tlTime = 0;
    _tlEnd = time + 0.02;
    _tlActive = true;
  }

  Iterable<CoinState> _dealtCoins(SessionTransition t, String id) sync* {
    for (final b in t.from.deals) {
      for (final c in b.coins) {
        if (c.id == id) yield c;
      }
    }
  }

  /// Flies [token] from [at] to the HUD goal tile for [key] after [start].
  void _launchToken(CoinComponent token, String key, double start, Vector2 at) {
    final target = hooks.goalTarget?.call(key);
    hooks.onGoalLaunch?.call(key);
    _pendingGoals.add(key);
    if (target == null || _rm) {
      token
        ..fadeTo(start, 0, 0.05)
        ..callAt(start + 0.06, (c) {
          c.removeFromParent();
          _goalHit(key);
        });
      return;
    }
    final dest = Vector2(target.dx, target.dy);
    final dist = (dest - at).length;
    token
      ..priority = 960
      ..whitenTo(start, 0, 0.18)
      ..scaleTo(start, 0.62, 0.38, curve: Curves.easeIn)
      ..flyTo(
        start,
        dest,
        0.38,
        arc: math.min(120, dist * 0.35),
        flips: 1,
        landSquash: false,
      )
      ..fadeTo(start + 0.38, 0, 0.05)
      ..callAt(start + 0.4, (c) {
        c.removeFromParent();
        _goalHit(key);
      });
    _cue(start + 0.38, () => audio.play(Sfx.reward));
  }

  void _goalHit(String key) {
    if (_pendingGoals.remove(key)) hooks.onGoalHit?.call(key);
  }

  void _flushGoals() {
    for (final k in List.of(_pendingGoals)) {
      _goalHit(k);
    }
  }

  void _cue(double at, void Function() f) => _cues.add((at, f));

  void _complete() {
    final pending = _pendingArea;
    if (pending != null) {
      // Defer to the next frame so the timeline's final state is in place.
      Future.microtask(() {
        if (!_tlActive && _pendingArea == pending) _applyArea(pending);
      });
    }
    final s = _settled;
    _settled = null;
    if (s != null && !s.isCompleted) s.complete();
    _applyLift();
  }

  void _applyHighlights() {
    final h = _highlights;
    for (final t in _trays.values) {
      final id = t.stackId;
      t
        ..mark = id == h.selected
            ? TrayMark.selected
            : h.targets.contains(id)
            ? TrayMark.target
            : h.selected != null
            ? TrayMark.dimmed
            : TrayMark.none
        ..hintSource = h.hint?.from == id && h.selected == null
        ..hintTarget = h.hint?.to == id
        ..focus = h.focus.contains(id)
        ..dealBlocked = h.dealBlocked.contains(id)
        ..interactive = h.interactive;
    }
    _applyLift();
  }

  void _applyLift() {
    final board = _board;
    final layout = _layout;
    if (board == null || layout == null) return;
    for (final c in _coins.values) {
      c
        ..targetLift = 0
        ..bob = false;
    }
    final sel = _highlights.selected;
    if (sel == null || _tlActive) return;
    final stack = board.stackById(sel);
    if (stack == null) return;
    final n = _highlights.liftCount.clamp(0, stack.coins.length);
    for (var i = stack.coins.length - n; i < stack.coins.length; i++) {
      _coins[stack.coins[i].id]
        ?..targetLift = layout.lift
        ..bob = !_rm;
    }
  }

  Rect _boardRect() {
    final rects = _layout?.trayRects ?? const <Rect>[];
    if (rects.isEmpty) return Rect.fromLTWH(0, 0, size.x, size.y);
    return rects.reduce((a, b) => a.expandToInclude(b));
  }

  bool _sameStacks(BoardState a, BoardState b) {
    if (a.stacks.length != b.stacks.length) return false;
    for (var i = 0; i < a.stacks.length; i++) {
      if (a.stacks[i].id != b.stacks[i].id) return false;
    }
    return true;
  }

  void renderDims(Canvas canvas) {
    for (final t in _trays.values) {
      t.renderDim(canvas);
    }
  }

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final class _DimLayer extends Component {
  _DimLayer(this.game) : super(priority: 800);
  final CoinAtelierGame game;

  @override
  void render(Canvas canvas) => game.renderDims(canvas);
}
