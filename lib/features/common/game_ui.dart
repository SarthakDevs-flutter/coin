import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';
import '../../game/render/theme/coin_themes.dart';
import 'game_icons.dart';
import 'theme_scope.dart';
import 'widgets.dart';

/// Colour of a chunky game button (game UI redesign §2).
enum GameTone {
  green([
    Color(0xFF8BE85A),
    Color(0xFF3DB83A),
    Color(0xFF23862A),
  ], Color(0xFF145A1A)),
  gold([
    Color(0xFFFFE88A),
    Color(0xFFF6BB2C),
    Color(0xFFD08A0E),
  ], Color(0xFF8A5406)),
  blue([
    Color(0xFF8AD8FF),
    Color(0xFF3796E6),
    Color(0xFF2468BC),
  ], Color(0xFF16427A)),
  red([
    Color(0xFFFF8E7E),
    Color(0xFFE5483D),
    Color(0xFFB8302A),
  ], Color(0xFF761A16)),
  walnut([
    Color(0xFFA8683A),
    Color(0xFF7A4520),
    Color(0xFF5A2F12),
  ], Color(0xFF341A08)),
  grey([
    Color(0xFFD6D0C6),
    Color(0xFFADA597),
    Color(0xFF8E8678),
  ], Color(0xFF5E574C));

  const GameTone(this.ramp, this.lip);

  final List<Color> ramp;
  final Color lip;
}

const _ink = Color(0xFF2A1407);

/// Fredoka label with a dark stroke and drop shadow, the way game titles and
/// button labels read on busy art.
class StrokeText extends StatelessWidget {
  const StrokeText(
    this.text, {
    super.key,
    this.size = 20,
    this.color = Colors.white,
    this.stroke = _ink,
    this.strokeWidth,
    this.align = TextAlign.center,
    this.maxLines = 1,
  });

  final String text;
  final double size;
  final Color color;
  final Color stroke;
  final double? strokeWidth;
  final TextAlign align;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final w = strokeWidth ?? math.max(2.5, size * 0.16);
    TextStyle style(Paint? fg, Color? c) => TextStyle(
      fontFamily: AtelierFonts.display,
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: 1.1,
      foreground: fg,
      color: c,
    );
    return Stack(
      children: [
        Text(
          text,
          textAlign: align,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style:
              style(
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = w
                  ..strokeJoin = StrokeJoin.round
                  ..color = stroke,
                null,
              ).copyWith(
                shadows: [
                  Shadow(color: stroke, offset: Offset(0, size * 0.09)),
                ],
              ),
        ),
        Text(
          text,
          textAlign: align,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style(null, color),
        ),
      ],
    );
  }
}

/// Press handling shared by game buttons: sinks into the lip on press, light
/// haptic on release, no response when disabled.
class _Press extends StatefulWidget {
  const _Press({required this.onTap, required this.builder});

  final VoidCallback? onTap;
  final Widget Function(bool down) builder;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null ? null : (_) => _set(true),
    onTapCancel: () => _set(false),
    onTapUp: widget.onTap == null
        ? null
        : (_) {
            _set(false);
            HapticFeedback.selectionClick();
            widget.onTap!();
          },
    child: widget.builder(_down),
  );
}

/// The glossy body with a darker lip under it. [down] sinks it.
class _Chunk extends StatelessWidget {
  const _Chunk({
    required this.tone,
    required this.down,
    required this.child,
    required this.shape,
    this.lip = 5,
  });

  final GameTone tone;
  final bool down;
  final Widget child;
  final ShapeBorder shape;
  final double lip;

