import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'currency_art.dart';
import 'theme/coin_theme.dart';
import 'theme/coin_themes.dart';

/// Visual identity per coin family. Hue is never the only cue: each family
/// has its own emblem, rim pattern and letter (design.md §4, §10).
enum Glyph { star, moon, sun, crown, gem, diamond, clover, heart }

enum RimPattern { beads, notches, ticks, dots, zigzag, rings, chevrons, waves }

/// Polished-metal ramp, brightest to darkest.
final class Metal {
  const Metal(this.shine, this.light, this.base, this.dark, this.deep);

  final Color shine;
  final Color light;
  final Color base;
  final Color dark;
  final Color deep;

  static const gold = Metal(
    Color(0xFFFFF7CF),
    Color(0xFFFFDE73),
    Color(0xFFE9AE2E),
    Color(0xFFA9680C),
    Color(0xFF5A3203),
  );
  static const silver = Metal(
    Color(0xFFFFFFFF),
    Color(0xFFEFF3F7),
    Color(0xFFBAC4CE),
    Color(0xFF77838F),
    Color(0xFF39424C),
  );
  static const copper = Metal(
    Color(0xFFFFE6D2),
    Color(0xFFFAAE7C),
    Color(0xFFD7743F),
    Color(0xFF8E3A15),
    Color(0xFF4A1906),
  );
  static const patina = Metal(
    Color(0xFFD9D2C4),
    Color(0xFFA79C88),
    Color(0xFF6E6454),
    Color(0xFF423A2F),
    Color(0xFF221D16),
  );

  /// Pale yellow "Nordic gold" alloy.
  static const brass = Metal(
    Color(0xFFFFF8D6),
    Color(0xFFF3DE8C),
    Color(0xFFD0B254),
    Color(0xFF8E7424),
    Color(0xFF473908),
  );

  /// Brown, darker than copper.
  static const bronze = Metal(
    Color(0xFFFFE2C4),
    Color(0xFFDDA676),
    Color(0xFFAA6C3E),
    Color(0xFF6B3F1E),
    Color(0xFF33190A),
  );

  /// Cool, slightly blue cupro-nickel.
  static const nickel = Metal(
    Color(0xFFF6FAFF),
    Color(0xFFD6E0EE),
    Color(0xFF9DADC4),
    Color(0xFF5B6B84),
    Color(0xFF2A3446),
  );

  /// Pale, matte aluminium.
  static const aluminium = Metal(
    Color(0xFFFFFFFF),
    Color(0xFFF2F2EF),
    Color(0xFFD2D3CF),
    Color(0xFF9A9C97),
    Color(0xFF585A55),
  );

  static const roseGold = Metal(
    Color(0xFFFFEFE6),
    Color(0xFFF6C3AB),
    Color(0xFFDA8F78),
    Color(0xFF9A5342),
    Color(0xFF4D2219),
  );

  /// Deep, reddish 22-carat gold.
  static const redGold = Metal(
    Color(0xFFFFF0C4),
    Color(0xFFFFC75A),
    Color(0xFFDC8A1C),
    Color(0xFF94500A),
    Color(0xFF4A2402),
  );
}

final class FamilyStyle {
  const FamilyStyle({
    required this.base,
    required this.dark,
    required this.light,
    required this.glyph,
    required this.rim,
    required this.letter,
    this.metal,
    this.rimMetal = Metal.gold,
    this.glyphColor = const Color(0xFFFFF8EA),
  });

  /// Field colours (enamel) or the metal's mid tones (metal coins).
  final Color base;
  final Color dark;
  final Color light;
  final Glyph glyph;
  final RimPattern rim;
  final String letter;

  /// Non-null for solid-metal coins: the field is polished metal too.
  final Metal? metal;

  /// The rim and edge trim.
  final Metal rimMetal;

  /// Colour for the colour-blind letter.
  final Color glyphColor;

  bool get isMetal => metal != null;
}

