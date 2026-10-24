import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'coin_theme.dart';

/// Filled silhouettes for currency-coin emblems, in unit space: the shape
/// fits inside -1..1 on both axes, centred on the origin, y pointing down.
/// Internal detail is cut out of the fill so it survives at small sizes.
abstract final class Emblems {
  static final Map<Emblem, Path> _cache = {};

  static Path path(Emblem e) => _cache[e] ??= _build(e);

  static Path _build(Emblem e) => switch (e) {
    Emblem.none => Path(),
    Emblem.spire => _spire(),
    Emblem.bridge => _bridge(),
    Emblem.sakura => _sakura(),
    Emblem.pagoda => _pagoda(),
    Emblem.riceEar => _riceEar(),
    Emblem.paulownia => _paulownia(),
    Emblem.sapling => _sapling(),
    Emblem.phoenix => _phoenix(),
    Emblem.portcullis => _portcullis(),
    Emblem.shield => _shield(),
    Emblem.rose => _rose(),
    Emblem.crown => _crown(),
    Emblem.thistle => _thistle(),
    Emblem.profile => _profile(),
    Emblem.torch => _torch(),
    Emblem.eagle => _eagle(),
    Emblem.dome => _dome(),
    Emblem.lotus => _lotus(),
    Emblem.wheat => _wheat(),
    Emblem.chakra => _chakra(),
    Emblem.peacock => _peacock(),
    Emblem.elephant => _elephant(),
    Emblem.rhino => _rhino(),
    Emblem.hornbill => _hornbill(),
    Emblem.orchid => _orchid(),
    Emblem.teaLeaf => _teaLeaf(),
    Emblem.hills => _hills(),
  };

  // ---- Europe ----

  /// Cathedral front: tall central spire between two spired towers.
  static Path _spire() {
    final body = _u([
      _poly([-0.26, -0.3, 0, -0.98, 0.26, -0.3]),
      _r(-0.22, -0.32, 0.22, 0.9),
      _sym(_poly([0.42, -0.04, 0.6, -0.62, 0.78, -0.04])),
      _sym(_r(0.45, -0.06, 0.75, 0.9)),
      _r(-0.8, 0.28, 0.8, 0.9),
    ]);
    return _d(body, [
      _garch(-0.13, 0.13, 1, 0.62, 0.36),
      _o(0, 0.02, 0.11),
      _sym(_garch(0.53, 0.67, 0.58, 0.3, 0.12)),
      _sym(_garch(0.28, 0.38, 0.75, 0.55, 0.42)),
      _r(-0.04, -0.62, 0.04, -0.42, 0.04),
    ]);
  }

  /// Three-arched stone bridge over a ripple of water.
  static Path _bridge() {
    final deck = Path()
      ..moveTo(-0.95, -0.12)
      ..quadraticBezierTo(0, -0.5, 0.95, -0.12)
      ..lineTo(0.95, 0.45)
      ..lineTo(-0.95, 0.45)
      ..close();
    final body = _d(
      _u([
        deck,
        _sym(_r(0.66, -0.42, 0.76, -0.14, 0.03)),
        _sym(_o(0.71, -0.45, 0.07)),
      ]),
      [
        _arch(-0.3, 0.3, 0.5, 0.16, 0.28),
        _sym(_arch(0.47, 0.82, 0.5, 0.3, 0.15)),
        // parapet line
        _tube(
          const Offset(-0.85, -0.03),
          const Offset(-0.3, -0.25),
          const Offset(0.3, -0.25),
          const Offset(0.85, -0.03),
          0.05,
          0.05,
        ),
      ],
    );
    final wave = Path()..moveTo(-0.85, 0.66);
    for (var i = 0; i < 4; i++) {
      final x = -0.85 + i * 0.425;
      wave.cubicTo(x + 0.1, 0.56, x + 0.32, 0.56, x + 0.425, 0.66);
    }
    for (var i = 3; i >= 0; i--) {
      final x = -0.85 + i * 0.425;
      wave.cubicTo(x + 0.32, 0.7, x + 0.1, 0.7, x, 0.8);
    }
    wave.close();
    return _u([body, wave]);
  }

  // ---- Japan ----

  /// Five notched cherry-blossom petals around a stamen dot.
  static Path _sakura() {
    final petal = Path()
      ..moveTo(0, -0.1)
      ..cubicTo(-0.4, -0.3, -0.44, -0.8, -0.17, -0.95)
      ..lineTo(0, -0.8)
      ..lineTo(0.17, -0.95)
      ..cubicTo(0.44, -0.8, 0.4, -0.3, 0, -0.1)
      ..close();
    final petals = _u([
      for (var i = 0; i < 5; i++) _tf(petal, rot: i * 2 * math.pi / 5),
    ]);
    final flower = _u([
      _d(petals, [
        _o(0, 0, 0.17),
        for (var i = 0; i < 5; i++)
          _tf(
            _line(const Offset(0, -0.2), const Offset(0, -0.5), 0.05, 0),
            rot: i * 2 * math.pi / 5,
          ),
      ]),
      _o(0, 0, 0.1),
    ]);
    return _tf(flower, at: const Offset(0, 0.09));
  }

  /// Three-tier pagoda with upturned eaves and a ringed finial.
  static Path _pagoda() {
    const ys = [-0.4, 0.02, 0.44];
    const ws = [0.56, 0.74, 0.92];
    const bw = [0.3, 0.4, 0.5];
    final parts = <Path>[
      _r(-0.035, -0.9, 0.035, -0.5),
      for (final y in [-0.62, -0.72, -0.82]) _e(-0.1, y - 0.03, 0.1, y + 0.03),
      _o(0, -0.92, 0.055),
      _r(-0.72, 0.8, 0.72, 0.92, 0.03),
    ];
    final cuts = <Path>[];
    for (var i = 0; i < 3; i++) {
      final y = ys[i], w = ws[i];
      parts.add(
        Path()
          ..moveTo(-w, y - 0.12)
          ..quadraticBezierTo(-w * 0.75, y + 0.05, -w * 0.45, y + 0.05)
          ..lineTo(w * 0.45, y + 0.05)
          ..quadraticBezierTo(w * 0.75, y + 0.05, w, y - 0.12)
          ..quadraticBezierTo(w * 0.6, y - 0.08, w * 0.3, y - 0.2)
          ..lineTo(-w * 0.3, y - 0.2)
          ..quadraticBezierTo(-w * 0.6, y - 0.08, -w, y - 0.12)
          ..close(),
      );
      final bottom = i < 2 ? ys[i + 1] - 0.15 : 0.82;
      parts.add(_r(-bw[i], y, bw[i], bottom));
      cuts.add(
        i < 2
            ? _r(-0.08, y + 0.1, 0.08, bottom - 0.03, 0.03)
            : _garch(-0.11, 0.11, bottom - 0.02, y + 0.2, y + 0.1),
      );
    }
    return _d(_u(parts), cuts);
  }

