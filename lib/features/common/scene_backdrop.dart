import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../app/theme/tokens.dart';
import '../../game/render/theme/coin_theme.dart';

/// Procedural scenery behind every screen, one per theme.
abstract final class SceneArt {
  /// Paints the static scene for [scene] filling [size].
  static void paint(Canvas canvas, Size size, SceneStyle scene) {
    if (size.isEmpty) return;
    final p = _Scene(canvas, size, scene);
    switch (scene.kind) {
      case SceneKind.atelier:
        p.atelier();
      case SceneKind.paris:
        p.paris();
      case SceneKind.kyoto:
        p.kyoto();
      case SceneKind.london:
        p.london();
      case SceneKind.newYork:
        p.newYork();
      case SceneKind.delhi:
        p.delhi();
      case SceneKind.northeast:
        p.northeast();
    }
  }
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

Color _alpha(Color c, double a) => c.withValues(alpha: c.a * a);

/// Small seeded LCG so every scene paints identically on every device.
final class _Rng {
  _Rng(this._s);

  int _s;

  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x7fffffff;
  }

  double range(double a, double b) => a + next() * (b - a);
}

const _white = Color(0xFFFFFFFF);
const _warm = Color(0xFFFFCF7A);
const _hot = Color(0xFFFFF2C8);

/// One paint pass. Lengths are authored for a 400-wide phone and scaled by
/// [k]; landmarks stand on the horizon [hz] so the board area stays calm.
final class _Scene {
  _Scene(this.c, Size size, this.s)
    : w = size.width,
      h = size.height,
      k = math.min(size.width, size.height * 0.46) / 400,
      hz = size.height * 0.36;

  final Canvas c;
  final SceneStyle s;
  final double w, h, k, hz;
  final rng = _Rng(7);

  // Lit windows are batched into two paths per layer and drawn by [lights].
  final _win = Path();
  final _winHot = Path();

  Rect get full => Rect.fromLTWH(0, 0, w, h);

  /// Silhouette tone: 0 is the mid sky, 1 is the ground colour. Far layers
  /// use low values (hazy), near layers high values (dark).
  Color haze(double t) => _mix(s.sky[1], s.ground, t);

  Paint fill(Color col) => Paint()..color = col;

  // ------------------------------------------------------------- shared

