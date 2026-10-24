import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';

import '../../domain/model/coin.dart';
import '../render/coin_art.dart';
import '../render/coin_sprite_cache.dart';
import '../render/currency_art.dart';
import '../render/disc_art.dart';
import '../render/theme/coin_theme.dart';
import '../render/theme/coin_themes.dart';

/// Look shared by every coin on the board.
final class CoinLook {
  const CoinLook({
    required this.finish,
    required this.colorBlind,
    this.theme = CoinThemes.atelier,
  });
  final String finish;
  final bool colorBlind;
  final CoinTheme theme;
}

/// Visual stand-in for one domain coin, drawn as a thick disc. [position] is
/// the face centre. Holds presentation-only state; never game data.
final class CoinComponent extends PositionComponent {
  CoinComponent({
    required this.coin,
    required this.diameter,
    required this.cache,
    required this.look,
    required Vector2 at,
  }) : super(position: at);

  CoinState coin;
  double diameter;
  CoinSpriteCache cache;
  CoinLook look;
  String? stackId;

  double lift = 0;
  double targetLift = 0;
  double _liftVel = 0;

  /// Extra scale while airborne (the coin comes closer to the camera).
  double airScale = 1;

  /// Seconds left of the "something landed on me" dip.
  double _impact = 0;
  static const _impactTime = 0.16;
  double opacity = 1;
  double size_ = 1;

  /// Tumble angle (radians around the horizontal axis) while flying.
  double tumble = 0;

  /// Spin around the view axis while flying.
  double spin = 0;
  double whiten = 0;

  /// Glint band position across the coin (0..1); negative = no glint.
  double shine = -1;

  /// True while flying: the coin is drawn as a real 3D disc so it can roll.
  bool airborne = false;

  /// Roll angle (radians) about [_axisX], [_axisY]: an axis lying in the
  /// coin's own plane, perpendicular to its direction of travel.
  double roll = 0;
  double _axisX = 0;
  double _axisY = 1;

  void setRollAxis(double x, double y) {
    final len = math.sqrt(x * x + y * y);
    if (len < 1e-6) return;
    _axisX = x / len;
    _axisY = y / len;
  }

  /// Landing squash (1 = none).
  double squash = 1;
  double nudgeX = 0;
  double bobPhase = 0;
  bool bob = false;
  bool removing = false;

  late int shownFrost = coin.frost;
  late bool shownRevealed = coin.isRevealed;

  /// One queue per property so a flight, a scale and a fade scheduled at
  /// the same time run together. Times are relative to when the timeline
  /// was built (all motions are scheduled up front).
  final List<_Track> _tracks = List.generate(_Track.count, (_) => _Track());

  bool get isAnimating => _tracks.any((t) => t.queue.isNotEmpty);

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  void _at(double time, _Motion m) {
    final t = _tracks[m.track];
    if (time > t.cursor) t.queue.add(_Wait(time - t.cursor, m.track));
    t.queue.add(m);
    t.cursor = math.max(time, t.cursor) + m.duration;
  }

  /// Pick-and-place flight: rises out of its stack, glides over at [arc]
  /// above the higher end point, drops straight in and settles with a squash.
  /// [flips] is the number of half-turn rolls in 3D (0 keeps it flat).
  void flyTo(
    double time,
    Vector2 target,
    double duration, {
    double arc = 0,
    double flips = 0,
    double spinTurns = 0,
    bool landSquash = true,
  }) {
    _at(time, _Move(target.clone(), duration, arc, flips, spinTurns));
    if (landSquash) _at(time + duration, _Squash(0.15));
  }

  void moveTo(double time, Vector2 target, double duration) =>
      _at(time, _Move(target.clone(), duration, 0, 0, 0));

  /// A small dip, as if a coin just landed on top of this one.
  void impact() => _impact = _impactTime;

  void scaleTo(
    double time,
    double to,
    double duration, {
    Curve curve = Curves.easeOutBack,
  }) => _at(time, _Scale(to, duration, curve));

  void fadeTo(double time, double to, double duration) =>
      _at(time, _Fade(to, duration));

  void whitenTo(double time, double to, double duration) =>
      _at(time, _Whiten(to, duration));