  /// Drooping ear of rice on a stalk, with one long leaf.
  static Path _riceEar() {
    const d0 = Offset(0.02, -0.8),
        d1 = Offset(0.48, -1.02),
        d2 = Offset(0.84, -0.5),
        d3 = Offset(0.64, 0.12);
    final parts = <Path>[
      _tube(
        const Offset(-0.15, 0.95),
        const Offset(-0.2, 0.1),
        const Offset(-0.25, -0.7),
        d0,
        0.12,
        0.08,
      ),
      _tube(d0, d1, d2, d3, 0.08, 0.03),
      _tube(
        const Offset(-0.17, 0.55),
        const Offset(-0.45, 0.35),
        const Offset(-0.75, 0.0),
        const Offset(-0.82, -0.45),
        0.1,
        0,
        0.16,
      ),
    ];
    for (var k = 0; k < 8; k++) {
      final t = 0.08 + k * 0.12;
      final p = _bez(d0, d1, d2, d3, t);
      final g = _dir(d0, d1, d2, d3, t);
      final n = Offset(-g.dy, g.dx);
      final a = math.atan2(g.dy, g.dx);
      final s = 1 - t * 0.3;
      for (final side in [-1.0, 1.0]) {
        parts.add(
          _tf(
            _e(-0.16 * s, -0.09 * s, 0.16 * s, 0.09 * s),
            rot: a - side * 0.5,
            at: p + n * side * 0.1 * s,
          ),
        );
      }
    }
    parts.add(
      _tf(
        _e(-0.13, -0.07, 0.13, 0.07),
        rot: math.atan2(_dir(d0, d1, d2, d3, 1).dy, _dir(d0, d1, d2, d3, 1).dx),
        at: d3 + _dir(d0, d1, d2, d3, 1) * 0.06,
      ),
    );
    return _u(parts);
  }

  /// Paulownia crest: three leaves below three blossom spikes.
  static Path _paulownia() {
    final leaf = _d(
      Path()
        ..moveTo(0, 0)
        ..cubicTo(-0.34, -0.05, -0.4, 0.3, 0, 0.58)
        ..cubicTo(0.4, 0.3, 0.34, -0.05, 0, 0)
        ..close(),
      [_line(const Offset(0, 0.08), const Offset(0, 0.48), 0.045, 0)],
    );
    final leaves = _layer(
      _u([
        _tf(leaf, rot: 1.25, at: const Offset(-0.06, 0.28)),
        _tf(leaf, rot: -1.25, at: const Offset(0.06, 0.28)),
      ]),
      _tf(leaf, s: 1.12, at: const Offset(0, 0.26)),
    );
    final spikes = <Path>[
      _line(const Offset(0, 0.3), const Offset(0, -0.8), 0.07, 0.05),
      for (var j = 0; j < 5; j++)
        _o(j.isEven ? -0.09 : 0.09, -0.1 - j * 0.15, 0.1),
      _o(0, -0.86, 0.09),
    ];
    for (final sx in [-1.0, 1.0]) {
      spikes.add(
        _tube(
          Offset(sx * 0.05, 0.3),
          Offset(sx * 0.4, 0.2),
          Offset(sx * 0.55, 0.0),
          Offset(sx * 0.55, -0.6),
          0.06,
          0.045,
        ),
      );
      for (var j = 0; j < 4; j++) {
        spikes.add(
          _o(sx * 0.55 + (j.isEven ? -0.08 : 0.08), -0.02 - j * 0.15, 0.09),
        );
      }
      spikes.add(_o(sx * 0.55, -0.66, 0.08));
    }
    return _u([
      _d(_u(spikes), [_grow(leaves)]),
      leaves,
    ]);
  }

  /// Young sprout: two leaves on a short stem above a mound of soil.
  static Path _sapling() {
    return _u([
      Path()
        ..moveTo(-0.72, 0.92)
        ..quadraticBezierTo(0, 0.5, 0.72, 0.92)
        ..close(),
      _tube(
        const Offset(0, 0.8),
        const Offset(0.04, 0.4),
        const Offset(-0.04, 0.1),
        const Offset(0, -0.15),
        0.12,
        0.08,
      ),
      _veinedLeaf(
        const Offset(-0.02, -0.08),
        const Offset(-0.9, -0.5),
        0.3,
        bend: 0.08,
      ),
      _veinedLeaf(
        const Offset(0.02, -0.14),
        const Offset(0.72, -0.9),
        0.28,
        bend: -0.08,
      ),
    ]);
  }

  /// Phoenix in flight facing left: crested head, raised wing, long plumes.
  static Path _phoenix() {
    final wing = _u([
      for (final (tip, w) in [
        (const Offset(0.28, -0.95), 0.2),
        (const Offset(0.56, -0.92), 0.21),
        (const Offset(0.8, -0.74), 0.2),
        (const Offset(0.94, -0.48), 0.18),
      ])
        _leaf(const Offset(-0.1, 0.0), tip, w),
      _tf(_e(-0.34, -0.2, 0.34, 0.2), rot: -0.8, at: const Offset(0.12, -0.24)),
    ]);
    final body = _u([
      _o(-0.55, -0.6, 0.14),
      _poly([-0.64, -0.67, -0.92, -0.56, -0.64, -0.52]),
      _tube(
        const Offset(-0.52, -0.52),
        const Offset(-0.45, -0.3),
        const Offset(-0.35, -0.12),
        const Offset(-0.12, -0.02),
        0.18,
        0.3,
      ),
      _tf(_e(-0.3, -0.18, 0.3, 0.18), rot: -0.3, at: const Offset(-0.05, 0.05)),
      for (final (a, b, w) in [
        (const Offset(-0.32, -0.95), const Offset(-0.38, -0.82), 0.07),
        (const Offset(-0.16, -0.92), const Offset(-0.3, -0.76), 0.07),
        (const Offset(-0.08, -0.78), const Offset(-0.25, -0.68), 0.06),
      ])
        _tube(const Offset(-0.5, -0.66), b, b, a, w + 0.03, 0.02),
    ]);
    final tail = _u([
      _tube(
        const Offset(0.0, 0.15),
        const Offset(0.45, 0.2),
        const Offset(0.95, 0.15),
        const Offset(0.88, 0.5),
        0.18,
        0.06,
      ),
      _ring(0.8, 0.53, 0.1, 0.05),
      _tube(
        const Offset(-0.05, 0.2),
        const Offset(0.3, 0.45),
        const Offset(0.75, 0.55),
        const Offset(0.55, 0.82),
        0.16,
        0.06,
      ),
      _ring(0.47, 0.8, 0.1, 0.05),
      _tube(
        const Offset(-0.1, 0.2),
        const Offset(0.0, 0.5),
        const Offset(0.25, 0.85),
        const Offset(0.02, 0.92),
        0.14,
        0.05,
      ),
      _ring(-0.04, 0.86, 0.08, 0.045),
    ]);
    final front = _u([body, tail]);
    return _d(
      _u([
        _d(wing, [_grow(front)]),
        front,
      ]),
      [_o(-0.56, -0.62, 0.035)],
    );
  }