abstract final class CoinArt {
  static const styles = <String, FamilyStyle>{
    'amber': FamilyStyle(
      base: Color(0xFFE9AE2E),
      dark: Color(0xFFA9680C),
      light: Color(0xFFFFDE73),
      glyph: Glyph.star,
      rim: RimPattern.dots,
      letter: 'A',
      metal: Metal.gold,
      glyphColor: Color(0xFF4A2A02),
    ),
    'pearl': FamilyStyle(
      base: Color(0xFFBAC4CE),
      dark: Color(0xFF77838F),
      light: Color(0xFFEFF3F7),
      glyph: Glyph.moon,
      rim: RimPattern.rings,
      letter: 'P',
      metal: Metal.silver,
      rimMetal: Metal.silver,
      glyphColor: Color(0xFF26303A),
    ),
    'coral': FamilyStyle(
      base: Color(0xFFD7743F),
      dark: Color(0xFF8E3A15),
      light: Color(0xFFFAAE7C),
      glyph: Glyph.sun,
      rim: RimPattern.waves,
      letter: 'C',
      metal: Metal.copper,
      rimMetal: Metal.copper,
    ),
    'onyx': FamilyStyle(
      base: Color(0xFF2A2C33),
      dark: Color(0xFF0A0B0E),
      light: Color(0xFF5E636E),
      glyph: Glyph.crown,
      rim: RimPattern.chevrons,
      letter: 'O',
    ),
    'ruby': FamilyStyle(
      base: Color(0xFFD3202E),
      dark: Color(0xFF6E0410),
      light: Color(0xFFFF7A80),
      glyph: Glyph.gem,
      rim: RimPattern.notches,
      letter: 'R',
    ),
    'sapphire': FamilyStyle(
      base: Color(0xFF2161D8),
      dark: Color(0xFF0A2672),
      light: Color(0xFF7DB4FF),
      glyph: Glyph.diamond,
      rim: RimPattern.ticks,
      letter: 'S',
    ),
    'jade': FamilyStyle(
      base: Color(0xFF1DA14B),
      dark: Color(0xFF064A1D),
      light: Color(0xFF7DEB9D),
      glyph: Glyph.clover,
      rim: RimPattern.beads,
      letter: 'J',
    ),
    'amethyst': FamilyStyle(
      base: Color(0xFF8C3FD3),
      dark: Color(0xFF3B0F6E),
      light: Color(0xFFD69CFF),
      glyph: Glyph.heart,
      rim: RimPattern.zigzag,
      letter: 'M',
    ),
  };

  static const brassBase = Color(0xFFE9AE2E);
  static const brassDark = Color(0xFFA9680C);
  static const brassLight = Color(0xFFFFDE73);
  static const ivory = Color(0xFFFFF8EA);

  /// Style of [family]; in a currency [theme], one derived from the
  /// denomination's metal (used for edges, particles and flight slices).
  static FamilyStyle style(String family, [CoinTheme? theme]) {
    final coin = theme?.coin(family);
    if (coin == null) return styles[family] ?? styles['pearl']!;
    return _currencyStyles[(theme!.id, family)] ??= () {
      final m = coin.outer;
      return FamilyStyle(
        base: m.base,
        dark: m.dark,
        light: m.light,
        glyph: Glyph.star,
        rim: RimPattern.ticks,
        letter: coin.value,
        metal: m,
        rimMetal: m,
      );
    }();
  }

  static final Map<(String, String), FamilyStyle> _currencyStyles = {};

  /// Veiled coin: aged patina with a gold question mark.
  static const veil = FamilyStyle(
    base: Color(0xFF6E6454),
    dark: Color(0xFF2A241C),
    light: Color(0xFFA79C88),
    glyph: Glyph.moon,
    rim: RimPattern.ticks,
    letter: '?',
    metal: Metal.patina,
    rimMetal: Metal.patina,
  );