  /// Sky down to the horizon; below it a dim floor that darkens into the
  /// ground, so layers that end early never leave a bright seam.
  void sky() {
    c.drawRect(
      Rect.fromLTWH(0, 0, w, hz + 1),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: s.sky,
        ).createShader(Rect.fromLTWH(0, 0, w, hz)),
    );
    final floor = Rect.fromLTRB(0, hz, w, h);
    c.drawRect(
      floor,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_mix(s.sky[1], s.ground, 0.55), s.ground],
        ).createShader(Rect.fromLTRB(0, hz, w, hz + 160 * k)),
    );
  }

  void glow(Offset o, double r, {Color? color, double a = 0.6}) {
    final col = color ?? s.glow;
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [_alpha(col, a), _alpha(col, a * 0.3), _alpha(col, 0)],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  /// Wide flattened glow sitting on the horizon.
  void horizonGlow(double x, double r, double a) {
    c.save();
    c.translate(x, hz);
    c.scale(1, 0.38);
    glow(Offset.zero, r, a: a);
    c.restore();
  }

  void stars(int n, double maxY, double a) {
    final p = Path();
    for (var i = 0; i < n; i++) {
      final o = Offset(rng.next() * w, math.pow(rng.next(), 1.5) * maxY);
      p.addOval(Rect.fromCircle(center: o, radius: rng.range(0.4, 1.2) * k));
    }
    c.drawPath(p, fill(_alpha(_white, a)));
  }

  /// Long soft streak of cloud (one blur each, so use sparingly).
  void cloud(Offset o, double wd, double ht, Color col) => c.drawOval(
    Rect.fromCenter(center: o, width: wd, height: ht),
    Paint()
      ..color = col
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, ht * 0.45),
  );

  void windows(
    Rect r, {
    double cw = 7,
    double ch = 9,
    double ww = 3,
    double wh = 4,
    double p = 0.3,
  }) {
    final cx = cw * k, cy = ch * k, wx = ww * k, wy = wh * k;
    final cols = ((r.width - wx) / cx).floor() + 1;
    final x0 = r.left + (r.width - (cols - 1) * cx - wx) / 2;
    for (var y = r.top + (cy - wy) / 2; y + wy <= r.bottom; y += cy) {
      for (var i = 0; i < cols; i++) {
        final v = rng.next();
        if (v >= p) continue;
        (v < p * 0.2 ? _winHot : _win).addRect(
          Rect.fromLTWH(x0 + i * cx, y, wx, wy),
        );
      }
    }
  }

  /// Draws and clears the pending windows of one layer.
  void lights([double a = 1, Color col = _warm]) {
    c.drawPath(_win, fill(_alpha(col, 0.75 * a)));
    c.drawPath(
      _winHot,
      fill(_alpha(_hot, a))..maskFilter = MaskFilter.blur(BlurStyle.solid, k),
    );
    _win.reset();
    _winHot.reset();
  }

  /// River or lake: the horizon colours reflected, darkening with depth,
  /// plus horizontal shimmer under the glow.
  void water(double top, double bottom, {double glowX = -1}) {
    final r = Rect.fromLTRB(0, top, w, bottom);
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _mix(s.sky.last, s.sky[1], 0.45),
            _mix(s.sky[1], s.ground, 0.55),
            _mix(s.sky[1], s.ground, 0.85),
          ],
        ).createShader(r),
    );
    final gx = glowX < 0 ? w / 2 : glowX;
    final p = Path();
    for (var i = 0; i < 46; i++) {
      final d = rng.next();
      final y = top + 2 * k + d * (bottom - top - 4 * k);
      final x = gx + (rng.next() - 0.5) * w * (0.5 + d);
      final len = rng.range(6, 34) * k * (1 - d * 0.5);
      p.addRect(Rect.fromLTWH(x - len / 2, y, len, 0.9 * k));
    }
    c.drawPath(p, fill(_alpha(s.glow, 0.32)));
  }

  /// Broken vertical streak under a light, as on rippled water.
  void reflection(double x, double top, double len, double wd, Color col) {
    final p = Path();
    for (var y = 0.0; y < len; y += 3 * k) {
      final f = 1 - y / len;
      final ww = wd * (0.4 + rng.next() * 0.8) * (0.6 + f * 0.4);
      p.addRect(
        Rect.fromLTWH(x - ww / 2 + (rng.next() - 0.5) * 2 * k, top + y, ww, k),
      );
    }
    c.drawPath(p, fill(_alpha(col, 0.5)));
  }

  /// Street lamp: post plus warm head glow.
  void lamp(Offset base, double ht, Color post) {
    c.drawRect(
      Rect.fromLTWH(base.dx - 0.04 * ht, base.dy - ht, 0.08 * ht, ht),
      fill(post),
    );
    c.drawRect(
      Rect.fromLTWH(
        base.dx - 0.12 * ht,
        base.dy - 0.06 * ht,
        0.24 * ht,
        0.06 * ht,
      ),
      fill(post),
    );
    final head = Offset(base.dx, base.dy - ht - 0.08 * ht);
    glow(head, ht * 0.9, color: _warm, a: 0.55);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: head, width: 0.16 * ht, height: 0.2 * ht),
        Radius.circular(0.04 * ht),
      ),
      fill(_hot),
    );
  }

  /// Fades everything below [from] into the ground colour and adds a
  /// vignette so the board and HUD read cleanly.
  void settle(double from) {
    final solid = math.max(from + 60 * k, h * 0.6);
    final r = Rect.fromLTRB(0, from, w, h);
    final t = ((solid - from) / (h - from)).clamp(0.05, 1.0);
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_alpha(s.ground, 0), _alpha(s.ground, 0.8), s.ground],
          stops: [0, t * 0.55, t],
        ).createShader(r),
    );
    // A faint pool of the scene's light behind the board keeps the floor
    // from looking dead.
    final pool = Rect.fromCenter(
      center: Offset(w / 2, h * 0.62),
      width: w * 1.2,
      height: h * 0.5,
    );
    c.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(
          colors: [_alpha(s.glow, 0.07), _alpha(s.glow, 0)],
        ).createShader(pool),
    );
    vignette(0x77);
  }

  void vignette(int alpha) => c.drawRect(
    full,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.1),
        radius: 1.05,
        colors: [const Color(0x00000000), Color.fromARGB(alpha, 0, 0, 0)],
        stops: const [0.6, 1],
      ).createShader(full),
  );

  // ------------------------------------------------------------ atelier

  /// The original walnut backdrop, unchanged.
  void atelier() {
    c.drawRect(
      full,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.2,
          colors: [
            AtelierColors.backgroundGlow,
            AtelierColors.background,
            AtelierColors.backgroundDeep,
          ],
          stops: [0, 0.5, 1],
        ).createShader(full),
    );
    var seed = 17;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    for (var i = 0; i < 22; i++) {
      // Keep the lights near the edges, away from the board.
      final edge = rnd() < 0.5;
      final x = edge
          ? (rnd() < 0.5 ? rnd() * 0.18 : 0.82 + rnd() * 0.18) * w
          : rnd() * w;
      final y = edge
          ? rnd() * h
          : (rnd() < 0.5 ? rnd() * 0.12 : 0.9 + rnd() * 0.1) * h;
      final r = 6 + rnd() * 26;
      final a = 0.04 + rnd() * 0.08;
      // Radial falloff matching a disc blurred by sigma r/2, without the
      // cost of a blur filter.
      final o = Offset(x, y);
      c.drawCircle(
        o,
        r * 2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 196, 90, a * 0.86),
              Color.fromRGBO(255, 196, 90, a * 0.45),
              Color.fromRGBO(255, 196, 90, a * 0.13),
              const Color.fromRGBO(255, 196, 90, 0),
            ],
            stops: const [0, 0.5, 0.75, 1],
          ).createShader(Rect.fromCircle(center: o, radius: r * 2)),
      );
    }
    c.drawRect(
      full,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x88000000)],
          stops: [0.6, 1],
        ).createShader(full),
    );
  }

  // -------------------------------------------------------------- paris

  void paris() {
    sky();
    stars(36, hz * 0.4, 0.55);
    horizonGlow(w * 0.38, 320 * k, 0.8);
    glow(Offset(w * 0.38, hz - 6 * k), 80 * k, a: 0.55);
    cloud(Offset(w * 0.2, hz * 0.5), 170 * k, 9 * k, _alpha(s.glow, 0.22));
    cloud(Offset(w * 0.78, hz * 0.36), 200 * k, 11 * k, _alpha(s.glow, 0.14));
    cloud(Offset(w * 0.55, hz * 0.68), 230 * k, 7 * k, _alpha(s.glow, 0.25));
    // Far bank of hazy rooftops, then the tower, then the river.
    rooftops(-10 * k, w + 10 * k, hz + 2 * k, 0.55, haze(0.35), 0.18, 40, 70);
    lights(0.55);
    eiffel(w * 0.62, hz + 2 * k, 250 * k);
    water(hz + 2 * k, hz + 90 * k, glowX: w * 0.45);
    reflection(w * 0.62, hz + 4 * k, 70 * k, 10 * k, s.glow);
    for (var i = 0; i < 9; i++) {
      reflection(w * (0.08 + i * 0.11), hz + 4 * k, 26 * k, 3 * k, _warm);
    }
    // Quay with a row of lamps.
    final quay = hz + 86 * k;
    c.drawRect(Rect.fromLTRB(0, quay, w, h), fill(haze(0.8)));
    for (var x = w * 0.06; x < w; x += 62 * k) {
      lamp(Offset(x, quay), 24 * k, haze(0.9));
    }
    // Near Haussmann blocks framing both sides.
    rooftops(-30 * k, w * 0.27, hz + 160 * k, 1, haze(0.82), 0.45, 160, 220);
    lights();
    rooftops(w * 0.8, w + 30 * k, hz + 160 * k, 1, haze(0.82), 0.45, 150, 200);
    lights();
    settle(hz + 100 * k);
  }

  /// Haussmann blocks: stone body, grey mansard roof with dormers and
  /// chimney pots, rows of tall windows.
  void rooftops(
    double x0,
    double x1,
    double base,
    double sc,
    Color col,
    double lit,
    double minH,
    double maxH,
  ) {
    final body = Path();
    final roofs = Path();
    final roofCol = _mix(col, const Color(0xFF3A3F5C), 0.25);
    var x = x0;
    while (x < x1) {
      final bw = rng.range(42, 66) * k * sc;
      final bh = rng.range(minH, maxH) * k;
      final top = base - bh;
      final roof = 15 * k * sc;
      body.addRect(Rect.fromLTWH(x, top, bw, bh));
      roofs
        ..moveTo(x + 1 * k * sc, top)
        ..lineTo(x + 6 * k * sc, top - roof)
        ..lineTo(x + bw - 6 * k * sc, top - roof)
        ..lineTo(x + bw - 1 * k * sc, top)
        ..close();
      for (var i = 0; i < 2; i++) {
        final cx = x + bw * (0.2 + i * 0.5 + rng.next() * 0.1);
        roofs.addRect(
          Rect.fromLTWH(cx, top - roof - 7 * k * sc, 5 * k * sc, 8 * k * sc),
        );
      }
      // Dormers along the mansard.
      for (
        var dx = x + 10 * k * sc;
        dx < x + bw - 12 * k * sc;
        dx += 12 * k * sc
      ) {
        final d = Rect.fromLTWH(dx, top - roof * 0.7, 4 * k * sc, 6 * k * sc);
        if (rng.next() < lit) _win.addRect(d);
      }
      windows(
        Rect.fromLTRB(
          x + 4 * k * sc,
          top + 5 * k * sc,
          x + bw - 4 * k * sc,
          base,
        ),
        cw: 10 * sc,
        ch: 15 * sc,
        ww: 4 * sc,
        wh: 8 * sc,
        p: lit,
      );
      x += bw + rng.range(0, 3) * k;
    }
    c.drawPath(roofs, fill(roofCol));
    c.drawPath(body, fill(col));
  }

  void eiffel(double x, double by, double H) {
    Offset p(double fx, double fy) => Offset(x + fx * H, by - fy * H);
    void q(Path path, double cx, double cy, double ex, double ey) {
      final a = p(cx, cy), b = p(ex, ey);
      path.quadraticBezierTo(a.dx, a.dy, b.dx, b.dy);
    }

    void l(Path path, double fx, double fy) {
      final a = p(fx, fy);
      path.lineTo(a.dx, a.dy);
    }

    final start = p(-0.2, 0);
    final t = Path()..moveTo(start.dx, start.dy);
    q(t, -0.15, 0.07, -0.135, 0.17);
    q(t, -0.095, 0.25, -0.072, 0.36);
    q(t, -0.032, 0.6, -0.016, 0.86);
    l(t, -0.009, 0.9);
    l(t, -0.004, 0.94);
    l(t, 0, 1);
    l(t, 0.004, 0.94);
    l(t, 0.009, 0.9);
    l(t, 0.016, 0.86);
    q(t, 0.032, 0.6, 0.072, 0.36);
    q(t, 0.095, 0.25, 0.135, 0.17);
    q(t, 0.15, 0.07, 0.2, 0);
    l(t, 0.15, 0);
    final a1 = p(0.13, 0.15), a2 = p(-0.13, 0.15), a3 = p(-0.15, 0);
    t
      ..cubicTo(a1.dx, a1.dy, a2.dx, a2.dy, a3.dx, a3.dy)
      ..close();

    glow(p(0, 0.45), H * 0.6, a: 0.35);
    final col = haze(0.62);
    c.drawPath(t, fill(col));
    for (final r in [
      Rect.fromPoints(p(-0.16, 0.165), p(0.16, 0.195)),
      Rect.fromPoints(p(-0.088, 0.355), p(0.088, 0.38)),
      Rect.fromPoints(p(-0.024, 0.85), p(0.024, 0.865)),
    ]) {
      c.drawRect(r, fill(_mix(col, s.ground, 0.25)));
    }
    // Lattice: crossing diagonals clipped to the silhouette.
    c.save();
    c.clipPath(t);
    final lat = Path();
    for (var d = -H; d < H; d += 0.028 * H) {
      lat
        ..moveTo(x + d - H * 0.3, by)
        ..lineTo(x + d + H * 0.3, by - H)
        ..moveTo(x + d + H * 0.3, by)
        ..lineTo(x + d - H * 0.3, by - H);
    }
    c.drawPath(
      lat,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 * k
        ..color = _alpha(s.glow, 0.22),
    );
    c.restore();
    // Golden illumination dotted along the outline.
    final dots = Path();
    for (final m in t.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 5 * k) {
        final pos = m.getTangentForOffset(d)!.position;
        if (pos.dy > by - 2 * k) continue;
        dots.addOval(Rect.fromCircle(center: pos, radius: 0.8 * k));
      }
    }
    c.drawPath(
      dots,
      fill(_hot)..maskFilter = MaskFilter.blur(BlurStyle.solid, 0.8 * k),
    );
    glow(p(0, 1), 26 * k, color: _hot, a: 0.7);
  }

  // -------------------------------------------------------------- kyoto

  void kyoto() {
    sky();
    stars(20, hz * 0.3, 0.45);
    horizonGlow(w * 0.5, 320 * k, 0.7);
    glow(Offset(w * 0.28, hz - 70 * k), 90 * k, a: 0.45);
    cloud(Offset(w * 0.25, hz * 0.42), 180 * k, 10 * k, _alpha(_white, 0.16));
    cloud(Offset(w * 0.8, hz * 0.55), 160 * k, 8 * k, _alpha(s.glow, 0.3));
    final fujiPath = fuji(w * 0.5, 160 * k, 290 * k);
    // Low hazy hills and a far shore with town lights.
    hills(hz + 2 * k, 18 * k, haze(0.55), 3);
    for (var i = 0; i < 26; i++) {
      final o = Offset(rng.next() * w, hz - rng.next() * 4 * k);
      c.drawCircle(o, 0.9 * k, fill(_alpha(_warm, 0.9)));
    }
    final lake = Rect.fromLTRB(0, hz + 2 * k, w, hz + 96 * k);
    water(lake.top, lake.bottom, glowX: w * 0.5);
    // Mirror of the mountain, faint and clipped to the lake.
    c.save();
    c.clipRect(lake);
    c.saveLayer(lake, Paint()..color = const Color(0x48FFFFFF));
    c.translate(0, 2 * (hz + 2 * k));
    c.scale(1, -1);
    c.drawPath(fujiPath, fill(haze(0.3)));
    c.restore();
    c.restore();
    // Right shore: hill with the pagoda.
    final hill = Path()
      ..moveTo(w * 0.6, hz + 40 * k)
      ..quadraticBezierTo(w * 0.78, hz - 14 * k, w + 10 * k, hz - 6 * k)
      ..lineTo(w + 10 * k, hz + 100 * k)
      ..lineTo(w * 0.6, hz + 100 * k)
      ..close();
    c.drawPath(hill, fill(haze(0.78)));
    pagoda(w * 0.84, hz - 4 * k, 200 * k);
    torii(w * 0.2, hz + 52 * k, 92 * k);
    // Near shore under the trees.
    hills(hz + 98 * k, 14 * k, haze(0.88), 9);
    cherry(Offset(-8 * k, hz * 0.22), -0.2, 130 * k);
    cherry(Offset(w + 8 * k, hz * 0.1), math.pi + 0.25, 115 * k);
    settle(hz + 104 * k);
  }

  /// Returns the mountain outline so the lake can mirror it.
  Path fuji(double x, double ht, double half) {
    final top = hz - ht;
    final m = Path()
      ..moveTo(x - 14 * k, top)
      ..quadraticBezierTo(x - 6 * k, top - 3 * k, x + 2 * k, top + 1 * k)
      ..lineTo(x + 14 * k, top + 1 * k)
      ..quadraticBezierTo(x + half * 0.28, hz - ht * 0.22, x + half, hz + 4 * k)
      ..lineTo(x - half, hz + 4 * k)
      ..quadraticBezierTo(x - half * 0.28, hz - ht * 0.22, x - 14 * k, top)
      ..close();
    final bounds = m.getBounds();
    c.drawPath(
      m,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_mix(s.sky[0], s.sky[1], 0.4), haze(0.45)],
        ).createShader(bounds),
    );
    // Snow cap with a jagged lower edge, lit on the sunward side.
    c.save();
    c.clipPath(m);
    final snow = Path()..moveTo(x - half, top - 10 * k);
    final edge = top + ht * 0.36;
    var px = x - half * 0.5;
    snow.lineTo(px, edge);
    var up = true;
    while (px < x + half * 0.5) {
      px += rng.range(6, 13) * k;
      snow.lineTo(px, edge + (up ? -rng.range(4, 12) : rng.range(6, 22)) * k);
      up = !up;
    }
    snow
      ..lineTo(x + half, top - 10 * k)
      ..close();
    c.drawPath(
      snow,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _mix(_white, s.sky.last, 0.25),
            _mix(_white, s.sky[1], 0.45),
          ],
        ).createShader(Rect.fromLTRB(x - 40 * k, top, x + 40 * k, edge)),
    );
    // Shadowed gullies.
    final gully = Path();
    for (var i = -3; i <= 3; i++) {
      final gx = x + i * 9 * k;
      gully
        ..moveTo(gx, top + 8 * k)
        ..lineTo(gx + i * 6 * k - 2 * k, edge + 16 * k)
        ..lineTo(gx + i * 6 * k + 2 * k, edge + 16 * k)
        ..close();
    }
    c.drawPath(gully, fill(_alpha(haze(0.4), 0.35)));
    c.restore();
    return m;
  }

  /// Rolling band of hills with its top around [y].
  void hills(double y, double amp, Color col, int seed) {
    final p = Path()..moveTo(-2, h);
    for (var x = -2.0; x <= w + 6; x += 6 * k) {
      final u = x / (60 * k) + seed;
      p.lineTo(
        x,
        y - amp * (0.5 + 0.3 * math.sin(u) + 0.2 * math.sin(u * 2.7 + seed)),
      );
    }
    p
      ..lineTo(w + 6, h)
      ..close();
    c.drawPath(p, fill(col));
  }

  void pagoda(double x, double by, double H) {
    final col = haze(0.86);
    final body = Path();
    final rimLight = Path();
    body.addRect(Rect.fromLTRB(x - 0.2 * H, by - 0.04 * H, x + 0.2 * H, by));
    var y = by - 0.04 * H;
    for (var i = 0; i < 5; i++) {
      final bw = 0.15 * H * (1 - i * 0.11);
      final rw = bw + 0.11 * H * (1 - i * 0.1);
      final bh = (i == 0 ? 0.11 : 0.08) * H;
      body.addRect(Rect.fromLTRB(x - bw, y - bh, x + bw, y));
      // A warm lit opening on every storey.
      _win.addRect(
        Rect.fromCenter(
          center: Offset(x, y - bh * 0.45),
          width: bw * 0.5,
          height: bh * 0.45,
        ),
      );
      y -= bh;
      final tip = 0.045 * H;
      body
        ..moveTo(x - rw, y - tip)
        ..quadraticBezierTo(x - bw, y + 0.004 * H, x - bw * 0.6, y)
        ..lineTo(x + bw * 0.6, y)
        ..quadraticBezierTo(x + bw, y + 0.004 * H, x + rw, y - tip)
        ..lineTo(x + bw * 0.75, y - 0.055 * H)
        ..lineTo(x - bw * 0.75, y - 0.055 * H)
        ..close();
      rimLight
        ..moveTo(x - rw, y - tip)
        ..quadraticBezierTo(x - bw, y + 0.004 * H, x - bw * 0.6, y);
      glow(
        Offset(x - rw + 1 * k, y - tip + 5 * k),
        9 * k,
        color: _warm,
        a: 0.8,
      );
      glow(
        Offset(x + rw - 1 * k, y - tip + 5 * k),
        9 * k,
        color: _warm,
        a: 0.8,
      );
      y -= 0.05 * H;
    }
    // Finial spire with rings.
    body.addRect(Rect.fromLTRB(x - 0.008 * H, y - 0.22 * H, x + 0.008 * H, y));
    for (var i = 0; i < 6; i++) {
      body.addOval(
        Rect.fromCenter(
          center: Offset(x, y - 0.04 * H - i * 0.025 * H),
          width: 0.05 * H,
          height: 0.008 * H,
        ),
      );
    }
    c.drawPath(body, fill(col));
    c.drawPath(
      rimLight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * k
        ..color = _alpha(s.glow, 0.45),
    );
    lights(0.9);
  }

  void torii(double x, double by, double H) {
    const red = Color(0xFFC23A2C);
    final col = _mix(red, s.ground, 0.32);
    final g = Path();
    Offset p(double fx, double fy) => Offset(x + fx * H, by - fy * H);
    for (final sgn in [-1.0, 1.0]) {
      final b = p(sgn * 0.3, 0), t = p(sgn * 0.27, 0.86);
      g
        ..moveTo(b.dx - 0.035 * H, b.dy)
        ..lineTo(t.dx - 0.028 * H, t.dy)
        ..lineTo(t.dx + 0.028 * H, t.dy)
        ..lineTo(b.dx + 0.035 * H, b.dy)
        ..close();
    }
    g
      ..addRect(Rect.fromPoints(p(-0.42, 0.66), p(0.42, 0.71)))
      ..addRect(Rect.fromPoints(p(-0.025, 0.71), p(0.025, 0.84)))
      ..addRect(Rect.fromPoints(p(-0.47, 0.84), p(0.47, 0.89)));
    final a = p(-0.58, 1.0), b = p(0, 0.9), cc = p(0.58, 1.0);
    final d = p(0.5, 0.9), e = p(0, 0.86), f = p(-0.5, 0.9);
    g
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(b.dx, b.dy - 0.02 * H, cc.dx, cc.dy)
      ..lineTo(d.dx, d.dy)
      ..quadraticBezierTo(e.dx, e.dy, f.dx, f.dy)
      ..close();
    c.drawPath(g, fill(col));
    // Reflection in the lake.
    c.save();
    c.translate(0, 2 * by);
    c.scale(1, -1);
    c.drawPath(g, fill(_alpha(col, 0.28)));
    c.restore();
  }

  /// Branching cherry tree reaching in from an edge, crowned in blossom.
  void cherry(Offset root, double angle, double len) {
    const depth = 4;
    final wood = List.generate(depth + 1, (_) => Path());
    final bloom = [Path(), Path(), Path(), Path()];
    void cluster(Offset o, double spread, int n) {
      for (var i = 0; i < n; i++) {
        final off = Offset(rng.range(-1, 1), rng.range(-0.75, 0.6)) * spread;
        // Darker blossoms underneath, highlights on top.
        final tone = ((off.dy / spread + 0.75) / 1.35 * 2 + rng.next() * 1.6)
            .floor()
            .clamp(0, 3);
        bloom[3 - tone].addOval(
          Rect.fromCircle(center: o + off, radius: rng.range(2.2, 4.6) * k),
        );
      }
    }

    void branch(Offset o, double a, double l, int d) {
      final end = o + Offset(math.cos(a), math.sin(a)) * l;
      final mid =
          Offset.lerp(o, end, 0.5)! +
          Offset(-math.sin(a), math.cos(a)) * l * 0.14 * (d.isEven ? 1 : -1);
      wood[d]
        ..moveTo(o.dx, o.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
      if (d < 2) cluster(Offset.lerp(o, end, 0.6)!, 12 * k, 10);
      if (d == 0) {
        cluster(end, 18 * k, 26);
        return;
      }
      branch(end, a - rng.range(0.25, 0.6), l * rng.range(0.62, 0.78), d - 1);
      branch(end, a + rng.range(0.25, 0.6), l * rng.range(0.62, 0.78), d - 1);
    }

    branch(root, angle, len * 0.5, depth);
    final bark = _mix(const Color(0xFF3A1E26), s.ground, 0.3);
    for (var d = 0; d <= depth; d++) {
      c.drawPath(
        wood[d],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1.2 + d * 1.3) * k
          ..strokeCap = StrokeCap.round
          ..color = bark,
      );
    }
    const pinks = [
      Color(0xFFC85A8A),
      Color(0xFFE88AB2),
      Color(0xFFF7B4CE),
      Color(0xFFFFE0EC),
    ];
    for (var i = 0; i < 4; i++) {
      c.drawPath(bloom[i], fill(_mix(pinks[i], s.sky[1], 0.1)));
    }
  }

  // ------------------------------------------------------------- london

  void london() {
    sky();
    stars(30, hz * 0.4, 0.5);
    horizonGlow(w * 0.48, 300 * k, 0.7);
    glow(Offset(w * 0.5, hz - 10 * k), 70 * k, a: 0.4);
    cloud(Offset(w * 0.3, hz * 0.3), 220 * k, 12 * k, _alpha(s.glow, 0.14));
    cloud(Offset(w * 0.7, hz * 0.55), 180 * k, 8 * k, _alpha(s.glow, 0.22));
    // Far skyline: London Eye, a dome and hazy blocks.
    final far = haze(0.32);
    eye(Offset(w * 0.86, hz - 58 * k), 54 * k, far);
    var x = 0.0;
    final blocks = Path();
    while (x < w) {
      final bw = rng.range(14, 34) * k;
      final bh = rng.range(10, 46) * k;
      blocks.addRect(Rect.fromLTWH(x, hz - bh, bw, bh + 2 * k));
      windows(
        Rect.fromLTWH(x + 2 * k, hz - bh + 3 * k, bw - 4 * k, bh),
        p: 0.2,
      );
      x += bw;
    }
    // A cathedral dome on the far skyline.
    final dx = w * 0.7;
    blocks
      ..addRect(Rect.fromLTWH(dx - 16 * k, hz - 48 * k, 32 * k, 48 * k))
      ..addArc(
        Rect.fromCenter(
          center: Offset(dx, hz - 48 * k),
          width: 30 * k,
          height: 34 * k,
        ),
        math.pi,
        math.pi,
      )
      ..addRect(Rect.fromLTWH(dx - 2.5 * k, hz - 76 * k, 5 * k, 12 * k));
    c.drawPath(blocks, fill(far));
    lights(0.5);
    // Parliament along the bank, Big Ben at its end.
    final mid = haze(0.66);
    parliament(w * 0.2, w * 0.62, hz + 2 * k, 46 * k, mid);
    tower(w * 0.63, hz + 2 * k, 150 * k, mid);
    bigBen(w * 0.2, hz + 2 * k, 255 * k, mid);
    water(hz + 2 * k, hz + 110 * k, glowX: w * 0.45);
    reflection(w * 0.2, hz + 4 * k, 60 * k, 9 * k, _hot);
    for (var i = 0; i < 10; i++) {
      reflection(w * (0.22 + i * 0.042), hz + 4 * k, 30 * k, 3 * k, _warm);
    }
    // Arched stone bridge across the Thames with lamps.
    bridge(hz + 52 * k, 9 * k, hz + 84 * k, 74 * k, haze(0.84));
    for (var x = w * 0.05; x < w; x += 37 * k) {
      lamp(Offset(x, hz + 52 * k), 15 * k, haze(0.9));
    }
    settle(hz + 92 * k);
    // Big lamp posts at the very edges, outside the board.
    lamp(
      Offset(10 * k, hz + 190 * k),
      120 * k,
      _mix(s.ground, const Color(0xFF000000), 0.3),
    );
    lamp(
      Offset(w - 10 * k, hz + 190 * k),
      120 * k,
      _mix(s.ground, const Color(0xFF000000), 0.3),
    );
  }

  void eye(Offset o, double r, Color col) {
    final st = Paint()
      ..style = PaintingStyle.stroke
      ..color = col
      ..strokeWidth = 1.6 * k;
    c.drawCircle(o, r, st);
    c.drawCircle(o, r * 0.94, st..strokeWidth = 0.7 * k);
    final spokes = Path();
    final pods = Path();
    for (var i = 0; i < 32; i++) {
      final a = i / 32 * math.pi * 2;
      final e = o + Offset(math.cos(a), math.sin(a)) * r;
      if (i.isEven) {
        spokes
          ..moveTo(o.dx, o.dy)
          ..lineTo(e.dx, e.dy);
      }
      pods.addOval(Rect.fromCircle(center: e, radius: 1.5 * k));
    }
    spokes
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx - r * 0.45, hz + 2 * k)
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + r * 0.1, hz + 2 * k);
    c.drawPath(spokes, st..strokeWidth = 0.5 * k);
    c.drawPath(pods, fill(_alpha(const Color(0xFFBFD8FF), 0.8)));
  }

  void parliament(double x0, double x1, double by, double ht, Color col) {
    final p = Path()..addRect(Rect.fromLTRB(x0, by - ht, x1, by));
    for (var x = x0 + 4 * k; x < x1; x += 9 * k) {
      final t = (x - x0) / (x1 - x0);
      final spike = (t - 0.5).abs() < 0.03 ? 40 * k : 11 * k;
      p
        ..moveTo(x - 1.6 * k, by - ht)
        ..lineTo(x, by - ht - spike)
        ..lineTo(x + 1.6 * k, by - ht)
        ..close();
    }
    // Central lantern tower.
    final cx = (x0 + x1) / 2;
    p.addRect(Rect.fromLTRB(cx - 6 * k, by - ht - 22 * k, cx + 6 * k, by - ht));
    c.drawPath(p, fill(col));
    windows(
      Rect.fromLTRB(x0 + 2 * k, by - ht + 6 * k, x1 - 2 * k, by - 2 * k),
      cw: 6,
      ch: 11,
      ww: 2.4,
      wh: 6,
      p: 0.55,
    );
    lights();
  }

  /// Victoria Tower: square, with corner pinnacles.
  void tower(double x, double by, double H, Color col) {
    final hw = 0.11 * H;
    final p = Path()..addRect(Rect.fromLTRB(x - hw, by - 0.9 * H, x + hw, by));
    for (final f in [-1.0, -0.33, 0.33, 1.0]) {
      final px = x + f * hw;
      p
        ..moveTo(px - 2 * k, by - 0.9 * H)
        ..lineTo(px, by - H)
        ..lineTo(px + 2 * k, by - 0.9 * H)
        ..close();
    }
    c.drawPath(p, fill(col));
    windows(
      Rect.fromLTRB(
        x - hw + 3 * k,
        by - 0.85 * H,
        x + hw - 3 * k,
        by - 0.3 * H,
      ),
      cw: 7,
      ch: 16,
      ww: 2.4,
      wh: 9,
      p: 0.4,
    );
    lights();
  }

  void bigBen(double x, double by, double H, Color col) {
    Rect r(double l, double t, double rr, double b) =>
        Rect.fromLTRB(x + l * H, by - t * H, x + rr * H, by - b * H);
    final p = Path()
      ..addRect(r(-0.06, 0.62, 0.06, 0))
      ..addRect(r(-0.075, 0.77, 0.075, 0.62))
      ..addRect(r(-0.065, 0.85, 0.065, 0.77));
    for (final f in [-0.075, 0.075]) {
      p
        ..moveTo(x + (f - 0.012) * H, by - 0.77 * H)
        ..lineTo(x + f * H, by - 0.82 * H)
        ..lineTo(x + (f + 0.012) * H, by - 0.77 * H)
        ..close();
    }
    Offset o(double fx, double fy) => Offset(x + fx * H, by - fy * H);
    final pts = [
      o(-0.07, 0.85),
      o(-0.034, 0.93),
      o(-0.008, 0.98),
      o(0, 1.03),
      o(0.008, 0.98),
      o(0.034, 0.93),
      o(0.07, 0.85),
    ];
    p.addPolygon(pts, true);
    glow(o(0, 0.69), 0.2 * H, a: 0.4);
    c.drawPath(p, fill(col));
    // Recessed vertical panels on the shaft.
    final panels = Path();
    for (final f in [-0.035, 0, 0.035]) {
      panels.addRect(r(f - 0.006, 0.6, f + 0.006, 0.05));
    }
    c.drawPath(panels, fill(_alpha(s.glow, 0.13)));
    // Belfry windows.
    for (final f in [-0.035, 0, 0.035]) {
      _win.addRect(r(f - 0.009, 0.835, f + 0.009, 0.79));
    }
    lights(0.9);
    // Lit clock face.
    final cc = o(0, 0.695);
    final cr = 0.052 * H;
    glow(cc, cr * 3, color: _hot, a: 0.55);
    c.drawCircle(cc, cr * 1.15, fill(_mix(col, s.ground, 0.4)));
    c.drawCircle(
      cc,
      cr,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFFFFF6D8), Color(0xFFFFD98A)],
        ).createShader(Rect.fromCircle(center: cc, radius: cr)),
    );
    final hand = Paint()
      ..color = const Color(0xFF3A2A1A)
      ..strokeWidth = 0.9 * k
      ..strokeCap = StrokeCap.round;
    c.drawLine(cc, cc + Offset(0, -cr * 0.8), hand);
    c.drawLine(cc, cc + Offset(cr * 0.5, cr * 0.15), hand);
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2;
      c.drawCircle(
        cc + Offset(math.cos(a), math.sin(a)) * cr * 0.85,
        0.5 * k,
        hand,
      );
    }
  }

  /// Masonry bridge whose arches open onto the water at [waterY].
  void bridge(
    double deck,
    double thick,
    double waterY,
    double span,
    Color col,
  ) {
    final band = Rect.fromLTRB(0, deck, w, waterY);
    final p = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(band);
    final archH = (waterY - deck - thick) * 2;
    for (var x = -span * 0.3; x < w + span; x += span) {
      p.addOval(
        Rect.fromCenter(
          center: Offset(x, waterY),
          width: span * 0.84,
          height: archH,
        ),
      );
    }
    c.save();
    c.clipRect(band);
    c.drawPath(p, fill(col));
    c.restore();
    c.drawRect(
      Rect.fromLTWH(0, deck - 1.2 * k, w, 1.4 * k),
      fill(_alpha(s.glow, 0.35)),
    );
  }

  // ----------------------------------------------------------- new york

  void newYork() {
    sky();
    stars(90, hz * 0.62, 0.7);
    horizonGlow(w * 0.5, 320 * k, 0.65);
    cloud(Offset(w * 0.4, hz * 0.62), 240 * k, 8 * k, _alpha(s.glow, 0.2));
    // Far towers.
    towers(-6 * k, w + 6 * k, 30, 120, 14, 28, haze(0.4), 0.16, 0.5);
    // Mid towers with the famous three among them.
    towers(w * 0.18, w * 0.84, 60, 150, 18, 32, haze(0.66), 0.35, 1);
    final mid = haze(0.72);
    chrysler(w * 0.32, hz + 2 * k, 210 * k, mid);
    empire(w * 0.48, hz + 2 * k, 245 * k, mid);
    oneWtc(w * 0.66, hz + 2 * k, 272 * k, mid);
    water(hz + 2 * k, hz + 110 * k, glowX: w * 0.5);
    for (var i = 0; i < 26; i++) {
      final x = w * (0.15 + rng.next() * 0.7);
      reflection(
        x,
        hz + 4 * k,
        rng.range(16, 40) * k,
        2.5 * k,
        rng.next() < 0.3 ? _hot : _warm,
      );
    }
    suspension(hz + 30 * k, haze(0.82));
    liberty(w * 0.14, hz + 70 * k, 215 * k);
    settle(hz + 100 * k);
  }

  void towers(
    double x0,
    double x1,
    double minH,
    double maxH,
    double minW,
    double maxW,
    Color col,
    double lit,
    double winA,
  ) {
    final p = Path();
    var x = x0;
    while (x < x1) {
      final bw = rng.range(minW, maxW) * k;
      final bh = rng.range(minH, maxH) * k;
      final top = hz + 2 * k - bh;
      p.addRect(Rect.fromLTWH(x, top, bw, bh));
      if (rng.next() < 0.35) {
        // Setback crown.
        p.addRect(Rect.fromLTWH(x + bw * 0.2, top - 10 * k, bw * 0.6, 10 * k));
      }
      if (rng.next() < 0.2) {
        p.addRect(Rect.fromLTWH(x + bw / 2 - 0.5 * k, top - 26 * k, k, 26 * k));
      }
      windows(
        Rect.fromLTRB(x + 2 * k, top + 3 * k, x + bw - 2 * k, hz),
        cw: 5,
        ch: 6,
        ww: 2.2,
        wh: 2.6,
        p: lit,
      );
      x += bw + rng.range(-4, 2) * k;
    }
    c.drawPath(p, fill(col));
    lights(winA);
  }

  void empire(double x, double by, double H, Color col) {
    Rect r(double hw, double t, double b) =>
        Rect.fromLTRB(x - hw * H, by - t * H, x + hw * H, by - b * H);
    final p = Path()
      ..addRect(r(0.1, 0.42, 0))
      ..addRect(r(0.075, 0.7, 0.42))
      ..addRect(r(0.055, 0.76, 0.7))
      ..addRect(r(0.035, 0.82, 0.76))
      ..addRect(r(0.02, 0.88, 0.82))
      ..addRect(r(0.004, 1, 0.88));
    glow(Offset(x, by - 0.8 * H), 0.25 * H, a: 0.4);
    c.drawPath(p, fill(col));
    windows(r(0.065, 0.68, 0.02), cw: 5, ch: 6, ww: 2, wh: 2.6, p: 0.45);
    lights();
    // Floodlit crown.
    c.drawRect(r(0.035, 0.82, 0.76), fill(_alpha(s.glow, 0.28)));
    c.drawRect(r(0.02, 0.88, 0.82), fill(_alpha(_hot, 0.3)));
  }

  void chrysler(double x, double by, double H, Color col) {
    final p = Path()
      ..addRect(Rect.fromLTRB(x - 0.08 * H, by - 0.72 * H, x + 0.08 * H, by));
    final crown = Path();
    // Stacked sunburst arches narrowing to the needle.
    for (var i = 0; i < 5; i++) {
      final hw = 0.075 * H * (1 - i * 0.18);
      final base = by - (0.72 + i * 0.045) * H;
      final arch = Rect.fromLTRB(
        x - hw,
        base - hw * 1.2,
        x + hw,
        base + hw * 1.2,
      );
      p.addArc(arch, math.pi, math.pi);
      crown.addArc(arch, math.pi, math.pi);
    }
    p.addPolygon([
      Offset(x - 0.012 * H, by - 0.9 * H),
      Offset(x, by - H),
      Offset(x + 0.012 * H, by - 0.9 * H),
    ], true);
    c.drawPath(p, fill(col));
    windows(
      Rect.fromLTRB(x - 0.07 * H, by - 0.7 * H, x + 0.07 * H, by),
      cw: 5,
      ch: 6,
      ww: 2,
      wh: 2.6,
      p: 0.4,
    );
    lights();
    c.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 * k
        ..color = _alpha(_hot, 0.8),
    );
  }

  void oneWtc(double x, double by, double H, Color col) {
    final p = Path()
      ..addPolygon([
        Offset(x - 0.075 * H, by),
        Offset(x - 0.075 * H, by - 0.12 * H),
        Offset(x - 0.04 * H, by - 0.82 * H),
        Offset(x + 0.04 * H, by - 0.82 * H),
        Offset(x + 0.075 * H, by - 0.12 * H),
        Offset(x + 0.075 * H, by),
      ], true)
      ..addRect(
        Rect.fromLTRB(x - 0.003 * H, by - H, x + 0.003 * H, by - 0.82 * H),
      );
    c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          colors: [_mix(col, s.sky[1], 0.3), col, _mix(col, s.ground, 0.4)],
          stops: const [0, 0.5, 0.5],
        ).createShader(Rect.fromLTRB(x - 0.075 * H, 0, x + 0.075 * H, 1)),
    );
    // Glass catches the sunset along the left facet.
    c.drawLine(
      Offset(x - 0.073 * H, by - 0.12 * H),
      Offset(x - 0.04 * H, by - 0.82 * H),
      Paint()
        ..strokeWidth = 1 * k
        ..color = _alpha(s.glow, 0.6),
    );
    glow(Offset(x, by - H), 10 * k, color: const Color(0xFFFF6A6A), a: 0.9);
  }

  void suspension(double deck, Color col) {
    final t1 = w * 0.62, t2 = w * 1.02, top = deck - 130 * k;
    final towers = Path()..fillType = PathFillType.evenOdd;
    for (final tx in [t1, t2]) {
      towers.addRect(
        Rect.fromLTRB(tx - 13 * k, top, tx + 13 * k, deck + 18 * k),
      );
      for (final f in [-1.0, 1.0]) {
        final ax = tx + f * 5.5 * k;
        towers
          ..moveTo(ax - 3.5 * k, deck - 10 * k)
          ..lineTo(ax - 3.5 * k, top + 34 * k)
          ..quadraticBezierTo(ax, top + 22 * k, ax + 3.5 * k, top + 34 * k)
          ..lineTo(ax + 3.5 * k, deck - 10 * k)
          ..close();
      }
    }
    final cable = Path()
      ..moveTo(w * 0.42, deck)
      ..quadraticBezierTo(t1 - 40 * k, deck - 20 * k, t1, top + 4 * k)
      ..quadraticBezierTo(
        (t1 + t2) / 2,
        2 * (deck - 6 * k) - top,
        t2,
        top + 4 * k,
      )
      ..quadraticBezierTo(t2 + 40 * k, deck - 30 * k, w * 1.4, deck);
    // Hangers from the cable to the deck.
    final hangers = Path();
    for (final m in cable.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7 * k) {
        final pos = m.getTangentForOffset(d)!.position;
        hangers
          ..moveTo(pos.dx, pos.dy)
          ..lineTo(pos.dx, deck);
      }
    }
    c.drawPath(
      hangers,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 * k
        ..color = _alpha(col, 0.7),
    );
    c.drawPath(
      cable,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * k
        ..color = col,
    );
    c.drawPath(towers, fill(_mix(col, s.glow, 0.1)));
    c.drawPath(
      towers,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * k
        ..color = _alpha(s.glow, 0.35),
    );
    c.drawRect(Rect.fromLTRB(w * 0.4, deck, w, deck + 6 * k), fill(col));
    // String of lights along cable and deck.
    final dots = Path();
    for (final m in cable.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 6 * k) {
        dots.addOval(
          Rect.fromCircle(
            center: m.getTangentForOffset(d)!.position,
            radius: 1.1 * k,
          ),
        );
      }
    }
    for (var x = w * 0.42; x < w; x += 8 * k) {
      dots.addOval(
        Rect.fromCircle(center: Offset(x, deck + 1 * k), radius: 1.1 * k),
      );
    }
    c.drawPath(
      dots,
      fill(_hot)..maskFilter = MaskFilter.blur(BlurStyle.solid, 1.4 * k),
    );
  }

  void liberty(double x, double by, double H) {
    final col = _mix(const Color(0xFF4A9C8E), s.ground, 0.38);
    final stone = haze(0.85);
    Offset o(double fx, double fy) => Offset(x + fx * H, by - fy * H);
    // Island and star-fort base.
    c.drawOval(
      Rect.fromCenter(center: o(0, 0), width: 0.75 * H, height: 0.08 * H),
      fill(_mix(stone, s.ground, 0.4)),
    );
    final ped = Path()
      ..addRect(Rect.fromPoints(o(-0.15, 0.05), o(0.15, 0)))
      ..addPolygon([
        o(-0.08, 0.05),
        o(-0.062, 0.36),
        o(0.062, 0.36),
        o(0.08, 0.05),
      ], true)
      ..addRect(Rect.fromPoints(o(-0.074, 0.38), o(0.074, 0.36)));
    c.drawPath(ped, fill(stone));
    windows(
      Rect.fromPoints(o(-0.055, 0.33), o(0.055, 0.26)),
      cw: 8,
      ch: 8,
      ww: 2,
      wh: 4,
      p: 0.6,
    );
    lights(0.8);
    glow(o(-0.06, 0.97), 0.14 * H, color: _hot, a: 0.8);
    final fig = Path()
      ..moveTo(o(-0.062, 0.38).dx, o(-0.062, 0.38).dy)
      ..lineTo(o(-0.05, 0.6).dx, o(-0.05, 0.6).dy)
      ..quadraticBezierTo(
        o(-0.048, 0.72).dx,
        o(-0.048, 0.72).dy,
        o(-0.03, 0.77).dx,
        o(-0.03, 0.77).dy,
      )
      ..lineTo(o(0.032, 0.77).dx, o(0.032, 0.77).dy)
      ..quadraticBezierTo(
        o(0.05, 0.72).dx,
        o(0.05, 0.72).dy,
        o(0.052, 0.6).dx,
        o(0.052, 0.6).dy,
      )
      ..lineTo(o(0.066, 0.38).dx, o(0.066, 0.38).dy)
      ..close()
      ..addOval(Rect.fromCircle(center: o(0, 0.8), radius: 0.026 * H))
      ..addRect(Rect.fromPoints(o(-0.008, 0.79), o(0.008, 0.76)));
    for (var i = 0; i < 5; i++) {
      final a = -math.pi * (0.15 + i * 0.175);
      final c0 = o(0, 0.8);
      final dir = Offset(math.cos(a), math.sin(a));
      final perp = Offset(-dir.dy, dir.dx) * 0.006 * H;
      final b = c0 + dir * 0.02 * H;
      fig.addPolygon([b - perp, c0 + dir * 0.06 * H, b + perp], true);
    }
    // Tablet held at the left side.
    fig.addPolygon([
      o(0.035, 0.6),
      o(0.07, 0.62),
      o(0.06, 0.7),
      o(0.028, 0.68),
    ], true);
    c.drawPath(
      fig,
      Paint()
        ..shader = LinearGradient(
          colors: [_mix(col, s.glow, 0.25), col, _mix(col, s.ground, 0.3)],
        ).createShader(Rect.fromPoints(o(-0.07, 1), o(0.07, 0.38))),
    );
    // Raised arm and torch.
    c.drawLine(
      o(-0.024, 0.75),
      o(-0.055, 0.93),
      Paint()
        ..color = col
        ..strokeWidth = 0.024 * H
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      Path()..addPolygon([
        o(-0.07, 0.955),
        o(-0.04, 0.955),
        o(-0.05, 0.93),
        o(-0.06, 0.93),
      ], true),
      fill(col),
    );
    final flame = o(-0.055, 0.975);
    c.drawOval(
      Rect.fromCenter(center: flame, width: 0.022 * H, height: 0.035 * H),
      fill(_hot),
    );
  }

  // -------------------------------------------------------------- delhi

  void delhi() {
    sky();
    horizonGlow(w * 0.38, 340 * k, 0.85);
    final sun = Offset(w * 0.38, hz - 26 * k);
    glow(sun, 150 * k, a: 0.6);
    c.drawCircle(sun, 30 * k, fill(_mix(s.glow, _white, 0.45)));
    cloud(Offset(w * 0.25, hz * 0.55), 200 * k, 8 * k, _alpha(s.glow, 0.35));
    cloud(Offset(w * 0.72, hz * 0.4), 170 * k, 10 * k, _alpha(_white, 0.18));
    cloud(Offset(w * 0.5, hz * 0.75), 260 * k, 6 * k, _alpha(s.sky[1], 0.4));
    birds(Offset(w * 0.6, hz * 0.45), 9);
    // Hazy city and tree line.
    final far = haze(0.32);
    hills(hz + 2 * k, 10 * k, far, 5);
    final domes = Path();
    for (var i = 0; i < 8; i++) {
      final dx = rng.next() * w, r = rng.range(5, 10) * k;
      domes
        ..addArc(
          Rect.fromCircle(center: Offset(dx, hz - 6 * k), radius: r),
          math.pi,
          math.pi,
        )
        ..addRect(Rect.fromLTWH(dx - r, hz - 6 * k, 2 * r, 8 * k));
    }
    c.drawPath(domes, fill(far));
    taj(w * 0.64, hz + 2 * k, 185 * k);
    indiaGate(w * 0.16, hz + 6 * k, 130 * k);
    water(hz + 4 * k, hz + 70 * k, glowX: w * 0.38);
    reflection(w * 0.38, hz + 6 * k, 60 * k, 26 * k, _mix(s.glow, _white, 0.4));
    // Ghat steps lined with diyas.
    final steps = haze(0.82);
    for (var i = 0; i < 4; i++) {
      c.drawRect(
        Rect.fromLTRB(0, hz + (70 + i * 7) * k, w, h),
        fill(_mix(steps, s.ground, i * 0.15)),
      );
    }
    for (var x = w * 0.06; x < w; x += 40 * k) {
      diya(Offset(x + rng.range(-6, 6) * k, hz + 72 * k));
    }
    palm(Offset(w * 0.02, hz + 200 * k), Offset(w * 0.1, hz - 50 * k), 1);
    palm(Offset(w * 0.98, hz + 210 * k), Offset(w * 0.92, hz - 20 * k), 0.9);
    palm(Offset(w * 1.04, hz + 200 * k), Offset(w * 1.0, hz - 80 * k), 1.05);
    settle(hz + 110 * k);
  }

  void birds(Offset o, int n) {
    final p = Path();
    for (var i = 0; i < n; i++) {
      final b = o + Offset(rng.range(-50, 50), rng.range(-25, 25)) * k;
      final s = rng.range(3, 6) * k;
      p
        ..moveTo(b.dx - s, b.dy - s * 0.3)
        ..quadraticBezierTo(b.dx - s * 0.4, b.dy - s * 0.5, b.dx, b.dy)
        ..quadraticBezierTo(
          b.dx + s * 0.4,
          b.dy - s * 0.5,
          b.dx + s,
          b.dy - s * 0.3,
        );
    }
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * k
        ..color = _alpha(haze(0.7), 0.8),
    );
  }

  void taj(double x, double by, double H) {
    final col = _mix(s.sky[1], s.ground, 0.4);
    Offset o(double fx, double fy) => Offset(x + fx * H, by - fy * H);
    Rect r(double l, double t, double rr, double b) =>
        Rect.fromPoints(o(l, t), o(rr, b));
    final p = Path()
      ..addRect(r(-0.5, 0.05, 0.5, 0))
      ..addPolygon([
        o(-0.27, 0.05),
        o(-0.27, 0.29),
        o(-0.23, 0.33),
        o(0.23, 0.33),
        o(0.27, 0.29),
        o(0.27, 0.05),
      ], true)
      ..addRect(r(-0.1, 0.37, 0.1, 0.33))
      ..addRect(r(-0.12, 0.43, 0.12, 0.33));
    void dome(double cx, double base, double hw, double ht) {
      final a = o(cx - hw, base);
      p
        ..moveTo(a.dx, a.dy)
        ..cubicTo(
          o(cx - hw * 1.65, base + ht * 0.15).dx,
          o(cx - hw * 1.65, base + ht * 0.15).dy,
          o(cx - hw * 1.4, base + ht * 0.55).dx,
          o(cx - hw * 1.4, base + ht * 0.55).dy,
          o(cx - hw * 0.6, base + ht * 0.78).dx,
          o(cx - hw * 0.6, base + ht * 0.78).dy,
        )
        ..quadraticBezierTo(
          o(cx - hw * 0.12, base + ht * 0.9).dx,
          o(cx - hw * 0.12, base + ht * 0.9).dy,
          o(cx, base + ht).dx,
          o(cx, base + ht).dy,
        )
        ..quadraticBezierTo(
          o(cx + hw * 0.12, base + ht * 0.9).dx,
          o(cx + hw * 0.12, base + ht * 0.9).dy,
          o(cx + hw * 0.6, base + ht * 0.78).dx,
          o(cx + hw * 0.6, base + ht * 0.78).dy,
        )
        ..cubicTo(
          o(cx + hw * 1.4, base + ht * 0.55).dx,
          o(cx + hw * 1.4, base + ht * 0.55).dy,
          o(cx + hw * 1.65, base + ht * 0.15).dx,
          o(cx + hw * 1.65, base + ht * 0.15).dy,
          o(cx + hw, base).dx,
          o(cx + hw, base).dy,
        )
        ..close()
        ..addRect(
          r(cx - hw * 0.06, base + ht * 1.28, cx + hw * 0.06, base + ht * 0.95),
        );
    }

    dome(0, 0.43, 0.115, 0.34);
    for (final f in [-0.2, 0.2]) {
      p.addRect(r(f - 0.04, 0.38, f + 0.04, 0.33));
      dome(f, 0.38, 0.035, 0.08);
    }
    for (final f in [-0.45, 0.45]) {
      p
        ..addPolygon([
          o(f - 0.022, 0.05),
          o(f - 0.017, 0.6),
          o(f + 0.017, 0.6),
          o(f + 0.022, 0.05),
        ], true)
        ..addRect(r(f - 0.03, 0.26, f + 0.03, 0.245))
        ..addRect(r(f - 0.028, 0.44, f + 0.028, 0.425))
        ..addRect(r(f - 0.026, 0.61, f + 0.026, 0.595));
      dome(f, 0.61, 0.022, 0.05);
    }
    final b = p.getBounds();
    c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          colors: [_mix(col, s.glow, 0.35), col, _mix(col, s.ground, 0.25)],
          stops: const [0, 0.45, 1],
        ).createShader(b),
    );
    // Arched recesses in shadow.
    final rec = Path();
    void arch(double cx, double bottom, double hw, double ht) {
      final a = o(cx - hw, bottom), top = o(cx, bottom + ht);
      final sh = o(cx - hw, bottom + ht * 0.72),
          sh2 = o(cx + hw, bottom + ht * 0.72);
      rec
        ..moveTo(a.dx, a.dy)
        ..lineTo(sh.dx, sh.dy)
        ..quadraticBezierTo(sh.dx, top.dy, top.dx, top.dy)
        ..quadraticBezierTo(sh2.dx, top.dy, sh2.dx, sh2.dy)
        ..lineTo(o(cx + hw, bottom).dx, a.dy)
        ..close();
    }

    arch(0, 0.05, 0.065, 0.26);
    for (final f in [-0.19, -0.13, 0.13, 0.19]) {
      arch(f, 0.07, 0.022, 0.1);
      arch(f, 0.19, 0.022, 0.1);
    }
    c.drawPath(rec, fill(_mix(col, s.ground, 0.45)));
    // Reflection in the pool.
    c.save();
    c.clipRect(Rect.fromLTRB(0, by, w, by + 70 * k));
    c.translate(0, 2 * by);
    c.scale(1, -1);
    c.drawPath(p, fill(_alpha(col, 0.3)));
    c.restore();
  }

  void indiaGate(double x, double by, double H) {
    final col = haze(0.68);
    Offset o(double fx, double fy) => Offset(x + fx * H, by - fy * H);
    final p = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromPoints(o(-0.32, 0.78), o(0.32, 0)))
      ..addRect(Rect.fromPoints(o(-0.35, 0.82), o(0.35, 0.78)))
      ..addRect(Rect.fromPoints(o(-0.26, 0.95), o(0.26, 0.82)));
    final hole = Path()
      ..moveTo(o(-0.13, 0).dx, o(-0.13, 0).dy)
      ..lineTo(o(-0.13, 0.45).dx, o(-0.13, 0.45).dy)
      ..arcToPoint(o(0.13, 0.45), radius: Radius.circular(0.13 * H))
      ..lineTo(o(0.13, 0).dx, o(0.13, 0).dy)
      ..close();
    final gate = Path.combine(PathOperation.difference, p, hole)
      ..addOval(
        Rect.fromCenter(center: o(0, 0.95), width: 0.18 * H, height: 0.08 * H),
      );
    c.drawPath(gate, fill(col));
    // Inscription band and the eternal flame.
    c.drawRect(
      Rect.fromPoints(o(-0.24, 0.9), o(0.24, 0.87)),
      fill(_alpha(s.glow, 0.25)),
    );
    glow(o(0, 0.04), 24 * k, color: _warm, a: 0.9);
  }

  void diya(Offset o) {
    glow(o + Offset(0, -4 * k), 22 * k, color: _warm, a: 0.7);
    c.drawPath(
      Path()
        ..moveTo(o.dx - 5 * k, o.dy - 2 * k)
        ..quadraticBezierTo(o.dx, o.dy + 4 * k, o.dx + 5 * k, o.dy - 2 * k)
        ..close(),
      fill(const Color(0xFFB0532A)),
    );
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - 9 * k)
        ..quadraticBezierTo(o.dx + 2.4 * k, o.dy - 4 * k, o.dx, o.dy - 2 * k)
        ..quadraticBezierTo(o.dx - 2.4 * k, o.dy - 4 * k, o.dx, o.dy - 9 * k),
      fill(_hot),
    );
  }

  void palm(Offset base, Offset crown, double sc) {
    final col = _mix(s.ground, const Color(0xFF000000), 0.2);
    final ctrl = Offset(
      (base.dx + crown.dx) / 2 + 20 * k * sc,
      (base.dy + crown.dy) / 2,
    );
    final trunk = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, crown.dx, crown.dy);
    final m = trunk.computeMetrics().first;
    for (var d = 0.0; d < m.length; d += 6 * k) {
      final f = d / m.length;
      c.drawCircle(
        m.getTangentForOffset(d)!.position,
        (6 - f * 3) * k * sc,
        fill(col),
      );
    }
    final leaves = Path();
    final leaflets = Path();
    for (var i = 0; i < 9; i++) {
      final a = -math.pi + i / 8 * math.pi + rng.range(-0.15, 0.15);
      final len = rng.range(60, 85) * k * sc;
      final dir = Offset(math.cos(a), math.sin(a) * 0.55);
      final tip = crown + dir * len + Offset(0, len * 0.45);
      final ctl = crown + dir * len * 0.55 - Offset(0, len * 0.2);
      leaves
        ..moveTo(crown.dx, crown.dy)
        ..quadraticBezierTo(ctl.dx, ctl.dy - 4 * k, tip.dx, tip.dy)
        ..quadraticBezierTo(ctl.dx, ctl.dy + 4 * k, crown.dx, crown.dy + 3 * k);
      for (var t = 0.1; t < 1; t += 0.07) {
        final pt = Offset(
          (1 - t) * (1 - t) * crown.dx +
              2 * (1 - t) * t * ctl.dx +
              t * t * tip.dx,
          (1 - t) * (1 - t) * crown.dy +
              2 * (1 - t) * t * ctl.dy +
              t * t * tip.dy,
        );
        final ll = (1 - t) * 16 * k * sc + 4 * k;
        leaflets
          ..moveTo(pt.dx, pt.dy)
          ..lineTo(pt.dx + dir.dx * ll * 0.3 - 3 * k, pt.dy + ll)
          ..moveTo(pt.dx, pt.dy)
          ..lineTo(pt.dx + dir.dx * ll * 0.3 + 3 * k, pt.dy + ll * 0.8);
      }
    }
    c.drawPath(leaves, fill(col));
    c.drawPath(
      leaflets,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * k
        ..strokeCap = StrokeCap.round
        ..color = col,
    );
  }

  // ---------------------------------------------------------- northeast

  void northeast() {
    sky();
    final sun = Offset(w * 0.76, hz * 0.28);
    glow(sun, 160 * k, color: _white, a: 0.5);
    glow(sun, 60 * k, a: 0.8);
    c.drawCircle(sun, 18 * k, fill(_mix(_white, s.glow, 0.25)));
    for (var i = 0; i < 6; i++) {
      final o = Offset(rng.next() * w, hz * rng.range(0.15, 0.7));
      final cw = rng.range(80, 160) * k;
      cloud(o, cw, cw * 0.18, _alpha(_white, 0.55));
      cloud(
        o + Offset(cw * 0.15, -cw * 0.05),
        cw * 0.5,
        cw * 0.2,
        _alpha(_white, 0.5),
      );
    }
    double ridge(double x, double base, double amp, double seed) {
      final u = x / (70 * k) + seed;
      return base -
          amp *
              (0.55 +
                  0.25 * math.sin(u * 0.9) +
                  0.15 * math.sin(u * 2.3 + seed) +
                  0.05 * math.sin(u * 5.1 + seed * 3));
    }

    void layer(double base, double amp, double seed, Color top, Color bottom) {
      final p = Path()..moveTo(-2, h);
      for (var x = -2.0; x <= w + 6; x += 5 * k) {
        p.lineTo(x, ridge(x, base, amp, seed));
      }
      p
        ..lineTo(w + 6, h)
        ..close();
      c.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ).createShader(Rect.fromLTRB(0, base - amp, w, base + 60 * k)),
      );
    }

    void mist(double y, double ht, double a) {
      final r = Rect.fromLTRB(0, y - ht, w, y + ht);
      c.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_alpha(_white, 0), _alpha(_white, a), _alpha(_white, 0)],
          ).createShader(r),
      );
    }

    layer(
      hz - 30 * k,
      110 * k,
      1,
      const Color(0xFF9FC0D6),
      const Color(0xFFB8D4DE),
    );
    mist(hz - 10 * k, 22 * k, 0.5);
    layer(
      hz + 10 * k,
      90 * k,
      4,
      const Color(0xFF7BA89C),
      const Color(0xFF9CC2B4),
    );
    mist(hz + 26 * k, 20 * k, 0.45);
    // Waterfall pouring from a cliff on the left.
    final fx = w * 0.17;
    final fTop = ridge(fx, hz + 50 * k, 80 * k, 7) + 6 * k;
    final cliff = Path()
      ..moveTo(fx - 26 * k, hz + 140 * k)
      ..lineTo(fx - 24 * k, fTop - 8 * k)
      ..lineTo(fx - 6 * k, fTop - 2 * k)
      ..lineTo(fx + 8 * k, fTop - 6 * k)
      ..lineTo(fx + 30 * k, fTop - 14 * k)
      ..lineTo(fx + 34 * k, hz + 140 * k)
      ..close();
    layer(
      hz + 50 * k,
      80 * k,
      7,
      const Color(0xFF5A9064),
      const Color(0xFF6E9E78),
    );
    c.drawPath(cliff, fill(const Color(0xFF4A6A5A)));
    final fall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fBottom = hz + 92 * k;
    for (var i = 0; i < 9; i++) {
      final x = fx - 6 * k + i * 1.6 * k + rng.range(-0.6, 0.6) * k;
      c.drawLine(
        Offset(x, fTop),
        Offset(x + rng.range(-1.5, 1.5) * k, fBottom),
        fall
          ..strokeWidth = rng.range(1, 2.4) * k
          ..color = _alpha(_white, rng.range(0.45, 0.9)),
      );
    }
    glow(Offset(fx, fBottom), 30 * k, color: _white, a: 0.8);
    mist(hz + 80 * k, 26 * k, 0.55);
    // Hillside village of stilt houses on the right.
    const nearTop = Color(0xFF3F7445), nearBottom = Color(0xFF2F5A36);
    layer(hz + 110 * k, 70 * k, 11, nearTop, nearBottom);
    for (final (f, sc) in [(0.66, 0.85), (0.8, 1.0), (0.94, 0.9)]) {
      final x = w * f;
      house(x, ridge(x, hz + 110 * k, 70 * k, 11) + 4 * k, sc);
    }
    // Tea-garden rows on the near slope.
    final rows = Path();
    for (var i = 0; i < 5; i++) {
      final y = hz + 120 * k + i * 12 * k;
      rows
        ..moveTo(-4, y)
        ..quadraticBezierTo(w * 0.25, y - 14 * k, w * 0.55, y + 6 * k);
    }
    c.drawPath(
      rows,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * k
        ..strokeCap = StrokeCap.round
        ..color = _alpha(const Color(0xFF6FA860), 0.45),
    );
    // Near tree clumps at the edges.
    canopy(Offset(-4 * k, hz + 70 * k), 1.1);
    canopy(Offset(w + 6 * k, hz + 110 * k), 1);
    settle(hz + 120 * k);
  }

  void house(double x, double ground, double sc) {
    final u = k * sc;
    final floor = ground - 18 * u;
    final post = Paint()
      ..strokeWidth = 1.6 * u
      ..color = const Color(0xFF3B2A1A);
    for (final f in [-14.0, -5.0, 5.0, 14.0]) {
      c.drawLine(
        Offset(x + f * u, floor),
        Offset(x + f * u, ground + 8 * u),
        post,
      );
    }
    c.drawRect(
      Rect.fromLTRB(x - 18 * u, floor - 2 * u, x + 18 * u, floor),
      fill(const Color(0xFF4A3420)),
    );
    c.drawRect(
      Rect.fromLTRB(x - 15 * u, floor - 15 * u, x + 15 * u, floor - 2 * u),
      fill(const Color(0xFFA58457)),
    );
    c.drawPath(
      Path()
        ..moveTo(x - 23 * u, floor - 12 * u)
        ..lineTo(x - 10 * u, floor - 28 * u)
        ..lineTo(x + 10 * u, floor - 28 * u)
        ..lineTo(x + 23 * u, floor - 12 * u)
        ..close(),
      fill(const Color(0xFF6E5530)),
    );
    // Lighter thatch on the sunlit side.
    c.drawPath(
      Path()
        ..moveTo(x - 23 * u, floor - 12 * u)
        ..lineTo(x - 10 * u, floor - 28 * u)
        ..lineTo(x - 2 * u, floor - 28 * u)
        ..lineTo(x - 12 * u, floor - 12 * u)
        ..close(),
      fill(const Color(0xFF8E7444)),
    );
    final door = Rect.fromLTRB(
      x - 3 * u,
      floor - 11 * u,
      x + 3 * u,
      floor - 2 * u,
    );
    glow(door.center, 12 * u, color: _warm, a: 0.6);
    c.drawRect(door, fill(const Color(0xFFFFD48A)));
  }

  void canopy(Offset o, double sc) {
    const shades = [Color(0xFF1F3E24), Color(0xFF2C5432), Color(0xFF3E6E40)];
    for (var s = 0; s < 3; s++) {
      final p = Path();
      for (var i = 0; i < 14; i++) {
        final off =
            Offset(rng.range(-60, 60), rng.range(-70, 40) - s * 6) * k * sc;
        p.addOval(
          Rect.fromCircle(
            center: o + off,
            radius: rng.range(14, 26) * k * sc * (1 - s * 0.25),
          ),
        );
      }
      c.drawPath(p, fill(shades[s]));
    }
  }
}

