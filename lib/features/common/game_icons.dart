import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Glyphs of the painted game icon set (game UI redesign §2).
enum GameGlyph {
  play,
  home,
  map,
  shop,
  cabinet,
  cities,
  gift,
  settings,
  hint,
  undo,
  extraTray,
  restart,
  pause,
  lock,
  check,
  close,
  star,
  video,
  noAds,
  sound,
  music,
  vibrate,
  back,
  motion,
  eye,
  language,
  privacy,
  help,
}

/// Glossy, outlined, two-tone icon drawn in code so it stays crisp at any
/// size and matches the coin art. [mono] paints a flat silhouette instead
/// (for disabled states and small inline use).
class GameIcon extends StatelessWidget {
  const GameIcon(this.glyph, {super.key, this.size = 32, this.mono});

  final GameGlyph glyph;
  final double size;
  final Color? mono;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _GlyphPainter(glyph, mono)),
  );
}

const _ink = Color(0xFF2A1407);

// Colour ramps, light → dark.
const _green = [Color(0xFF9BF06A), Color(0xFF39B53A), Color(0xFF1E7A25)];
const _gold = [Color(0xFFFFF0A0), Color(0xFFF5BE2E), Color(0xFFB4760C)];
const _red = [Color(0xFFFF9A8A), Color(0xFFE5483D), Color(0xFF9E2620)];
const _blue = [Color(0xFF9EE2FF), Color(0xFF3A9BE8), Color(0xFF1E5EA8)];
const _wood = [Color(0xFFD08A4A), Color(0xFF94531F), Color(0xFF5E300F)];
const _cream = [Color(0xFFFFFBEF), Color(0xFFF4E2BC), Color(0xFFD9BC86)];
const _steel = [Color(0xFFE8F0F8), Color(0xFFA5B4C6), Color(0xFF66768A)];
const _purple = [Color(0xFFE2B5FF), Color(0xFF9C5BE0), Color(0xFF5E2A9C)];

