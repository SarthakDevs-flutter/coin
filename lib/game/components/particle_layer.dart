import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/seeded_random.dart';

/// Lightweight pooled particle system for fuse/seal/win bursts. Fixed-size
/// arrays: no per-frame allocation (architecture.md §12).
final class ParticleLayer extends Component {
  ParticleLayer({this.capacity = 260}) : super(priority: 900);

  final int capacity;
  late final _x = List<double>.filled(capacity, 0);
  late final _y = List<double>.filled(capacity, 0);
  late final _vx = List<double>.filled(capacity, 0);
  late final _vy = List<double>.filled(capacity, 0);
  late final _life = List<double>.filled(capacity, 0);
  late final _max = List<double>.filled(capacity, 1);
  late final _size = List<double>.filled(capacity, 1);
  late final _color = List<Color>.filled(capacity, const Color(0xFFFFFFFF));
  late final _spark = List<bool>.filled(capacity, false);

  /// Coin particles: little gold discs that spin as they fly.
  late final _coin = List<bool>.filled(capacity, false);
  late final _phase = List<double>.filled(capacity, 0);
  final _rng = SeededRandom(99);
  final _paint = Paint();
  final _sparkPath = Path();
  int _next = 0;

  /// Multiplier from quality settings; 0 disables particles (reduced motion).
  double density = 1;

  void burst(
    Offset at,
    List<Color> colors, {
    int count = 18,
    double speed = 220,
    double size = 4,
  }) {
    final n = (count * density).round();
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final v = speed * (0.35 + _rng.nextDouble() * 0.65);
      _emit(
        at,
        math.cos(a) * v,
        math.sin(a) * v - speed * 0.35,
        0.45 + _rng.nextDouble() * 0.35,
        size * (0.6 + _rng.nextDouble() * 0.8),
        colors[i % colors.length],
        i % 3 == 0,
      );
    }
  }

  /// Gold coins thrown up and out from [at], falling back with gravity.
  void shower(
    Offset at, {
    int count = 14,
    double speed = 300,
    double size = 7,
  }) {
    final n = (count * density).round();
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 2.2;
      final v = speed * (0.55 + _rng.nextDouble() * 0.6);
      _emit(
        at,
        math.cos(a) * v,
        math.sin(a) * v,
        0.7 + _rng.nextDouble() * 0.4,
        size * (0.7 + _rng.nextDouble() * 0.6),
        const Color(0xFFE9AE2E),
        false,
        coin: true,
      );
    }
  }

  void rain(Rect area, List<Color> colors, {int count = 60}) {
    final n = (count * density).round();
    for (var i = 0; i < n; i++) {
      _emit(
        Offset(
          area.left + _rng.nextDouble() * area.width,
          area.top - _rng.nextDouble() * 40,
        ),
        (_rng.nextDouble() - 0.5) * 80,
        120 + _rng.nextDouble() * 160,
        1.0 + _rng.nextDouble() * 0.8,
        3 + _rng.nextDouble() * 4,
        colors[i % colors.length],
        i.isEven,
        coin: i % 3 == 0,
      );
    }
  }

  void _emit(
    Offset at,
    double vx,
    double vy,
    double life,
    double size,
    Color c,
    bool spark, {
    bool coin = false,
  }) {
    final i = _next;
    _next = (_next + 1) % capacity;
    _x[i] = at.dx;
    _y[i] = at.dy;
    _vx[i] = vx;
    _vy[i] = vy;
    _life[i] = life;
    _max[i] = life;
    _size[i] = size;
    _color[i] = c;
    _spark[i] = spark;
    _coin[i] = coin;
    _phase[i] = _rng.nextDouble() * math.pi * 2;
  }

  void clear() => _life.fillRange(0, capacity, 0);

  @override
  void update(double dt) {
    for (var i = 0; i < capacity; i++) {
      if (_life[i] <= 0) continue;
      _life[i] -= dt;
      _vy[i] += 520 * dt;
      _vx[i] *= 1 - 1.8 * dt;
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
      if (_coin[i]) _phase[i] += dt * 11;
    }
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < capacity; i++) {
      final l = _life[i];
      if (l <= 0) continue;
      final t = (l / _max[i]).clamp(0.0, 1.0);
      _paint.color = _color[i].withValues(alpha: t);
      final s = _size[i] * (0.5 + 0.5 * t);
      if (_coin[i]) {
        // Spinning disc: width follows |cos|, rim darker than face.
        final w = s * (0.2 + 0.8 * math.cos(_phase[i]).abs());
        final r = Rect.fromCenter(
          center: Offset(_x[i], _y[i]),
          width: w * 2,
          height: s * 2,
        );
        final a = math.min(1.0, t * 2.5);
        _paint.color = Color.fromRGBO(140, 82, 8, a);
        canvas.drawOval(r.inflate(0.8), _paint);
        _paint.color = Color.fromRGBO(255, 214, 92, a);
        canvas.drawOval(r, _paint);
        _paint.color = Color.fromRGBO(255, 250, 220, a * 0.9);
        canvas.drawOval(
          Rect.fromCenter(
            center: r.center.translate(-w * 0.25, -s * 0.3),
            width: w * 0.6,
            height: s * 0.5,
          ),
          _paint,
        );
      } else if (_spark[i]) {
        final x = _x[i], y = _y[i];
        final p = _sparkPath
          ..reset()
          ..moveTo(x, y - s * 1.6)
          ..lineTo(x + s * 0.5, y)
          ..lineTo(x, y + s * 1.6)
          ..lineTo(x - s * 0.5, y)
          ..close();
        canvas.drawPath(p, _paint);
      } else {
        canvas.drawCircle(Offset(_x[i], _y[i]), s, _paint);
      }
    }
  }
}