// ---------------------------------------------------------------- ambience

/// Drifting particles over the scene (petals, fireflies…).
class AmbientLayer extends StatefulWidget {
  const AmbientLayer({
    super.key,
    required this.ambient,
    required this.reducedMotion,
  });

  final Ambient ambient;
  final bool reducedMotion;

  /// Paints one frame at [t] seconds, for previews and tests.
  static void paintFrame(Canvas canvas, Size size, Ambient ambient, double t) =>
      _Ambience.paint(canvas, size, ambient, t);

  @override
  State<AmbientLayer> createState() => _AmbientLayerState();
}

class _AmbientLayerState extends State<AmbientLayer>
    with SingleTickerProviderStateMixin {
  /// Time of the still frame shown with reduced motion (and the clock's
  /// origin, so toggling motion doesn't jump).
  static const _still = 4.0;

  final _time = ValueNotifier<double>(_still);
  late final Ticker _ticker = createTicker(
    (e) => _time.value = _still + e.inMicroseconds / 1e6,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AmbientLayer old) {
    super.didUpdateWidget(old);
    if (old.reducedMotion != widget.reducedMotion) _sync();
  }

  void _sync() {
    if (widget.reducedMotion) {
      _ticker.stop();
      _time.value = _still;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(painter: _AmbientPainter(widget.ambient, _time)),
      ),
    ),
  );
}

