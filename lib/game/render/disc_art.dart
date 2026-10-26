import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'coin_art.dart';
import 'currency_art.dart';
import 'theme/coin_theme.dart';
import 'theme/coin_themes.dart';

/// Thick-disc coin seen from ~55° above: an elliptical enamel face on top of a
/// textured edge band. Stacked discs show only the top face plus each lower
/// coin's band, so the edge texture carries identity (design spec v2 §2.2).
abstract final class DiscArt {
  /// Face ellipse height relative to diameter (perspective squash).
  static const double faceRatio = 0.56;

  /// Visible band thickness per coin relative to diameter.
  static const double thicknessRatio = 0.17;

  static double faceHeight(double d) => d * faceRatio;
  static double thickness(double d) => d * thicknessRatio;

  /// Paints one disc whose face ellipse is centred at [c].
  static void paint(
    Canvas canvas,
    Offset c,
    double d, {
    required String family,
    required int tier,
    String finish = 'enamel',
    bool colorBlind = false,
    bool hidden = false,
    int frost = 0,
    double whiten = 0,
    CoinTheme theme = CoinThemes.atelier,
  }) {
    final coin = hidden ? null : theme.coin(family);
    if (coin != null) {
      _paintCurrency(
        canvas,
        c,
        d,
        coin,
        tier: tier,
        finish: finish,
        colorBlind: colorBlind,
        frost: frost,
      );
      return;
    }
    final r = d / 2;
    final fh = faceHeight(d);
    final t = thickness(d);
    final s = hidden ? CoinArt.veil : CoinArt.style(family);
    final trim = finish == 'gilded' && !hidden ? Metal.gold : s.rimMetal;
    final m = s.metal;

    // Edge band: from the face's horizontal diameter down by t, closed by
    // the lower half of the ellipse.
    final faceRect = Rect.fromCenter(center: c, width: d, height: fh);
    final band = Path()
      ..moveTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r, c.dy + t)
      ..arcTo(faceRect.shift(Offset(0, t)), math.pi, -math.pi, false)
      ..lineTo(c.dx + r, c.dy)
      ..arcTo(faceRect, 0, math.pi, false)
      ..close();
    // Cylinder shading: a hot reflection left of centre, falling off to the
    // sides. Metal coins show their metal; enamel coins their colour.
    final (deep, dark, base, light, shine) = m != null
        ? (m.deep, m.dark, m.base, m.light, m.shine)
        : (
            _mix(s.dark, const Color(0xFF000000), 0.4),
            s.dark,
            s.base,
            s.light,
            _mix(s.light, const Color(0xFFFFFFFF), 0.35),
          );
    canvas.drawPath(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r, 0),
          Offset(c.dx + r, 0),
          [deep, dark, light, shine, base, dark, deep],
          const [0, 0.1, 0.3, 0.38, 0.6, 0.86, 1],
        ),
    );
    canvas.save();
    canvas.clipPath(band);
    _edgeTexture(canvas, c, d, fh, t, s, trim, hidden: hidden);
    // Underside shade.
    canvas.drawPath(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, c.dy),
          Offset(0, c.dy + t + fh / 2),
          const [Color(0x00000000), Color(0x00000000), Color(0x66000000)],
          const [0, 0.55, 1],
        ),
    );
    canvas.restore();
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, d * 0.016)
        ..color = _mix(deep, const Color(0xFF000000), 0.5),
    );

    // Face: the flat coin art squashed into the ellipse.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, faceRatio);
    CoinArt.paintCoin(
      canvas,
      Offset.zero,
      r,
      family: family,
      tier: tier,
      finish: finish,
      colorBlind: colorBlind,
      hidden: hidden,
      shadow: false,
    );
    if (frost > 0) CoinArt.paintFrost(canvas, Offset.zero, r, frost);
    canvas.restore();

    if (frost > 0) {
      canvas.save();
      canvas.clipPath(band);
      canvas.drawPath(band, Paint()..color = const Color(0x99D6F1FF));
      final crack = Paint()
        ..strokeWidth = 1.2
        ..color = const Color(0xDDFFFFFF);
      for (var i = 0; i < 5; i++) {
        final x = c.dx - r * 0.8 + i * r * 0.4;
        canvas.drawLine(
          Offset(x, c.dy + t * 0.2),
          Offset(x + r * 0.12, c.dy + t * 0.9 + fh * 0.2),
          crack,
        );
      }
      canvas.restore();
    }

    if (whiten > 0) {
      final w = Paint()
        ..color = Color.fromRGBO(255, 255, 255, whiten.clamp(0, 1) * 0.85);
      canvas.drawPath(band, w);
      canvas.drawOval(faceRect, w);
    }
  }

  /// Contact shadow under a stack base.
  static void paintShadow(Canvas canvas, Offset c, double d) {
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(0, thickness(d) * 0.9),
        width: d * 1.08,
        height: faceHeight(d) * 1.05,
      ),
      Paint()
        ..color = const Color(0x77000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d * 0.06),
    );
  }

  /// Edge decoration. Metal coins are reeded; enamel coins carry the
  /// casino-chip look: metal trim at both edges plus family-specific inlays
  /// so lower coins stay identifiable without relying on colour.
  static void _edgeTexture(
    Canvas canvas,
    Offset c,
    double d,
    double fh,
    double t,
    FamilyStyle s,
    Metal trim, {
    required bool hidden,
  }) {
    final r = d / 2;
    // Front-of-band points by angle, so spacing foreshortens at the sides.
    Offset front(double theta, double f) {
      final x = c.dx + r * math.cos(theta);
      return Offset(x, c.dy + fh / 2 * math.sin(theta) + t * f);
    }

    double shade(double theta) => 0.35 + 0.65 * math.sin(theta);

    final m = s.metal;
    if (m != null || hidden) {
      final metal = m ?? trim;
      const n = 30;
      for (var i = 1; i < n; i++) {
        final th = math.pi * i / n;
        final k = shade(th);
        canvas.drawLine(
          front(th, 0.14),
          front(th, 0.86),
          Paint()
            ..strokeWidth = math.max(0.8, d * 0.012)
            ..color = (i.isEven ? metal.deep : metal.shine).withValues(
              alpha: (i.isEven ? 0.45 : 0.55) * k,
            ),
        );
      }
      return;
    }

    // Metal trim lines at the top and bottom of the band.
    for (final f in const [0.1, 0.9]) {
      final p = Path();
      for (var i = 0; i <= 32; i++) {
        final pt = front(math.pi * i / 32, f);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, t * 0.16)
          ..shader = ui.Gradient.linear(
            Offset(c.dx - r, 0),
            Offset(c.dx + r, 0),
            [trim.dark, trim.shine, trim.base, trim.dark],
            const [0, 0.32, 0.62, 1],
          ),
      );
    }

    // Inlays around the band, foreshortened towards the sides.
    final inlay = Paint()
      ..shader = ui.Gradient.linear(
        Offset(c.dx - r, 0),
        Offset(c.dx + r, 0),
        [trim.dark, trim.light, trim.shine, trim.base, trim.dark],
        const [0, 0.25, 0.36, 0.6, 1],
      );
    final light = Paint()..color = s.light.withValues(alpha: 0.9);
    switch (s.rim) {
      case RimPattern.notches || RimPattern.ticks || RimPattern.chevrons:
        // Rectangular chip inserts (wide, thin, or arrow-tipped).
        final n = switch (s.rim) {
          RimPattern.notches => 6,
          RimPattern.ticks => 10,
          _ => 7,
        };
        final w = switch (s.rim) {
          RimPattern.notches => 0.16,
          RimPattern.ticks => 0.05,
          _ => 0.11,
        };
        for (var i = 0; i < n; i++) {
          final th = math.pi * (i + 0.5) / n;
          final a = front(th - w / 2, 0.24);
          final b = front(th + w / 2, 0.76);
          final rect = Rect.fromPoints(a, b);
          if (s.rim == RimPattern.chevrons) {
            canvas.drawPath(
              Path()
                ..moveTo(rect.left, rect.top)
                ..lineTo(rect.center.dx, rect.center.dy)
                ..lineTo(rect.left, rect.bottom)
                ..lineTo(rect.right, rect.bottom)
                ..lineTo(rect.right, rect.top)
                ..close(),
              inlay,
            );
          } else {
            canvas.drawRect(rect, inlay);
          }
        }
      case RimPattern.beads || RimPattern.dots:
        final n = s.rim == RimPattern.beads ? 10 : 7;
        for (var i = 0; i < n; i++) {
          final th = math.pi * (i + 0.5) / n;
          final p = front(th, 0.5);
          final k = math.sin(th);
          canvas.drawOval(
            Rect.fromCenter(
              center: p,
              width: t * (s.rim == RimPattern.beads ? 0.42 : 0.6) * k,
              height: t * (s.rim == RimPattern.beads ? 0.42 : 0.6),
            ),
            inlay,
          );
        }
      case RimPattern.zigzag || RimPattern.waves:
        final p = Path();
        const n = 48;
        for (var i = 0; i <= n; i++) {
          final th = math.pi * i / n;
          final f = s.rim == RimPattern.zigzag
              ? (i % 4 < 2 ? 0.28 : 0.72)
              : 0.5 + 0.22 * math.sin(i * 0.9);
          final pt = front(th, f);
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, t * 0.16)
            ..shader = inlay.shader,
        );
      case RimPattern.rings:
        final p = Path();
        for (var i = 0; i <= 32; i++) {
          final pt = front(math.pi * i / 32, 0.5);
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(
          p,
          light
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, t * 0.18),
        );
    }
  }

  /// A currency coin: the band follows the coin's shape, shows the
  /// denomination's edge finish and carries its value stamped on the front,
  /// so coins low in a stack stay identifiable.
  static void _paintCurrency(
    Canvas canvas,
    Offset c,
    double d,
    CurrencyCoin coin, {
    required int tier,
    required String finish,
    required bool colorBlind,
    required int frost,
  }) {
    final r = d / 2;
    final fh = faceHeight(d);
    final t = thickness(d);
    final m = coin.outer;

    // Front of the edge: the lower half of the outline, then the same
    // points dropped by the thickness, walked back.
    Offset front(double theta, double f) {
      final k = CurrencyArt.rho(coin.shape, theta);
      return Offset(
        c.dx + r * k * math.cos(theta),
        c.dy + fh / 2 * k * math.sin(theta) + t * f,
      );
    }

    const n = 48;
    final band = Path()..moveTo(front(0, 0).dx, front(0, 0).dy);
    for (var i = 0; i <= n; i++) {
      final p = front(math.pi * i / n, 1);
      band.lineTo(p.dx, p.dy);
    }
    for (var i = n; i >= 0; i--) {
      final p = front(math.pi * i / n, 0);
      band.lineTo(p.dx, p.dy);
    }
    band.close();
    canvas.drawPath(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r, 0),
          Offset(c.dx + r, 0),
          [m.deep, m.dark, m.light, m.shine, m.base, m.dark, m.deep],
          const [0, 0.1, 0.3, 0.38, 0.6, 0.86, 1],
        ),
    );

    canvas.save();
    canvas.clipPath(band);
    double shade(double theta) => 0.35 + 0.65 * math.sin(theta);
    final line = Paint()..strokeWidth = math.max(0.8, d * 0.012);
    void reeds(bool Function(int i) keep) {
      const k = 34;
      for (var i = 1; i < k; i++) {
        if (!keep(i)) continue;
        final th = math.pi * i / k;
        line.color = (i.isEven ? m.deep : m.shine).withValues(
          alpha: (i.isEven ? 0.45 : 0.55) * shade(th),
        );
        canvas.drawLine(front(th, 0.14), front(th, 0.86), line);
      }
    }

    Path rail(double f) {
      final p = Path();
      for (var i = 0; i <= 32; i++) {
        final pt = front(math.pi * i / 32, f);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p;
    }

    switch (coin.edge) {
      case EdgeStyle.reeded:
        reeds((_) => true);
      case EdgeStyle.interrupted:
        reeds((i) => (i ~/ 4).isEven);
      case EdgeStyle.smooth:
        break;
      case EdgeStyle.grooved:
        canvas.drawPath(
          rail(0.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, t * 0.2)
            ..color = m.deep.withValues(alpha: 0.6),
        );
        canvas.drawPath(
          rail(0.62),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.6, t * 0.08)
            ..color = m.shine.withValues(alpha: 0.6),
        );
      case EdgeStyle.lettered:
        // Incuse inscription marks.
        final mark = Paint()..color = m.deep.withValues(alpha: 0.5);
        for (var i = 1; i < 18; i++) {
          final th = math.pi * i / 18;
          final p = front(th, 0.5);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: p,
                width: t * 0.5 * math.sin(th),
                height: t * 0.32,
              ),
              Radius.circular(t * 0.08),
            ),
            mark,
          );
        }
    }
    final tint = coin.enamel;
    if (tint != null) {
      // Coloured enamel stripe round the edge: stacked coins show their
      // family colour even when only the edge is visible.
      final stripe = Path()..addPath(rail(0.32), Offset.zero);
      for (var i = 32; i >= 0; i--) {
        final pt = front(math.pi * i / 32, 0.68);
        stripe.lineTo(pt.dx, pt.dy);
      }
      stripe.close();
      canvas.drawPath(
        stripe,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(c.dx - r, 0),
            Offset(c.dx + r, 0),
            [
              _mix(tint, const Color(0xFF000000), 0.45),
              _mix(tint, const Color(0xFFFFFFFF), 0.25),
              tint,
              _mix(tint, const Color(0xFF000000), 0.5),
            ],
            const [0, 0.32, 0.6, 1],
          ),
      );
    }
    if (coin.shape != CoinShape.round) {
      // Crisp creases where the flat sides meet.
      final sides = coin.shape == CoinShape.dodecagon ? 12 : 7;
      final start = coin.shape == CoinShape.dodecagon
          ? -math.pi / 2 + math.pi / 12
          : -math.pi / 2;
      if (coin.shape != CoinShape.notched) {
        for (var i = 0; i < sides; i++) {
          final th = (start + i * math.pi * 2 / sides) % (math.pi * 2);
          if (th <= 0.05 || th >= math.pi - 0.05) continue;
          canvas.drawLine(
            front(th, 0),
            front(th, 1),
            Paint()
              ..strokeWidth = math.max(0.8, d * 0.01)
              ..color = m.shine.withValues(alpha: 0.5 * shade(th)),
          );
        }
      }
    }
    _stamp(
      canvas,
      front(math.pi / 2, 0.5),
      t,
      d,
      coin.value,
      m,
      strong: colorBlind,
      tint: tint,
    );
    canvas.drawPath(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, c.dy),
          Offset(0, c.dy + t + fh / 2),
          const [Color(0x00000000), Color(0x00000000), Color(0x55000000)],
          const [0, 0.55, 1],
        ),
    );
    canvas.restore();
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, d * 0.016)
        ..color = _mix(m.deep, const Color(0xFF000000), 0.5),
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, faceRatio);
    CurrencyArt.paint(
      canvas,
      Offset.zero,
      r,
      coin,
      tier: tier,
      finish: finish,
      colorBlind: colorBlind,
      shadow: false,
    );
    if (frost > 0) CoinArt.paintFrost(canvas, Offset.zero, r, frost);
    canvas.restore();

    if (coin.hole && frost == 0) {
      // The far inner wall of the hole; the rest stays see-through.
      final h = Rect.fromCenter(
        center: c,
        width: r * 0.4,
        height: r * 0.4 * faceRatio,
      );
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addOval(h),
          Path()..addOval(h.shift(Offset(0, t))),
        ),
        Paint()
          ..shader = ui.Gradient.linear(h.topCenter, h.center, [
            coin.metal.deep,
            coin.metal.dark,
          ]),
      );
    }
  }

  /// The value stamped on a plate at the front of the edge band.
  static void _stamp(
    Canvas canvas,
    Offset at,
    double t,
    double d,
    String value,
    Metal m, {
    required bool strong,
    Color? tint,
  }) {
    final size = t * 0.78;
    TextPainter tp(Color color, double s) => TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontFamilyFallback: const ['Nunito', 'Roboto', 'sans-serif'],
          fontSize: s,
          height: 1,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var s = size;
    var text = tp(m.deep, s);
    final maxW = d * 0.42;
    if (text.width > maxW) {
      s *= maxW / text.width;
      text = tp(m.deep, s);
    }
    final plate = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: text.width + t * 0.7, height: t * 0.8),
      Radius.circular(t * 0.2),
    );
    // Ivory plate on the coloured stripe; metal plate on bare metal.
    final plateColors = tint != null
        ? const [Color(0xFFFFFFFF), Color(0xFFFFF8EA), Color(0xFFE9DFC8)]
        : [m.shine, m.light, m.base];
    canvas.drawRRect(
      plate,
      Paint()
        ..shader = ui.Gradient.linear(
          plate.outerRect.topCenter,
          plate.outerRect.bottomCenter,
          plateColors,
          const [0, 0.5, 1],
        ),
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, t * 0.06)
        ..color = tint != null
            ? _mix(tint, const Color(0xFF000000), 0.35)
            : m.dark.withValues(alpha: 0.8),
    );
    final o = at - Offset(text.width / 2, text.height / 2);
    final ink = strong
        ? const Color(0xFF000000)
        : (tint != null ? _mix(tint, const Color(0xFF000000), 0.55) : m.deep);
    tp(ink, s).paint(canvas, o);
  }

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
}