  void callAt(double time, void Function(CoinComponent c) f) =>
      _at(time, _Call(f));

  void flipReveal(double time, double duration) => _at(time, _Reveal(duration));

  /// A diagonal highlight sweeping across the face.
  void glint(double time, double duration) => _at(time, _Glint(duration));

  void clearMotions() {
    for (final t in _tracks) {
      t
        ..queue.clear()
        ..cursor = 0;
    }
  }

  void snap(Vector2 home) {
    clearMotions();
    position.setFrom(home);
    _resetPose();
  }

  /// Like [snap], but glides to [home] over [duration] from wherever the coin
  /// is now (mid-flight included). Flight pose is dropped at once so the
  /// glide reads as a flat slide back into the well.
  void settle(Vector2 home, double duration) {
    clearMotions();
    removing = false;
    final dist = (home - position).length;
    if (dist < 0.5 || duration <= 0) {
      position.setFrom(home);
      _resetPose();
      return;
    }
    // Keep the lift out of the glide: _Move folds it into the start point.
    final from = position.clone()..y -= lift;
    position.setFrom(from);
    lift = 0;
    _liftVel = 0;
    _resetPose();
    // Short hops settle quicker than long ones; the pace stays even.
    final d = (duration * (0.5 + 0.5 * math.min(1, dist / (diameter * 4))))
        .clamp(0.08, duration)
        .toDouble();
    moveTo(0, home, d);
  }

  void _resetPose() {
    size_ = 1;
    airScale = 1;
    opacity = 1;
    tumble = 0;
    spin = 0;
    whiten = 0;
    shine = -1;
    roll = 0;
    airborne = false;
    squash = 1;
    shownFrost = coin.frost;
    shownRevealed = coin.isRevealed;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Under-damped spring: the lifted run pops up with a slight overshoot.
    final step = math.min(dt, 1 / 30);
    _liftVel += ((targetLift - lift) * 520 - _liftVel * 32) * step;
    lift += _liftVel * step;
    if ((targetLift - lift).abs() < 0.05 && _liftVel.abs() < 0.5) {
      lift = targetLift;
      _liftVel = 0;
    }
    if (_impact > 0) _impact = math.max(0, _impact - dt);
    if (bob) bobPhase += dt * 3.2;
    for (final track in _tracks) {
      final q = track.queue;
      var remaining = dt;
      while (remaining > 0 && q.isNotEmpty) {
        final m = q.first;
        if (!m.started) {
          m.started = true;
          m.begin(this);
        }
        final use = math.min(m.duration - m.elapsed, remaining);
        m.elapsed += use;
        remaining -= use;
        m.apply(
          this,
          m.duration <= 0 ? 1 : (m.elapsed / m.duration).clamp(0, 1),
        );
        if (m.elapsed >= m.duration) {
          m.finish(this);
          q.removeAt(0);
        }
      }
      while (q.isNotEmpty && q.first.duration <= 0) {
        final m = q.removeAt(0);
        m.begin(this);
        m.finish(this);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (opacity <= 0.01 || size_ <= 0.01) return;
    if (airborne) {
      _render3d(canvas);
      return;
    }
    final img = cache.disc(
      family: coin.familyId,
      tier: coin.tier,
      diameter: diameter,
      finish: look.finish,
      colorBlind: look.colorBlind,
      hidden: !shownRevealed,
      frost: shownFrost,
      theme: look.theme,
    );
    final sz = CoinSpriteCache.spriteSize(diameter);
    final anchor = CoinSpriteCache.anchor(diameter);
    final bobY = bob && lift > 1 ? math.sin(bobPhase) * 1.5 : 0.0;
    final dip = _impact > 0
        ? math.sin(math.pi * (1 - _impact / _impactTime)) * diameter * 0.022
        : 0.0;
    canvas.save();
    canvas.translate(nudgeX, -lift + bobY + dip);
    // Tumble: the disc's apparent height follows |cos|; never fully flat so
    // the edge band stays visible mid-flip.
    final tumbleScale = 0.28 + 0.72 * math.cos(tumble).abs();
    canvas.rotate(spin);
    final k = size_ * airScale;
    canvas.scale(k * (2 - squash), k * tumbleScale * squash);
    final dst = Rect.fromLTWH(-anchor.dx, -anchor.dy, sz.width, sz.height);
    _paint
      ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1).toDouble())
      ..colorFilter = whiten > 0.01
          ? ColorFilter.mode(
              Color.fromRGBO(255, 255, 255, (whiten * 0.85).clamp(0, 1)),
              BlendMode.srcATop,
            )
          : null;
    final glinting = shine >= 0 && shine <= 1;
    if (glinting) canvas.saveLayer(dst, Paint());
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      _paint,
    );
    if (glinting) {
      // Painted only where the coin is (srcATop), like light on metal.
      final x = dst.left - dst.width * 0.4 + dst.width * 1.8 * shine;
      canvas.drawRect(
        dst,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader = Gradient.linear(
            Offset(x - dst.width * 0.25, dst.top),
            Offset(x + dst.width * 0.05, dst.bottom),
            const [Color(0x00FFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)],
            const [0, 0.5, 1],
          ),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  /// Rest tilt of the table view: a flat disc seen at this angle shows a
  /// face ellipse of height `d * DiscArt.faceRatio`.
  static final double _rest = math.acos(DiscArt.faceRatio);

  /// Real coin thickness, so the band at rest matches DiscArt.thickness.
  static double _depth(double d) => DiscArt.thickness(d) / math.sin(_rest);

  static const _slices = 6;

  /// Cross-section of a shaped or holed currency coin; null for a plain
  /// disc (drawn as a circle).
  Path? _sliceShape(double r) {
    final c = shownRevealed ? look.theme.coin(coin.familyId) : null;
    if (c == null || (c.shape == CoinShape.round && !c.hole)) return null;
    final key = (look.theme.id, coin.familyId, r);
    if (_sliceKey == key) return _slicePath;
    final p = CurrencyArt.outline(c.shape, Offset.zero, r);
    if (c.hole) {
      p
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 0.2))
        ..fillType = PathFillType.evenOdd;
    }
    _sliceKey = key;
    return _slicePath = p;
  }

