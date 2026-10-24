import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'coin_art.dart';
import 'theme/coin_theme.dart';
import 'theme/emblems.dart';

/// Struck currency coins: polished rim, raised legend, a large readable
/// value and the theme's emblem. Every shape is a radial function
/// [rho] so the face, its outline and the edge band agree exactly.
abstract final class CurrencyArt {
  /// Distance from the centre to the edge at angle [theta], as a fraction
  /// of the radius (1 = on the circle). Angles follow the canvas: 0 is
  /// right, pi/2 is down.
  static double rho(CoinShape shape, double theta) {
    switch (shape) {
      case CoinShape.round:
        return 1;
      case CoinShape.dodecagon:
        return _polygon(12, theta, -math.pi / 2 + math.pi / 12);
      case CoinShape.heptagon:
        // Curved sides: halfway between a flat heptagon and the circle.
        return 0.45 + 0.55 * _polygon(7, theta, -math.pi / 2);
      case CoinShape.notched:
        // Seven shallow scallops cut into the rim.
        var r = 1.0;
        for (var i = 0; i < 7; i++) {
          final a = -math.pi / 2 + math.pi / 7 + i * math.pi * 2 / 7;
          var dist = (theta - a) % (math.pi * 2);
          if (dist > math.pi) dist -= math.pi * 2;
          r = math.min(r, 1 - 0.07 * math.exp(-dist * dist / 0.006));
        }
        return r;
    }
  }

  /// Regular polygon with a vertex at [start], normalised so its vertices
  /// touch the unit circle.
  static double _polygon(int n, double theta, double start) {
    final seg = math.pi * 2 / n;
    final a = ((theta - start) % seg) - seg / 2;
    return math.cos(seg / 2) / math.cos(a);
  }

  static final Map<(CoinShape, int), Float64List> _outlines = {};

  /// Unit outline as interleaved x,y pairs, [n] samples, starting at angle 0.
  static Float64List unitOutline(CoinShape shape, {int n = 96}) =>
      _outlines[(shape, n)] ??= () {
        final out = Float64List(n * 2);
        for (var i = 0; i < n; i++) {
          final a = i * math.pi * 2 / n;
          final k = rho(shape, a);
          out[i * 2] = math.cos(a) * k;
          out[i * 2 + 1] = math.sin(a) * k;
        }
        return out;
      }();

