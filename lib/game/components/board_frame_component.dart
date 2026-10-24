import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../render/coin_art.dart';
import '../render/theme/coin_theme.dart';
import 'tray_component.dart';

/// One tray well baked into the board image.
typedef WellSpec = ({Rect rect, int capacity, bool aux});

/// Polished wooden board with a metal inlay frame (and, per theme, an enamel
/// border carrying the theme's motif), plus every tray's well.
/// All of it is static, so it is rasterised once per layout into a single
/// image: per frame the raster thread blits one texture instead of
/// replaying dozens of blurs.
final class BoardFrameComponent extends PositionComponent {
  BoardFrameComponent({
    required this.rect,
    required this.unit,
    required this.wells,
    required this.pixelRatio,
    required this.style,
  }) : super(priority: -10);

  /// Outer edge of the board in game coordinates.
  final Rect rect;

  /// Coin diameter; scales bevels and grain.
  final double unit;

  final List<WellSpec> wells;
  final double pixelRatio;
  final BoardStyle style;

  /// Same board in another style (the image is re-baked).
  BoardFrameComponent restyled(BoardStyle s) => BoardFrameComponent(
    rect: rect,
    unit: unit,
    wells: wells,
    pixelRatio: pixelRatio,
    style: s,
  );

  ui.Image? _image;
  late final Rect _bounds = rect.inflate(unit * 0.5);