  Object? _sliceKey;
  Path? _slicePath;
  static final _slicePaint = Paint();
  static final _m = Float64List(16);

  /// Orthographic 3D disc: R = Rz(spin) · Rx(rest) · Raxis(roll), drawn as
  /// the face sprite at both ends of the coin with solid slices between.
  void _render3d(Canvas canvas) {
    final d = diameter;
    final r = d / 2;
    final img = cache.face(
      family: coin.familyId,
      tier: coin.tier,
      diameter: d,
      finish: look.finish,
      colorBlind: look.colorBlind,
      hidden: !shownRevealed,
      frost: shownFrost,
      theme: look.theme,
    );
    // Axis-angle rotation in the coin's local frame.
    final ax = _axisX, ay = _axisY;
    final c = math.cos(roll), sn = math.sin(roll), t = 1 - c;
    final a00 = t * ax * ax + c, a01 = t * ax * ay, a02 = sn * ay;
    final a10 = t * ax * ay, a11 = t * ay * ay + c, a12 = -sn * ax;
    final a20 = -sn * ay, a21 = sn * ax, a22 = c;
    // Rest tilt about screen x.
    final rc = math.cos(_rest), rs = math.sin(_rest);
    final b00 = a00, b01 = a01, b02 = a02;
    final b10 = rc * a10 - rs * a20;
    final b11 = rc * a11 - rs * a21;
    final b12 = rc * a12 - rs * a22;
    final b22 = rs * a12 + rc * a22;
    // In-plane spin about the view axis.
    final zc = math.cos(spin), zs = math.sin(spin);
    final m00 = zc * b00 - zs * b10, m01 = zc * b01 - zs * b11;
    final m02 = zc * b02 - zs * b12;
    final m10 = zs * b00 + zc * b10, m11 = zs * b01 + zc * b11;
    final m12 = zs * b02 + zc * b12;
    final k = size_ * airScale;
    final depth = _depth(d);
    final topVisible = b22 >= 0;

    final st = shownRevealed
        ? CoinArt.style(coin.familyId, look.theme)
        : CoinArt.veil;
    final slice = _sliceShape(r * 0.995);
    final metal = st.metal ?? st.rimMetal;
    final edgeDark = st.metal != null ? metal.dark : st.dark;
    final edgeBase = st.metal != null ? metal.base : st.base;

    void place(double z) {
      _m
        ..[0] = m00 * k
        ..[1] = m10 * k
        ..[2] = 0
        ..[3] = 0
        ..[4] = m01 * k
        ..[5] = m11 * k
        ..[6] = 0
        ..[7] = 0
        ..[8] = 0
        ..[9] = 0
        ..[10] = 1
        ..[11] = 0
        ..[12] = nudgeX + m02 * z * k
        ..[13] = -lift + m12 * z * k
        ..[14] = 0
        ..[15] = 1;
      canvas.save();
      canvas.transform(_m);
    }

    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final dst = Rect.fromLTWH(-r, -r, d, d);
    _paint
      ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1).toDouble())
      ..colorFilter = whiten > 0.01
          ? ColorFilter.mode(
              Color.fromRGBO(255, 255, 255, (whiten * 0.85).clamp(0, 1)),
              BlendMode.srcATop,
            )
          : null;
    void face(double z) {
      place(z);
      canvas.drawImageRect(img, src, dst, _paint);
      canvas.restore();
    }

    // Enough slices that an edge-on coin reads as a solid band.
    final shift = depth * k * math.sqrt(m02 * m02 + m12 * m12);
    final n = math.max(_slices, math.min(28, (shift / 1.2).ceil()));
    final trim = st.metal == null;
    final alpha = opacity.clamp(0, 1).toDouble();
    void slices() {
      for (var i = 0; i < n; i++) {
        final u = i / (n - 1);
        final f = topVisible ? u : 1 - u;
        final z = -depth * (1 - f);
        place(z);
        // Enamel chips keep their gold trim near both faces.
        final atTrim = trim && ((f > 0.08 && f < 0.2) || (f > 0.8 && f < 0.92));
        _slicePaint.color =
            (atTrim
                    ? Color.lerp(st.rimMetal.dark, st.rimMetal.light, f)!
                    : Color.lerp(edgeDark, edgeBase, f)!)
                .withValues(alpha: alpha);
        slice == null
            ? canvas.drawCircle(Offset.zero, r * 0.995, _slicePaint)
            : canvas.drawPath(slice, _slicePaint);
        canvas.restore();
      }
    }

    if (topVisible) {
      face(-depth);
      slices();
      face(0);
    } else {
      face(0);
      slices();
      face(-depth);
    }
  }
}