  // ---- United Kingdom ----

  /// Portcullis grid with spiked foot and chains hanging from the top bar.
  static Path _portcullis() {
    final grid = _u([
      _r(-0.72, -0.56, 0.72, -0.4, 0.04),
      _sym(_o(0.72, -0.48, 0.09)),
      for (final x in [-0.5, -0.17, 0.17, 0.5]) ...[
        _r(x - 0.065, -0.42, x + 0.065, 0.64),
        _poly([x - 0.065, 0.62, x, 0.88, x + 0.065, 0.62]),
      ],
      for (final y in [-0.14, 0.14, 0.42]) _r(-0.62, y - 0.05, 0.62, y + 0.05),
    ]);
    const c0 = Offset(0.74, -0.42),
        c1 = Offset(0.92, -0.25),
        c2 = Offset(0.92, 0.05),
        c3 = Offset(0.82, 0.38);
    final chain = <Path>[];
    for (var k = 0; k < 5; k++) {
      final t = 0.12 + k * 0.2;
      final p = _bez(c0, c1, c2, c3, t);
      final g = _dir(c0, c1, c2, c3, t);
      final a = math.atan2(g.dy, g.dx);
      chain.add(
        k.isEven
            ? _tf(
                _d(_e(-0.11, -0.075, 0.11, 0.075), [
                  _e(-0.05, -0.022, 0.05, 0.022),
                ]),
                rot: a,
                at: p,
              )
            : _tf(_r(-0.1, -0.035, 0.1, 0.035, 0.035), rot: a, at: p),
      );
    }
    return _u([grid, _sym(_u(chain))]);
  }

  /// Heraldic shield with a border, quartered, each quarter charged.
  static Path _shield() {
    final outline = Path()
      ..moveTo(-0.78, -0.88)
      ..lineTo(0.78, -0.88)
      ..lineTo(0.78, -0.12)
      ..cubicTo(0.78, 0.45, 0.38, 0.78, 0, 0.96)
      ..cubicTo(-0.38, 0.78, -0.78, 0.45, -0.78, -0.12)
      ..close();
    final inner = _tf(outline, s: 0.82, at: const Offset(0, -0.01));
    return _d(outline, [
      _d(_grow(inner, 0.07), [inner]),
      _r(-0.035, -1, 0.035, 1),
      _r(-1, -0.2, 1, -0.13),
      // quarters: bars, lozenge, lozenge, bars
      for (final y in [-0.6, -0.46, -0.32]) ...[
        _r(-0.5, y - 0.03, -0.17, y + 0.03, 0.03),
      ],
      _poly([0.33, -0.62, 0.45, -0.44, 0.33, -0.28, 0.21, -0.44]),
      _poly([-0.31, 0.0, -0.21, 0.17, -0.31, 0.34, -0.41, 0.17]),
      for (final y in [0.02, 0.16, 0.3]) ...[
        _r(0.15, y - 0.03, 0.42, y + 0.03, 0.03),
      ],
    ]);
  }

  /// Tudor rose: notched outer petals, inner petals, seeded heart, sepals.
  static Path _rose() {
    final outer = _u([
      for (var i = 0; i < 5; i++) ...[
        _tf(_o(0, -0.52, 0.38), rot: i * 2 * math.pi / 5),
        _tf(
          _leaf(const Offset(0, -0.5), const Offset(0, -0.98), 0.18),
          rot: (i + 0.5) * 2 * math.pi / 5,
        ),
      ],
    ]);
    final notched = _d(outer, [
      for (var i = 0; i < 5; i++)
        _tf(
          _poly([-0.07, -0.95, 0, -0.84, 0.07, -0.95]),
          rot: i * 2 * math.pi / 5,
        ),
    ]);
    final innerP = _u([
      for (var i = 0; i < 5; i++)
        _tf(_o(0, -0.28, 0.22), rot: (i + 0.5) * 2 * math.pi / 5),
    ]);
    return _u([
      _d(notched, [_o(0, 0, 0.55)]),
      _d(_i(innerP, _o(0, 0, 0.49)), [_o(0, 0, 0.3)]),
      _d(_o(0, 0, 0.24), [
        _o(0, 0, 0.05),
        for (var i = 0; i < 6; i++)
          _tf(_o(0, -0.14, 0.04), rot: i * math.pi / 3),
      ]),
    ]);
  }

  /// Arched royal crown on a jewelled band, topped with orb and cross.
  static Path _crown() {
    final cap = Path()
      ..moveTo(-0.7, 0.4)
      ..lineTo(-0.82, -0.12)
      ..cubicTo(-0.82, -0.5, -0.35, -0.6, 0, -0.4)
      ..cubicTo(0.35, -0.6, 0.82, -0.5, 0.82, -0.12)
      ..lineTo(0.7, 0.4)
      ..close();
    final body = _u([
      _d(cap, [
        _sym(
          Path()
            ..moveTo(0.12, 0.36)
            ..lineTo(0.12, -0.22)
            ..cubicTo(0.3, -0.36, 0.58, -0.3, 0.62, -0.08)
            ..lineTo(0.56, 0.36)
            ..close(),
        ),
      ]),
      _sym(_o(0.82, -0.15, 0.08)),
      _o(0, -0.52, 0.13),
      _r(-0.055, -0.96, 0.055, -0.6),
      _r(-0.18, -0.87, 0.18, -0.76),
    ]);
    final band = _d(_r(-0.76, 0.42, 0.76, 0.7, 0.05), [
      _o(0, 0.56, 0.07),
      _sym(_poly([0.3, 0.56, 0.38, 0.48, 0.46, 0.56, 0.38, 0.64])),
    ]);
    return _u([body, band, _r(-0.82, 0.76, 0.82, 0.9, 0.07)]);
  }

