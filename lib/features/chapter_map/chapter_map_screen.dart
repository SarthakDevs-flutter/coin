import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/providers.dart';
import '../../domain/model/level.dart';
import '../../domain/progression/progression.dart';
import '../common/game_icons.dart';
import '../common/game_ui.dart';
import '../common/theme_scope.dart';
import '../common/widgets.dart';
import '../gameplay/gameplay_screen.dart';
import '../home/home_screen.dart';
import '../shell/app_shell.dart';

/// Map tab (game UI redesign §4.2): every level as a coin on a winding road,
/// one ribbon per chapter, opened at the player's current level.
class ChapterMapScreen extends ConsumerStatefulWidget {
  const ChapterMapScreen({super.key});

  /// Vertical distance between consecutive level nodes.
  static const double step = 96;

  /// Chapter ribbon + caption above each stretch of road.
  static const double header = 110;

  @override
  ConsumerState<ChapterMapScreen> createState() => _ChapterMapScreenState();
}

class _ChapterMapScreenState extends ConsumerState<ChapterMapScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toCurrent(false));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls so the current level sits a little above the middle.
  void _toCurrent(bool animate) {
    if (!mounted || !_scroll.hasClients) return;
    final pack = ref.read(packProvider);
    final profile = ref.read(saveProvider).profile;
    final current = Progression.currentLevel(pack, profile);
    var y = 0.0;
    for (final ch in pack.chapters) {
      final levels = pack.chapter(ch);
      final i = levels.indexWhere((l) => l.id == current.id);
      y += ChapterMapScreen.header;
      if (i >= 0) {
        y += i * ChapterMapScreen.step + ChapterMapScreen.step / 2;
        break;
      }
      y += levels.length * ChapterMapScreen.step;
    }
    final view = _scroll.position.viewportDimension;
    final target = (y - view * 0.45).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if (animate) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shellTabProvider, (_, tab) {
      if (tab == ShellTab.map) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _toCurrent(true));
      }
    });
    final pack = ref.watch(packProvider);
    final profile = ref.watch(saveProvider.select((s) => s.profile));
    final current = Progression.currentLevel(pack, profile);
    // QA aid: every level is open in debug builds, and in any build made
    // with `--dart-define=UNLOCK_ALL=true`. Release builds stay locked.
    const qaUnlock = kDebugMode || bool.fromEnvironment('UNLOCK_ALL');
    final chapters = pack.chapters;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: chapters.length,
      itemBuilder: (context, i) {
        final ch = chapters[i];
        final levels = pack.chapter(ch);
        return Column(
          children: [
            SizedBox(
              height: ChapterMapScreen.header,
              child: _ChapterHeader(
                chapter: ch,
                done: Progression.completedInChapter(pack, profile, ch),
                total: levels.length,
              ),
            ),
            _Road(
              levels: levels,
              flip: i.isOdd,
              nodeState: (level) {
                final done = profile.isCompleted(level.id);
                if (level.id == current.id && !done) return _Node.current;
                if (done) return _Node.done;
                return qaUnlock || Progression.isUnlocked(pack, profile, level)
                    ? _Node.open
                    : _Node.locked;
              },
            ),
          ],
        );
      },
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({
    required this.chapter,
    required this.done,
    required this.total,
  });

  final int chapter;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final complete = done >= total;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RibbonBanner(
            HomeScreen.chapterName(context, chapter),
            tone: complete ? GameTone.green : GameTone.blue,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0x99140A04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${l.chapterLabel(chapter)} · ${l.progressFraction(done, total)}',
            style: const TextStyle(
              fontFamily: AtelierFonts.display,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AtelierColors.textOnDark,
            ),
          ),
        ),
      ],
    );
  }
}

enum _Node { done, current, open, locked }

/// One chapter's stretch of road: nodes swing left and right along a sine,
/// joined by a dotted path.
class _Road extends StatelessWidget {
  const _Road({
    required this.levels,
    required this.flip,
    required this.nodeState,
  });

  final List<LevelDefinition> levels;

