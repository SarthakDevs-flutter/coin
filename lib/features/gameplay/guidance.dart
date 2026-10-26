import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Pointing hand that shows exactly where to tap next (lesson steps, idle
/// nudges and hints). Glides between targets and pulses a tap; never takes
/// touches. Under reduced motion it jumps and holds still.
class HandPointer extends StatefulWidget {
  const HandPointer({
    super.key,
    required this.target,
    required this.reducedMotion,
    required this.label,
  });

  /// Spot to tap, in the coordinates of the enclosing Stack.
  final Offset target;
  final bool reducedMotion;
  final String label;

  static const double size = 64;

  /// Where the fingertip sits inside the icon box (fractions of [size]).
  static const Offset _tip = Offset(0.42, 0.12);

  @override
  State<HandPointer> createState() => _HandPointerState();
}

class _HandPointerState extends State<HandPointer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reducedMotion) _tap.repeat();
  }

  @override
  void didUpdateWidget(HandPointer old) {
    super.didUpdateWidget(old);
    if (widget.reducedMotion && _tap.isAnimating) {
      _tap
        ..stop()
        ..value = 0;
    } else if (!widget.reducedMotion && !_tap.isAnimating) {
      _tap.repeat();
    }
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const s = HandPointer.size;
    final left = widget.target.dx - HandPointer._tip.dx * s;
    final top = widget.target.dy - HandPointer._tip.dy * s;
    return AnimatedPositioned(
      duration: widget.reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      left: left,
      top: top,
      width: s,
      height: s,
      child: IgnorePointer(
        child: Semantics(
          label: widget.label,
          child: AnimatedBuilder(
            animation: _tap,
            builder: (context, child) {
              // Press in over the first third, release, then rest.
              final t = _tap.value;
              final press = t < 0.3
                  ? Curves.easeOut.transform(t / 0.3)
                  : t < 0.55
                  ? 1 - Curves.easeIn.transform((t - 0.3) / 0.25)
                  : 0.0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Tap ripple under the fingertip.
                  Positioned(
                    left: HandPointer._tip.dx * s - 18,
                    top: HandPointer._tip.dy * s - 18,
                    width: 36,
                    height: 36,
                    child: Opacity(
                      opacity: press * 0.8,
                      child: Transform.scale(
                        scale: 0.6 + press * 0.6,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: AtelierColors.accent, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, 6 * (1 - press)),
                    child: Transform.rotate(
                      angle: -math.pi / 14,
                      alignment: Alignment.topCenter,
                      child: Transform.scale(
                        scale: 1 - press * 0.1,
                        child: child,
                      ),
                    ),
                  ),
                ],
              );
            },
            child: const _Hand(),
          ),
        ),
      ),
    );
  }
}

class _Hand extends StatelessWidget {
  const _Hand();

  @override
  Widget build(BuildContext context) => const Stack(
    children: [
      // Dark outline so the cream hand reads on light and dark boards.
      Positioned(
        left: 1,
        top: 3,
        child: Icon(
          Icons.touch_app_rounded,
          size: HandPointer.size - 2,
          color: Color(0xAA000000),
        ),
      ),
      Icon(
        Icons.touch_app_rounded,
        size: HandPointer.size,
        color: AtelierColors.textOnDark,
        shadows: [Shadow(color: AtelierColors.accentDeep, blurRadius: 6)],
      ),
    ],
  );
}

/// One-time tip bubble above a HUD button. Any tap anywhere dismisses it and
/// still reaches whatever was tapped.
class CoachBubble extends StatelessWidget {
  const CoachBubble({
    super.key,
    required this.anchor,
    required this.text,
    required this.onDismiss,
  });

  /// The button the tip points at, in the coordinates of the enclosing Stack.
  final Rect anchor;
  final String text;
  final VoidCallback onDismiss;

  static const double _maxWidth = 240;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: LayoutBuilder(
      builder: (context, box) {
        final width = math.min(_maxWidth, box.maxWidth - 32);
        final left = (anchor.center.dx - width / 2)
            .clamp(16.0, math.max(16.0, box.maxWidth - 16 - width))
            .toDouble();
        final arrowX = (anchor.center.dx - left)
            .clamp(18.0, width - 18)
            .toDouble();
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) => onDismiss(),
          child: Stack(
            children: [
              Positioned(
                left: left,
                width: width,
                bottom: box.maxHeight - anchor.top + _gap,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: AtelierMotion.ui,
                  curve: Curves.easeOutBack,
                  builder: (context, v, child) => Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * v,
                      alignment: Alignment(arrowX / width * 2 - 1, 1),
                      child: child,
                    ),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: _Bubble(text: text, arrowX: arrowX),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.arrowX});

  final String text;
  final double arrowX;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AtelierColors.surface,
          borderRadius: const BorderRadius.all(AtelierRadii.md),
          border: Border.all(color: AtelierColors.accent, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AtelierColors.textOnLight,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(left: arrowX - 9),
        child: CustomPaint(size: const Size(18, 10), painter: _ArrowPainter()),
      ),
    ],
  );
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, -1)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, -1)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = AtelierColors.surface)
      ..drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0),
        Paint()
          ..color = AtelierColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}
