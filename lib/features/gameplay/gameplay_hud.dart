import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../application/session/gameplay_controller.dart';
import '../../domain/model/board.dart';
import '../../domain/model/objective.dart';
import '../../game/coin_atelier_game.dart';
import '../../game/render/theme/coin_themes.dart';
import '../common/names.dart';
import '../common/widgets.dart';

/// One HUD goal: what to make and how many remain (committed state).
final class GoalSpec {
  const GoalSpec({
    required this.key,
    required this.family,
    required this.tier,
    required this.remaining,
  });

  final String key;
  final String family;
  final int tier;
  final int remaining;
}

/// Derives goal tiles from authoritative state (design spec v2 §2.4).
List<GoalSpec> goalsFor(GameplayState st) {
  final level = st.level;
  final board = st.session.board;
  switch (level.objective) {
    case ForgeObjective(:final tier, :final count):
      final fam = _families(level.initialState).firstOrNull ?? 'jade';
      return [
        GoalSpec(
          key: goalKeyForTier(tier),
          family: fam,
          tier: tier,
          remaining: math.max(0, count - board.progress.forgedOfTier(tier)),
        ),
      ];
    case ClearBoardObjective():
      final k = board.rules.mergeThreshold;
      // Fill mode: set sizes vary by tray, so the tiles count coins.
      final setUnits = board.rules.fillToSeal
          ? 1
          : math.pow(k, board.rules.maxTier).toInt();
      final units = <String, int>{};
      for (final c in [
        for (final s in board.stacks) ...s.coins,
        for (var i = board.dealIndex; i < board.deals.length; i++)
          ...board.deals[i].coins,
      ]) {
        units[c.familyId] =
            (units[c.familyId] ?? 0) + math.pow(k, c.tier - 1).toInt();
      }
      return [
        for (final f in _families(level.initialState))
          GoalSpec(
            key: goalKeyForFamily(f),
            family: f,
            tier: board.rules.maxTier,
            remaining: ((units[f] ?? 0) / setUnits).ceil(),
          ),
      ];
  }
}

List<String> _families(BoardState s) {
  final seen = <String>[];
  for (final c in [
    for (final st in s.stacks) ...st.coins,
    for (final d in s.deals) ...d.coins,
  ]) {
    if (!seen.contains(c.familyId)) seen.add(c.familyId);
  }
  return seen;
}

/// Row of goal tiles. Each tile owns a [GlobalKey] so coin flights can aim
/// at it; [inFlight] keeps the shown count in step with arriving coins.
class GoalTiles extends StatelessWidget {
  const GoalTiles({
    super.key,
    required this.goals,
    required this.keys,
    required this.inFlight,
    required this.bumps,
    required this.finish,
    required this.colorBlind,
  });

