import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Perspective of the table: rings lie flat on it (matches DiscArt.faceRatio).
const double _flat = 0.56;

/// Fuse/seal burst: white-gold flash, two shockwave rings lying flat on the
/// table, a fan of light rays and twinkling four-point stars. Self-removing;
/// purely presentational.
final class BurstComponent extends PositionComponent {
  BurstComponent({
    required Vector2 at,
    required this.radius,
    required this.color,
    this.duration = 0.7,
    this.stars = 12,
    this.rays = true,
  }) : super(position: at, priority: 850);

  final double radius;
  final Color color;
  final double duration;
  final int stars;
  final bool rays;
  double _t = 0;

  static final _rnd = math.Random(7);
  late final List<(double, double, double, double)> _star = [
    for (var i = 0; i < stars; i++)
      (
        i * math.pi * 2 / stars + _rnd.nextDouble() * 0.4,
        0.7 + _rnd.nextDouble() * 0.7,
        0.6 + _rnd.nextDouble() * 0.7,
        _rnd.nextDouble() * math.pi * 2,
      ),
  ];

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    final p = (_t / duration).clamp(0.0, 1.0);
    final fade = 1 - Curves.easeIn.transform(p);

    if (rays) {
      paintRays(
        canvas,
        radius * (1.2 + 1.4 * Curves.easeOutCubic.transform(p)),
        _t * 0.9,
        0.55 * fade,
        12,
      );
    }

    // Flash: blooms in the first 15 %, then fades.
    final flash = p < 0.15 ? p / 0.15 : 1 - (p - 0.15) / 0.85;
    final g = radius * (0.7 + 0.9 * Curves.easeOut.transform(p));
    canvas.drawCircle(
      Offset.zero,
      g,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          g,
          [
            const Color(0xFFFFFFFF).withValues(alpha: 0.95 * flash),
            const Color(0xFFFFE9A0).withValues(alpha: 0.8 * flash),
            color.withValues(alpha: 0.45 * flash),
            color.withValues(alpha: 0),
          ],
          const [0, 0.2, 0.5, 1],
        ),
    );

    // Shockwaves lying on the table, the second one trailing.
    for (final (delay, scale) in const [(0.0, 1.0), (0.12, 0.75)]) {
      final q = ((p - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (q <= 0) continue;
      final rr =
          radius * scale * (0.4 + 1.5 * Curves.easeOutCubic.transform(q));
      final a = 1 - q;
      final rect = Rect.fromCenter(
        center: Offset(0, radius * 0.1),
        width: rr * 2,
        height: rr * 2 * _flat,
      );
      // Feathered halo in three strokes instead of a blur filter (a blur on a
      // growing ring is re-rendered per frame and stutters on phones).
      final halo = radius * 0.22 * a + 1;
      _ring
        ..strokeWidth = halo * 1.9
        ..color = color.withValues(alpha: 0.12 * a);
      canvas.drawOval(rect, _ring);
      _ring
        ..strokeWidth = halo * 1.2
        ..color = color.withValues(alpha: 0.2 * a);
      canvas.drawOval(rect, _ring);
      _ring
        ..strokeWidth = halo * 0.6
        ..color = color.withValues(alpha: 0.35 * a);
      canvas.drawOval(rect, _ring);
      _ring
        ..strokeWidth = radius * 0.07 * a + 1
        ..color = const Color(0xFFFFF4C8).withValues(alpha: a);
      canvas.drawOval(rect, _ring);
    }

    // Stars fly out, twinkle and shrink.
    _starPaint.color = const Color(0xFFFFF8D8).withValues(alpha: fade);
    for (final (ang, dist, sz, ph) in _star) {
      final d = radius * (0.4 + dist * 1.5 * Curves.easeOutCubic.transform(p));
      final c = Offset(math.cos(ang) * d, math.sin(ang) * d * 0.8);
      final twinkle = 0.6 + 0.4 * math.sin(ph + _t * 30);
      final s = radius * 0.2 * sz * (1 - p * 0.7) * twinkle;
      canvas.drawPath(star4(c, s, _starPath), _starPaint);
    }
  }

  static final _ring = Paint()..style = PaintingStyle.stroke;
  static final _starPaint = Paint();
  static final _starPath = Path();

  /// Soft-edged light rays around the origin.
  static void paintRays(
    Canvas canvas,
    double length,
    double rotation,
    double alpha,
    int count, {
    Color color = const Color(0xFFFFE08A),
  }) {
    if (alpha <= 0.01) return;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        length,
        [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.4),
          color.withValues(alpha: 0),
        ],
        const [0, 0.5, 1],
      );
    final half = math.pi / count * 0.42;
    final path = Path();
    for (var i = 0; i < count; i++) {
      final a = rotation + i * math.pi * 2 / count;
      path
        ..moveTo(0, 0)
        ..lineTo(math.cos(a - half) * length, math.sin(a - half) * length)
        ..lineTo(math.cos(a + half) * length, math.sin(a + half) * length)
        ..close();
    }
    canvas.save();
    canvas.scale(1, 0.85);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  /// Four-point star into [into] (reset first) or a fresh path.
  static Path star4(Offset c, double s, [Path? into]) =>
      (into?..reset()) ?? Path()
        ..moveTo(c.dx, c.dy - s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
        ..close();
}

/// Charge-up before a fuse: slowly turning rays and a warm glow that swell
/// behind the stack, then fade as the burst takes over.
final class AuraComponent extends PositionComponent {
  AuraComponent({
    required Vector2 at,
    required this.radius,
    required this.duration,
    this.color = const Color(0xFFFFD45A),
  }) : super(position: at, priority: 5);

  final double radius;
  final double duration;
  final Color color;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    final p = (_t / duration).clamp(0.0, 1.0);
    // Swell over the first 70 %, fade over the rest.
    final a = p < 0.7
        ? Curves.easeOut.transform(p / 0.7)
        : 1 - Curves.easeIn.transform(((p - 0.7) / 0.3).clamp(0.0, 1.0));
    canvas.drawCircle(
      Offset.zero,
      radius * 1.3,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, radius * 1.3, [
          color.withValues(alpha: 0.45 * a),
          color.withValues(alpha: 0),
        ]),
    );
    BurstComponent.paintRays(
      canvas,
      radius * (1.1 + 0.6 * a),
      _t * 1.6,
      0.4 * a,
      10,
      color: color,
    );
  }
}
