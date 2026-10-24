/// Versioned, platform-independent PRNG (mulberry32). `dart:math` Random is
/// not guaranteed stable across SDK versions, and saved seeds must replay
/// identically forever.
final class SeededRandom {
  SeededRandom(int seed) : _state = seed & 0xFFFFFFFF;

  static const int algorithmVersion = 1;

  int _state;

  int get state => _state;

  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= (t + _imul(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF;
    return (t ^ (t >>> 14)) & 0xFFFFFFFF;
  }

  /// Uniform integer in [0, max).
  int nextInt(int max) {
    assert(max > 0);
    return nextUint32() % max;
  }

  double nextDouble() => nextUint32() / 4294967296.0;

  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }

  static int _imul(int a, int b) {
    final ah = (a >>> 16) & 0xFFFF;
    final al = a & 0xFFFF;
    final bh = (b >>> 16) & 0xFFFF;
    final bl = b & 0xFFFF;
    return ((al * bl) + (((ah * bl + al * bh) << 16) & 0xFFFFFFFF)) &
        0xFFFFFFFF;
  }
}