  /// Thistle: cross-hatched bulb, spiky tuft, stem with spiny leaves.
  static Path _thistle() {
    final bulb = Path()
      ..addOval(
        Rect.fromCenter(
          center: const Offset(0, 0.14),
          width: 0.62,
          height: 0.56,
        ),
      );
    final hatch = _i(
      _u([
        for (var k = -2; k <= 2; k++) ...[
          _tf(
            _r(-0.6, -0.022, 0.6, 0.022),
            rot: math.pi / 4,
            at: Offset(k * 0.19, 0.14),
          ),
          _tf(
            _r(-0.6, -0.022, 0.6, 0.022),
            rot: -math.pi / 4,
            at: Offset(k * 0.19, 0.14),
          ),
        ],
      ]),
      _tf(bulb, s: 0.8, at: const Offset(0, 0.03)),
    );
    final tuft = _u([
      for (var k = 0; k < 9; k++)
        _leaf(
          const Offset(0, -0.05),
          Offset(
            math.cos(math.pi + k * math.pi / 8) * 0.72,
            -0.12 + math.sin(math.pi + k * math.pi / 8) * 0.8,
          ),
          0.1,
        ),
    ]);
    final head = _u([
      _d(tuft, [_e(-0.4, -0.25, 0.4, 0.4)]),
      _e(-0.3, -0.2, 0.3, -0.06),
    ]);
    final leaf = _poly([
      0,
      0.6,
      -0.22,
      0.44,
      -0.28,
      0.58,
      -0.5,
      0.38,
      -0.54,
      0.55,
      -0.82,
      0.36,
      -0.72,
      0.62,
      -0.48,
      0.7,
      -0.22,
      0.8,
      0,
      0.8,
    ]);
    return _u([
      _d(bulb, [hatch, _e(-0.34, -0.22, 0.34, -0.03)]),
      head,
      _line(const Offset(0, 0.38), const Offset(0, 0.95), 0.1, 0.08),
      _sym(leaf),
    ]);
  }

  // ---- United States ----

  /// Head-and-shoulders bust facing left.
  static Path _profile() {
    final bust = Path()
      ..moveTo(-0.05, -0.9)
      ..cubicTo(-0.3, -0.9, -0.42, -0.72, -0.42, -0.55)
      ..lineTo(-0.43, -0.46)
      ..lineTo(-0.56, -0.23)
      ..lineTo(-0.46, -0.18)
      ..cubicTo(-0.48, -0.13, -0.46, -0.11, -0.48, -0.07)
      ..cubicTo(-0.46, -0.03, -0.45, 0.0, -0.46, 0.03)
      ..cubicTo(-0.47, 0.08, -0.44, 0.15, -0.36, 0.16)
      ..cubicTo(-0.25, 0.17, -0.2, 0.18, -0.18, 0.25)
      ..cubicTo(-0.17, 0.35, -0.2, 0.45, -0.3, 0.52)
      ..cubicTo(-0.55, 0.58, -0.8, 0.7, -0.85, 0.95)
      ..lineTo(0.85, 0.95)
      ..cubicTo(0.82, 0.7, 0.6, 0.55, 0.38, 0.48)
      ..cubicTo(0.3, 0.4, 0.28, 0.25, 0.3, 0.12)
      ..cubicTo(0.45, -0.05, 0.5, -0.3, 0.45, -0.5)
      ..cubicTo(0.38, -0.8, 0.2, -0.9, -0.05, -0.9)
      ..close();
    return _d(bust, [
      // ear
      _tube(
        const Offset(0.1, -0.38),
        const Offset(0.24, -0.42),
        const Offset(0.26, -0.12),
        const Offset(0.1, -0.14),
        0.045,
        0.045,
      ),
      // hair cap and strands
      _tube(
        const Offset(-0.38, -0.66),
        const Offset(-0.1, -0.56),
        const Offset(0.0, -0.5),
        const Offset(0.02, -0.44),
        0.045,
        0.045,
      ),
      _tube(
        const Offset(0.02, -0.44),
        const Offset(0.3, -0.5),
        const Offset(0.36, -0.1),
        const Offset(0.3, 0.05),
        0.045,
        0.03,
      ),
      _tube(
        const Offset(-0.12, -0.8),
        const Offset(0.1, -0.78),
        const Offset(0.28, -0.66),
        const Offset(0.36, -0.46),
        0.035,
        0.0,
      ),
      _tube(
        const Offset(0.08, -0.62),
        const Offset(0.22, -0.58),
        const Offset(0.32, -0.42),
        const Offset(0.38, -0.24),
        0.035,
        0.0,
      ),
      // eye
      _tf(_e(-0.06, -0.025, 0.06, 0.025), at: const Offset(-0.32, -0.4)),
      // collar
      _tube(
        const Offset(-0.62, 0.62),
        const Offset(-0.3, 0.75),
        const Offset(0.3, 0.75),
        const Offset(0.62, 0.6),
        0.05,
        0.05,
      ),
    ]);
  }

  /// Liberty torch: flame above a ribbed cup and ringed handle.
  static Path _torch() {
    final flame = Path()
      ..moveTo(0.02, -0.98)
      ..cubicTo(0.12, -0.78, 0.42, -0.66, 0.38, -0.4)
      ..cubicTo(0.36, -0.28, 0.3, -0.2, 0.2, -0.17)
      ..lineTo(-0.2, -0.17)
      ..cubicTo(-0.34, -0.22, -0.4, -0.32, -0.36, -0.46)
      ..cubicTo(-0.32, -0.6, -0.22, -0.62, -0.2, -0.76)
      ..cubicTo(-0.1, -0.66, -0.08, -0.56, -0.12, -0.48)
      ..cubicTo(-0.02, -0.6, 0.06, -0.75, 0.02, -0.98)
      ..close();
    final inner = Path()
      ..moveTo(0.02, -0.6)
      ..cubicTo(0.18, -0.48, 0.2, -0.32, 0.08, -0.24)
      ..lineTo(-0.08, -0.24)
      ..cubicTo(-0.18, -0.32, -0.12, -0.44, 0.02, -0.6)
      ..close();
    final cup = _d(
      _u([
        _r(-0.42, -0.14, 0.42, -0.04, 0.03),
        _poly([-0.38, -0.05, 0.38, -0.05, 0.22, 0.2, -0.22, 0.2]),
      ]),
      [
        for (final x in [-0.2, 0.0, 0.2])
          _r(x - 0.025, 0.0, x + 0.025, 0.14, 0.02),
      ],
    );
    return _u([
      _d(flame, [inner]),
      cup,
      _r(-0.24, 0.24, 0.24, 0.32, 0.03),
      _poly([-0.14, 0.32, 0.14, 0.32, 0.1, 0.86, -0.1, 0.86]),
      _r(-0.17, 0.5, 0.17, 0.58, 0.03),
      _e(-0.15, 0.82, 0.15, 0.94),
    ]);
  }