final class _Track {
  static const count = 7;
  final List<_Motion> queue = [];
  double cursor = 0;
}

abstract class _Motion {
  _Motion(this.duration);
  final double duration;

  /// Which property track this motion animates.
  int get track;
  double elapsed = 0;
  bool started = false;
  void begin(CoinComponent c) {}
  void apply(CoinComponent c, double t) {}
  void finish(CoinComponent c) => apply(c, 1);
}

final class _Wait extends _Motion {
  _Wait(super.duration, this.track);

  @override
  final int track;
}

final class _Move extends _Motion {
  @override
  int get track => 0;

  _Move(this.target, super.duration, this.arc, this.flips, this.spinTurns);
  final Vector2 target;
  final double arc;
  final double flips;
  final double spinTurns;
  late Vector2 _from;
  late double _peak;

  /// Symmetric ease: a smooth take-off and a soft touchdown, which keeps a
  /// tightly staggered run reading as one continuous ribbon.
  static const _curve = Cubic(0.4, 0.0, 0.5, 1.0);

  @override
  void begin(CoinComponent c) {
    _from = c.position.clone()..y -= c.lift;
    c.position.setFrom(_from);
    c.lift = 0;
    c.targetLift = 0;
    c._liftVel = 0;
    _peak = math.min(_from.y, target.y) - arc;
    if (flips > 0) {
      // Roll toward the target: the axis lies in the table plane,
      // perpendicular to the direction of travel.
      final mx = target.x - _from.x;
      final my = (target.y - _from.y) / DiscArt.faceRatio;
      if (mx.abs() + my.abs() < 1) {
        c.setRollAxis(0, 1);
      } else {
        c.setRollAxis(my, -mx);
      }
      c.airborne = true;
    }
  }