  @override
  void render(ui.Canvas canvas) {
    final img = _image ??= _bake();
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      _bounds,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  void onRemove() {
    _image?.dispose();
    _image = null;
    super.onRemove();
  }

  ui.Image _bake() {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..scale(pixelRatio)
      ..translate(-_bounds.left, -_bounds.top);
    paintBoard(canvas, rect, unit, style);
    for (final w in wells) {
      TrayComponent.paintWell(
        canvas,
        w.rect,
        diameter: unit,
        capacity: w.capacity,
        aux: w.aux,
        style: style,
      );
    }
    final picture = rec.endRecording();
    final img = picture.toImageSync(
      (_bounds.width * pixelRatio).ceil(),
      (_bounds.height * pixelRatio).ceil(),
    );
    picture.dispose();
    return img;
  }

  /// Paints the board into [r]. Shared with previews.
  static void paintBoard(Canvas canvas, Rect r, double u, BoardStyle st) {
    final radius = Radius.circular(u * 0.42);
    final outer = RRect.fromRectAndRadius(r, radius);
    // Drop shadow and the board's own thickness.
    canvas.drawRRect(
      outer.shift(Offset(0, u * 0.16)),
      Paint()
        ..color = const Color(0xAA000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.28),
    );
    canvas.drawRRect(outer.shift(Offset(0, u * 0.1)), Paint()..color = st.edge);
    // Wood (or lacquer, or bamboo) body.
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(
          r.topLeft,
          r.bottomRight,
          [st.woodLight, st.woodMid, st.woodDark],
          const [0, 0.5, 1],
        ),
    );
    canvas.save();
    canvas.clipRRect(outer);
    if (st.grain) {
      paintGrain(canvas, r, u, seed: 3);
    } else if (st.motif == BoardMotif.weave) {
      _bamboo(canvas, r, u);
    } else {
      _lacquer(canvas, r, u);
    }
    canvas.restore();

    final panel = st.panel;
    if (panel != null) {
      // Enamel border between the edge and the inlay, carrying the motif.
      final band = outer.deflate(u * 0.07);
      final inner = outer.deflate(u * 0.25);
      final ring = Path.combine(
        PathOperation.difference,
        Path()..addRRect(band),
        Path()..addRRect(inner),
      );
      canvas.drawPath(
        ring,
        Paint()
          ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, panel, [
            for (var i = 0; i < panel.length; i++) i / (panel.length - 1),
          ]),
      );
      canvas.save();
      canvas.clipPath(ring);
      _borderMotif(canvas, band, inner, u, st);
      canvas.restore();
      for (final rr in [band, inner]) {
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, u * 0.035)
            ..shader = metalShader(r, st.inlay),
        );
      }
    } else {
      _scatterMotif(canvas, r, u, st);
    }

    // Outer bevel: lit top edge, dark bottom edge.
    canvas.drawRRect(
      outer.deflate(u * 0.03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.06
        ..shader = ui.Gradient.linear(
          r.topCenter,
          r.bottomCenter,
          const [Color(0x66FFD9A8), Color(0x00000000), Color(0x66000000)],
          const [0, 0.5, 1],
        ),
    );
    if (panel == null) {
      // Metal inlay a little inside the edge.
      final inlay = outer.deflate(u * 0.11);
      canvas.drawRRect(
        inlay,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, u * 0.045)
          ..shader = metalShader(r, st.inlay),
      );
      canvas.drawRRect(
        inlay.deflate(u * 0.035),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x55000000),
      );
    }
  }

  /// Motifs spaced along the enamel border.
  static void _borderMotif(
    Canvas canvas,
    RRect band,
    RRect inner,
    double u,
    BoardStyle st,
  ) {
    final paint = Paint()..color = st.motifColor;
    final mid = band.outerRect.deflate((band.width - inner.width) / 4);
    final size = (band.width - inner.width) / 2 * 0.36;
    if (st.motif == BoardMotif.weave) {
      // Continuous diamond weave.
      final zig = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.35
        ..color = st.motifColor;
      for (final (y, w) in [(mid.top, mid.width), (mid.bottom, mid.width)]) {
        final p = Path()..moveTo(mid.left, y);
        for (var x = 0.0; x <= w; x += size * 1.6) {
          p
            ..lineTo(mid.left + x + size * 0.8, y - size * 0.7)
            ..lineTo(mid.left + x + size * 1.6, y + size * 0.7);
        }
        canvas.drawPath(p, zig);
      }
      for (final x in [mid.left, mid.right]) {
        final p = Path()..moveTo(x, mid.top);
        for (var y = 0.0; y <= mid.height; y += size * 1.6) {
          p
            ..lineTo(x - size * 0.7, mid.top + y + size * 0.8)
            ..lineTo(x + size * 0.7, mid.top + y + size * 1.6);
        }
        canvas.drawPath(p, zig);
      }
      return;
    }
    if (st.motif == BoardMotif.starsStripes) {
      // Red and white stripes along the bottom run.
      final stripe = Rect.fromLTRB(
        inner.left + u * 0.3,
        mid.bottom - size * 0.9,
        inner.right - u * 0.3,
        mid.bottom + size * 0.9,
      );
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            stripe.left,
            stripe.top + i * stripe.height / 4,
            stripe.width,
            stripe.height / 4,
          ),
          Paint()
            ..color = i.isEven
                ? const Color(0xFFC8202E)
                : const Color(0xFFF4F0E6),
        );
      }
    }
    final step = size * 3.2;
    void along(Offset a, Offset b, {bool skip = false}) {
      final len = (b - a).distance;
      final n = (len / step).floor();
      for (var i = 0; i <= n; i++) {
        final p = Offset.lerp(a, b, n == 0 ? 0.5 : i / n)!;
        paintMotif(canvas, p, size, st.motif, paint);
      }
    }

    along(mid.topLeft, mid.topRight);
    if (st.motif != BoardMotif.starsStripes) {
      along(mid.bottomLeft, mid.bottomRight);
    }
    along(mid.topLeft + Offset(0, step), mid.bottomLeft - Offset(0, step));
    along(mid.topRight + Offset(0, step), mid.bottomRight - Offset(0, step));
  }

  /// Faint marquetry motifs inlaid in the wood (boards without a border).
  static void _scatterMotif(Canvas canvas, Rect r, double u, BoardStyle st) {
    if (st.motif == BoardMotif.none) return;
    final paint = Paint()..color = st.motifColor.withValues(alpha: 0.32);
    final size = u * 0.09;
    final corners = [
      r.topLeft + Offset(u * 0.26, u * 0.26),
      r.topRight + Offset(-u * 0.26, u * 0.26),
      r.bottomLeft + Offset(u * 0.26, -u * 0.26),
      r.bottomRight + Offset(-u * 0.26, -u * 0.26),
    ];
    for (final c in corners) {
      paintMotif(canvas, c, size * 1.4, st.motif, paint);
    }
    final n = (r.width / (u * 0.9)).floor();
    for (var i = 1; i < n; i++) {
      final x = r.left + r.width * i / n;
      paintMotif(canvas, Offset(x, r.top + u * 0.2), size, st.motif, paint);
      paintMotif(canvas, Offset(x, r.bottom - u * 0.2), size, st.motif, paint);
    }
  }

  /// One small motif of size [s] centred at [c].
  static void paintMotif(
    Canvas canvas,
    Offset c,
    double s,
    BoardMotif m,
    Paint paint,
  ) {
    switch (m) {
      case BoardMotif.none || BoardMotif.weave:
        return;
      case BoardMotif.stars || BoardMotif.starsStripes:
        final p = Path();
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final k = i.isEven ? s : s * 0.42;
          final pt = c + Offset(math.cos(a) * k, math.sin(a) * k);
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(p..close(), paint);
      case BoardMotif.sakura:
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * math.pi * 2 / 5;
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(a + math.pi / 2);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(0, -s * 0.55),
              width: s * 0.62,
              height: s * 0.9,
            ),
            paint,
          );
          canvas.restore();
        }
        canvas.drawCircle(c, s * 0.2, Paint()..color = const Color(0xFFFFE08A));
      case BoardMotif.crowns:
        final p = Path()
          ..moveTo(c.dx - s, c.dy + s * 0.6)
          ..lineTo(c.dx - s, c.dy - s * 0.4)
          ..lineTo(c.dx - s * 0.5, c.dy + s * 0.05)
          ..lineTo(c.dx, c.dy - s * 0.75)
          ..lineTo(c.dx + s * 0.5, c.dy + s * 0.05)
          ..lineTo(c.dx + s, c.dy - s * 0.4)
          ..lineTo(c.dx + s, c.dy + s * 0.6)
          ..close();
        canvas.drawPath(p, paint);
      case BoardMotif.paisley:
        final p = Path()
          ..moveTo(c.dx + s * 0.2, c.dy - s)
          ..cubicTo(
            c.dx + s * 1.1,
            c.dy - s * 0.2,
            c.dx + s * 0.8,
            c.dy + s,
            c.dx - s * 0.1,
            c.dy + s * 0.8,
          )
          ..cubicTo(
            c.dx - s * 0.9,
            c.dy + s * 0.6,
            c.dx - s * 0.7,
            c.dy - s * 0.3,
            c.dx + s * 0.2,
            c.dy - s,
          )
          ..close();
        canvas.drawPath(p, paint);
        canvas.drawCircle(
          c + Offset(0, s * 0.25),
          s * 0.22,
          Paint()..color = const Color(0x66000000),
        );
    }
  }

  /// Glossy lacquer: a broad soft reflection instead of grain.
  static void _lacquer(Canvas canvas, Rect r, double u) {
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.5),
      Paint()
        ..shader = ui.Gradient.linear(
          r.topCenter,
          Offset(r.center.dx, r.top + r.height * 0.5),
          const [Color(0x40FFFFFF), Color(0x00FFFFFF)],
        ),
    );
  }

  /// Bamboo slats with nodes.
  static void _bamboo(Canvas canvas, Rect r, double u) {
    final slat = u * 0.32;
    var i = 0;
    for (var y = r.top; y < r.bottom; y += slat, i++) {
      final rect = Rect.fromLTWH(r.left, y, r.width, slat);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            const [Color(0x30FFFFFF), Color(0x00000000), Color(0x40000000)],
            const [0, 0.5, 1],
          ),
      );
      final node = Paint()
        ..strokeWidth = math.max(1, u * 0.025)
        ..color = const Color(0x55402808);
      final off = (i.isEven ? 0.0 : 0.5) * u * 1.6;
      for (var x = r.left + off + u * 0.4; x < r.right; x += u * 1.6) {
        canvas.drawLine(Offset(x, y + 1), Offset(x, y + slat - 1), node);
      }
    }
  }

  /// Metal gradient running diagonally across [r].
  static Shader metalShader(Rect r, Metal m) => ui.Gradient.linear(
    r.topLeft,
    r.bottomRight,
    [m.shine, m.base, m.light, m.dark, m.base],
    const [0, 0.25, 0.5, 0.75, 1],
  );

  /// Long, slightly wavy grain strokes, deterministic per [seed].
  static void paintGrain(Canvas canvas, Rect r, double u, {int seed = 1}) {
    var state = seed * 9301 + 49297;
    double rnd() {
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      return state / 0x7fffffff;
    }

    final spacing = math.max(3.0, u * 0.09);
    final lines = (r.height / spacing).ceil();
    for (var i = 0; i < lines; i++) {
      final y0 = r.top + i * spacing + rnd() * spacing;
      final amp = u * (0.03 + rnd() * 0.08);
      final freq = 1.5 + rnd() * 3;
      final phase = rnd() * math.pi * 2;
      final p = Path();
      const steps = 24;
      for (var k = 0; k <= steps; k++) {
        final x = r.left + r.width * k / steps;
        final y = y0 + math.sin(phase + k / steps * freq * math.pi) * amp;
        k == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
      }
      final dark = rnd() < 0.6;
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, u * (0.008 + rnd() * 0.02))
          ..color = dark
              ? Color.fromRGBO(30, 12, 2, 0.12 + rnd() * 0.16)
              : Color.fromRGBO(255, 210, 150, 0.04 + rnd() * 0.07),
      );
    }
  }
}
