import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../../app/theme/tokens.dart';
import '../render/disc_art.dart';
import '../render/theme/coin_theme.dart';

enum TrayMark { none, selected, target, dimmed }

/// One stack: a recessed walnut well in a gold frame, sized for disc stacks.
/// The whole column (including lift space) is the tap target.
final class TrayComponent extends PositionComponent with TapCallbacks {
  TrayComponent({
    required this.stackId,
    required this.onTap,
    required this.trayRect,
    required Rect hitRect,
    required this.capacity,
    required this.diameter,
    this.isBonus = false,
    this.isWorkshop = false,
  }) : super(
         position: Vector2(hitRect.left, hitRect.top),
         size: Vector2(hitRect.width, hitRect.height),
       );

  final String stackId;
  final void Function(String id) onTap;
  Rect trayRect;
  final int capacity;
  double diameter;
  final bool isBonus;
  final bool isWorkshop;

  TrayMark mark = TrayMark.none;
  bool hintSource = false;
  bool hintTarget = false;
  bool focus = false;
  bool dealBlocked = false;
  bool interactive = true;
  bool reducedMotion = false;
  double time = 0;
  double _nudge = 0;

  /// Seconds of "stack complete" glow remaining.
  double fullGlow = 0;

  double get nudgeX => reducedMotion || _nudge <= 0
      ? 0
      : math.sin(_nudge * 46) * 5 * (_nudge / 0.3);

  void nudge() => _nudge = 0.3;

  @override
  void update(double dt) {
    super.update(dt);
    time += dt;
    if (_nudge > 0) _nudge = math.max(0, _nudge - dt);
    if (fullGlow > 0) fullGlow = math.max(0, fullGlow - dt);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (interactive) onTap(stackId);
  }

  /// Highlight colours: gold for the lifted tray, green for valid targets,
  /// cyan for hints, red for blocked deals, mint for a completed set.
  static const _gold = Color(0xFFFFD45A);
  static const _target = Color(0xFF7CF29A);
  static const _hint = Color(0xFF8EF0FF);
  static const _done = Color(0xFF6CF0C9);

  @override
  void render(ui.Canvas canvas) {
    final local = trayRect.shift(Offset(-position.x, -position.y));
    final r = RRect.fromRectAndRadius(local, Radius.circular(diameter * 0.26));
    final pulse = reducedMotion
        ? 1.0
        : 0.6 + 0.4 * (0.5 + 0.5 * math.sin(time * 4.2));

    canvas.save();
    canvas.translate(nudgeX, 0);
    Color? glow;
    if (mark == TrayMark.selected) glow = _gold;
    if (mark == TrayMark.target) glow = _target.withValues(alpha: 0.6 * pulse);
    if (hintSource || hintTarget || focus) {
      glow = _hint.withValues(alpha: 0.8 * pulse);
    }
    if (dealBlocked) {
      glow = AtelierColors.danger.withValues(alpha: 0.85 * pulse);
    }
    if (fullGlow > 0) glow = _done.withValues(alpha: math.min(1, fullGlow * 4));
    if (glow != null) _paintGlow(canvas, r, glow);

    Color? edge;
    var width = 0.0;
    switch (mark) {
      case TrayMark.selected:
        edge = _gold;
        width = 3.5;
      case TrayMark.target:
        edge = _target.withValues(alpha: 0.55 + 0.45 * pulse);
        width = 3;
      case TrayMark.none || TrayMark.dimmed:
        break;
    }
    if (hintSource || hintTarget || focus) {
      edge = _hint.withValues(alpha: 0.6 + 0.4 * pulse);
      width = 3.5;
    }
    if (dealBlocked) {
      edge = AtelierColors.danger;
      width = 3.5;
    }
    if (fullGlow > 0) {
      edge = _done;
      width = 3.5;
    }
    if (edge != null) {
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = edge,
      );
    }