final class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.ambient, this.time) : super(repaint: time);

  final Ambient ambient;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) =>
      _Ambience.paint(canvas, size, ambient, time.value);

  @override
  bool shouldRepaint(_AmbientPainter old) =>
      old.ambient != ambient || old.time != time;
}

/// One particle's fixed traits, all 0..1 except [p] (a phase in radians).
final class _Mote {
  const _Mote(this.x, this.y, this.s, this.v, this.p);

  final double x, y, s, v, p;
}

abstract final class _Ambience {
  static const _cell = 64.0;
  static const _maxSprites = 64;

  /// Sprite sheet built once: a soft dot and a four-point star, both white
  /// so drawAtlas can tint them.
  static final ui.Image _sheet = _buildSheet();
  static final _xf = Float32List(_maxSprites * 4);
  static final _src = Float32List(_maxSprites * 4);
  static final _col = Int32List(_maxSprites);
  static final _atlasPaint = Paint()..filterQuality = FilterQuality.low;
  static final _cache = <Ambient, List<_Mote>>{};

  static final Path _petal = Path()
    ..moveTo(0, 1)
    ..cubicTo(0.9, 0.4, 0.85, -1, 0.16, -0.95)
    ..lineTo(0, -0.7)
    ..lineTo(-0.16, -0.95)
    ..cubicTo(-0.85, -1, -0.9, 0.4, 0, 1)
    ..close();

