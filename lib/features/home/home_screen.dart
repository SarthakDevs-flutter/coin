import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/ports/ports.dart';
import '../../application/providers.dart';
import '../../domain/economy/economy.dart';
import '../../domain/model/level.dart';
import '../../domain/progression/progression.dart';
import '../common/game_icons.dart';
import '../common/game_ui.dart';
import '../common/theme_scope.dart';
import '../common/widgets.dart';
import '../gameplay/gameplay_screen.dart';
import '../shell/app_shell.dart';

/// Home tab of the shell (game UI redesign §4.1): the level button is
/// dominant; the gift and offers sit on side rails; the chapter panel shows
/// how far the player is through the current chapter.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static String chapterName(BuildContext context, int chapter) {
    final l = context.l10n;
    return switch (chapter) {
      1 => l.chapter1,
      2 => l.chapter2,
      3 => l.chapter3,
      4 => l.chapter4,
      5 => l.chapter5,
      6 => l.chapter6,
      7 => l.chapter7,
      8 => l.chapter8,
      9 => l.chapter9,
      10 => l.chapter10,
      11 => l.chapter11,
      12 => l.chapter12,
      13 => l.chapter13,
      14 => l.chapter14,
      15 => l.chapter15,
      16 => l.chapter16,
      17 => l.chapter17,
      _ => l.chapterN(chapter),
    };
  }

  static String chapterDesc(BuildContext context, int chapter) {
    final l = context.l10n;
    return switch (chapter) {
      1 => l.chapter1Desc,
      2 => l.chapter2Desc,
      3 => l.chapter3Desc,
      4 => l.chapter4Desc,
      5 => l.chapter5Desc,
      6 => l.chapter6Desc,
      7 => l.chapter7Desc,
      8 => l.chapter8Desc,
      9 => l.chapter9Desc,
      10 => l.chapter10Desc,
      11 => l.chapter11Desc,
      12 => l.chapter12Desc,
      13 => l.chapter13Desc,
      14 => l.chapter14Desc,
      15 => l.chapter15Desc,
      16 => l.chapter16Desc,
      17 => l.chapter17Desc,
      _ => '',
    };
  }

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the play button's breathing and the ready gift's wobble.
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = CoinThemeScope.maybeOf(context)?.reducedMotion ?? false;
    if (reduced) {
      _beat
        ..stop()
        ..value = 0;
    } else if (!_beat.isAnimating) {
      _beat.repeat();
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  void _claimGift() {
    final l = context.l10n;
    final s = ref.read(servicesProvider);
    final r = Economy.claimStipend(
      ref.read(saveProvider).profile,
      now: s.clock.now(),
    );
    if (!r.isOk) {
      showToast(context, l.giftClaimed);
      return;
    }
    ref.read(saveProvider.notifier).updateProfile((_) => r.profile);
    s.audio.play(Sfx.reward);
    showToast(context, l.giftCollected(Economy.stipendAmount));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pack = ref.watch(packProvider);
    final save = ref.watch(saveProvider);
    final profile = save.profile;
    final activeId = save.activeSession?['levelId'] as String?;
    final current =
        (activeId == null ? null : pack.byId(activeId)) ??
        Progression.currentLevel(pack, profile);
    final chapter = current.chapter;
    final done = Progression.completedInChapter(pack, profile, chapter);
    final total = pack.chapter(chapter).length;
    final allDone = Progression.campaignComplete(pack, profile);
    final currentIndex = pack.levels.indexWhere((x) => x.id == current.id);
    final giftReady = Economy.stipendAvailable(
      profile,
      ref.read(servicesProvider).clock.now(),
    );
    final tabs = ref.read(shellTabProvider.notifier);

    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 560;
        return Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SizedBox(height: compact ? 4 : 16),
                    BrandMark(size: compact ? 64 : 92),
                    const SizedBox(height: 6),
                    StrokeText(
                      l.appTitle,
                      size: compact ? 30 : 38,
                      color: const Color(0xFFFFE08A),
                    ),
                    const Spacer(),
                    if (!compact && !allDone)
                      _PathPreview(
                        levels: [
                          for (
                            var k = currentIndex - 1;
                            k <= currentIndex + 3;
                            k++
                          )
                            if (k >= 0 && k < pack.levels.length)
                              pack.levels[k],
                        ],
                        currentId: current.id,
                        isDone: profile.isCompleted,
                      ),
                    const Spacer(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: GamePanel(
                        title: HomeScreen.chapterName(context, chapter),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          children: [
                            Text(
                              l.chapterLabel(chapter).toUpperCase(),
                              style: const TextStyle(
                                fontFamily: AtelierFonts.display,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.4,
                                color: AtelierColors.accentDeep,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ChapterProgress(done: done, total: total),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 24),
                    AnimatedBuilder(
                      animation: _beat,
                      builder: (context, child) => Transform.scale(
                        scale: 1 + 0.04 * math.sin(_beat.value * math.pi * 2),
                        child: child,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 230,
                          maxWidth: 320,
                        ),
                        child: GameButton(
                          expand: true,
                          height: 74,
                          fontSize: 32,
                          label: allDone
                              ? l.allSolved
                              : l.levelN(current.number),
                          onPressed: allDone
                              ? () => tabs.go(ShellTab.map)
                              : () => Navigator.of(context).push(
                                  atelierRoute(
                                    GameplayScreen(levelId: current.id),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 22),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: compact ? 4 : 12,
              child: AnimatedBuilder(
                animation: _beat,
                builder: (context, child) => Transform.rotate(
                  angle: giftReady
                      ? 0.12 *
                            math.sin(_beat.value * math.pi * 6) *
                            math.max(0, math.sin(_beat.value * math.pi * 2))
                      : 0,
                  child: child,
                ),
                child: GameRoundButton(
                  icon: GameGlyph.gift,
                  tone: giftReady ? GameTone.blue : GameTone.walnut,
                  size: 58,
                  tooltip: l.dailyGift,
                  badge: giftReady ? '!' : null,
                  label: giftReady ? l.giftReadyShort : l.giftTomorrow,
                  onPressed: _claimGift,
                ),
              ),
            ),
            if (!profile.removeAds)
              Positioned(
                right: 12,
                top: compact ? 4 : 12,
                child: GameRoundButton(
                  icon: GameGlyph.noAds,
                  tone: GameTone.gold,
                  size: 58,
                  tooltip: l.removeAdsTitle,
                  label: l.noAdsShort,
                  onPressed: () => tabs.go(ShellTab.shop),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Chunky progress track with the chapter chest at its end.
class _ChapterProgress extends StatelessWidget {
  const _ChapterProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final f = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Semantics(
      label: context.l10n.chapterProgress(done, total),
      excludeSemantics: true,
      child: SizedBox(
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 22),
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF4A2A12),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF2A1407), width: 2),
              ),
              padding: const EdgeInsets.all(3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: math.max(f, 0.08),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          GameTone.green.ramp[0],
                          GameTone.green.ramp[2],
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              right: 22,
              child: Center(
                child: StrokeText('$done / $total', size: 16, strokeWidth: 3),
              ),
            ),
            const Positioned(
              right: -6,
              child: GameIcon(GameGlyph.shop, size: 46),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short stretch of the level road: the last solved level, the current one
/// (big, green) and what comes next.
class _PathPreview extends StatelessWidget {
  const _PathPreview({
    required this.levels,
    required this.currentId,
    required this.isDone,
  });

  final List<LevelDefinition> levels;
  final String currentId;
  final bool Function(String id) isDone;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 96,
      child: LayoutBuilder(
        builder: (context, box) {
          final n = levels.length;
          final gap = math.min(box.maxWidth / n, 78.0);
          final left = (box.maxWidth - gap * (n - 1)) / 2;
          final centers = [
            for (var i = 0; i < n; i++)
              Offset(left + gap * i, 48 + (i.isEven ? 8.0 : -8.0)),
          ];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _MiniRoad(centers))),
              for (var i = 0; i < n; i++)
                Positioned(
                  left: centers[i].dx - 34,
                  top: centers[i].dy - 34,
                  width: 68,
                  height: 68,
                  child: Center(child: _dot(levels[i])),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _dot(LevelDefinition level) {
    final current = level.id == currentId;
    final done = isDone(level.id) && !current;
    final tone = current
        ? GameTone.green
        : done
        ? GameTone.gold
        : GameTone.grey;
    final size = current ? 60.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: tone.ramp,
        ),
        border: Border.all(color: const Color(0xFF2A1407), width: 2),
        boxShadow: [BoxShadow(color: tone.lip, offset: const Offset(0, 3))],
      ),
      alignment: Alignment.center,
      child: done
          ? const GameIcon(GameGlyph.check, size: 26)
          : StrokeText('${level.number}', size: current ? 24 : 17),
    );
  }
}

class _MiniRoad extends CustomPainter {
  _MiniRoad(this.centers);

  final List<Offset> centers;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      final a = centers[i - 1];
      final b = centers[i];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0x88140A04)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xFF8A5A2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_MiniRoad old) => old.centers != centers;
}