final class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.mono);

  final GameGlyph glyph;
  final Color? mono;

  late Canvas _c;

  /// Fills [p] with a vertical ramp over an ink outline, then a gloss band.
  void _part(Path p, List<Color> ramp, {bool gloss = true, double line = 7}) {
    final b = p.getBounds();
    if (mono != null) {
      _c.drawPath(p, Paint()..color = mono!);
      return;
    }
    _c
      ..drawPath(
        p,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = line
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: ramp,
            stops: const [0, 0.55, 1],
          ).createShader(b),
      );
    if (!gloss) return;
    _c
      ..save()
      ..clipPath(p)
      ..drawOval(
        Rect.fromLTRB(
          b.left - b.width * 0.1,
          b.top - b.height * 0.55,
          b.right + b.width * 0.1,
          b.top + b.height * 0.42,
        ),
        Paint()..color = const Color(0x55FFFFFF),
      )
      ..restore();
  }

  void _line(
    List<Offset> pts, {
    Color color = const Color(0xFFFFFFFF),
    double w = 7,
    bool outline = true,
  }) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    Paint paint(Color c, double width) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (outline && mono == null) _c.drawPath(path, paint(_ink, w + 7));
    _c.drawPath(path, paint(mono ?? color, w));
  }

  Path _rr(double l, double t, double r, double b, double rad) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

  Path _circle(double x, double y, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

  Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

  Path _star(double cx, double cy, double r, double inner) {
    final pts = <Offset>[];
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * inner;
      pts.add(Offset(cx + rr * math.cos(a), cy + rr * math.sin(a)));
    }
    return _poly(pts);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    canvas
      ..save()
      ..scale(size.width / 100, size.height / 100);
    switch (glyph) {
      case GameGlyph.play:
        _part(
          Path()
            ..moveTo(32, 18)
            ..quadraticBezierTo(26, 15, 26, 22)
            ..lineTo(26, 78)
            ..quadraticBezierTo(26, 85, 32, 82)
            ..lineTo(80, 55)
            ..quadraticBezierTo(85, 50, 80, 45)
            ..close(),
          _green,
        );
      case GameGlyph.home:
        _part(_rr(22, 44, 78, 88, 6), _cream);
        _part(
          Path()
            ..moveTo(50, 10)
            ..lineTo(92, 48)
            ..quadraticBezierTo(94, 54, 88, 54)
            ..lineTo(12, 54)
            ..quadraticBezierTo(6, 54, 8, 48)
            ..close(),
          _red,
        );
        _part(_rr(42, 62, 58, 88, 4), _wood, gloss: false);
      case GameGlyph.map:
        _part(
          _poly(const [
            Offset(8, 22),
            Offset(36, 12),
            Offset(64, 22),
            Offset(92, 12),
            Offset(92, 78),
            Offset(64, 88),
            Offset(36, 78),
            Offset(8, 88),
          ]),
          _cream,
        );
        if (mono == null) {
          final fold = Paint()
            ..color = const Color(0x33000000)
            ..strokeWidth = 3;
          canvas
            ..drawLine(const Offset(36, 12), const Offset(36, 78), fold)
            ..drawLine(const Offset(64, 22), const Offset(64, 88), fold);
          final dash = Paint()
            ..color = const Color(0xFFD8463C)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round;
          for (final (a, b) in const [
            (Offset(18, 70), Offset(26, 62)),
            (Offset(34, 56), Offset(44, 54)),
            (Offset(52, 52), Offset(60, 46)),
          ]) {
            canvas.drawLine(a, b, dash);
          }
          _line(const [Offset(66, 30), Offset(80, 44)], color: _red[1], w: 6);
          _line(const [Offset(80, 30), Offset(66, 44)], color: _red[1], w: 6);
        }
      case GameGlyph.shop:
        // Treasure chest.
        _part(_rr(10, 46, 90, 88, 8), _wood);
        _part(
          Path()
            ..moveTo(10, 50)
            ..lineTo(10, 38)
            ..quadraticBezierTo(10, 14, 50, 14)
            ..quadraticBezierTo(90, 14, 90, 38)
            ..lineTo(90, 50)
            ..close(),
          _wood,
        );
        _part(_rr(10, 44, 90, 54, 3), _gold, gloss: false, line: 5);
        _part(_rr(42, 40, 58, 66, 4), _gold, line: 5);
        if (mono == null) {
          canvas.drawCircle(const Offset(50, 54), 3.5, Paint()..color = _ink);
        }
      case GameGlyph.cabinet:
        // Trophy.
        _part(_rr(30, 78, 70, 90, 4), _wood, gloss: false);
        _part(_rr(42, 62, 58, 80, 2), _gold, gloss: false);
        _part(
          Path()
            ..moveTo(24, 12)
            ..lineTo(76, 12)
            ..lineTo(74, 40)
            ..quadraticBezierTo(70, 66, 50, 66)
            ..quadraticBezierTo(30, 66, 26, 40)
            ..close(),
          _gold,
        );
        for (final s in const [-1.0, 1.0]) {
          _line(
            [
              Offset(50 + s * 26, 20),
              Offset(50 + s * 40, 22),
              Offset(50 + s * 36, 40),
              Offset(50 + s * 24, 46),
            ],
            color: _gold[1],
            w: 6,
          );
        }
        if (mono == null) {
          _part(_star(50, 36, 12, 0.45), _cream, gloss: false, line: 4);
        }
      case GameGlyph.cities:
        _part(_circle(46, 54, 36), _blue);
        if (mono == null) {
          canvas
            ..save()
            ..clipPath(_circle(46, 54, 36));
          _part(
            Path()
              ..moveTo(20, 40)
              ..quadraticBezierTo(34, 26, 44, 38)
              ..quadraticBezierTo(50, 48, 40, 56)
              ..quadraticBezierTo(28, 66, 18, 56)
              ..close(),
            _green,
            gloss: false,
            line: 4,
          );
          _part(
            Path()
              ..moveTo(54, 66)
              ..quadraticBezierTo(70, 58, 78, 72)
              ..quadraticBezierTo(70, 90, 56, 84)
              ..close(),
            _green,
            gloss: false,
            line: 4,
          );
          canvas.restore();
        }
        // Map pin.
        _part(
          Path()
            ..moveTo(74, 52)
            ..quadraticBezierTo(58, 32, 58, 24)
            ..arcToPoint(
              const Offset(90, 24),
              radius: const Radius.circular(16),
            )
            ..quadraticBezierTo(90, 32, 74, 52)
            ..close(),
          _red,
        );
        if (mono == null) {
          canvas.drawCircle(
            const Offset(74, 24),
            5.5,
            Paint()..color = const Color(0xFFFFFFFF),
          );
        }
      case GameGlyph.gift:
        _part(_rr(14, 44, 86, 90, 6), _red);
        _part(_rr(8, 32, 92, 48, 5), _red);
        _part(_rr(43, 32, 57, 90, 2), _gold, gloss: false, line: 5);
        for (final s in const [-1.0, 1.0]) {
          _part(
            Path()
              ..moveTo(50, 30)
              ..quadraticBezierTo(50 + s * 30, 2, 50 + s * 34, 22)
              ..quadraticBezierTo(50 + s * 32, 32, 50, 30)
              ..close(),
            _gold,
            line: 5,
          );
        }
      case GameGlyph.settings:
        final gear = Path();
        const teeth = 8;
        for (var i = 0; i < teeth * 2; i++) {
          final a0 = i * math.pi / teeth - math.pi / teeth / 2;
          final r = i.isEven ? 42.0 : 32.0;
          final a1 = a0 + math.pi / teeth;
          final p0 = Offset(50 + r * math.cos(a0), 50 + r * math.sin(a0));
          final p1 = Offset(50 + r * math.cos(a1), 50 + r * math.sin(a1));
          if (i == 0) gear.moveTo(p0.dx, p0.dy);
          gear
            ..lineTo(p0.dx, p0.dy)
            ..lineTo(p1.dx, p1.dy);
        }
        gear.close();
        _part(
          Path.combine(PathOperation.difference, gear, _circle(50, 50, 13)),
          _steel,
        );
      case GameGlyph.hint:
        _part(_rr(37, 70, 63, 90, 5), _steel, gloss: false);
        _part(
          Path.combine(
            PathOperation.union,
            _circle(50, 40, 30),
            _poly(const [
              Offset(30, 56),
              Offset(70, 56),
              Offset(64, 74),
              Offset(36, 74),
            ]),
          ),
          _gold,
        );
        if (mono == null) {
          _line(
            const [Offset(43, 80), Offset(57, 80)],
            color: const Color(0x66000000),
            w: 3,
            outline: false,
          );
          _line(const [Offset(36, 34), Offset(42, 24)], w: 5, outline: false);
        }
      case GameGlyph.undo:
        _arrowArc(_blue, ccw: true);
      case GameGlyph.restart:
        _arrowArc(const [
          Color(0xFFFFD08A),
          Color(0xFFF08A2A),
          Color(0xFFA9540E),
        ], ccw: false);
      case GameGlyph.extraTray:
        _part(_rr(10, 34, 70, 90, 10), _wood);
        if (mono == null) {
          canvas.drawRRect(
            RRect.fromLTRBR(20, 44, 60, 82, const Radius.circular(6)),
            Paint()..color = const Color(0x66000000),
          );
        }
        _part(_circle(70, 32, 22), _green);
        _line(const [Offset(70, 21), Offset(70, 43)], w: 8, outline: false);
        _line(const [Offset(59, 32), Offset(81, 32)], w: 8, outline: false);
      case GameGlyph.pause:
        _part(_rr(26, 18, 44, 82, 6), _cream);
        _part(_rr(56, 18, 74, 82, 6), _cream);
      case GameGlyph.lock:
        _line(
          const [
            Offset(32, 48),
            Offset(32, 34),
            Offset(68, 34),
            Offset(68, 48),
          ],
          color: _steel[1],
          w: 9,
        );
        if (mono == null) {
          canvas.drawArc(
            const Rect.fromLTRB(32, 14, 68, 52),
            math.pi,
            math.pi,
            false,
            Paint()
              ..color = _steel[1]
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9,
          );
        }
        _part(_rr(20, 44, 80, 90, 10), _gold);
        if (mono == null) {
          canvas
            ..drawCircle(const Offset(50, 62), 6, Paint()..color = _ink)
            ..drawRect(
              const Rect.fromLTWH(47, 62, 6, 14),
              Paint()..color = _ink,
            );
        }
      case GameGlyph.check:
        _line(
          const [Offset(18, 52), Offset(40, 74), Offset(82, 26)],
          color: _green[1],
          w: 15,
        );
      case GameGlyph.close:
        _line(const [Offset(24, 24), Offset(76, 76)], w: 14);
        _line(const [Offset(76, 24), Offset(24, 76)], w: 14);
      case GameGlyph.star:
        _part(_star(50, 54, 44, 0.48), _gold);
      case GameGlyph.video:
        _part(_rr(8, 20, 92, 80, 12), _blue);
        _part(
          _poly(const [Offset(40, 34), Offset(66, 50), Offset(40, 66)]),
          _cream,
          gloss: false,
          line: 5,
        );
      case GameGlyph.noAds:
        _part(_circle(50, 50, 42), _cream);
        if (mono == null) _text('AD', const Offset(50, 50), 28, _ink);
        _line(
          const [Offset(22, 22), Offset(78, 78)],
          color: _red[1],
          w: 10,
          outline: false,
        );
        if (mono == null) {
          canvas.drawCircle(
            const Offset(50, 50),
            40,
            Paint()
              ..color = _red[1]
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9,
          );
        }
      case GameGlyph.sound:
        _speaker();
        for (final r in const [16.0, 28.0]) {
          _arc(60, 50, r, w: 6);
        }
      case GameGlyph.music:
        _line(
          const [
            Offset(42, 72),
            Offset(42, 20),
            Offset(78, 12),
            Offset(78, 62),
          ],
          color: _purple[1],
          w: 7,
        );
        _part(_circle(32, 74, 13), _purple);
        _part(_circle(68, 66, 13), _purple);
      case GameGlyph.vibrate:
        _part(_rr(32, 12, 68, 88, 9), _steel);
        if (mono == null) {
          canvas.drawRRect(
            RRect.fromLTRBR(38, 20, 62, 74, const Radius.circular(3)),
            Paint()..color = const Color(0xFF2B4A6E),
          );
        }
        for (final s in const [-1.0, 1.0]) {
          _line(
            [
              Offset(50 + s * 30, 32),
              Offset(50 + s * 38, 42),
              Offset(50 + s * 30, 52),
              Offset(50 + s * 38, 62),
            ],
            color: _gold[1],
            w: 5,
          );
        }
      case GameGlyph.back:
        _line(const [Offset(60, 18), Offset(28, 50), Offset(60, 82)], w: 15);
      case GameGlyph.motion:
        _part(_circle(50, 50, 36), _blue);
        _line(const [Offset(50, 30), Offset(50, 52), Offset(64, 62)], w: 7);
      case GameGlyph.eye:
        _part(
          Path()
            ..moveTo(8, 50)
            ..quadraticBezierTo(50, 4, 92, 50)
            ..quadraticBezierTo(50, 96, 8, 50)
            ..close(),
          _cream,
        );
        _part(_circle(50, 50, 16), _blue);
        if (mono == null) {
          canvas.drawCircle(const Offset(50, 50), 6, Paint()..color = _ink);
        }
      case GameGlyph.language:
        _part(_rr(8, 16, 70, 66, 12), _blue);
        _part(_rr(34, 38, 92, 84, 12), _green);
        if (mono == null) {
          _text('A', const Offset(28, 37), 26, const Color(0xFFFFFFFF));
          // Speech dots instead of a second script: no font has every
          // language's glyphs, and a missing glyph draws as a box.
          for (final x in const [50.0, 63.0, 76.0]) {
            canvas.drawCircle(
              Offset(x, 62),
              4.5,
              Paint()..color = const Color(0xFFFFFFFF),
            );
          }
        }
      case GameGlyph.privacy:
        _part(
          Path()
            ..moveTo(50, 8)
            ..lineTo(86, 22)
            ..quadraticBezierTo(86, 74, 50, 92)
            ..quadraticBezierTo(14, 74, 14, 22)
            ..close(),
          _blue,
        );
        _line(const [Offset(34, 50), Offset(46, 62), Offset(68, 38)], w: 8);
      case GameGlyph.help:
        _part(_circle(50, 50, 42), _gold);
        if (mono == null) {
          _text(
            '?',
            const Offset(50, 50),
            58,
            const Color(0xFFFFFFFF),
            shadow: true,
          );
        }
    }
    canvas.restore();
  }

  /// Fredoka text centred on [at]. Only ASCII is used here: Fredoka has no
  /// other scripts, and a missing glyph would paint as a box.
  void _text(
    String text,
    Offset at,
    double size,
    Color color, {
    bool shadow = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontWeight: FontWeight.w700,
          fontSize: size,
          color: color,
          shadows: shadow
              ? const [Shadow(color: _ink, offset: Offset(0, 3))]
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(_c, at - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  void _arc(double cx, double cy, double r, {double w = 6}) {
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    if (mono == null) {
      _c.drawArc(
        rect,
        -0.9,
        1.8,
        false,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = w + 6
          ..strokeCap = StrokeCap.round,
      );
    }
    _c.drawArc(
      rect,
      -0.9,
      1.8,
      false,
      Paint()
        ..color = mono ?? const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
  }

  void _speaker() => _part(
    _poly(const [
      Offset(10, 38),
      Offset(28, 38),
      Offset(50, 18),
      Offset(50, 82),
      Offset(28, 62),
      Offset(10, 62),
    ]),
    _gold,
  );

  /// Thick circular arrow with a head; undo turns left, restart turns right.
  void _arrowArc(List<Color> ramp, {required bool ccw}) {
    final c = _c;
    if (!ccw) {
      c
        ..save()
        ..translate(100, 0)
        ..scale(-1, 1);
    }
    final body = Path()
      ..addArc(
        const Rect.fromLTRB(22, 22, 86, 86),
        math.pi * 1.05,
        math.pi * 1.45,
      );
    final band = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (mono == null) {
      c.drawPath(
        body,
        band
          ..color = _ink
          ..strokeWidth = 24,
      );
    }
    c.drawPath(
      body,
      band
        ..color = mono ?? ramp[1]
        ..strokeWidth = 16,
    );
    _part(
      _poly(const [Offset(4, 50), Offset(26, 24), Offset(42, 56)]),
      ramp,
      gloss: false,
      line: 6,
    );
    if (!ccw) c.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.mono != mono;
}