  final List<GoalSpec> goals;
  final Map<String, GlobalKey> keys;
  final Map<String, int> inFlight;
  final Map<String, int> bumps;
  final String finish;
  final bool colorBlind;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in goals)
          _GoalTile(
            key: keys.putIfAbsent(g.key, GlobalKey.new),
            goal: g,
            shown: g.remaining + (inFlight[g.key] ?? 0),
            bump: bumps[g.key] ?? 0,
            finish: finish,
            colorBlind: colorBlind,
            label: g.key.startsWith('tier')
                ? l.goalForge(g.tier, g.remaining)
                : l.goalSeal(familyDisplayName(context, g.family), g.remaining),
          ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    super.key,
    required this.goal,
    required this.shown,
    required this.bump,
    required this.finish,
    required this.colorBlind,
    required this.label,
  });

  final GoalSpec goal;
  final int shown;
  final int bump;
  final String finish;
  final bool colorBlind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final done = shown == 0;
    return Semantics(
      label: label,
      excludeSemantics: true,
      // Pop 1 → 1.15 → 1 whenever a coin lands (bump changes).
      child: TweenAnimationBuilder<double>(
        key: ValueKey(bump),
        tween: Tween(begin: bump == 0 ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 320),
        builder: (context, t, child) => Transform.scale(
          scale: 1 + math.sin(t * math.pi) * 0.15,
          child: child,
        ),
        child: SizedBox(
          width: 60,
          child: GoldFrame(
            radius: 14,
            width: 2.5,
            fill: done
                ? const [Color(0xFFE4FBE9), Color(0xFFB4EBC2)]
                : const [Color(0xFFFFF8E8), Color(0xFFEBD3A6)],
            glow: done ? AtelierColors.primary.withValues(alpha: 0.6) : null,
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoinIcon(
                  family: goal.family,
                  tier: goal.tier,
                  size: 36,
                  finish: finish,
                  colorBlind: colorBlind,
                ),
                done
                    ? const Icon(
                        Icons.check_rounded,
                        color: AtelierColors.primaryDeep,
                        size: 20,
                      )
                    : Text(
                        '$shown',
                        style: const TextStyle(
                          fontFamily: AtelierFonts.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          height: 1.1,
                          color: AtelierColors.textOnLight,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Big Deal button with remaining count and a preview of the next batch.
class DealButton extends StatelessWidget {
  const DealButton({
    super.key,
    required this.board,
    required this.onPressed,
    required this.glow,
    required this.finish,
    required this.colorBlind,
  });

  final BoardState board;
  final VoidCallback? onPressed;
  final bool glow;
  final String finish;
  final bool colorBlind;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final next = board.nextDeal;
    final left = board.dealsLeft;
    final enabled = onPressed != null && next != null;
    final preview = next == null ? const [] : next.coins.take(8).toList();
    return Semantics(
      button: true,
      enabled: enabled,
      label: l.a11yDeal(left),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedScale(
          duration: AtelierMotion.ui,
          scale: glow ? 1.05 : 1,
          child: GoldFrame(
            radius: 24,
            width: 3.5,
            fill: enabled
                ? const [
                    Color(0xFF7BEA6A),
                    Color(0xFF32B23F),
                    Color(0xFF1C7A26),
                  ]
                : const [Color(0xFF9C9286), Color(0xFF6E655B)],
            glow: glow ? AtelierColors.accent.withValues(alpha: 0.8) : null,
            child: SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 46,
                      height: 40,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            child: CoinIcon(
                              family: 'amber',
                              size: 30,
                              theme: CoinThemes.atelier,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CoinIcon(
                              family: 'amber',
                              size: 30,
                              theme: CoinThemes.atelier,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.deal.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: AtelierFonts.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            height: 1,
                            letterSpacing: 0.5,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Color(0xFF0E4A16),
                                offset: Offset(0, 2.5),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          l.dealsLeft(left),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: Color(0xFFEFFFE8),
                          ),
                        ),
                      ],
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x44000000),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final c in preview)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: CoinIcon(
                                  family: c.familyId,
                                  tier: c.tier,
                                  size: 22,
                                  finish: finish,
                                  colorBlind: colorBlind,
                                  hidden: !c.isRevealed,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Chain ×N!" — letters type in with a wave, hold, then fade out one by one.
class ChainBanner extends StatelessWidget {
  const ChainBanner({super.key, required this.chain, required this.serial});

  final int chain;
  final int serial;

  @override
  Widget build(BuildContext context) {
    if (serial == 0) return const SizedBox.shrink();
    final text = context.l10n.chainText(chain);
    final reduce = MediaQuery.of(context).disableAnimations;
    const total = 1700.0;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(serial),
        tween: Tween(begin: 0, end: total),
        duration: Duration(milliseconds: total.toInt()),
        builder: (context, ms, _) {
          final chars = text.characters.toList();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < chars.length; i++)
                _letter(chars[i], i, ms, chars.length, reduce),
            ],
          );
        },
      ),
    );
  }

  Widget _letter(String ch, int i, double ms, int n, bool reduce) {
    const inStep = 45.0;
    const hold = 520.0;
    final appear = i * inStep;
    final vanish = n * inStep + hold + i * 40.0;
    double a;
    double y = 0;
    double s = 1;
    if (ms < appear) {
      a = 0;
    } else if (ms < vanish) {
      final t = ((ms - appear) / 220).clamp(0.0, 1.0);
      a = t;
      s = reduce ? 1 : 0.4 + 0.6 * Curves.easeOutBack.transform(t);
      y = reduce ? 0 : math.sin((ms / 140) + i * 0.7) * 4;
    } else {
      final t = ((ms - vanish) / 200).clamp(0.0, 1.0);
      a = 1 - t;
      y = reduce ? 0 : -t * 14;
    }
    return Opacity(
      opacity: a,
      child: Transform.translate(
        offset: Offset(0, y),
        child: Transform.scale(
          scale: s,
          child: Text(
            ch,
            style: TextStyle(
              fontFamily: AtelierFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 40,
              foreground: Paint()
                ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF4C2),
                    AtelierColors.accent,
                    Color(0xFFC88A2A),
                  ],
                ).createShader(const Rect.fromLTWH(0, 0, 30, 46)),
              shadows: const [
                Shadow(
                  color: Color(0xFF3B2508),
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
                Shadow(color: Color(0x99000000), blurRadius: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card drawn over a locked top-row workshop position.
class WorkshopLockCard extends StatelessWidget {
  const WorkshopLockCard({
    super.key,
    required this.afterLevel,
    required this.cost,
    required this.reachable,
    required this.isNext,
    required this.onUnlock,
  });

  final int afterLevel;
  final int cost;

  /// Level requirement met (only the next slot can be bought).
  final bool reachable;
  final bool isNext;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ready = isNext && reachable;
    return Semantics(
      button: ready,
      label: ready ? l.workshopReady(cost) : l.workshopLocked(afterLevel),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: ready ? onUnlock : null,
        child: GoldFrame(
          radius: 14,
          width: 2.5,
          shadow: false,
          fill: ready
              ? const [Color(0xFF6BE36B), Color(0xFF2DA83C), Color(0xFF17702A)]
              : const [Color(0xFF3B2210), Color(0xFF26150A)],
          glow: ready ? AtelierColors.primary.withValues(alpha: 0.55) : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.workshopLevel(afterLevel),
                    style: TextStyle(
                      fontFamily: AtelierFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: ready
                          ? Colors.white
                          : AtelierColors.textOnDarkMuted,
                      shadows: ready
                          ? const [
                              Shadow(
                                color: Color(0xFF0E4A16),
                                offset: Offset(0, 1.5),
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox.square(
                    dimension: 34,
                    child: GoldFrame(
                      radius: 10,
                      width: 2,
                      shadow: false,
                      fill: ready
                          ? const [Color(0xFF5BD872), Color(0xFF1E8A34)]
                          : const [Color(0xFF2A170A), Color(0xFF1A0E05)],
                      child: Center(
                        child: ready
                            ? const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 24,
                              )
                            : const GoldShade(
                                child: Icon(
                                  Icons.lock_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CoinIcon(
                        family: 'amber',
                        size: 16,
                        theme: CoinThemes.atelier,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$cost',
                        style: TextStyle(
                          fontFamily: AtelierFonts.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: ready
                              ? Colors.white
                              : AtelierColors.textOnDarkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