  static ui.Image _buildSheet() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const o = Offset(_cell / 2, _cell / 2);
    c.drawCircle(
      o,
      _cell / 2,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0x80FFFFFF), Color(0x00FFFFFF)],
          stops: [0, 0.3, 1],
        ).createShader(Rect.fromCircle(center: o, radius: _cell / 2)),
    );
    const s = Offset(_cell * 1.5, _cell / 2);
    final star = Path()..moveTo(s.dx, 2);
    for (final (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)]) {
      final tip = s + Offset(dx * 30.0, dy == 0 ? 0 : dy * 30.0);
      if (dx == 1) {
        star.quadraticBezierTo(s.dx + 3, s.dy - 3, tip.dx, tip.dy);
      } else if (dy == 1) {
        star.quadraticBezierTo(s.dx + 3, s.dy + 3, tip.dx, tip.dy);
      } else if (dx == -1) {
        star.quadraticBezierTo(s.dx - 3, s.dy + 3, tip.dx, tip.dy);
      } else {
        star.quadraticBezierTo(s.dx - 3, s.dy - 3, tip.dx, tip.dy);
      }
    }
    star.close();
    c.drawCircle(
      s,
      14,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x99FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromCircle(center: s, radius: 14)),
    );
    c.drawPath(star, Paint()..color = const Color(0xFFFFFFFF));
    return rec.endRecording().toImageSync((_cell * 2).toInt(), _cell.toInt());
  }

  static List<_Mote> _spawn(Ambient a) {
    final r = _Rng(31 + a.index * 7);
    final n = switch (a) {
      Ambient.bokeh => 16,
      Ambient.petals => 22,
      Ambient.sparkles => 22,
      Ambient.fireflies => 22,
      Ambient.lanterns => 14,
    };
    return List.generate(n, (_) {
      // Mostly hug the edges and the sky so the board stays clear.
      var x = r.next(), y = r.next();
      if (a != Ambient.petals && a != Ambient.lanterns && r.next() < 0.6) {
        x = r.next() < 0.5 ? r.next() * 0.16 : 0.84 + r.next() * 0.16;
      } else if (a == Ambient.sparkles || a == Ambient.bokeh) {
        y = r.next() < 0.75 ? r.next() * 0.36 : 0.9 + r.next() * 0.1;
      }
      if (a == Ambient.lanterns) {
        x = r.next() < 0.5 ? r.next() * 0.22 : 0.78 + r.next() * 0.22;
      }
      return _Mote(x, y, r.next(), r.next(), r.next() * math.pi * 2);
    });
  }

  static void paint(Canvas canvas, Size size, Ambient ambient, double t) {
    if (size.isEmpty) return;
    final u = size.shortestSide / 400;
    final motes = _cache[ambient] ??= _spawn(ambient);
    final w = size.width, h = size.height;
    if (ambient == Ambient.petals) {
      _petals(canvas, w, h, u, motes, t);
      return;
    }
    var n = 0;
    void add(
      int sprite,
      double x,
      double y,
      double radius,
      double rot,
      Color c,
    ) {
      if (n >= _maxSprites || c.a <= 0.004) return;
      final sc = radius * 2 / _cell;
      final cs = sc * math.cos(rot), sn = sc * math.sin(rot);
      const half = _cell / 2;
      _xf
        ..[n * 4] = cs
        ..[n * 4 + 1] = sn
        ..[n * 4 + 2] = x - cs * half + sn * half
        ..[n * 4 + 3] = y - sn * half - cs * half;
      _src
        ..[n * 4] = sprite * _cell
        ..[n * 4 + 1] = 0
        ..[n * 4 + 2] = sprite * _cell + _cell
        ..[n * 4 + 3] = _cell;
      _col[n] = c.toARGB32();
      n++;
    }

    for (final m in motes) {
      final sp = 0.6 + m.v * 0.8;
      switch (ambient) {
        case Ambient.bokeh:
          final x = m.x * w + math.sin(t * 0.12 * sp + m.p) * 22 * u;
          final y = m.y * h + math.cos(t * 0.09 * sp + m.p) * 18 * u;
          final a = 0.06 + 0.07 * (0.5 + 0.5 * math.sin(t * 0.4 * sp + m.p));
          add(0, x, y, (12 + m.s * 30) * u, 0, Color.fromRGBO(255, 196, 90, a));
        case Ambient.sparkles:
          final tw = math.max(0.0, math.sin(t * 1.1 * sp + m.p));
          final a = tw * tw * tw;
          final x = m.x * w, y = m.y * h;
          add(
            0,
            x,
            y,
            (6 + m.s * 6) * u * a,
            0,
            Color.fromRGBO(255, 230, 170, a * 0.5),
          );
          add(
            1,
            x,
            y,
            (4 + m.s * 7) * u * (0.4 + 0.6 * a),
            t * 0.3 + m.p,
            Color.fromRGBO(255, 248, 225, a * 0.95),
          );
        case Ambient.fireflies:
          final x =
              m.x * w +
              (math.sin(t * 0.3 * sp + m.p) * 34 +
                      math.sin(t * 0.77 + m.p * 2) * 12) *
                  u;
          final y =
              m.y * h +
              (math.cos(t * 0.24 * sp + m.p) * 28 +
                      math.sin(t * 0.9 + m.p) * 8) *
                  u;
          final f = 0.5 + 0.5 * math.sin(t * 1.8 * sp + m.p);
          final a = 0.25 + 0.75 * f * f;
          add(
            0,
            x,
            y,
            (10 + m.s * 6) * u,
            0,
            Color.fromRGBO(220, 255, 140, a * 0.45),
          );
          add(0, x, y, 2.6 * u, 0, Color.fromRGBO(250, 255, 210, a));
        case Ambient.lanterns:
          final span = h + 120 * u;
          final y = h + 60 * u - (t * (10 + m.v * 14) * u + m.y * span) % span;
          final x = m.x * w + math.sin(t * 0.4 + m.p) * 12 * u;
          // Fade in from the bottom and out near the top.
          final a =
              ((y / h) * 2.2).clamp(0.0, 1.0) *
              (1 - (y / h - 0.85).clamp(0.0, 1.0) * 6).clamp(0.0, 1.0);
          final flick = 0.85 + 0.15 * math.sin(t * 5 + m.p * 3);
          final r = (5 + m.s * 5) * u;
          add(
            0,
            x,
            y,
            r * 4.5,
            0,
            Color.fromRGBO(255, 150, 60, 0.3 * a * flick),
          );
          add(0, x, y, r, 0, Color.fromRGBO(255, 214, 140, 0.95 * a * flick));
        case Ambient.petals:
          break;
      }
    }
    if (n == 0) return;
    canvas.drawRawAtlas(
      _sheet,
      Float32List.sublistView(_xf, 0, n * 4),
      Float32List.sublistView(_src, 0, n * 4),
      Int32List.sublistView(_col, 0, n),
      BlendMode.modulate,
      null,
      _atlasPaint,
    );
  }

  static void _petals(
    Canvas canvas,
    double w,
    double h,
    double u,
    List<_Mote> motes,
    double t,
  ) {
    final paint = Paint();
    for (final m in motes) {
      final speed = (22 + m.v * 30) * u;
      final span = h + 40 * u;
      final y = (m.y * span + t * speed) % span - 20 * u;
      final x =
          (m.x * w +
                  t * 9 * u +
                  math.sin(t * 0.7 * (0.6 + m.v) + m.p) * 26 * u) %
              (w + 20 * u) -
          10 * u;
      final flip = math.cos(t * 1.6 * (0.5 + m.s) + m.p);
      final size = (4.5 + m.s * 4) * u;
      paint.color = Color.lerp(
        const Color(0xFFE88AB0),
        const Color(0xFFFFD3E3),
        flip.abs(),
      )!.withValues(alpha: 0.9);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(t * (0.6 + m.v) + m.p)
        ..scale(size, size * (0.25 + 0.75 * flip.abs()))
        ..drawPath(_petal, paint)
        ..restore();
    }
  }
}
