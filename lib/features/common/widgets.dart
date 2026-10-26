import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/theme/tokens.dart';
import '../../game/render/coin_art.dart';
import '../../game/render/theme/coin_theme.dart';
import '../../game/render/theme/coin_themes.dart';
import 'game_icons.dart';
import 'scene_backdrop.dart';
import 'theme_scope.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The selected theme's scenery behind every screen: a static painting,
/// rasterised once per theme and size, under a light ambient particle layer.
class AtelierBackground extends StatelessWidget {
  const AtelierBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = CoinThemeScope.maybeOf(context);
    final scene = (scope?.theme ?? CoinThemes.atelier).scene;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: scene.ground,
      ),
      child: ColoredBox(
        color: scene.ground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                child: _SceneImage(key: ValueKey(scene.kind), scene: scene),
              ),
            ),
            AmbientLayer(
              key: ValueKey(scene.ambient),
              ambient: scene.ambient,
              reducedMotion: scope?.reducedMotion ?? false,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Paints [scene] from a cached raster. The cache keeps the last few
/// scenes so moving between screens never re-paints the scenery.
class _SceneImage extends StatelessWidget {
  const _SceneImage({super.key, required this.scene});

  final SceneStyle scene;

  static final Map<(SceneKind, Size, double), ui.Image> _cache = {};

  static ui.Image _image(SceneStyle scene, Size size, double dpr) {
    final key = (scene.kind, size, dpr);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..scale(dpr);
    SceneArt.paint(canvas, size, scene);
    final pic = rec.endRecording();
    final img = pic.toImageSync(
      (size.width * dpr).ceil(),
      (size.height * dpr).ceil(),
    );
    pic.dispose();
    _cache[key] = img;
    // Keys only grow on rotation or theme switches: keep three.
    while (_cache.length > 3) {
      final old = _cache.keys.first;
      _cache.remove(old)!.dispose();
    }
    return img;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final size = c.biggest;
      if (size.isEmpty || !size.isFinite) return const SizedBox.shrink();
      // Soft scenery: 2x is plenty and keeps the texture small.
      final dpr = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
      // RawImage owns (and disposes) what it is given: hand it a clone.
      return RawImage(
        image: _image(scene, size, dpr).clone(),
        width: size.width,
        height: size.height,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );
    },
  );
}

/// Polished gold frame around a filled body: the house style for buttons,
/// chips and cards.
class GoldFrame extends StatelessWidget {
  const GoldFrame({
    super.key,
    required this.child,
    this.fill = AtelierColors.walnut,
    this.radius = 18,
    this.width = 2.5,
    this.glow,
    this.padding,
    this.shadow = true,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final List<Color> fill;
  final double radius;
  final double width;
  final Color? glow;
  final EdgeInsetsGeometry? padding;
  final bool shadow;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final circle = shape == BoxShape.circle;
    return Container(
      padding: EdgeInsets.all(width),
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AtelierColors.gold,
          stops: AtelierColors.goldStops,
        ),
        boxShadow: [
          if (shadow)
            const BoxShadow(
              color: Color(0x88000000),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          if (glow != null)
            BoxShadow(color: glow!, blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: circle
              ? null
              : BorderRadius.circular(math.max(0, radius - width)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: fill,
          ),
        ),
        foregroundDecoration: BoxDecoration(
          shape: shape,
          borderRadius: circle
              ? null
              : BorderRadius.circular(math.max(0, radius - width)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Gold gradient applied to an icon or text.
class GoldShade extends StatelessWidget {
  const GoldShade({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => enabled
      ? ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF4C2), Color(0xFFF2C14E), Color(0xFFB5760E)],
          ).createShader(r),
          child: child,
        )
      : Opacity(opacity: 0.45, child: child);
}

/// Static coin drawn with the same art as the board.
class CoinIcon extends StatelessWidget {
  const CoinIcon({
    super.key,
    required this.family,
    this.tier = 1,
    this.size = 40,
    this.finish = 'enamel',
    this.colorBlind = false,
    this.hidden = false,
    this.dim = false,
    this.theme,
  });

  final String family;
  final int tier;
  final double size;
  final String finish;
  final bool colorBlind;
  final bool hidden;
  final bool dim;

  /// Overrides the player's theme: gilt and brand coins always use the
  /// atelier's gold.
  final CoinTheme? theme;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _CoinPainter(
        family,
        tier,
        finish,
        colorBlind,
        hidden,
        dim,
        theme ?? CoinThemeScope.of(context),
      ),
    ),
  );
}

class _CoinPainter extends CustomPainter {
  _CoinPainter(
    this.family,
    this.tier,
    this.finish,
    this.colorBlind,
    this.hidden,
    this.dim,
    this.theme,
  );

  final String family;
  final int tier;
  final String finish;
  final bool colorBlind;
  final bool hidden;
  final bool dim;
  final CoinTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.86;
    if (dim) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = const Color(0x40FFFFFF),
      );
    }
    CoinArt.paintCoin(
      canvas,
      size.center(Offset(0, -r * 0.05)),
      r,
      family: family,
      tier: tier,
      finish: finish,
      colorBlind: colorBlind,
      hidden: hidden,
      theme: theme,
    );
    if (dim) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoinPainter old) =>
      old.family != family ||
      old.tier != tier ||
      old.finish != finish ||
      old.colorBlind != colorBlind ||
      old.hidden != hidden ||
      old.dim != dim ||
      old.theme.id != theme.id;
}

