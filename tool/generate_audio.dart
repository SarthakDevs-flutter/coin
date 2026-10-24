// Synthesises the game's original sound effects and ambient loop as 16-bit
// mono WAV files. No third-party samples are used, so there are no licence
// obligations (recorded in assets/ASSET_MANIFEST.json).
//
//   dart run tool/generate_audio.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:coin/core/seeded_random.dart';

const rate = 44100;
const tau = math.pi * 2;

typedef Voice = double Function(double t);

Float64List render(double seconds, Voice v) {
  final n = (seconds * rate).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = v(i / rate);
  }
  return out;
}

double env(double t, {double a = 0.004, required double d}) =>
    t < a ? t / a : math.exp(-(t - a) / d);

/// Bell-like partials with slight inharmonicity: reads as "enamel & brass".
double bell(double t, double f, {double decay = 0.25}) =>
    env(t, d: decay) *
    (math.sin(tau * f * t) +
        0.45 * math.sin(tau * f * 2.76 * t) * math.exp(-t / (decay * 0.5)) +
        0.22 * math.sin(tau * f * 5.4 * t) * math.exp(-t / (decay * 0.3)));

double note(String n) {
  const names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2};
  final semis = names[n[0]]! + (int.parse(n.substring(1)) - 4) * 12;
  return 440 * math.pow(2, semis / 12).toDouble();
}

final noise = SeededRandom(7);
double white() => noise.nextDouble() * 2 - 1;

/// One metal-on-metal contact: a bright noise tick plus inharmonic partials
/// (free-plate modes of a thin disc), each decaying at its own rate, and a
/// short low "body" so the coin has weight. [pitch] scales the whole voice.
Float64List contact(
  double pitch, {
  double gain = 1,
  double ring = 1,
  double tickGain = 1,
}) {
  const ratios = [1.0, 1.47, 2.09, 2.56, 3.31, 4.12];
  const amps = [1.0, 0.62, 0.38, 0.24, 0.14, 0.07];
  const decays = [0.14, 0.1, 0.07, 0.05, 0.035, 0.025];
  final f0 = 2650 * pitch;
  final phases = [for (var i = 0; i < ratios.length; i++) noise.nextDouble()];
  final tick = highpass(
    render(0.012, (t) => white() * env(t, a: 0.0002, d: 0.0018)),
    2500,
  );
  final body = render(0.25 * ring, (t) {
    var v = 0.0;
    for (var i = 0; i < ratios.length; i++) {
      v +=
          amps[i] *
          math.exp(-t / (decays[i] * ring)) *
          math.sin(tau * (f0 * ratios[i] * t + phases[i]));
    }
    final thump = 0.35 * math.exp(-t / 0.012) * math.sin(tau * 170 * pitch * t);
    return (t < 0.0006 ? t / 0.0006 : 1) * (v * 0.5 + thump);
  });
  final out = mix([
    (0, lowpass(tick, 6000)..scale(tickGain)),
    (0, body),
  ], 0.32 * ring);
  for (var i = 0; i < out.length; i++) {
    out[i] *= gain;
  }
  return out;
}

/// A coin settling on a stack: main hit, a quick rattle and a soft re-hit.
Float64List settle(double pitch, {double rattle = 0.016}) => mix([
  (0, contact(pitch)),
  (rattle, contact(pitch * 1.012, gain: 0.42, ring: 0.7)),
  (rattle * 2.3, contact(pitch * 0.995, gain: 0.18, ring: 0.5)),
], 0.3);

extension on Float64List {
  void scale(double g) {
    for (var i = 0; i < length; i++) {
      this[i] *= g;
    }
  }
}

/// Small warm room: four damped combs into two all-passes (Schroeder),
/// mixed at [wet]. Adds [tail] seconds so the decay is not cut off.
Float64List reverb(Float64List dry, {double wet = 0.22, double tail = 0.5}) {
  final n = dry.length + (tail * rate).round();
  final x = Float64List(n)..setRange(0, dry.length, dry);
  final out = Float64List(n);
  for (final (ms, g) in const [
    (29.7, 0.78),
    (37.1, 0.76),
    (41.1, 0.74),
    (43.7, 0.72),
  ]) {
    final dl = (ms / 1000 * rate).round();
    final buf = Float64List(dl);
    var idx = 0;
    var lp = 0.0;
    for (var i = 0; i < n; i++) {
      final y = buf[idx];
      lp = y * 0.55 + lp * 0.45; // damping: darker tail
      buf[idx] = x[i] + lp * g;
      idx = (idx + 1) % dl;
      out[i] += y * 0.25;
    }
  }
  var wetSig = out;
  for (final ms in const [5.0, 1.7]) {
    final dl = (ms / 1000 * rate).round();
    final buf = Float64List(dl);
    var idx = 0;
    final next = Float64List(n);
    for (var i = 0; i < n; i++) {
      final b = buf[idx];
      final y = -0.7 * wetSig[i] + b;
      buf[idx] = wetSig[i] + 0.7 * y;
      idx = (idx + 1) % dl;
      next[i] = y;
    }
    wetSig = next;
  }
  for (var i = 0; i < n; i++) {
    x[i] = x[i] * (1 - wet) + wetSig[i] * wet;
  }
  return x;
}

