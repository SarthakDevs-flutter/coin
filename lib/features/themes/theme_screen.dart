import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/ports/ports.dart';
import '../../application/providers.dart';
import '../../domain/model/families.dart';
import '../../game/render/theme/coin_theme.dart';
import '../../game/render/theme/coin_themes.dart';
import '../common/scene_backdrop.dart';
import '../common/theme_scope.dart';
import '../common/widgets.dart';

/// Pick the coins, board and scenery to play with. Purely cosmetic and free:
/// themes never change rules, odds or prices.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final selected = ref.watch(saveProvider.select((s) => s.settings.themeId));
    final finish = ref.watch(
      saveProvider.select((s) => s.profile.activeFinish),
    );

    void choose(CoinTheme t) {
      if (t.id == selected) return;
      final s = ref.read(servicesProvider);
      s.audio.play(Sfx.tap);
      if (ref.read(saveProvider).settings.haptics) {
        HapticFeedback.selectionClick();
      }
      ref
          .read(saveProvider.notifier)
          .updateSettings((st) => st.copyWith(themeId: t.id));
      showToast(context, l.themeApplied(t.name));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.themesTitle)),
      extendBodyBehindAppBar: true,
      body: AtelierBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              // One column on phones, two on tablets.
              final cols = c.maxWidth >= 720 ? 2 : 1;
              final themes = CoinThemes.all;
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AtelierSpacing.md,
                      4,
                      AtelierSpacing.md,
                      14,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        l.themesSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AtelierColors.textOnDark,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Color(0xCC000000), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AtelierSpacing.md,
                      0,
                      AtelierSpacing.md,
                      32,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: 268,
                      ),
                      itemCount: themes.length,
                      itemBuilder: (context, i) => ThemeCard(
                        theme: themes[i],
                        selected: themes[i].id == selected,
                        finish: finish,
                        onTap: () => choose(themes[i]),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One theme: a slice of its scenery, its name and currency, and all eight
/// of its coins on a strip of its board.
class ThemeCard extends StatefulWidget {
  const ThemeCard({
    super.key,
    required this.theme,
    required this.selected,
    required this.finish,
    required this.onTap,
  });

  final CoinTheme theme;
  final bool selected;
  final String finish;
  final VoidCallback onTap;

  @override
  State<ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<ThemeCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = widget.theme;
    final b = t.board;
    return Semantics(
      button: true,
      selected: widget.selected,
      label:
          '${t.name}, ${t.symbol.isEmpty ? t.currency : l.themeCurrency(t.currency, t.symbol)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: AtelierMotion.ui,
          curve: Curves.easeOut,
          child: GoldFrame(
            radius: 22,
            width: widget.selected ? 3.5 : 2.5,
            fill: [b.woodLight, b.woodMid, b.woodDark],
            glow: widget.selected
                ? const Color(0xFFFFD45A).withValues(alpha: 0.8)
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Column(
                children: [
                  SizedBox(
                    height: 138,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: _ScenePreviewPainter(t.scene),
                          ),
                        ),
                        // Fade the scenery into the board.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0x00000000),
                                const Color(0x00000000),
                                b.woodLight.withValues(alpha: 0.95),
                              ],
                              stops: const [0, 0.55, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          top: 12,
                          right: 60,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: GoldText(t.name, size: 28),
                              ),
                              const SizedBox(height: 6),
                              _CurrencyPill(
                                text: t.symbol.isEmpty
                                    ? t.currency
                                    : l.themeCurrency(t.currency, t.symbol),
                                color: t.accent,
                              ),
                            ],
                          ),
                        ),
                        if (widget.selected)
                          const Positioned(
                            right: 12,
                            top: 12,
                            child: _CheckBadge(),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
                      child: Column(
                        children: [
                          Expanded(
                            child: CoinThemeScope(
                              theme: t,
                              child: _CoinRow(finish: widget.finish),
                            ),
                          ),
                          _ThemeAction(selected: widget.selected),
                        ],
                      ),
                    ),
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

/// All eight coins in two staggered rows, on a dark tray strip.
class _CoinRow extends StatelessWidget {
  const _CoinRow({required this.finish});

  final String finish;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final size = math.min(52.0, c.maxWidth / 8.4);
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x33FFE08A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in CoinFamilies.all)
                CoinIcon(family: f, size: size, finish: finish),
            ],
          ),
        ),
      );
    },
  );
}

class _ThemeAction extends StatelessWidget {
  const _ThemeAction({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AnimatedSwitcher(
      duration: AtelierMotion.ui,
      child: GoldFrame(
        key: ValueKey(selected),
        radius: 16,
        width: 2,
        shadow: false,
        fill: selected
            ? const [Color(0xFF5BD872), AtelierColors.primaryDeep]
            : const [Color(0xFF5A3A1E), Color(0xFF2E1A0A)],
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_rounded : Icons.palette_rounded,
              size: 18,
              color: AtelierColors.textOnDark,
            ),
            const SizedBox(width: 6),
            Text(
              selected ? l.themeInUse : l.themeUse,
              style: const TextStyle(
                fontFamily: AtelierFonts.display,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AtelierColors.textOnDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => GoldFrame(
    radius: 12,
    width: 1.5,
    shadow: false,
    fill: [
      Color.lerp(color, const Color(0xFFFFFFFF), 0.15)!,
      Color.lerp(color, const Color(0xFF000000), 0.35)!,
    ],
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    child: Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: AtelierFonts.display,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.8,
        color: Color(0xFFFFF4D6),
      ),
    ),
  );
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 38,
    child: GoldFrame(
      shape: BoxShape.circle,
      width: 2.5,
      fill: [Color(0xFF5BD872), AtelierColors.primaryDeep],
      child: Icon(Icons.check_rounded, color: Colors.white, size: 24),
    ),
  );
}

/// The skyline band of a scene, scaled to the card's width.
class _ScenePreviewPainter extends CustomPainter {
  _ScenePreviewPainter(this.scene);

  final SceneStyle scene;

  @override
  void paint(Canvas canvas, Size size) {
    // Paint a phone-shaped scene and show its landmark band.
    final full = Size(size.width, size.width * 2.17);
    canvas.clipRect(Offset.zero & size);
    // Scenes stand on a horizon at 36% of their height: put it near the
    // bottom of the card so the landmarks fill it.
    canvas.translate(0, -(full.height * 0.36 - size.height * 0.88));
    SceneArt.paint(canvas, full, scene);
  }

  @override
  bool shouldRepaint(covariant _ScenePreviewPainter old) =>
      old.scene.kind != scene.kind;
}