  /// Paints a full coin of radius [r] centred at [c], seen face-on.
  ///
  /// Light comes from the upper-left. Built like a struck coin: a polished
  /// rim with a decorated border, a recessed field, an embossed emblem and a
  /// clear-coat gloss.
  static void paintCoin(
    Canvas canvas,
    Offset c,
    double r, {
    required String family,
    required int tier,
    String finish = 'enamel',
    bool colorBlind = false,
    bool hidden = false,
    bool shadow = true,
    CoinTheme theme = CoinThemes.atelier,
  }) {
    final coin = hidden ? null : theme.coin(family);
    if (coin != null) {
      CurrencyArt.paint(
        canvas,
        c,
        r,
        coin,
        tier: tier,
        finish: finish,
        colorBlind: colorBlind,
        shadow: shadow,
      );
      return;
    }
    final s = hidden ? veil : style(family);
    final gilded = finish == 'gilded';
    final satin = finish == 'satin';
    final rimM = gilded && !hidden ? Metal.gold : s.rimMetal;

    if (shadow) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(r * 0.04, r * 0.18),
          width: r * 2.04,
          height: r * 1.86,
        ),
        Paint()
          ..color = const Color(0x77000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
      );
      // Edge thickness peeking below the face.
      canvas.drawCircle(
        c + Offset(0, r * 0.1),
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            c + Offset(-r, 0),
            c + Offset(r, 0),
            [rimM.dark, rimM.base, rimM.deep],
            const [0, 0.35, 1],
          ),
      );
    }

    _paintRim(canvas, c, r, rimM);
    _paintRimPattern(canvas, c, r, s, rimM, strong: colorBlind);

    // Recessed lip between rim and field.
    final fieldR = r * 0.76;
    canvas.drawCircle(
      c,
      fieldR + r * 0.035,
      Paint()
        ..shader = ui.Gradient.linear(
          c + Offset(-fieldR, -fieldR),
          c + Offset(fieldR, fieldR),
          [rimM.deep, rimM.dark, rimM.shine],
          const [0, 0.5, 1],
        ),
    );

    _paintField(canvas, c, fieldR, s, satin: satin);

    if (tier >= 3 && !hidden) {
      paintLaurel(canvas, c, fieldR * 0.9, rimM);
    }

    if (hidden) {
      _paintQuestion(canvas, c, r, rimM);
    } else {
      final emblemY = tier >= 2 ? -r * 0.07 : 0.0;
      _paintEmblem(
        canvas,
        c + Offset(0, emblemY),
        r * (tier >= 2 ? 0.4 : 0.44),
        s,
      );
    }

    if (tier >= 2 && !hidden) {
      final pipY = c.dy + fieldR * 0.66;
      for (var i = 0; i < tier; i++) {
        final x = c.dx + (i - (tier - 1) / 2) * r * 0.2;
        gemPip(canvas, Offset(x, pipY), r * 0.075, rimM);
      }
    }

    if (colorBlind && !hidden) {
      final tp = TextPainter(
        text: TextSpan(
          text: s.letter,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: r * 0.34,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFFFFFF),
            shadows: [
              Shadow(color: const Color(0xFF000000), blurRadius: r * 0.06),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Lower-left of the face: the part that stays visible when stacked.
      tp.paint(
        canvas,
        Offset(c.dx - fieldR * 0.74 - tp.width / 2, c.dy + fieldR * 0.18),
      );
    }

    // Clear-coat gloss: a soft window reflection across the upper-left.
    final gloss = satin ? 0.12 : (gilded ? 0.42 : 0.32);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
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
    // Rim catch-light.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.965),
      math.pi * 1.08,
      math.pi * 0.42,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.035
        ..color = const Color(0xFFFFFFFF).withValues(alpha: gloss + 0.35),
    );
    if (gilded || tier >= 3) {
      sparkle(canvas, c + Offset(-r * 0.5, -r * 0.55), r * 0.17);
    }
    if (gilded) {
      sparkle(canvas, c + Offset(r * 0.58, r * 0.42), r * 0.1);
    }

    // Crisp outline for contrast against the board.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.03)
        ..color = rimM.deep,
    );
  }

  static void _paintRim(Canvas canvas, Offset c, double r, Metal m) {
    // Polished ring: sweep bands fake the reflections of a turned edge.
    canvas.drawCircle(
      c,
      r,
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
    // Bevel: lit outer edge top-left, shaded bottom-right.
    canvas.drawCircle(
      c,
      r * 0.97,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..shader = ui.Gradient.linear(
          c + Offset(-r, -r),
          c + Offset(r, r),
          [
            m.shine.withValues(alpha: 0.9),
            m.base.withValues(alpha: 0),
            m.deep.withValues(alpha: 0.7),
          ],
          const [0, 0.5, 1],
        ),
    );
  }

  static void _paintField(
    Canvas canvas,
    Offset c,
    double f,
    FamilyStyle s, {
    required bool satin,
  }) {
    final m = s.metal;
    final rect = Rect.fromCircle(center: c, radius: f);
    if (m != null) {
      canvas.drawCircle(
        c,
        f,
        Paint()
          ..shader = ui.Gradient.radial(
            c + Offset(-f * 0.35, -f * 0.45),
            f * 1.55,
            [m.shine, m.light, m.base, m.dark],
            const [0, 0.22, 0.6, 1],
          ),
      );
      // Fine lathe rings.
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.5, f * 0.008)
        ..color = m.dark.withValues(alpha: 0.12);
      for (var i = 1; i < 8; i++) {
        canvas.drawCircle(c, f * i / 8, ring);
      }
    } else {
      canvas.drawCircle(
        c,
        f,
        Paint()
          ..shader = ui.Gradient.radial(
            c + Offset(-f * 0.3, -f * 0.4),
            f * 1.5,
            satin
                ? [Color.lerp(s.base, s.light, 0.3)!, s.base, s.dark]
                : [s.light, s.base, Color.lerp(s.base, s.dark, 0.7)!],
            const [0, 0.5, 1],
          ),
      );
      // Guilloché: radiating fine lines under the enamel.
      final g = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.5, f * 0.01)
        ..color = s.dark.withValues(alpha: 0.22);
      for (var i = 0; i < 36; i++) {
        final a = i * math.pi / 18;
        canvas.drawLine(
          c + Offset(math.cos(a), math.sin(a)) * f * 0.25,
          c + Offset(math.cos(a), math.sin(a)) * f * 0.97,
          g,
        );
      }
    }
    // Inner shadow from the raised rim.
    canvas.drawCircle(
      c,
      f,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(f * 0.06, f * 0.08),
          f,
          const [Color(0x00000000), Color(0x00000000), Color(0x66000000)],
          const [0, 0.82, 1],
        ),
    );
    canvas.drawCircle(
      c,
      f,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, f * 0.025)
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
          const Color(0x99000000),
          const Color(0x33FFFFFF),
        ]),
    );
  }

  /// Raised emblem: cast shadow, rim light, gradient body and a top sheen.
  static void _paintEmblem(
    Canvas canvas,
    Offset c,
    double scale,
    FamilyStyle s,
  ) {
    final path = glyphFor(s.glyph)
        .transform(_affine(dx: c.dx, dy: c.dy, scale: scale));
    final b = path.getBounds();
    final gem = s.glyph == Glyph.gem || s.glyph == Glyph.diamond;
    final m = s.metal ?? Metal.gold;

    canvas.drawPath(
      path.shift(Offset(scale * 0.05, scale * 0.09)),
      Paint()
        ..color = const Color(0x88000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.05),
    );
    canvas.drawPath(
      path.shift(Offset(-scale * 0.03, -scale * 0.04)),
      Paint()..color = (gem ? s.light : m.shine).withValues(alpha: 0.9),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          b.topLeft,
          b.bottomRight,
          gem
              ? [
                  Color.lerp(s.light, const Color(0xFFFFFFFF), 0.5)!,
                  s.light,
                  s.base,
                  s.dark,
                ]
              : [m.shine, m.light, m.base, m.dark],
          const [0, 0.3, 0.65, 1],
        ),
    );
    canvas.save();
    canvas.clipPath(path);
    if (gem) _facets(canvas, s.glyph, c, scale, s);
    // Upper sheen.
    canvas.drawRect(
      Rect.fromLTRB(b.left, b.top, b.right, b.top + b.height * 0.42),
      Paint()
        ..shader = ui.Gradient.linear(
          b.topCenter,
          Offset(b.center.dx, b.top + b.height * 0.42),
          const [Color(0x66FFFFFF), Color(0x00FFFFFF)],
        ),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, scale * 0.045)
        ..strokeJoin = StrokeJoin.round
        ..color = gem ? Metal.gold.base : m.deep.withValues(alpha: 0.85),
    );
    if (gem) {
      sparkle(canvas, c + Offset(-scale * 0.3, -scale * 0.35), scale * 0.28);
    }
  }

  static void _facets(
    Canvas canvas,
    Glyph g,
    Offset c,
    double s,
    FamilyStyle st,
  ) {
    Offset p(double x, double y) => c + Offset(x * s, y * s);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, s * 0.035)
      ..color = const Color(0x99FFFFFF);
    final dark = Paint()..color = st.dark.withValues(alpha: 0.35);
    if (g == Glyph.diamond) {
      // Table, crown and pavilion facets.
      canvas.drawPath(
        Path()
          ..moveTo(p(0.0, 0.95).dx, p(0.0, 0.95).dy)
          ..lineTo(p(0.95, -0.3).dx, p(0.95, -0.3).dy)
          ..lineTo(p(0.3, -0.3).dx, p(0.3, -0.3).dy)
          ..close(),
        dark,
      );
      for (final (a, b) in [
        ((-0.95, -0.3), (0.95, -0.3)),
        ((-0.3, -0.3), (0.0, 0.95)),
        ((0.3, -0.3), (0.0, 0.95)),
        ((-0.95, -0.3), (0.0, 0.95)),
        ((-0.3, -0.3), (-0.5, -0.75)),
        ((0.3, -0.3), (0.5, -0.75)),
        ((0.0, -0.75), (-0.3, -0.3)),
        ((0.0, -0.75), (0.3, -0.3)),
      ]) {
        canvas.drawLine(p(a.$1, a.$2), p(b.$1, b.$2), line);
      }
    } else {
      // Emerald-cut ruby: table plus four bevels.
      canvas.drawPath(
        Path()
          ..moveTo(p(0.4, -0.35).dx, p(0.4, -0.35).dy)
          ..lineTo(p(0.85, 0.0).dx, p(0.85, 0.0).dy)
          ..lineTo(p(0.85, 0.3).dx, p(0.85, 0.3).dy)
          ..lineTo(p(0.4, 0.65).dx, p(0.4, 0.65).dy)
          ..close(),
        dark,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          p(-0.4, -0.35).dx,
          p(0.0, -0.35).dy,
          p(0.4, 0).dx,
          p(0.0, 0.65).dy,
        ),
        line,
      );
      for (final (a, b) in [
        ((-0.4, -0.35), (-0.6, -0.8)),
        ((0.4, -0.35), (0.6, -0.8)),
        ((-0.4, 0.65), (-0.6, 1.0)),
        ((0.4, 0.65), (0.6, 1.0)),
        ((-0.4, -0.35), (-0.85, 0.0)),
        ((0.4, -0.35), (0.85, 0.0)),
        ((-0.4, 0.65), (-0.85, 0.3)),
        ((0.4, 0.65), (0.85, 0.3)),
      ]) {
        canvas.drawLine(p(a.$1, a.$2), p(b.$1, b.$2), line);
      }
    }
  }

  static void _paintQuestion(Canvas canvas, Offset c, double r, Metal m) {
    final style = TextStyle(
      fontFamily: 'Fredoka',
      fontSize: r * 1.0,
      fontWeight: FontWeight.w700,
      foreground: Paint()
        ..shader = ui.Gradient.linear(
          c + Offset(0, -r * 0.5),
          c + Offset(0, r * 0.5),
          [Metal.gold.shine, Metal.gold.light, Metal.gold.dark],
          const [0, 0.4, 1],
        ),
      shadows: [
        Shadow(
          color: const Color(0xAA000000),
          offset: Offset(r * 0.03, r * 0.05),
          blurRadius: r * 0.03,
        ),
      ],
    );
    final tp = TextPainter(
      text: TextSpan(text: '?', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  static void paintLaurel(Canvas canvas, Offset c, double rad, Metal m) {
    final leaf = Paint()..color = m.light.withValues(alpha: 0.85);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rad * 0.015
      ..color = m.dark.withValues(alpha: 0.7);
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 6; i++) {
        final a = math.pi / 2 + side * (0.45 + i * 0.36);
        final at = c + Offset(math.cos(a), math.sin(a)) * rad;
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(a + side * 0.9);
        final o = Rect.fromCenter(
          center: Offset.zero,
          width: rad * 0.2,
          height: rad * 0.09,
        );
        canvas.drawOval(o, leaf);
        canvas.drawOval(o, edge);
        canvas.restore();
      }
    }
  }

  /// Frost seal overlay: an ice cap with crystals and a thaw counter.
  static void paintFrost(
    Canvas canvas,
    Offset c,
    double r,
    int frost, {
    double opacity = 1,
  }) {
    if (opacity <= 0) return;
    final a = opacity.clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r * 1.03,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.3, -r * 0.4),
          r * 1.4,
          [
            const Color(0xFFF4FCFF).withValues(alpha: 0.55 * a),
            const Color(0xFF9FDBFF).withValues(alpha: 0.3 * a),
            const Color(0xFF3E9BE0).withValues(alpha: 0.6 * a),
          ],
          const [0, 0.55, 1],
        ),
    );
    final crystal = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.92 * a);
    for (var i = 0; i < 6; i++) {
      final ang = i * math.pi / 3 + math.pi / 6;
      final d = Offset(math.cos(ang), math.sin(ang));
      // Crystals sit on the rim so the coin's emblem stays readable.
      canvas.drawLine(c + d * r * 0.62, c + d * r * 0.95, crystal);
      final mid = c + d * r * 0.78;
      final side = Offset(-d.dy, d.dx);
      canvas.drawLine(mid, mid + (d + side) * r * 0.09, crystal);
      canvas.drawLine(mid, mid + (d - side) * r * 0.09, crystal);
    }
    canvas.drawCircle(
      c,
      r * 1.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = const Color(0xFFDFF4FF).withValues(alpha: a),
    );
    // Counter badge, in the lower half that stays visible when stacked.
    final b = c + Offset(r * 0.62, r * 0.5);
    canvas.drawCircle(
      b,
      r * 0.34,
      Paint()
        ..shader = ui.Gradient.linear(
          b + Offset(0, -r * 0.34),
          b + Offset(0, r * 0.34),
          [
            const Color(0xFF3C9BE0).withValues(alpha: a),
            const Color(0xFF134A86).withValues(alpha: a),
          ],
        ),
    );
    canvas.drawCircle(
      b,
      r * 0.34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = const Color(0xFFE6F7FF).withValues(alpha: a),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '$frost',
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: r * 0.42,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFFFFF).withValues(alpha: a),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, b - Offset(tp.width / 2, tp.height / 2));
  }

  /// Raised border decoration, distinct per family (non-colour cue).
  static void _paintRimPattern(
    Canvas canvas,
    Offset c,
    double r,
    FamilyStyle s,
    Metal m, {
    required bool strong,
  }) {
    final hi = strong ? const Color(0xFFFFFFFF) : m.shine;
    final lo = strong ? const Color(0xFF000000) : m.deep;
    void emboss(void Function(Paint p, Offset o) draw, {double w = 0.04}) {
      final o = r * 0.012;
      draw(
        Paint()
          ..color = lo.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill
          ..strokeWidth = r * w
          ..strokeCap = StrokeCap.round,
        Offset(o, o * 1.4),
      );
      draw(
        Paint()
          ..color = hi.withValues(alpha: strong ? 0.95 : 0.85)
          ..style = PaintingStyle.fill
          ..strokeWidth = r * w
          ..strokeCap = StrokeCap.round,
        Offset.zero,
      );
    }

    Offset at(double ang, double rad) =>
        c + Offset(math.cos(ang) * rad, math.sin(ang) * rad);
    final mid = r * 0.875;
    switch (s.rim) {
      case RimPattern.beads:
        emboss((p, o) {
          for (var i = 0; i < 18; i++) {
            canvas.drawCircle(at(i * math.pi / 9, mid) + o, r * 0.04, p);
          }
        });
      case RimPattern.notches:
        emboss((p, o) {
          for (var i = 0; i < 24; i++) {
            canvas.drawLine(
              at(i * math.pi / 12, r * 0.82) + o,
              at(i * math.pi / 12, r * 0.93) + o,
              p,
            );
          }
        });
      case RimPattern.ticks:
        emboss((p, o) {
          for (var i = 0; i < 40; i++) {
            canvas.drawLine(
              at(i * math.pi / 20, r * 0.84) + o,
              at(i * math.pi / 20, r * 0.92) + o,
              p,
            );
          }
        }, w: 0.022);
      case RimPattern.dots:
        // Little stars, like a minted border.
        emboss((p, o) {
          for (var i = 0; i < 12; i++) {
            canvas.drawPath(_star(at(i * math.pi / 6, mid) + o, r * 0.055), p);
          }
        });
      case RimPattern.zigzag:
        emboss((p, o) {
          final path = Path();
          for (var i = 0; i <= 32; i++) {
            final pt = at(i * math.pi / 16, i.isEven ? r * 0.82 : r * 0.93) + o;
            i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path, p..style = PaintingStyle.stroke);
        }, w: 0.028);
      case RimPattern.rings:
        emboss((p, o) {
          p.style = PaintingStyle.stroke;
          canvas.drawCircle(c + o, r * 0.83, p);
          canvas.drawCircle(c + o, r * 0.92, p);
        }, w: 0.022);
      case RimPattern.chevrons:
        emboss((p, o) {
          p.style = PaintingStyle.stroke;
          for (var i = 0; i < 14; i++) {
            final a = i * math.pi / 7;
            final q1 = at(a - 0.11, r * 0.93) + o;
            final q2 = at(a, r * 0.82) + o;
            final q3 = at(a + 0.11, r * 0.93) + o;
            canvas.drawPath(
              Path()
                ..moveTo(q1.dx, q1.dy)
                ..lineTo(q2.dx, q2.dy)
                ..lineTo(q3.dx, q3.dy),
              p,
            );
          }
        }, w: 0.028);
      case RimPattern.waves:
        emboss((p, o) {
          final path = Path();
          for (var i = 0; i <= 140; i++) {
            final a = i * math.pi * 2 / 140;
            final pt = at(a, mid + math.sin(a * 14) * r * 0.045) + o;
            i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path, p..style = PaintingStyle.stroke);
        }, w: 0.026);
    }
  }

  static Path _star(Offset c, double s, {int points = 5}) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final a = -math.pi / 2 + i * math.pi / points;
      final rad = i.isEven ? s : s * 0.45;
      final pt = c + Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  static void gemPip(Canvas canvas, Offset c, double s, Metal m) {
    final p = Path()
      ..moveTo(c.dx, c.dy - s * 1.3)
      ..lineTo(c.dx + s, c.dy)
      ..lineTo(c.dx, c.dy + s * 1.3)
      ..lineTo(c.dx - s, c.dy)
      ..close();
    canvas.drawPath(
      p.shift(Offset(s * 0.15, s * 0.25)),
      Paint()..color = const Color(0x77000000),
    );
    canvas.drawPath(
      p,
      Paint()
        ..shader = ui.Gradient.linear(
          c + Offset(-s, -s),
          c + Offset(s, s),
          [m.shine, m.base, m.dark],
          const [0, 0.5, 1],
        ),
    );
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.3
        ..color = m.deep,
    );
  }

  static void sparkle(Canvas canvas, Offset c, double s) {
    final p = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawCircle(
      c,
      s * 0.5,
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.3),
    );
    canvas.drawPath(p, Paint()..color = const Color(0xF2FFFFFF));
  }

  static final Map<Glyph, Path> _glyphCache = {};

  /// Emblem outline in unit space (roughly -1..1 on both axes).
  static Path glyphFor(Glyph g) => _glyphCache[g] ??= _buildGlyph(g);

  static Path _buildGlyph(Glyph g) {
    switch (g) {
      case Glyph.star:
        return _star(const Offset(0.0, 0.08), 1.0);
      case Glyph.moon:
        return Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.9)),
          Path()..addOval(
            Rect.fromCircle(center: const Offset(0.42, -0.3), radius: 0.74),
          ),
        );
      case Glyph.sun:
        var p = Path()
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.46));
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          final len = i.isEven ? 1.0 : 0.8;
          final ray = Path()
            ..moveTo(math.cos(a - 0.16) * 0.56, math.sin(a - 0.16) * 0.56)
            ..lineTo(math.cos(a) * len, math.sin(a) * len)
            ..lineTo(math.cos(a + 0.16) * 0.56, math.sin(a + 0.16) * 0.56)
            ..close();
          p = Path.combine(PathOperation.union, p, ray);
        }
        return p;
      case Glyph.crown:
        final body = Path()
          ..moveTo(-0.95, -0.45)
          ..lineTo(-0.55, 0.05)
          ..lineTo(-0.3, -0.7)
          ..lineTo(0.0, -0.05)
          ..lineTo(0.3, -0.7)
          ..lineTo(0.55, 0.05)
          ..lineTo(0.95, -0.45)
          ..lineTo(0.75, 0.42)
          ..lineTo(-0.75, 0.42)
          ..close();
        final band = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTRB(-0.78, 0.5, 0.78, 0.78),
              const Radius.circular(0.08),
            ),
          );
        var p = Path.combine(PathOperation.union, body, band);
        for (final o in const [
          Offset(-0.95, -0.55),
          Offset(-0.3, -0.82),
          Offset(0.3, -0.82),
          Offset(0.95, -0.55),
          Offset(0.0, -0.2),
        ]) {
          p = Path.combine(
            PathOperation.union,
            p,
            Path()..addOval(Rect.fromCircle(center: o, radius: 0.13)),
          );
        }
        return p;
      case Glyph.gem:
        return Path()
          ..moveTo(-0.6, -0.8)
          ..lineTo(0.6, -0.8)
          ..lineTo(0.85, 0.0)
          ..lineTo(0.85, 0.3)
          ..lineTo(0.6, 1.0)
          ..lineTo(-0.6, 1.0)
          ..lineTo(-0.85, 0.3)
          ..lineTo(-0.85, 0.0)
          ..close();
      case Glyph.diamond:
        return Path()
          ..moveTo(-0.5, -0.75)
          ..lineTo(0.5, -0.75)
          ..lineTo(0.95, -0.3)
          ..lineTo(0.0, 0.95)
          ..lineTo(-0.95, -0.3)
          ..close();
      case Glyph.clover:
        var p = Path();
        for (final o in const [
          Offset(0.0, -0.45),
          Offset(0.45, 0),
          Offset(-0.45, 0),
        ]) {
          p = Path.combine(
            PathOperation.union,
            p,
            Path()..addOval(Rect.fromCircle(center: o, radius: 0.42)),
          );
        }
        final stem = Path()
          ..moveTo(-0.07, 0.2)
          ..quadraticBezierTo(0.0, 0.7, 0.3, 1.0)
          ..lineTo(0.18, 1.05)
          ..quadraticBezierTo(-0.15, 0.75, -0.19, 0.2)
          ..close();
        return Path.combine(
          PathOperation.union,
          p,
          stem,
        ).transform(_affine(dy: -0.05));
      case Glyph.heart:
        return Path()
          ..moveTo(0.0, 0.95)
          ..cubicTo(-0.55, 0.55, -1.0, 0.15, -0.95, -0.3)
          ..cubicTo(-0.9, -0.8, -0.25, -0.95, 0, -0.45)
          ..cubicTo(0.25, -0.95, 0.9, -0.8, 0.95, -0.3)
          ..cubicTo(1.0, 0.15, 0.55, 0.55, 0, 0.95)
          ..close();
    }
  }

  /// Column-major 4x4 affine: rotate, then scale, then translate.
  static Float64List _affine({
    double dx = 0,
    double dy = 0,
    double scale = 1,
    double rotation = 0,
  }) {
    final c = math.cos(rotation) * scale;
    final s = math.sin(rotation) * scale;
    return Float64List.fromList([
      c,
      s,
      0,
      0,
      -s,
      c,
      0,
      0,
      0,
      0,
      1,
      0,
      dx,
      dy,
      0,
      1,
    ]);
  }
}