    final cx = local.center.dx;
    final y =
        local.top -
        diameter * 0.2 -
        (reducedMotion ? 0 : pulse * diameter * 0.05);
    final s = diameter * 0.15;
    Path? arrow;
    var arrowColor = _target;
    if (hintSource || hintTarget) {
      arrowColor = _hint;
      arrow = hintSource
          ? (Path()
              ..moveTo(cx - s, y + s * 0.4)
              ..lineTo(cx, y - s * 0.6)
              ..lineTo(cx + s, y + s * 0.4))
          : (Path()
              ..moveTo(cx - s, y - s * 0.6)
              ..lineTo(cx, y + s * 0.4)
              ..lineTo(cx + s, y - s * 0.6));
    } else if (mark == TrayMark.target) {
      arrow = Path()
        ..moveTo(cx - s, y - s * 0.6)
        ..lineTo(cx, y + s * 0.4)
        ..lineTo(cx + s, y - s * 0.6);
    }
    if (arrow != null) {
      canvas.drawPath(
        arrow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0x88000000),
      );
      canvas.drawPath(
        arrow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = arrowColor,
      );
    }
    canvas.restore();
  }

  static final _glowPaint = Paint()..style = PaintingStyle.stroke;
  static final _glowFill = Paint();

  /// Soft halo around the well without a blur filter: a blur re-renders the
  /// whole rect through a multi-pass kernel every frame, which is the single
  /// most expensive thing a pulsing highlight can do on a phone GPU. Four
  /// feathered strokes read the same at a fraction of the cost.
  void _paintGlow(ui.Canvas canvas, RRect r, Color glow) {
    final a = glow.a * 0.7;
    final feather = diameter * 0.26;
    const rings = 4;
    final w = feather / rings;
    for (var i = 0; i < rings; i++) {
      final k = 1 - (i + 0.5) / rings;
      _glowPaint
        ..strokeWidth = w + 0.5
        ..color = glow.withValues(alpha: a * k * k * 0.9);
      canvas.drawRRect(r.inflate(w * (i + 0.5)), _glowPaint);
    }
    // Faint tint inside, as the old blur bled into the well.
    _glowFill.color = glow.withValues(alpha: a * 0.28);
    canvas.drawRRect(r, _glowFill);
  }

  /// Static well: recessed dark walnut, engraved slot lines, gold trim and a
  /// gold front lip. Baked into the board image (see BoardFrameComponent),
  /// so none of its blurs are paid per frame.
  static void paintWell(
    Canvas canvas,
    Rect local, {
    required double diameter,
    required int capacity,
    required bool aux,
    required BoardStyle style,
  }) {
    final d = diameter;
    final m = style.inlay;
    final r = RRect.fromRectAndRadius(local, Radius.circular(d * 0.26));
    // Raised gold frame around the well.
    final frame = r.inflate(d * 0.045);
    canvas.drawRRect(
      frame.shift(Offset(0, d * 0.03)),
      Paint()..color = const Color(0x88000000),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = ui.Gradient.linear(
          frame.outerRect.topLeft,
          frame.outerRect.bottomRight,
          aux
              ? const [Color(0xFFDFF8E6), Color(0xFF52C47A), Color(0xFF1C7A3E)]
              : [m.shine, m.base, m.dark],
          const [0, 0.45, 1],
        ),
    );
    // Well floor: darker towards the back wall for depth.
    canvas.drawRRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          local.topCenter,
          local.bottomCenter,
          [
            style.wellDark,
            Color.lerp(style.wellDark, style.wellLight, 0.55)!,
            style.wellLight,
          ],
          const [0, 0.55, 1],
        ),
    );
    canvas.save();
    canvas.clipRRect(r);
    _grain(canvas, local, d);
    // Inner shadow cast by the frame.
    canvas.drawRRect(
      r.shift(Offset(0, d * 0.1)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = d * 0.22
        ..color = const Color(0x88000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d * 0.09),
    );
    // Engraved slot lines on the back wall, one per coin.
    final t = DiscArt.thickness(d);
    final base = local.bottom - d * 0.16 - t;
    for (var i = 1; i <= capacity; i++) {
      final y = base - i * t;
      final a = Offset(local.left + d * 0.1, y);
      final b = Offset(local.right - d * 0.1, y);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = 1
          ..color = const Color(0x55000000),
      );
      canvas.drawLine(
        a.translate(0, 1),
        b.translate(0, 1),
        Paint()
          ..strokeWidth = 1
          ..color = const Color(0x14FFD9A8),
      );
    }
    // Contact shadow where the stack rests.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(local.center.dx, base + t * 0.4),
        width: d * 1.06,
        height: DiscArt.faceHeight(d) * 0.95,
      ),
      Paint()
        ..color = const Color(0x77000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d * 0.04),
    );
    canvas.restore();
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xAA1A0C03),
    );

    // Gold lip across the front.
    final lip = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        local.left - d * 0.06,
        local.bottom - d * 0.1,
        local.width + d * 0.12,
        d * 0.16,
      ),
      Radius.circular(d * 0.08),
    );
    canvas.drawRRect(
      lip.shift(Offset(0, d * 0.04)),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d * 0.03),
    );
    canvas.drawRRect(
      lip,
      Paint()
        ..shader = ui.Gradient.linear(
          lip.outerRect.topCenter,
          lip.outerRect.bottomCenter,
          aux
              ? const [Color(0xFFE6FFEE), Color(0xFF3FBF6A), Color(0xFF145C2D)]
              : [m.shine, m.base, m.dark],
          const [0, 0.45, 1],
        ),
    );
    canvas.drawLine(
      Offset(lip.left + d * 0.1, lip.top + 1.5),
      Offset(lip.right - d * 0.1, lip.top + 1.5),
      Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xCCFFFFFF),
    );
  }

  static void _grain(Canvas canvas, Rect r, double diameter) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final step = math.max(4.0, diameter * 0.12);
    var i = 0;
    for (var x = r.left + step * 0.4; x < r.right; x += step) {
      p.color = i.isEven ? const Color(0x22000000) : const Color(0x0DFFD9A8);
      final path = Path()..moveTo(x, r.top);
      final wob = diameter * 0.03 * (i % 3 == 0 ? 1 : -1);
      path.cubicTo(
        x + wob,
        r.top + r.height * 0.33,
        x - wob,
        r.top + r.height * 0.66,
        x,
        r.bottom,
      );
      canvas.drawPath(path, p);
      i++;
    }
  }

  void renderDim(ui.Canvas canvas) {
    if (mark != TrayMark.dimmed) return;
    final r = RRect.fromRectAndRadius(
      trayRect.inflate(2),
      Radius.circular(diameter * 0.3),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0x66100802));
  }
}