/// Simple one-pole high-pass.
Float64List highpass(Float64List s, double cutoff) {
  final lp = lowpass(s, cutoff);
  return Float64List.fromList([
    for (var i = 0; i < s.length; i++) s[i] - lp[i],
  ]);
}

void write(String name, Float64List s, {double peak = 0.5, double room = 0}) {
  if (room > 0) s = reverb(s, wet: room, tail: 0.7);
  var max = 1e-9;
  for (final v in s) {
    max = math.max(max, v.abs());
  }
  final gain = peak / max;
  final data = ByteData(44 + s.length * 2);
  void str(int o, String v) {
    for (var i = 0; i < v.length; i++) {
      data.setUint8(o + i, v.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + s.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, s.length * 2, Endian.little);
  for (var i = 0; i < s.length; i++) {
    final v = (s[i] * gain).clamp(-1.0, 1.0);
    data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  File('assets/audio/$name').writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln(
    'assets/audio/$name  ${(s.length / rate).toStringAsFixed(2)}s',
  );
}

/// Simple one-pole low-pass for noise shaping.
Float64List lowpass(Float64List s, double cutoff) {
  final a = math.exp(-tau * cutoff / rate);
  final out = Float64List(s.length);
  var y = 0.0;
  for (var i = 0; i < s.length; i++) {
    y = (1 - a) * s[i] + a * y;
    out[i] = y;
  }
  return out;
}

Float64List mix(List<(double, Float64List)> parts, double seconds) {
  final out = Float64List((seconds * rate).round());
  for (final (offset, p) in parts) {
    final o = (offset * rate).round();
    for (var i = 0; i < p.length && o + i < out.length; i++) {
      out[o + i] += p[i];
    }
  }
  return out;
}

void main() {
  Directory('assets/audio').createSync(recursive: true);

  // Pick-up: coins sliding apart, a light double clink over a soft shuffle.
  final slide = lowpass(
    highpass(render(0.09, (t) => white() * env(t, a: 0.01, d: 0.025)), 1800),
    7000,
  );
  write(
    'sfx_select.wav',
    mix([
      (0, slide),
      (0.004, contact(1.0, gain: 0.45, ring: 0.5, tickGain: 0.3)),
      (0.032, contact(1.12, gain: 0.25, ring: 0.4, tickGain: 0.2)),
    ], 0.2),
    peak: 0.28,
  );
  write(
    'sfx_deselect.wav',
    mix([(0, contact(0.9, gain: 0.6, ring: 0.45, tickGain: 0.3))], 0.16),
    peak: 0.22,
  );
  write(
    'sfx_tap.wav',
    render(0.05, (t) => env(t, a: 0.001, d: 0.012) * math.sin(tau * 1800 * t)),
    peak: 0.25,
  );

  write(
    'sfx_fuse.wav',
    mix([
      (0.00, contact(0.9, gain: 0.8)),
      (0.02, contact(1.1, gain: 0.6)),
      (0.00, render(0.4, (t) => bell(t, note('C6'), decay: 0.18))),
      (0.06, render(0.4, (t) => bell(t, note('E6'), decay: 0.18))),
      (0.12, render(0.4, (t) => bell(t, note('G6'), decay: 0.22))),
    ], 0.55),
    peak: 0.5,
    room: 0.28,
  );

  final shimmer = lowpass(
    render(0.7, (t) => white() * env(t, a: 0.05, d: 0.18) * 0.25),
    6000,
  );
  write(
    'sfx_seal.wav',
    mix([
      (0.0, render(0.8, (t) => bell(t, note('G5'), decay: 0.35))),
      (0.0, render(0.8, (t) => bell(t, note('D6'), decay: 0.3) * 0.7)),
      (0.08, render(0.8, (t) => bell(t, note('G6'), decay: 0.3) * 0.8)),
      (0.05, shimmer),
    ], 0.9),
    peak: 0.55,
    room: 0.3,
  );

  final crackle = Float64List((0.28 * rate).round());
  for (var k = 0; k < 9; k++) {
    final start = (noise.nextDouble() * 0.22 * rate).round();
    for (var i = 0; i < 160 && start + i < crackle.length; i++) {
      crackle[start + i] += white() * math.exp(-i / 30);
    }
  }
  write(
    'sfx_thaw.wav',
    mix([
      (0, crackle),
      (0.02, render(0.25, (t) => bell(t, 2900, decay: 0.08) * 0.4)),
    ], 0.3),
    peak: 0.35,
  );

  write(
    'sfx_reveal.wav',
    render(
      0.22,
      (t) =>
          env(t, a: 0.05, d: 0.06) * math.sin(tau * (600 + 1800 * t) * t) * 0.8,
    ),
    peak: 0.3,
  );
  write(
    'sfx_invalid.wav',
    render(
      0.14,
      (t) =>
          env(t, a: 0.003, d: 0.05) *
          (2 / math.pi) *
          math.asin(math.sin(tau * 196 * t)),
    ),
    peak: 0.32,
  );
  write(
    'sfx_undo.wav',
    render(
      0.18,
      (t) => env(t, a: 0.004, d: 0.07) * math.sin(tau * (700 - 900 * t) * t),
    ),
    peak: 0.3,
  );
  write(
    'sfx_win.wav',
    mix([
      for (final (i, n) in ['C5', 'E5', 'G5', 'C6', 'E6'].indexed)
        (i * 0.11, render(1.0, (t) => bell(t, note(n), decay: 0.4))),
    ], 1.5),
    peak: 0.55,
    room: 0.3,
  );
  write(
    'sfx_reward.wav',
    mix([
      for (var i = 0; i < 7; i++)
        (
          i * 0.06 + noise.nextDouble() * 0.02,
          render(
            0.3,
            (t) => bell(t, 2000 + noise.nextDouble() * 1500, decay: 0.07),
          ),
        ),
    ], 0.75),
    peak: 0.4,
    room: 0.22,
  );

  // Landings: soft, warm clinks on a major-pentatonic run (do re mi so la
  // do') so a stream of coins climbs like a little melody. Low tick, long
  // ring and a small room keep it calm rather than clattery.
  const penta = [1.0, 9 / 8, 5 / 4, 3 / 2, 5 / 3, 2.0];
  for (var i = 0; i < penta.length; i++) {
    final name = i == 0 ? 'sfx_land.wav' : 'sfx_land${i + 1}.wav';
    final p = 0.74 * penta[i];
    write(
      name,
      reverb(
        mix([
          (0, contact(p, tickGain: 0.35, ring: 1.2)),
          (0.018, contact(p * 1.004, gain: 0.3, ring: 0.8, tickGain: 0.2)),
        ], 0.4),
        wet: 0.24,
        tail: 0.45,
      ),
      peak: 0.42,
    );
  }
  // Whoosh: band-limited noise swell.
  write(
    'sfx_whoosh.wav',
    lowpass(
      render(0.26, (t) => white() * math.sin(math.pi * (t / 0.26)) * 0.8),
      1600,
    ),
    peak: 0.22,
  );
  // Deal: coins pouring out, a dense run of clinks that thins out.
  write(
    'sfx_deal.wav',
    mix([
      (
        0,
        lowpass(render(0.5, (t) => white() * env(t, a: 0.02, d: 0.14)), 2200),
      ),
      for (var k = 0; k < 16; k++)
        (
          k * 0.026 + noise.nextDouble() * 0.012,
          contact(
            0.85 + noise.nextDouble() * 0.4,
            gain: 0.9 - k * 0.04,
            ring: 0.55,
          ),
        ),
    ], 0.65),
    peak: 0.42,
    room: 0.18,
  );
  // Chain stinger: quick rising bells.
  write(
    'sfx_chain.wav',
    mix([
      for (final (i, n) in ['E6', 'G6', 'B6', 'E7'].indexed)
        (i * 0.05, render(0.45, (t) => bell(t, note(n), decay: 0.16))),
    ], 0.7),
    peak: 0.45,
    room: 0.28,
  );

  // Ambient loop: four soft chords, seamless because every voice's envelope
  // wraps around the loop length.
  const loop = 24.0;
  const chords = [
    ['C3', 'G3', 'E4', 'B4'],
    ['A2', 'E3', 'C4', 'G4'],
    ['F2', 'C3', 'A3', 'E4'],
    ['G2', 'D3', 'B3', 'E4'],
  ];
  final n = (loop * rate).round();
  final pad = Float64List(n);
  for (var c = 0; c < chords.length; c++) {
    final start = c * 6.0;
    for (final name in chords[c]) {
      final f = note(name);
      for (var i = 0; i < n; i++) {
        final t = i / rate;
        var local = t - start;
        if (local < 0) local += loop;
        if (local > 8) continue;
        final e = local < 2.5
            ? math.sin(local / 2.5 * math.pi / 2)
            : math.max(0, math.cos((local - 2.5) / 5.5 * math.pi / 2));
        // Phase relative to the loop so the waveform is continuous at wrap.
        final ft = (f * loop).roundToDouble() / loop;
        pad[i] +=
            e *
            (math.sin(tau * ft * t) + 0.25 * math.sin(tau * ft * 2 * t)) *
            (0.85 + 0.15 * math.sin(tau * t / loop * 4));
      }
    }
  }
  write('ambient_loop.wav', lowpass(pad, 1800), peak: 0.35);
}