  @override
  void apply(CoinComponent c, double t) {
    final e = _curve.transform(t);
    if (arc <= 0) {
      c.position
        ..x = _from.x + (target.x - _from.x) * e
        ..y = _from.y + (target.y - _from.y) * e;
    } else {
      // Cubic Bézier with both handles at peak height: vertical take-off,
      // level glide, vertical drop.
      final u = 1 - e;
      final b0 = u * u * u;
      final b1 = 3 * u * u * e;
      final b2 = 3 * u * e * e;
      final b3 = e * e * e;
      c.position
        ..x = _from.x * (b0 + b1) + target.x * (b2 + b3)
        ..y = _from.y * b0 + _peak * (b1 + b2) + target.y * b3;
    }
    final air = math.sin(math.pi * t);
    c.airScale = 1 + (arc > 0 ? 0.07 * air : 0);
    // One smooth roll per half-turn in [flips]; it finishes just before
    // touchdown so the coin lands flat.
    c.roll =
        flips * math.pi * Curves.easeInOut.transform(math.min(1, t / 0.92));
    // Lean into the direction of travel, mid-flight only.
    final lean = flips > 0 ? 0.0 : (target.x - _from.x).sign * 0.12 * air;
    c.spin = (arc > 0 ? lean : 0) + math.sin(math.pi * e) * spinTurns;
  }

  @override
  void finish(CoinComponent c) {
    apply(c, 1);
    c.roll = 0;
    c.airborne = false;
    c.spin = 0;
    c.airScale = 1;
  }
}

final class _Squash extends _Motion {
  @override
  int get track => 0;

  _Squash(super.duration);

  /// Squash on contact, rebound slightly past rest, settle.
  @override
  void apply(CoinComponent c, double t) {
    final v = t < 0.4
        ? -math.sin(math.pi * t / 0.4) * 0.1
        : math.sin(math.pi * (t - 0.4) / 0.6) * 0.035;
    c.squash = 1 + v;
  }

  @override
  void finish(CoinComponent c) => c.squash = 1;
}

final class _Scale extends _Motion {
  @override
  int get track => 1;

  _Scale(this.to, super.duration, this.curve);
  final double to;
  final Curve curve;
  late double _from;

  @override
  void begin(CoinComponent c) => _from = c.size_;

  @override
  void apply(CoinComponent c, double t) =>
      c.size_ = _from + (to - _from) * curve.transform(t);
}

final class _Fade extends _Motion {
  @override
  int get track => 2;

  _Fade(this.to, super.duration);
  final double to;
  late double _from;

  @override
  void begin(CoinComponent c) => _from = c.opacity;

  @override
  void apply(CoinComponent c, double t) => c.opacity = _from + (to - _from) * t;
}

final class _Whiten extends _Motion {
  @override
  int get track => 3;

  _Whiten(this.to, super.duration);
  final double to;
  late double _from;

  @override
  void begin(CoinComponent c) => _from = c.whiten;

  @override
  void apply(CoinComponent c, double t) => c.whiten = _from + (to - _from) * t;
}

final class _Reveal extends _Motion {
  @override
  int get track => 4;

  _Reveal(super.duration);
  bool _swapped = false;

  @override
  void apply(CoinComponent c, double t) {
    c.tumble = math.pi * t;
    if (t >= 0.5 && !_swapped) {
      _swapped = true;
      c.shownRevealed = c.coin.isRevealed;
    }
  }

  @override
  void finish(CoinComponent c) {
    c.tumble = 0;
    c.shownRevealed = c.coin.isRevealed;
  }
}

final class _Glint extends _Motion {
  @override
  int get track => 5;

  _Glint(super.duration);

  @override
  void apply(CoinComponent c, double t) =>
      c.shine = Curves.easeInOut.transform(t);

  @override
  void finish(CoinComponent c) => c.shine = -1;
}

final class _Call extends _Motion {
  @override
  int get track => 6;

  _Call(this.f) : super(0);
  final void Function(CoinComponent c) f;

  @override
  void finish(CoinComponent c) => f(c);
}