  /// Spread-wing eagle, head turned left, fanned tail.
  static Path _eagle() {
    // Right wing: raised arm with primaries fanning down and out.
    final arm = Path()
      ..moveTo(0.08, -0.22)
      ..cubicTo(0.2, -0.55, 0.42, -0.9, 0.64, -0.92)
      ..cubicTo(0.78, -0.92, 0.9, -0.82, 0.96, -0.7)
      ..lineTo(0.5, -0.36)
      ..lineTo(0.2, 0.12)
      ..close();
    final wing = _u([
      arm,
      for (final (b, t) in [
        (const Offset(0.62, -0.72), const Offset(0.98, -0.56)),
        (const Offset(0.56, -0.6), const Offset(0.97, -0.34)),
        (const Offset(0.48, -0.46), const Offset(0.9, -0.12)),
        (const Offset(0.4, -0.32), const Offset(0.78, 0.08)),
        (const Offset(0.3, -0.18), const Offset(0.6, 0.22)),
        (const Offset(0.2, -0.05), const Offset(0.4, 0.3)),
      ])
        _leaf(b, t, 0.1),
    ]);
    final head = _u([
      _o(0, -0.46, 0.15),
      Path()
        ..moveTo(-0.08, -0.56)
        ..cubicTo(-0.2, -0.56, -0.28, -0.5, -0.27, -0.4)
        ..lineTo(-0.21, -0.45)
        ..lineTo(-0.08, -0.42)
        ..close(),
    ]);
    final body = _u([
      head,
      _e(-0.2, -0.38, 0.2, 0.5),
      _d(_poly([-0.16, 0.4, 0.16, 0.4, 0.32, 0.94, -0.32, 0.94]), [
        _poly([-0.1, 0.94, -0.06, 0.7, -0.02, 0.94]),
        _poly([0.02, 0.94, 0.06, 0.7, 0.1, 0.94]),
      ]),
    ]);
    return _d(
      _u([
        _d(_sym(wing), [_grow(body)]),
        body,
      ]),
      [_o(-0.04, -0.5, 0.035)],
    );
  }

  /// Domed capitol: lantern, ribbed dome, drum and colonnaded wings.
  static Path _dome() {
    final dome = Path()
      ..moveTo(-0.42, -0.1)
      ..cubicTo(-0.42, -0.46, -0.2, -0.6, 0, -0.6)
      ..cubicTo(0.2, -0.6, 0.42, -0.46, 0.42, -0.1)
      ..close();
    return _u([
      _d(dome, [
        _sym(
          _tube(
            const Offset(0.12, -0.12),
            const Offset(0.13, -0.3),
            const Offset(0.1, -0.45),
            const Offset(0.05, -0.55),
            0.04,
            0.02,
          ),
        ),
      ]),
      _r(-0.07, -0.76, 0.07, -0.56),
      _o(0, -0.78, 0.08),
      _r(-0.025, -0.96, 0.025, -0.8),
      _r(-0.55, -0.16, 0.55, -0.07, 0.02),
      _d(_r(-0.5, -0.08, 0.5, 0.32), [
        for (var k = -4; k <= 4; k++)
          _r(k * 0.1 - 0.025, -0.02, k * 0.1 + 0.025, 0.26, 0.02),
      ]),
      _r(-0.98, 0.32, 0.98, 0.41, 0.02),
      _d(_r(-0.94, 0.4, 0.94, 0.78), [
        for (var k = -8; k <= 8; k++)
          if (k.abs() > 0)
            _r(k * 0.105 - 0.03, 0.46, k * 0.105 + 0.03, 0.72, 0.02),
      ]),
      _r(-0.98, 0.8, 0.98, 0.9, 0.02),
    ]);
  }

  // ---- India ----

  /// Lotus in bloom: fanned petals over drooping sepals and water.
  static Path _lotus() {
    const base = Offset(0, 0.5);
    final back = _sym(
      _leaf(base, const Offset(0.94, -0.08), 0.26, bend: -0.06),
    );
    final mid = _sym(_leaf(base, const Offset(0.56, -0.6), 0.3, bend: -0.05));
    final front = _leaf(const Offset(0, 0.55), const Offset(0, -0.94), 0.32);
    final low = _sym(
      _leaf(const Offset(0, 0.55), const Offset(0.9, 0.5), 0.17, bend: -0.08),
    );
    var p = _layer(back, mid);
    p = _layer(p, front);
    p = _layer(p, low);
    final pad = Path()
      ..moveTo(-0.62, 0.7)
      ..quadraticBezierTo(0, 0.6, 0.62, 0.7)
      ..quadraticBezierTo(0, 0.98, -0.62, 0.7)
      ..close();
    return _layer(p, pad);
  }

  /// Sheaf of wheat: three ears bound with a band.
  static Path _wheat() {
    Path ear(double len) {
      final ps = <Path>[_o(0, -len - 0.02, 0.07)];
      for (var k = 0; k < 5; k++) {
        final y = -len + 0.06 + k * len * 0.17;
        for (final s in [-1.0, 1.0]) {
          ps.add(
            _tf(
              _e(-0.055, -0.1, 0.055, 0.1),
              rot: s * 0.45,
              at: Offset(s * 0.065, y),
            ),
          );
        }
      }
      ps.add(_line(Offset(0, -len), Offset(0, -len - 0.22), 0.035, 0));
      return _u(ps);
    }

    final parts = <Path>[
      _tf(ear(0.68), at: const Offset(0, -0.25)),
      _tf(ear(0.6), rot: -0.6, at: const Offset(-0.14, -0.14)),
      _tf(ear(0.6), rot: 0.6, at: const Offset(0.14, -0.14)),
    ];
    final stalks = _u([
      for (final (top, bot) in [
        (const Offset(0, -0.25), const Offset(0, 0.95)),
        (const Offset(-0.14, -0.14), const Offset(-0.42, 0.92)),
        (const Offset(0.14, -0.14), const Offset(0.42, 0.92)),
        (const Offset(-0.06, 0.0), const Offset(-0.22, 0.95)),
        (const Offset(0.06, 0.0), const Offset(0.22, 0.95)),
      ])
        _tube(
          top,
          Offset(top.dx * 0.4, 0.2),
          Offset(bot.dx * 0.15, 0.4),
          bot,
          0.07,
          0.09,
        ),
    ]);
    final band = _r(-0.2, 0.22, 0.2, 0.36, 0.04);
    return _u([
      _d(_u([...parts, stalks]), [_grow(band, 0.05)]),
      band,
    ]);
  }