  @override
  Widget build(BuildContext context) {
    final sink = down ? lip - 1 : 0.0;
    return Padding(
      padding: EdgeInsets.only(top: sink),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: tone.lip,
          shape: shape,
          shadows: down
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 8,
                    offset: Offset(0, 5),
                  ),
                ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: lip - sink),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: tone.ramp,
                stops: const [0, 0.5, 1],
              ),
              shape: shape,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gloss band across the top, kept inside the shape.
                Positioned.fill(
                  child: ClipPath(
                    clipper: ShapeBorderClipper(shape: shape),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        widthFactor: 0.86,
                        heightFactor: 0.34,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: const StadiumBorder(),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.55),
                                  Colors.white.withValues(alpha: 0.08),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chunky rectangular game button with an optional leading icon and a
/// second line (e.g. a price).
class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = GameTone.green,
    this.icon,
    this.subtitle,
    this.height = 56,
    this.fontSize = 22,
    this.expand = false,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final GameTone tone;
  final GameGlyph? icon;

  /// Custom leading widget (e.g. a coin) instead of [icon].
  final Widget? leading;
  final String? subtitle;
  final double height;
  final double fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final t = enabled ? tone : GameTone.grey;
    final lead =
        leading ??
        (icon == null ? null : GameIcon(icon!, size: fontSize * 1.3));
    return Semantics(
      button: true,
      enabled: enabled,
      label: subtitle == null ? label : '$label, $subtitle',
      excludeSemantics: true,
      child: _Press(
        onTap: onPressed,
        builder: (down) => SizedBox(
          height: height,
          width: expand ? double.infinity : null,
          child: _Chunk(
            tone: t,
            down: down,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(height * 0.32),
              side: const BorderSide(color: _ink, width: 2),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: height * 0.36),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (lead != null) ...[lead, SizedBox(width: fontSize * 0.35)],
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StrokeText(label, size: fontSize),
                        ),
                        if (subtitle != null)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: StrokeText(
                              subtitle!,
                              size: fontSize * 0.55,
                              color: const Color(0xFFFFF4C8),
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
    );
  }
}

/// Circular game button holding a painted icon, with an optional label under
/// it and a notice badge.
class GameRoundButton extends StatelessWidget {
  const GameRoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.tone = GameTone.walnut,
    this.size = 48,
    this.badge,
    this.label,
  });

  final GameGlyph icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final GameTone tone;
  final double size;

  /// Text in the red badge ('!' or a count). Null hides it.
  final String? badge;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = _Press(
      onTap: onPressed,
      builder: (down) => SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _Chunk(
                tone: enabled ? tone : GameTone.grey,
                down: down,
                lip: 4,
                shape: const CircleBorder(
                  side: BorderSide(color: _ink, width: 2),
                ),
                child: Center(
                  child: GameIcon(
                    icon,
                    size: size * 0.58,
                    mono: enabled ? null : const Color(0xFFE8E2D8),
                  ),
                ),
              ),
            ),
            if (badge != null)
              Positioned(right: -4, top: -4, child: NoticeBadge(badge!)),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      excludeSemantics: true,
      child: label == null
          ? button
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                button,
                const SizedBox(height: 4),
                StrokeText(label!, size: 13),
              ],
            ),
    );
  }
}

/// Red circle with white text: "!" for something to claim, or a count.
class NoticeBadge extends StatelessWidget {
  const NoticeBadge(this.text, {super.key, this.tone = GameTone.red});

  final String text;
  final GameTone tone;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [tone.ramp[0], tone.ramp[2]],
      ),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 3)],
    ),
    alignment: Alignment.center,
    child: StrokeText(text, size: 12, strokeWidth: 2),
  );
}

/// Red ribbon banner with folded tails, used as a title over panels and
/// sections.
class RibbonBanner extends StatelessWidget {
  const RibbonBanner(
    this.text, {
    super.key,
    this.tone = GameTone.red,
    this.fontSize = 22,
  });