  /// Mirrors the swing on alternate chapters so the road keeps winding.
  final bool flip;
  final _Node Function(LevelDefinition) nodeState;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = math.min(box.maxWidth, 520.0);
      final amp = w * 0.27;
      final cx = box.maxWidth / 2;
      final points = [
        for (var i = 0; i < levels.length; i++)
          Offset(
            cx + (flip ? -1 : 1) * amp * math.sin(i * 0.95),
            ChapterMapScreen.step * (i + 0.5),
          ),
      ];
      final states = [for (final l in levels) nodeState(l)];
      return SizedBox(
        height: ChapterMapScreen.step * levels.length,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _RoadPainter(points, states)),
            ),
            for (var i = 0; i < levels.length; i++)
              Positioned(
                left: points[i].dx - 40,
                top: points[i].dy - 40,
                width: 80,
                height: 80,
                child: _LevelNode(level: levels[i], state: states[i]),
              ),
          ],
        ),
      );
    },
  );
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.points, this.states);

  final List<Offset> points;
  final List<_Node> states;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    // Continue the road above the first node and below the last so chapters
    // join up visually.
    final all = [
      points.first - const Offset(0, ChapterMapScreen.step * 0.5),
      ...points,
      points.last + const Offset(0, ChapterMapScreen.step * 0.5),
    ];
    final path = Path()..moveTo(all.first.dx, all.first.dy);
    for (var i = 1; i < all.length; i++) {
      final a = all[i - 1];
      final b = all[i];
      final mid = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0x66140A04)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 30
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xFF8A5A2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.round,
      );
    // Cream dashes down the middle of the road.
    final dash = Paint()
      ..color = const Color(0xCCFFF0C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 22) {
        canvas.drawPath(m.extractPath(d, math.min(d + 9, m.length)), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) =>
      !listEquals(old.points, points) || !listEquals(old.states, states);
}

class _LevelNode extends StatefulWidget {
  const _LevelNode({required this.level, required this.state});

  final LevelDefinition level;
  final _Node state;

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_LevelNode old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Only the current level animates; the rest of the map stays still.
  void _sync() {
    final reduced = CoinThemeScope.maybeOf(context)?.reducedMotion ?? false;
    final want = widget.state == _Node.current && !reduced;
    if (want && _pulse == null) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat();
    } else if (!want && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final level = widget.level;
    final state = widget.state;
    final playable = state != _Node.locked;
    final tone = switch (state) {
      _Node.done => GameTone.gold,
      _Node.current => GameTone.green,
      _Node.open => GameTone.blue,
      _Node.locked => GameTone.grey,
    };
    final size = state == _Node.current ? 72.0 : 60.0;
    final hard = DifficultyBadge.marks(level.difficulty);
    final coin = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: tone.ramp,
        ),
        border: Border.all(
          color: hard && playable
              ? DifficultyBadge.colors(level.difficulty).last
              : const Color(0xFF2A1407),
          width: hard && playable ? 4 : 2.5,
        ),
        boxShadow: [
          BoxShadow(color: tone.lip, offset: const Offset(0, 4)),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 6,
            offset: Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: state == _Node.locked
          ? const GameIcon(GameGlyph.lock, size: 28)
          : StrokeText(
              '${level.number}',
              size: state == _Node.current ? 26 : 21,
            ),
    );
    return Semantics(
      button: true,
      enabled: playable,
      label: '${l.levelN(level.number)}${playable ? '' : ', ${l.levelLocked}'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          if (!playable) {
            showToast(context, l.levelLocked);
            return;
          }
          Navigator.of(context)
              .push(atelierRoute(GameplayScreen(levelId: level.id)));
        },
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (_pulse != null)
              AnimatedBuilder(
                animation: _pulse!,
                builder: (context, _) {
                  final t = _pulse!.value;
                  return Container(
                    width: size + 26 * t,
                    height: size + 26 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: GameTone.green.ramp[0].withValues(alpha: 1 - t),
                        width: 4,
                      ),
                    ),
                  );
                },
              ),
            coin,
            if (state == _Node.done)
              const Positioned(
                bottom: 2,
                right: 6,
                child: GameIcon(GameGlyph.check, size: 26),
              ),
            if (hard && playable)
              Positioned(
                top: 2,
                right: 4,
                child: DifficultyBadge(
                  difficulty: level.difficulty,
                  compact: true,
                ),
              ),
            if (state == _Node.current)
              Positioned(
                top: -34,
                child: _pulse == null
                    ? const _Pointer()
                    : AnimatedBuilder(
                        animation: _pulse!,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(
                            0,
                            -6 * math.sin(_pulse!.value * math.pi * 2).abs(),
                          ),
                          child: child,
                        ),
                        child: const _Pointer(),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Down-pointing marker above the current level.
class _Pointer extends StatelessWidget {
  const _Pointer();

  @override
  Widget build(BuildContext context) => const RotatedBox(
    quarterTurns: 1,
    child: GameIcon(GameGlyph.play, size: 34),
  );
}