  /// Wheel of law: rim, hub and 24 tapering spokes.
  static Path _chakra() {
    return _u([
      _d(_o(0, 0, 0.95), [_o(0, 0, 0.8)]),
      _d(_o(0, 0, 0.2), [_o(0, 0, 0.08)]),
      for (var i = 0; i < 24; i++) ...[
        _tf(
          _poly([-0.018, -0.16, 0.018, -0.16, 0.038, -0.84, -0.038, -0.84]),
          rot: i * math.pi / 12,
        ),
        _tf(_o(0, -0.8, 0.035), rot: (i + 0.5) * math.pi / 12),
      ],
    ]);
  }

  /// Peacock feather: eyed vane on a curved shaft with side fronds.
  static Path _peacock() {
    final vane = Path()
      ..moveTo(0, 0.12)
      ..cubicTo(-0.52, -0.05, -0.5, -0.92, 0, -0.94)
      ..cubicTo(0.5, -0.92, 0.52, -0.05, 0, 0.12)
      ..close();
    final eye = _u([
      _d(vane, [
        _e(-0.27, -0.72, 0.27, -0.12),
        for (var k = 0; k < 9; k++)
          _tf(
            _line(const Offset(0, -0.42), const Offset(0, -0.98), 0.0, 0.05),
            rot: -1.6 + k * 0.4,
            at: const Offset(0, 0),
          ),
      ]),
      _d(_e(-0.21, -0.66, 0.21, -0.18), [_e(-0.15, -0.58, 0.15, -0.24)]),
      _e(-0.1, -0.52, 0.1, -0.27),
    ]);
    final shaft = <Path>[
      _line(const Offset(0, 0.95), const Offset(0, 0.0), 0.08, 0.06),
      for (var k = 0; k < 5; k++)
        for (final s in [-1.0, 1.0])
          _leaf(
            Offset(0, 0.2 + k * 0.14),
            Offset(s * (0.38 - k * 0.05), 0.0 + k * 0.15),
            0.07,
          ),
    ];
    return _tf(_u([eye, ...shaft]), rot: -0.3, s: 0.97);
  }

  /// Elephant walking left, trunk curled, ear outlined, tusk forward.
  static Path _elephant() {
    final body = Path()
      ..moveTo(-0.45, -0.55)
      ..cubicTo(-0.3, -0.75, 0.05, -0.7, 0.25, -0.6)
      ..cubicTo(0.6, -0.55, 0.9, -0.4, 0.9, 0.0)
      ..lineTo(0.88, 0.78)
      ..lineTo(0.6, 0.78)
      ..lineTo(0.6, 0.42)
      ..cubicTo(0.4, 0.46, 0.1, 0.46, -0.04, 0.42)
      ..lineTo(-0.05, 0.78)
      ..lineTo(-0.34, 0.78)
      ..lineTo(-0.34, 0.25)
      ..cubicTo(-0.38, 0.12, -0.44, 0.06, -0.48, 0.05)
      ..cubicTo(-0.55, 0.3, -0.55, 0.6, -0.68, 0.72)
      ..cubicTo(-0.75, 0.8, -0.92, 0.75, -0.92, 0.6)
      ..lineTo(-0.84, 0.6)
      ..cubicTo(-0.76, 0.56, -0.72, 0.3, -0.7, 0.1)
      ..cubicTo(-0.7, -0.15, -0.72, -0.4, -0.45, -0.55)
      ..close();
    final ear = Path()
      ..moveTo(-0.24, -0.5)
      ..cubicTo(0.0, -0.58, 0.2, -0.45, 0.16, -0.15)
      ..cubicTo(0.14, 0.05, 0.02, 0.18, -0.16, 0.12)
      ..cubicTo(-0.3, 0.05, -0.32, -0.3, -0.24, -0.5)
      ..close();
    final tusk = Path()
      ..moveTo(-0.5, 0.02)
      ..cubicTo(-0.55, 0.17, -0.66, 0.22, -0.8, 0.2)
      ..cubicTo(-0.68, 0.14, -0.6, 0.08, -0.58, -0.02)
      ..close();
    final b = _d(body, [
      _d(ear, [_tf(ear, s: 0.8, at: const Offset(-0.02, -0.03))]),
      _o(-0.5, -0.3, 0.04),
      _grow(tusk, 0.05),
      // far legs
      _r(0.58, 0.45, 0.62, 0.8),
      _line(const Offset(-0.04, 0.5), const Offset(-0.04, 0.8), 0.04, 0.04),
    ]);
    return _u([
      b,
      tusk,
      _tube(
        const Offset(0.86, -0.2),
        const Offset(0.95, -0.05),
        const Offset(0.97, 0.15),
        const Offset(0.96, 0.35),
        0.05,
        0.03,
      ),
    ]);
  }

  // ---- Northeast India ----