  /// Face outline centred at [c] with radii [rx] by [ry].
  static Path outline(CoinShape shape, Offset c, double rx, [double? ry]) {
    ry ??= rx;
    if (shape == CoinShape.round) {
      return Path()
        ..addOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2));
    }
    final u = unitOutline(shape);
    final p = Path()..moveTo(c.dx + u[0] * rx, c.dy + u[1] * ry);
    for (var i = 2; i < u.length; i += 2) {
      p.lineTo(c.dx + u[i] * rx, c.dy + u[i + 1] * ry);
    }
    return p..close();
  }

  /// Paints [coin] face-on, radius [r], centred at [c]. Light comes from
  /// the upper-left, as for the atelier coins.
  static void paint(
    Canvas canvas,
    Offset c,
    double r,
    CurrencyCoin coin, {
    required int tier,
    String finish = 'enamel',
    bool colorBlind = false,
    bool shadow = true,
  }) {
    final gilded = finish == 'gilded';
    final satin = finish == 'satin';
    final outer = coin.outer;
    final shape = outline(coin.shape, c, r);
    // The hole is cleared, so isolate it from whatever is underneath.
    if (coin.hole) {
      canvas.saveLayer(Rect.fromCircle(center: c, radius: r * 1.3), Paint());
    }

    if (shadow) {
      canvas.drawPath(
        outline(coin.shape, c + Offset(r * 0.04, r * 0.18), r * 1.02, r * 0.93),
        Paint()
          ..color = const Color(0x77000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
      );
      canvas.drawPath(
        outline(coin.shape, c + Offset(0, r * 0.1), r),
        Paint()
          ..shader = ui.Gradient.linear(
            c + Offset(-r, 0),
            c + Offset(r, 0),
            [outer.dark, outer.base, outer.deep],
            const [0, 0.35, 1],
          ),
      );
    }

    canvas.save();
    canvas.clipPath(shape);
    _rim(canvas, c, r, outer);
    canvas.restore();

    // Raised border just inside the edge.
    final lip = outline(coin.shape, c, r * 0.9);
    canvas.drawPath(
      lip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..shader = ui.Gradient.linear(
          c + Offset(-r, -r),
          c + Offset(r, r),
          [outer.deep, outer.dark, outer.shine],
          const [0, 0.5, 1],
        ),
    );

    final bimetal = coin.ring != null;
    final fieldR = bimetal ? r * 0.6 : r * 0.88;
    if (bimetal) {
      // Ring field, then the core with a dark seam between the metals.
      _field(canvas, c, r * 0.885, coin.ring!, coin.shape, satin: satin);
      canvas.drawCircle(
        c,
        fieldR + r * 0.03,
        Paint()
          ..shader = ui.Gradient.linear(
            c + Offset(-fieldR, -fieldR),
            c + Offset(fieldR, fieldR),
            [outer.deep, outer.dark, outer.shine],
            const [0, 0.5, 1],
          ),
      );
      _field(canvas, c, fieldR, coin.metal, CoinShape.round, satin: satin);
    } else {
      _field(canvas, c, fieldR, coin.metal, coin.shape, satin: satin);
    }

    final enamel = coin.enamel;
    if (enamel != null) {
      final e = r * 0.5;
      canvas.drawCircle(c, e + r * 0.03, Paint()..color = coin.metal.dark);
      canvas.drawCircle(
        c,
        e,
        Paint()
          ..shader = ui.Gradient.radial(
            c + Offset(-e * 0.3, -e * 0.4),
            e * 1.4,
            [
              Color.lerp(enamel, const Color(0xFFFFFFFF), 0.35)!,
              enamel,
              Color.lerp(enamel, const Color(0xFF000000), 0.45)!,
            ],
            const [0, 0.5, 1],
          ),
      );
    }

    // Text around the rim: on the ring for bimetal coins, else inside the
    // field's edge.
    if (coin.legend.isNotEmpty) {
      _arcText(
        canvas,
        c,
        bimetal ? r * 0.745 : r * 0.7,
        coin.legend,
        r * (bimetal ? 0.12 : 0.115),
        bimetal ? coin.ring! : coin.metal,
      );
    }

    final m = coin.metal;
    final emblemMetal = enamel != null ? Metal.silver : m;
    if (coin.hole) {
      _hole(canvas, c, r * 0.2, m);
      _value(
        canvas,
        c + Offset(0, -r * 0.42),
        coin.value,
        r * 0.3,
        m,
        strong: colorBlind,
      );
      if (coin.emblem != Emblem.none) {
        _emblem(canvas, c + Offset(0, r * 0.42), r * 0.17, coin.emblem, m);
      }
    } else {
      final hasEmblem = coin.emblem != Emblem.none;
      final size = r * _valueScale(coin.value) * (hasEmblem ? 0.82 : 1);
      if (hasEmblem) {
        _emblem(
          canvas,
          c + Offset(0, -r * (bimetal ? 0.3 : 0.36)),
          r * (bimetal ? 0.2 : 0.24),
          coin.emblem,
          emblemMetal,
        );
      }
      final vy = hasEmblem ? r * 0.12 : -r * 0.04;
      _value(
        canvas,
        c + Offset(0, vy),
        coin.value,
        size,
        emblemMetal,
        strong: colorBlind,
      );
      if (coin.unit.isNotEmpty) {
        _label(
          canvas,
          c + Offset(0, vy + size * 0.58 + r * 0.06),
          coin.unit,
          r * (bimetal ? 0.085 : 0.1),
          emblemMetal,
          maxWidth: (bimetal ? fieldR : r * 0.7) * 1.6,
        );
      }
    }

    if (tier >= 3) CoinArt.paintLaurel(canvas, c, r * 0.8, outer);
    if (tier >= 2) {
      final pipY = c.dy + r * 0.76;
      for (var i = 0; i < tier; i++) {
        final x = c.dx + (i - (tier - 1) / 2) * r * 0.2;
        CoinArt.gemPip(canvas, Offset(x, pipY), r * 0.07, Metal.gold);
      }
    }

    // Gloss.
    final gloss = satin ? 0.12 : (gilded ? 0.42 : 0.3);
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.32, -r * 0.42),
        width: r * 1.5,
        height: r * 0.9,
      ),
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.32, -r * 0.42),
          r * 0.75,
          [
            const Color(0xFFFFFFFF).withValues(alpha: gloss),
            const Color(0x00FFFFFF),
          ],
        ),
    );
    canvas.restore();
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.955),
      math.pi * 1.08,
      math.pi * 0.42,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.035
        ..color = const Color(0xFFFFFFFF).withValues(alpha: gloss + 0.3),
    );
    if (gilded || tier >= 3) {
      CoinArt.sparkle(canvas, c + Offset(-r * 0.5, -r * 0.55), r * 0.17);
    }
    if (gilded) {
      CoinArt.sparkle(canvas, c + Offset(r * 0.58, r * 0.42), r * 0.1);
    }
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.03)
        ..color = gilded ? Metal.gold.deep : outer.deep,
    );
    if (coin.hole) canvas.restore();
  }

  /// Font size of the value relative to the radius, by digit count.
  static double _valueScale(String v) => switch (v.length) {
    <= 1 => 0.78,
    2 => 0.66,
    3 => 0.5,
    4 => 0.4,
    _ => 0.33,
  };

  static void _rim(Canvas canvas, Offset c, double r, Metal m) {
    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..shader = ui.Gradient.sweep(
          c,
          [
            m.base,
            m.dark,
            m.base,
            m.shine,
            m.light,
            m.base,
            m.dark,
            m.light,
            m.base,
          ],
          const [0, 0.14, 0.3, 0.48, 0.56, 0.7, 0.82, 0.92, 1],
        ),
    );
  }

  static void _field(
    Canvas canvas,
    Offset c,
    double f,
    Metal m,
    CoinShape shape, {
    required bool satin,
  }) {
    final path = outline(shape, c, f);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-f * 0.35, -f * 0.45),
          f * 1.55,
          satin
              ? [m.light, m.base, m.dark, m.deep]
              : [m.shine, m.light, m.base, m.dark],
          const [0, 0.22, 0.62, 1],
        ),
    );
    // Lathe rings, then the inner shadow cast by the raised rim.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, f * 0.007)
      ..color = m.dark.withValues(alpha: 0.12);
    for (var i = 2; i < 8; i++) {
      canvas.drawCircle(c, f * i / 8, ring);
    }
    canvas.save();
    canvas.clipPath(path);
    canvas.drawCircle(
      c,
      f,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(f * 0.06, f * 0.08),
          f,
          const [Color(0x00000000), Color(0x00000000), Color(0x55000000)],
          const [0, 0.8, 1],
        ),
    );
    canvas.restore();
  }

  /// Centre hole: a dark well with its far inner wall lit.
  static void _hole(Canvas canvas, Offset c, double h, Metal m) {
    canvas.drawCircle(
      c,
      h + h * 0.18,
      Paint()
        ..shader = ui.Gradient.linear(
          c + Offset(-h, -h),
          c + Offset(h, h),
          [m.deep, m.dark, m.shine],
          const [0, 0.5, 1],
        ),
    );
    canvas.drawCircle(c, h, Paint()..blendMode = BlendMode.clear);
  }

  static void _emblem(
    Canvas canvas,
    Offset c,
    double scale,
    Emblem e,
    Metal m,
  ) {
    final path = Emblems.path(e).transform(_affine(c.dx, c.dy, scale));
    final b = path.getBounds();
    canvas.drawPath(
      path.shift(Offset(scale * 0.06, scale * 0.1)),
      Paint()
        ..color = m.deep.withValues(alpha: 0.75)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.05),
    );
    canvas.drawPath(
      path.shift(Offset(-scale * 0.035, -scale * 0.045)),
      Paint()..color = m.shine.withValues(alpha: 0.9),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          b.topLeft,
          b.bottomRight,
          [m.shine, m.light, m.base, m.dark],
          const [0, 0.3, 0.65, 1],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, scale * 0.04)
        ..strokeJoin = StrokeJoin.round
        ..color = m.deep.withValues(alpha: 0.8),
    );
  }

  /// Raised value: dark cast shadow, lit upper edge, metal body.
  static void _value(
    Canvas canvas,
    Offset c,
    String text,
    double size,
    Metal m, {
    required bool strong,
  }) {
    TextPainter tp(Paint fg) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontFamilyFallback: const ['Nunito', 'Roboto', 'sans-serif'],
          fontSize: size,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: -size * 0.03,
          foreground: fg,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final body = tp(
      Paint()
        ..shader = ui.Gradient.linear(
          c + Offset(0, -size * 0.45),
          c + Offset(0, size * 0.45),
          [m.shine, m.light, m.base, m.dark],
          const [0, 0.35, 0.7, 1],
        ),
    );
    final at = c - Offset(body.width / 2, body.height / 2);
    tp(Paint()..color = m.deep.withValues(alpha: 0.85))
        .paint(canvas, at + Offset(size * 0.03, size * 0.055));
    tp(Paint()..color = m.shine.withValues(alpha: 0.9))
        .paint(canvas, at - Offset(size * 0.02, size * 0.03));
    body.paint(canvas, at);
    tp(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, size * (strong ? 0.07 : 0.035))
        ..color = strong
            ? const Color(0xFF000000)
            : m.deep.withValues(alpha: 0.7),
    ).paint(canvas, at);
  }

  /// Small engraved caption, squeezed to [maxWidth].
  static void _label(
    Canvas canvas,
    Offset c,
    String text,
    double size,
    Metal m, {
    required double maxWidth,
  }) {
    TextPainter tp(Color color, double s) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: s,
          height: 1,
          fontWeight: FontWeight.w600,
          letterSpacing: s * 0.08,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var s = size;
    var probe = tp(m.deep, s);
    if (probe.width > maxWidth) {
      s *= maxWidth / probe.width;
      probe = tp(m.deep, s);
    }
    final at = c - Offset(probe.width / 2, probe.height / 2);
    tp(
      m.shine.withValues(alpha: 0.8),
      s,
    ).paint(canvas, at + Offset(0, s * 0.06));
    tp(m.deep.withValues(alpha: 0.85), s).paint(canvas, at);
  }

  /// [text] centred on the top of a circle of radius [rad], letters upright
  /// relative to the rim, debossed into the metal.
  static void _arcText(
    Canvas canvas,
    Offset c,
    double rad,
    String text,
    double size,
    Metal m,
  ) {
    final style = TextStyle(
      fontFamily: 'Fredoka',
      fontSize: size,
      height: 1,
      fontWeight: FontWeight.w600,
    );
    final glyphs = [
      for (final ch in text.split(''))
        TextPainter(
          text: TextSpan(text: ch, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final gap = size * 0.14;
    final total =
        glyphs.fold<double>(0, (s, g) => s + g.width) +
        gap * (glyphs.length - 1);
    // Keep the legend inside the upper ~150°.
    final span = math.min(total / rad, math.pi * 0.85);
    final squeeze = span < total / rad ? span * rad / total : 1.0;
    var a = -math.pi / 2 - span / 2;
    for (final g in glyphs) {
      final w = (g.width + gap) * squeeze;
      final mid = a + (g.width * squeeze / 2) / rad;
      canvas.save();
      canvas.translate(c.dx + math.cos(mid) * rad, c.dy + math.sin(mid) * rad);
      canvas.rotate(mid + math.pi / 2);
      canvas.scale(squeeze, 1);
      final o = Offset(-g.width / 2, -g.height / 2);
      for (final (color, dy) in [
        (m.shine.withValues(alpha: 0.75), size * 0.06),
        (m.deep.withValues(alpha: 0.8), 0.0),
      ]) {
        (TextPainter(
          text: TextSpan(
            text: (g.text! as TextSpan).text,
            style: style.copyWith(color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout()).paint(canvas, o + Offset(0, dy));
      }
      canvas.restore();
      a += w / rad;
    }
  }

  static Float64List _affine(double dx, double dy, double s) =>
      Float64List.fromList([s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1]);
}