/// Round icon button with a count badge, used for boosters and HUD.
class RoundAction extends StatelessWidget {
  const RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badge,
    this.highlight = false,
    this.busy = false,
    this.size = 56,
  });

  final GameGlyph icon;
  final String label;
  final VoidCallback? onPressed;
  final String? badge;
  final bool highlight;
  final bool busy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: badge == null ? label : '$label, $badge',
      excludeSemantics: true,
      child: _Pressable(
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  duration: AtelierMotion.ui,
                  scale: highlight ? 1.08 : 1,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: GoldFrame(
                      shape: BoxShape.circle,
                      width: 3,
                      fill: enabled
                          ? AtelierColors.walnut
                          : const [Color(0xFF5A4A3C), Color(0xFF3A2E24)],
                      glow: highlight
                          ? AtelierColors.accent.withValues(alpha: 0.75)
                          : null,
                      child: Center(
                        child: busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AtelierColors.accent,
                                ),
                              )
                            : GameIcon(
                                icon,
                                size: size * 0.58,
                                mono: enabled ? null : const Color(0xFF9C8F80),
                              ),
                      ),
                    ),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF5BD872),
                            AtelierColors.primaryDeep,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFE08A),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x88000000), blurRadius: 4),
                        ],
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontFamily: AtelierFonts.display,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AtelierColors.textOnDark,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AtelierFonts.display,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: enabled
                    ? AtelierColors.textOnDark
                    : AtelierColors.textOnDarkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small square icon button for top bars.
class BarButton extends StatelessWidget {
  const BarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final GameGlyph icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: _Pressable(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: AtelierSpacing.tapTarget,
          child: GoldFrame(
            shape: BoxShape.circle,
            width: 2.5,
            child: Center(
              child: GameIcon(
                icon,
                size: 26,
                mono: onPressed != null ? null : const Color(0xFF9C8F80),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Scale-down press feedback that respects reduced motion via short duration.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null
        ? null
        : (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: widget.onTap == null
        ? null
        : (_) {
            setState(() => _down = false);
            widget.onTap!();
          },
    child: AnimatedScale(
      scale: _down ? 0.94 : 1,
      duration: const Duration(milliseconds: 90),
      child: widget.child,
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool destructive = false,
}) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.cancel),
        ),
        TextButton(
          style: destructive
              ? TextButton.styleFrom(foregroundColor: AtelierColors.danger)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showToast(BuildContext context, String message, {double bottom = 0}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 2400),
        margin: bottom == 0 ? null : EdgeInsets.fromLTRB(16, 0, 16, bottom),
      ),
    );
}

/// Fade-through page route (calm, short).
Route<T> atelierRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 280),
  reverseTransitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (context, a, _, child) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) return FadeTransition(opacity: a, child: child);
    return FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween(
          begin: 0.98,
          end: 1.0,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  },
);

/// Brand mark: three overlapping coins.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * 1.6,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(-size * 0.42, size * 0.08),
          child: Transform.rotate(
            angle: -math.pi / 14,
            child: CoinIcon(
              family: 'ruby',
              size: size * 0.78,
              theme: CoinThemes.atelier,
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(size * 0.42, size * 0.08),
          child: Transform.rotate(
            angle: math.pi / 14,
            child: CoinIcon(
              family: 'sapphire',
              size: size * 0.78,
              theme: CoinThemes.atelier,
            ),
          ),
        ),
        CoinIcon(
          family: 'amber',
          tier: 2,
          size: size,
          finish: 'gilded',
          theme: CoinThemes.atelier,
        ),
      ],
    ),
  );
}

/// Display text in polished gold with a dark bevel outline, for titles and
/// celebration moments.
class GoldText extends StatelessWidget {
  const GoldText(this.text, {super.key, this.size = 40});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AtelierFonts.display,
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: 1.05,
      letterSpacing: 0.5,
    );
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF3A1E05),
            shadows: [
              Shadow(
                color: const Color(0xAA000000),
                offset: Offset(0, size * 0.08),
                blurRadius: size * 0.12,
              ),
            ],
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFBE0),
              Color(0xFFFFE08A),
              Color(0xFFF2B33A),
              Color(0xFFB5760E),
            ],
            stops: [0, 0.35, 0.6, 1],
          ).createShader(r),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: style.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Hard / super-hard marker for a level. Null for other difficulties.
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({
    super.key,
    required this.difficulty,
    this.compact = false,
  });

  final String difficulty;

  /// Icon only (chapter map nodes).
  final bool compact;

  static bool marks(String difficulty) =>
      difficulty == 'hard' || difficulty == 'expert';

  static List<Color> colors(String difficulty) => difficulty == 'expert'
      ? const [Color(0xFFC77DFF), Color(0xFF5A1B8C)]
      : const [Color(0xFFFF8A4C), Color(0xFFB0261A)];

  @override
  Widget build(BuildContext context) {
    if (!marks(difficulty)) return const SizedBox.shrink();
    final l = context.l10n;
    final expert = difficulty == 'expert';
    final icon = Icon(
      expert ? Icons.bolt_rounded : Icons.local_fire_department_rounded,
      size: compact ? 14 : 15,
      color: Colors.white,
    );
    return Container(
      padding: compact
          ? const EdgeInsets.all(2)
          : const EdgeInsets.fromLTRB(6, 2, 9, 2),
      decoration: BoxDecoration(
        shape: compact ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: compact ? null : BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors(difficulty),
        ),
        border: Border.all(color: const Color(0xFFFFE08A), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4)],
      ),
      child: compact
          ? icon
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 3),
                Text(
                  (expert ? l.difficultyExpert : l.difficultyHard)
                      .toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AtelierFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }
}