  /// One-horned rhino facing left, with skin folds.
  static Path _rhino() {
    final body = Path()
      ..moveTo(-0.92, 0.2)
      ..lineTo(-0.88, 0.06)
      ..cubicTo(-0.95, -0.1, -0.95, -0.3, -0.84, -0.52)
      ..cubicTo(-0.8, -0.28, -0.72, -0.12, -0.64, -0.06)
      ..lineTo(-0.6, -0.22)
      ..lineTo(-0.52, -0.12)
      ..cubicTo(-0.5, -0.15, -0.45, -0.24, -0.36, -0.27)
      ..lineTo(-0.38, -0.5)
      ..lineTo(-0.24, -0.3)
      ..cubicTo(-0.1, -0.5, 0.3, -0.6, 0.6, -0.46)
      ..cubicTo(0.85, -0.36, 0.95, -0.1, 0.92, 0.2)
      ..lineTo(0.88, 0.75)
      ..lineTo(0.6, 0.75)
      ..lineTo(0.58, 0.46)
      ..cubicTo(0.4, 0.52, 0.1, 0.52, -0.02, 0.48)
      ..lineTo(-0.05, 0.75)
      ..lineTo(-0.35, 0.75)
      ..lineTo(-0.38, 0.4)
      ..cubicTo(-0.48, 0.38, -0.55, 0.36, -0.62, 0.36)
      ..cubicTo(-0.75, 0.36, -0.85, 0.32, -0.92, 0.2)
      ..close();
    return _d(body, [
      _tube(
        const Offset(-0.14, -0.38),
        const Offset(-0.06, -0.15),
        const Offset(-0.08, 0.15),
        const Offset(-0.16, 0.38),
        0.045,
        0.02,
      ),
      _tube(
        const Offset(0.5, -0.45),
        const Offset(0.42, -0.2),
        const Offset(0.45, 0.15),
        const Offset(0.55, 0.38),
        0.045,
        0.02,
      ),
      _tube(
        const Offset(-0.35, 0.3),
        const Offset(-0.45, 0.2),
        const Offset(-0.5, 0.1),
        const Offset(-0.48, -0.02),
        0.035,
        0.015,
      ),
      _o(-0.52, -0.06, 0.035),
      _r(0.57, 0.5, 0.61, 0.8),
      _r(-0.07, 0.52, -0.03, 0.8),
    ]);
  }

  /// Great hornbill head facing left: casque over a long curved bill.
  static Path _hornbill() {
    final bill = Path()
      ..moveTo(-0.08, -0.26)
      ..cubicTo(-0.42, -0.26, -0.76, -0.04, -0.95, 0.46)
      ..cubicTo(-0.7, 0.18, -0.42, 0.06, -0.05, 0.06)
      ..close();
    final casque = Path()
      ..moveTo(0.0, -0.5)
      ..cubicTo(-0.28, -0.58, -0.58, -0.5, -0.74, -0.24)
      ..lineTo(-0.62, -0.28)
      ..cubicTo(-0.45, -0.32, -0.3, -0.32, -0.04, -0.3)
      ..close();
    final head = _u([
      _o(0.18, -0.24, 0.3),
      Path()
        ..moveTo(-0.02, -0.05)
        ..cubicTo(0.04, 0.35, 0.0, 0.65, -0.12, 0.96)
        ..lineTo(0.75, 0.96)
        ..cubicTo(0.62, 0.6, 0.55, 0.15, 0.44, -0.2)
        ..close(),
      _poly([0.44, -0.3, 0.62, -0.42, 0.5, -0.2]),
    ]);
    final h = _d(head, [
      _grow(_u([bill, casque]), 0.045),
      _ring(0.1, -0.26, 0.075, 0.03),
      _tube(
        const Offset(0.0, 0.42),
        const Offset(0.2, 0.48),
        const Offset(0.42, 0.42),
        const Offset(0.62, 0.3),
        0.06,
        0.06,
      ),
    ]);
    return _u([
      h,
      _o(0.1, -0.26, 0.035),
      _d(bill, [
        _tube(
          const Offset(-0.1, -0.1),
          const Offset(-0.4, -0.08),
          const Offset(-0.62, 0.05),
          const Offset(-0.8, 0.28),
          0.04,
          0.0,
        ),
      ]),
      casque,
    ]);
  }

  /// Orchid: sepals and wide petals behind a frilled lip and column.
  static Path _orchid() {
    const c = Offset(0, -0.05);
    final sepals = _u([
      _leaf(c, const Offset(0, -0.96), 0.24),
      _sym(_leaf(c, const Offset(0.58, 0.78), 0.22)),
    ]);
    final petals = _sym(_leaf(c, const Offset(0.94, -0.32), 0.36, bend: -0.05));
    final lip = Path()
      ..moveTo(0, 0.02)
      ..cubicTo(-0.25, 0.05, -0.38, 0.4, -0.26, 0.66)
      ..quadraticBezierTo(-0.18, 0.82, -0.1, 0.72)
      ..quadraticBezierTo(0, 0.86, 0.1, 0.72)
      ..quadraticBezierTo(0.18, 0.82, 0.26, 0.66)
      ..cubicTo(0.38, 0.4, 0.25, 0.05, 0, 0.02)
      ..close();
    final lipD = _d(lip, [
      _line(const Offset(0, 0.2), const Offset(0, 0.6), 0.04, 0.0),
    ]);
    var p = _layer(sepals, petals);
    p = _layer(p, lipD, 0.05);
    final column = _e(-0.09, -0.2, 0.09, 0.08);
    return _u([
      _d(p, [_grow(column, 0.05)]),
      column,
    ]);
  }

  /// Two tea leaves and a bud on a short stem.
  static Path _teaLeaf() {
    return _u([
      _tube(
        const Offset(0.02, 0.96),
        const Offset(0.06, 0.5),
        const Offset(-0.04, 0.0),
        const Offset(0.0, -0.3),
        0.08,
        0.06,
      ),
      _veinedLeaf(
        const Offset(0, -0.25),
        const Offset(0.08, -0.97),
        0.18,
        bend: 0.03,
        sideVeins: false,
      ),
      _veinedLeaf(
        const Offset(-0.02, 0.08),
        const Offset(-0.92, -0.42),
        0.36,
        bend: 0.08,
      ),
      _veinedLeaf(
        const Offset(0.03, 0.4),
        const Offset(0.92, -0.12),
        0.34,
        bend: -0.08,
      ),
    ]);
  }

  /// Layered hills under a rising sun, framed in a round window.
  static Path _hills() {
    final sun = _u([
      _o(0, -0.18, 0.36),
      for (var k = 0; k < 9; k++)
        _tf(
          _poly([-0.065, -0.46, 0, -0.78, 0.065, -0.46]),
          rot: -math.pi / 2 + k * math.pi / 8,
          at: const Offset(0, -0.18),
        ),
    ]);
    Path hill(double y0, double ya, double yb, double y1) => Path()
      ..moveTo(-1, y0)
      ..cubicTo(-0.6, ya, -0.25, ya + 0.15, 0.0, (ya + yb) / 2 + 0.12)
      ..cubicTo(0.3, yb, 0.65, yb, 1, y1)
      ..lineTo(1, 1)
      ..lineTo(-1, 1)
      ..close();
    final h1 = hill(0.18, -0.15, -0.12, 0.08);
    final h2 = hill(0.48, 0.2, 0.25, 0.42);
    final h3 = hill(0.72, 0.6, 0.5, 0.78);
    var p = _layer(sun, h1, 0.06);
    p = _layer(p, h2, 0.06);
    p = _layer(p, h3, 0.06);
    return _i(p, _o(0, 0, 0.94));
  }

