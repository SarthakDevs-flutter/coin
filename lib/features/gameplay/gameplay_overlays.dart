import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/ads/ad_policy.dart';
import '../../application/ports/ports.dart';
import '../../application/providers.dart';
import '../../application/session/gameplay_controller.dart';
import '../../domain/model/coin.dart';
import '../../domain/progression/player_profile.dart';
import '../../game/render/coin_art.dart';
import '../../game/render/theme/coin_theme.dart';
import '../../game/render/theme/coin_themes.dart';
import '../common/names.dart';
import '../common/theme_scope.dart';
import '../common/widgets.dart';
import 'gameplay_screen.dart';

/// Dimmed scrim + centred ivory card with a gentle scale-in.
class _ModalCard extends StatelessWidget {
  const _ModalCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xC40E0805),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AtelierSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // Pop: 0.6 → ~1.06 → 1.0 with fade (design spec v2 §2.3).
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: reduce ? 1 : 0, end: 1),
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                builder: (context, v, child) => Opacity(
                  opacity: (v * 2).clamp(0, 1),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * Curves.easeOutBack.transform(v),
                    child: child,
                  ),
                ),
                child: GoldFrame(
                  radius: 26,
                  width: 4,
                  fill: const [Color(0xFFFFF8EA), Color(0xFFF3E2C0)],
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Material(
                    type: MaterialType.transparency,
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: AtelierColors.textOnLight),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    liveRegion: true,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium
          ?.copyWith(color: AtelierColors.textOnLight),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: AtelierColors.textOnLightMuted,
      fontWeight: FontWeight.w700,
      fontSize: 15,
      height: 1.4,
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onPressed,
      child: GoldFrame(
        radius: 16,
        width: 2.5,
        shadow: false,
        fill: AtelierColors.walnut,
        child: SizedBox(
          height: AtelierSpacing.tapTarget,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GoldShade(
                child: Icon(
                  icon ?? Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AtelierFonts.display,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AtelierColors.textOnDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---- win -----------------------------------------------------------------

class WinOverlay extends ConsumerStatefulWidget {
  const WinOverlay({super.key, required this.state});

  final GameplayState state;

  @override
  ConsumerState<WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends ConsumerState<WinOverlay>
    with TickerProviderStateMixin {
  static int _interstitialsThisSession = 0;
  bool _leaving = false;

  /// Staged entrance: medallion, title, card, buttons.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  /// Endless backdrop motion: turning rays and falling coins.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// Pop-in for one stage of the entrance, between [from] and [to] (0..1).
  Widget _stage(double from, double to, Widget child) => AnimatedBuilder(
    animation: _intro,
    builder: (context, child) {
      final t = ((_intro.value - from) / (to - from)).clamp(0.0, 1.0);
      return Opacity(
        opacity: (t * 2).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - Curves.easeOutCubic.transform(t)) * 24),
          child: Transform.scale(
            scale: 0.6 + 0.4 * Curves.easeOutBack.transform(t),
            child: child,
          ),
        ),
      );
    },
    child: child,
  );

  /// Interstitials are only ever considered here, after the player chose to
  /// continue, under conservative caps (design.md §9).
  Future<void> _maybeInterstitial() async {
    final s = ref.read(servicesProvider);
    final profile = ref.read(saveProvider).profile;
    if (!s.ads.isConfigured) return;
    if (!const InterstitialPolicy().shouldShow(
      profile,
      shownThisSession: _interstitialsThisSession,
    )) {
      return;
    }
    s.analytics.log(AnalyticsEvent.adRequested, {
      'placement': 'between_levels',
    });
    final outcome = await s.ads.showInterstitial('between_levels');
    if (outcome == AdOutcome.completed || outcome == AdOutcome.dismissed) {
      _interstitialsThisSession++;
      s.analytics.log(AnalyticsEvent.adShown, {'placement': 'between_levels'});
      await ref
          .read(saveProvider.notifier)
          .updateProfile(
            (p) => p.copyWith(levelsCompletedSinceInterstitial: 0),
          );
    } else {
      s.analytics.log(AnalyticsEvent.adFailed, {
        'placement': 'between_levels',
        'outcome': outcome.name,
      });
    }
  }

  Future<void> _next(String? nextId) async {
    if (_leaving) return;
    _leaving = true;
    ref.read(servicesProvider).audio.play(Sfx.tap);
    await _maybeInterstitial();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nextId == null) {
      nav.pop();
    } else {
      nav.pushReplacement(atelierRoute(GameplayScreen(levelId: nextId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final win = widget.state.win!;
    final c = ref.read(gameplayProvider.notifier);
    final finish = ref.watch(
      saveProvider.select((s) => s.profile.activeFinish),
    );
    const cream = AtelierColors.textOnDark;
    final reward = Column(
      children: [
        if (win.alreadyClaimed)
          Text(
            l.rewardAlready,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AtelierColors.textOnDarkMuted,
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoinIcon(
                family: 'amber',
                tier: 2,
                size: 40,
                finish: finish,
                theme: CoinThemes.atelier,
              ),
              const SizedBox(width: 8),
              // Counts up once the card has landed.
              AnimatedBuilder(
                animation: _intro,
                builder: (context, _) {
                  final t = Curves.easeOutCubic.transform(
                    ((_intro.value - 0.5) / 0.45).clamp(0.0, 1.0),
                  );
                  return GoldText(
                    l.rewardEarned((win.granted * t).round()),
                    size: 28,
                  );
                },
              ),
            ],
          ),
        if (win.tutorialHints > 0) ...[
          const SizedBox(height: 6),
          Text(
            l.tutorialBonus(win.tutorialHints),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF8BF0A0),
            ),
          ),
        ],
        for (final f in win.newFamilies) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoinIcon(family: f, size: 30, finish: finish),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l.newFamily(familyDisplayName(context, f)),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cream,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_intro, _loop]),
              builder: (context, _) => CustomPaint(
                painter: _WinBackdropPainter(
                  intro: _intro.value,
                  loop: _loop.value,
                  centerY: 0.27,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AtelierSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _stage(
                        0,
                        0.35,
                        CoinIcon(
                          family: 'amber',
                          tier: 3,
                          size: 132,
                          finish: 'gilded',
                          theme: CoinThemes.atelier,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _stage(
                        0.15,
                        0.45,
                        Semantics(
                          header: true,
                          liveRegion: true,
                          child: GoldText(l.winTitle, size: 44),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _stage(
                        0.3,
                        0.6,
                        GoldFrame(
                          radius: 22,
                          width: 3.5,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          child: Column(
                            children: [
                              Text(
                                l.winMoves(win.moves),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AtelierColors.textOnDarkMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 1.5,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0x00F2C14E),
                                      Color(0xFFF2C14E),
                                      Color(0x00F2C14E),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              reward,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _stage(
                        0.45,
                        0.75,
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            label: win.nextLevelId == null
                                ? l.backToMap
                                : l.nextLevel,
                            icon: Icons.arrow_forward_rounded,
                            color: AtelierColors.primary,
                            large: true,
                            onPressed: () => _next(win.nextLevelId),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _stage(
                        0.55,
                        0.85,
                        Row(
                          children: [
                            Expanded(
                              child: _SecondaryButton(
                                label: l.replay,
                                icon: Icons.replay_rounded,
                                onPressed: c.restart,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SecondaryButton(
                                label: l.backToMap,
                                icon: Icons.map_rounded,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Win backdrop: warm scrim, slowly turning golden rays behind the
/// medallion and a gentle fall of spinning gold coins.
class _WinBackdropPainter extends CustomPainter {
  _WinBackdropPainter({
    required this.intro,
    required this.loop,
    required this.centerY,
  });

  final double intro;
  final double loop;
  final double centerY;

  static final _coins = () {
    final r = math.Random(11);
    return [
      for (var i = 0; i < 26; i++)
        (
          r.nextDouble(),
          r.nextDouble(),
          0.6 + r.nextDouble() * 0.8,
          r.nextDouble() * math.pi * 2,
          1 + r.nextInt(2),
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final fadeIn = Curves.easeOut.transform((intro / 0.25).clamp(0.0, 1.0));
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(14, 8, 5, 0.86 * fadeIn),
    );
    final c = Offset(size.width / 2, size.height * centerY);
    final len = size.longestSide * 0.75;
    // Two counter-rotating ray sets.
    for (final (n, speed, a) in const [(14, 1.0, 0.17), (9, -0.6, 0.1)]) {
      final rot = loop * math.pi * 2 * speed * 0.25;
      final half = math.pi / n * 0.45;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final ang = rot + i * math.pi * 2 / n;
        path
          ..moveTo(c.dx, c.dy)
          ..lineTo(
            c.dx + math.cos(ang - half) * len,
            c.dy + math.sin(ang - half) * len,
          )
          ..lineTo(
            c.dx + math.cos(ang + half) * len,
            c.dy + math.sin(ang + half) * len,
          )
          ..close();
      }
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(c, len, [
            Color.fromRGBO(255, 214, 110, a * fadeIn),
            const Color(0x00FFD66E),
          ]),
      );
    }
    canvas.drawCircle(
      c,
      size.width * 0.42,
      Paint()
        ..shader = ui.Gradient.radial(c, size.width * 0.42, [
          Color.fromRGBO(255, 200, 90, 0.35 * fadeIn),
          const Color(0x00FFC85A),
        ]),
    );
    // Falling coins.
    if (loop == 0) return;
    final paint = Paint();
    for (final (x, y0, speed, phase, layer) in _coins) {
      final y = ((y0 + loop * speed * 1.4) % 1.2 - 0.1) * size.height;
      final s = layer == 1 ? 9.0 : 15.0;
      final spin = math.cos(phase + loop * math.pi * 2 * 6 * speed);
      final w = s * (0.2 + 0.8 * spin.abs());
      final at = Offset(x * size.width + math.sin(phase + loop * 20) * 8, y);
      final r = Rect.fromCenter(center: at, width: w * 2, height: s * 2);
      final a = (layer == 1 ? 0.45 : 0.85) * fadeIn;
      paint.color = Color.fromRGBO(140, 82, 8, a);
      canvas.drawOval(r.inflate(1), paint);
      paint.color = Color.fromRGBO(255, 210, 90, a);
      canvas.drawOval(r, paint);
      paint.color = Color.fromRGBO(255, 250, 220, a * 0.85);
      canvas.drawOval(
        Rect.fromCenter(
          center: at.translate(-w * 0.25, -s * 0.3),
          width: w * 0.6,
          height: s * 0.5,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WinBackdropPainter old) =>
      old.intro != intro || old.loop != loop;
}

// ---- blocked (no legal moves) ---------------------------------------------

class BlockedOverlay extends ConsumerWidget {
  const BlockedOverlay({super.key, required this.state, required this.profile});

  final GameplayState state;
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(gameplayProvider.notifier);
    final s = state.session;
    final trays = profile.count(InventoryItem.bonusTray);
    return _ModalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.pan_tool_alt_rounded,
            size: 48,
            color: AtelierColors.accentDeep,
          ),
          const SizedBox(height: 6),
          _Title(l.blockedTitle),
          const SizedBox(height: 8),
          _Body(l.blockedBody),
          const SizedBox(height: 20),
          if (s.canUndo) ...[
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: l.undo,
                icon: Icons.undo_rounded,
                onPressed: c.undo,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (!s.bonusUsed && trays > 0 && !s.level.isTutorial) ...[
            _SecondaryButton(
              label: '${l.extraTray} (${l.owned(trays)})',
              icon: Icons.add_box_rounded,
              onPressed: c.useBonusTray,
            ),
            const SizedBox(height: 10),
          ],
          _SecondaryButton(
            label: l.restart,
            icon: Icons.restart_alt_rounded,
            onPressed: c.restart,
          ),
          const SizedBox(height: 10),
          _SecondaryButton(
            label: l.backToMap,
            icon: Icons.map_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ---- mechanic intro ---------------------------------------------------------

class IntroOverlay extends StatelessWidget {
  const IntroOverlay({super.key, required this.mechanic, required this.onDone});

  final String mechanic;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (title, body) = switch (mechanic) {
      'forge' => (l.introTitleForge, l.introBodyForge),
      'hidden' => (l.introTitleHidden, l.introBodyHidden),
      'deal' => (l.introTitleDeal, l.introBodyDeal),
      'fill' => (l.introTitleFill, l.introBodyFill),
      _ => (l.introTitleFrost, l.introBodyFrost),
    };
    return _ModalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 76,
            child: switch (mechanic) {
              'forge' => const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoinIcon(family: 'jade', size: 46),
                  CoinIcon(family: 'jade', size: 46),
                  CoinIcon(family: 'jade', size: 46),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AtelierColors.accentDeep,
                    ),
                  ),
                  CoinIcon(family: 'jade', tier: 2, size: 62),
                ],
              ),
              'fill' => const _FillPreview(),
              'deal' => const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.south_rounded,
                    size: 40,
                    color: AtelierColors.primaryDeep,
                  ),
                  SizedBox(width: 6),
                  CoinIcon(family: 'ruby', size: 44),
                  CoinIcon(family: 'jade', size: 44),
                  CoinIcon(family: 'sapphire', size: 44),
                ],
              ),
              'hidden' => const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoinIcon(family: 'ruby', hidden: true, size: 58),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AtelierColors.accentDeep,
                    ),
                  ),
                  CoinIcon(family: 'ruby', size: 58),
                ],
              ),
              _ => const _FrostPreview(),
            },
          ),
          const SizedBox(height: 10),
          _Title(title),
          const SizedBox(height: 8),
          _Body(body),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: l.gotIt,
              icon: Icons.check_rounded,
              onPressed: onDone,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two trays of different heights, the short one full and sealing.
class _FillPreview extends StatelessWidget {
  const _FillPreview();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      _tray(3, 3, 'jade', sealing: true),
      const SizedBox(width: 14),
      _tray(5, 3, 'ruby'),
    ],
  );

  Widget _tray(
    int capacity,
    int filled,
    String family, {
    bool sealing = false,
  }) => Container(
    width: 44,
    height: 12.0 * capacity + 8,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFF3A1D08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: sealing ? AtelierColors.primary : AtelierColors.accent,
        width: 2,
      ),
      boxShadow: [
        if (sealing)
          BoxShadow(
            color: AtelierColors.primary.withValues(alpha: 0.7),
            blurRadius: 10,
          ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < filled; i++)
          SizedBox(
            height: 12,
            child: OverflowBox(
              maxHeight: 22,
              child: CoinIcon(family: family, size: 22),
            ),
          ),
      ],
    ),
  );
}

class _FrostPreview extends StatelessWidget {
  const _FrostPreview();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    height: 70,
    child: CustomPaint(painter: _FrostPainter(CoinThemeScope.of(context))),
  );
}

class _FrostPainter extends CustomPainter {
  _FrostPainter(this.theme);

  final CoinTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.4;
    CoinArt.paintCoin(canvas, c, r, family: 'sapphire', tier: 1, theme: theme);
    CoinArt.paintFrost(canvas, c, r, 2);
  }

  @override
  bool shouldRepaint(covariant _FrostPainter old) => old.theme.id != theme.id;
}

// ---- pause ----------------------------------------------------------------

Future<void> showPauseSheet(
  BuildContext context,
  WidgetRef ref,
  GameplayState state,
) {
  final s = ref.read(servicesProvider);
  s.audio.play(Sfx.tap);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AtelierColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AtelierRadii.lg),
    ),
    builder: (ctx) => _PauseSheet(state: state),
  );
}

class _PauseSheet extends ConsumerWidget {
  const _PauseSheet({required this.state});

  final GameplayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(saveProvider.select((s) => s.settings));
    final save = ref.read(saveProvider.notifier);
    final c = ref.read(gameplayProvider.notifier);
    final rules = state.session.board.rules;
    final tutorial = state.level.isTutorial;
    Widget toggle(String label, bool v, ValueChanged<bool> f) =>
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AtelierColors.textOnLight,
            ),
          ),
          value: v,
          onChanged: f,
        );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9C49B),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Title(l.pausedTitle),
            const SizedBox(height: 16),
            PrimaryButton(
              label: l.resume,
              icon: Icons.play_arrow_rounded,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
            if (!tutorial) ...[
              _SecondaryButton(
                label: l.restart,
                icon: Icons.restart_alt_rounded,
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final ok =
                      state.session.board.moveCount == 0 ||
                      await confirmDialog(
                        context,
                        title: l.restartConfirmTitle,
                        body: l.restartConfirmBody,
                        confirm: l.restart,
                      );
                  if (!ok) return;
                  c.restart();
                  nav.pop();
                },
              ),
              const SizedBox(height: 10),
            ],
            _SecondaryButton(
              label: l.backToMap,
              icon: Icons.map_rounded,
              onPressed: () {
                c.onBackground();
                Navigator.of(context)
                  ..pop()
                  ..pop();
              },
            ),
            const SizedBox(height: 18),
            Text(
              l.howToPlay,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AtelierColors.textOnLight),
            ),
            const SizedBox(height: 6),
            for (final line in [
              l.ruleMove,
              l.ruleLand,
              l.ruleFuse(rules.mergeThreshold),
              if (rules.maxTier > 1) l.ruleTier,
              if (state.session.board.deals.isNotEmpty) l.ruleDeal,
              if (_uses(state, SpecialCoinType.hidden)) l.ruleHidden,
              if (_uses(state, SpecialCoinType.frosted)) l.ruleFrost,
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: AtelierColors.accentDeep,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: AtelierColors.textOnLightMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text(
              l.settings,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AtelierColors.textOnLight),
            ),
            toggle(
              l.soundEffects,
              settings.sfx,
              (v) => save.updateSettings((s) => s.copyWith(sfx: v)),
            ),
            toggle(
              l.music,
              settings.music,
              (v) => save.updateSettings((s) => s.copyWith(music: v)),
            ),
            toggle(
              l.haptics,
              settings.haptics,
              (v) => save.updateSettings((s) => s.copyWith(haptics: v)),
            ),
            toggle(
              l.reducedMotion,
              settings.reducedMotion,
              (v) => save.updateSettings((s) => s.copyWith(reducedMotion: v)),
            ),
            toggle(
              l.colorBlind,
              settings.colorBlind,
              (v) => save.updateSettings((s) => s.copyWith(colorBlind: v)),
            ),
          ],
        ),
      ),
    );
  }
}

bool _uses(GameplayState state, SpecialCoinType type) => state
    .level
    .initialState
    .stacks
    .any((s) => s.coins.any((c) => c.specialType == type));