  final String text;
  final GameTone tone;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: CustomPaint(
      painter: _RibbonPainter(tone),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          fontSize * 1.6,
          fontSize * 0.3,
          fontSize * 1.6,
          fontSize * 0.45,
        ),
        child: StrokeText(text, size: fontSize),
      ),
    ),
  );
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.tone);

  final GameTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tail = h * 0.55;
    final drop = h * 0.22;
    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    // Tails sit behind the band, lower and darker.
    for (final left in const [true, false]) {
      // Inner edge under the band, outer edge with a V notch.
      final inner = left ? tail * 0.6 : w - tail * 0.6;
      final outer = left ? -tail * 0.25 : w + tail * 0.25;
      final notch = left ? outer + tail * 0.35 : outer - tail * 0.35;
      final p = Path()
        ..moveTo(inner, drop)
        ..lineTo(outer, drop)
        ..lineTo(notch, drop + h * 0.5)
        ..lineTo(outer, h + drop)
        ..lineTo(inner, h + drop)
        ..close();
      canvas
        ..drawPath(p, Paint()..color = tone.lip)
        ..drawPath(p, outline);
    }
    final band = RRect.fromLTRBR(
      tail * 0.35,
      0,
      w - tail * 0.35,
      h,
      const Radius.circular(6),
    );
    canvas
      ..drawRRect(
        band.shift(const Offset(0, 4)),
        Paint()..color = const Color(0x55000000),
      )
      ..drawRRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: tone.ramp,
          ).createShader(band.outerRect),
      )
      ..drawRRect(
        RRect.fromLTRBR(
          band.left + 6,
          3,
          band.right - 6,
          h * 0.42,
          const Radius.circular(5),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      )
      ..drawRRect(band, outline);
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.tone != tone;
}

/// Parchment panel with a gold rim, and an optional ribbon title riding its
/// top edge.
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.tone = GameTone.red,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final GameTone tone;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8E6), Color(0xFFF5E4C0)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _ink, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AtelierColors.accent, width: 3),
        ),
        padding: padding.copyWith(top: padding.top + (title == null ? 0 : 18)),
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: AtelierColors.textOnLight),
            child: child,
          ),
        ),
      ),
    );
    if (title == null) return body;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          body,
          Positioned(
            top: -24,
            child: RibbonBanner(title!, tone: tone, fontSize: 20),
          ),
        ],
      ),
    );
  }
}

/// Dark glass pill with the gilt coin, the balance and a green "+" that opens
/// the shop.
class CurrencyPill extends StatelessWidget {
  const CurrencyPill({super.key, required this.amount, this.onAdd});

  final int amount;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.giltAmount(amount),
    child: SizedBox(
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 16),
            padding: EdgeInsets.only(left: 26, right: onAdd == null ? 14 : 38),
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xB3140A04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x66FFE7A8), width: 1.5),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: amount.toDouble()),
              duration: const Duration(milliseconds: 600),
              builder: (context, v, _) =>
                  StrokeText('${v.round()}', size: 18, strokeWidth: 3),
            ),
          ),
          const CoinIcon(family: 'amber', size: 40, theme: CoinThemes.atelier),
          if (onAdd != null)
            Positioned(
              right: 0,
              child: _PlusButton(onPressed: onAdd, tooltip: context.l10n.shop),
            ),
        ],
      ),
    ),
  );
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.onPressed, required this.tooltip});

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    excludeSemantics: true,
    child: _Press(
      onTap: onPressed,
      builder: (down) => SizedBox.square(
        dimension: 30,
        child: _Chunk(
          tone: GameTone.green,
          down: down,
          lip: 3,
          shape: const CircleBorder(side: BorderSide(color: _ink, width: 2)),
          child: const Center(child: StrokeText('+', size: 22)),
        ),
      ),
    ),
  );
}

/// Game-style on/off switch: a lipped track with a sliding knob.
class GameToggle extends StatelessWidget {
  const GameToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final reduced = CoinThemeScope.maybeOf(context)?.reducedMotion ?? false;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              },
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
          width: 62,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: value
                  ? [GameTone.green.ramp[2], GameTone.green.ramp[1]]
                  : const [Color(0xFF7D7366), Color(0xFFA79E91)],
            ),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _ink, width: 2),
          ),
          child: AnimatedAlign(
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFE2D8C6)],
                ),
                border: Border.all(color: _ink, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