  // ---- helpers ----

  static Path _u(List<Path> ps) =>
      ps.reduce((a, b) => Path.combine(PathOperation.union, a, b));

  static Path _d(Path a, List<Path> cuts) =>
      Path.combine(PathOperation.difference, a, _u(cuts));

  static Path _i(Path a, Path b) => Path.combine(PathOperation.intersect, a, b);

  /// [front] laid over [back] with a cut-out gap of [gap] around it.
  static Path _layer(Path back, Path front, [double gap = 0.045]) => _u([
    _d(back, [_grow(front, gap)]),
    front,
  ]);

  /// Approximate outward offset: the path stamped around a small circle.
  static Path _grow(Path p, [double g = 0.045]) => _u([
    for (var k = 0; k < 8; k++)
      p.shift(Offset.fromDirection(k * math.pi / 4, g)),
  ]);

  static Path _o(double x, double y, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

  static Path _ring(double x, double y, double r, double w) =>
      _d(_o(x, y, r), [_o(x, y, r - w)]);

  static Path _e(double l, double t, double r, double b) =>
      Path()..addOval(Rect.fromLTRB(l, t, r, b));

  static Path _r(double l, double t, double r, double b, [double rad = 0]) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

  static Path _poly(List<double> xy) => Path()
    ..addPolygon([
      for (var i = 0; i < xy.length; i += 2) Offset(xy[i], xy[i + 1]),
    ], true);

  /// Round arch opening from [bottom] up to [spring], with [rise] above it.
  static Path _arch(
    double l,
    double r,
    double bottom,
    double spring,
    double rise,
  ) => Path()
    ..moveTo(l, bottom)
    ..lineTo(l, spring)
    ..arcToPoint(
      Offset(r, spring),
      radius: Radius.elliptical((r - l) / 2, rise),
    )
    ..lineTo(r, bottom)
    ..close();

  /// Pointed gothic arch opening.
  static Path _garch(
    double l,
    double r,
    double bottom,
    double spring,
    double top,
  ) {
    final m = (l + r) / 2;
    final k = spring - (spring - top) * 0.45;
    return Path()
      ..moveTo(l, bottom)
      ..lineTo(l, spring)
      ..quadraticBezierTo(l, k, m, top)
      ..quadraticBezierTo(r, k, r, spring)
      ..lineTo(r, bottom)
      ..close();
  }

  /// Rotate by [rot], scale by [s], then translate to [at].
  static Path _tf(
    Path p, {
    double rot = 0,
    double s = 1,
    Offset at = Offset.zero,
  }) {
    final c = math.cos(rot) * s, n = math.sin(rot) * s;
    return p.transform(
      Float64List.fromList([
        c,
        n,
        0,
        0,
        -n,
        c,
        0,
        0,
        0,
        0,
        1,
        0,
        at.dx,
        at.dy,
        0,
        1,
      ]),
    );
  }

  static Path _sym(Path p) => _u([
    p,
    p.transform(
      Float64List.fromList([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
    ),
  ]);

  static Offset _bez(Offset a, Offset b, Offset c, Offset d, double t) {
    final m = 1 - t;
    return a * (m * m * m) +
        b * (3 * m * m * t) +
        c * (3 * m * t * t) +
        d * (t * t * t);
  }

  static Offset _dir(Offset a, Offset b, Offset c, Offset d, double t) {
    final g =
        _bez(a, b, c, d, math.min(t + 0.01, 1)) -
        _bez(a, b, c, d, math.max(t - 0.01, 0));
    return g / g.distance;
  }

  /// A cubic curve thickened to a filled band, width tapering [w0] → [w1]
  /// with an extra [bulge] in the middle.
  static Path _tube(
    Offset a,
    Offset b,
    Offset c,
    Offset d,
    double w0,
    double w1, [
    double bulge = 0,
  ]) {
    const n = 24;
    final l = <Offset>[], r = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final p = _bez(a, b, c, d, t);
      final g = _dir(a, b, c, d, t);
      final w = (w0 + (w1 - w0) * t + bulge * math.sin(math.pi * t)) / 2;
      final nn = Offset(-g.dy, g.dx) * w;
      l.add(p + nn);
      r.add(p - nn);
    }
    return Path()..addPolygon([...l, ...r.reversed], true);
  }

  static Path _line(Offset a, Offset b, double w0, double w1) =>
      _tube(a, Offset.lerp(a, b, 1 / 3)!, Offset.lerp(a, b, 2 / 3)!, b, w0, w1);

  /// Almond leaf from [base] to [tip], [w] is its half-width; [bend] curves
  /// it sideways.
  static Path _leaf(Offset base, Offset tip, double w, {double bend = 0}) {
    final d = tip - base;
    final n = Offset(-d.dy, d.dx) / d.distance;
    return Path()
      ..moveTo(base.dx, base.dy)
      ..cubicTo2(
        base + d * 0.2 + n * (w + bend),
        base + d * 0.75 + n * (w * 0.7 + bend),
        tip,
      )
      ..cubicTo2(
        base + d * 0.75 - n * (w * 0.7 - bend),
        base + d * 0.2 - n * (w - bend),
        base,
      )
      ..close();
  }

  /// Leaf with a cut midrib and optional side veins.
  static Path _veinedLeaf(
    Offset base,
    Offset tip,
    double w, {
    double bend = 0,
    bool sideVeins = true,
  }) {
    final d = tip - base;
    final n = Offset(-d.dy, d.dx) / d.distance;
    final mid = base + d * 0.5 + n * bend * 0.75;
    return _d(_leaf(base, tip, w, bend: bend), [
      _tube(
        base + d * 0.12,
        Offset.lerp(base + d * 0.12, mid, 0.6)!,
        Offset.lerp(mid, base + d * 0.85, 0.4)!,
        base + d * 0.85,
        0.05,
        0,
      ),
      if (sideVeins)
        for (final t in [0.32, 0.52, 0.7])
          for (final s in [-1.0, 1.0])
            _line(
              base + d * t + n * bend * 0.7,
              base + d * (t + 0.14) + n * (s * w * 0.55 + bend * 0.6),
              0.035,
              0,
            ),
    ]);
  }
}

extension on Path {
  void cubicTo2(Offset a, Offset b, Offset c) =>
      cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
}
