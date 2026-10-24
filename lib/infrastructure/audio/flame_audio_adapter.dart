import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../../application/ports/ports.dart';

/// Short generated SFX (see tool/generate_audio.dart) plus an ambient loop.
/// Effects play from pre-warmed low-latency pools (SoundPool on Android), so
/// a stream of landings stays in sync with the coins instead of paying for a
/// fresh player per clink. All failures are swallowed: audio must never break
/// gameplay.
final class FlameAudioAdapter implements AudioPort {
  FlameAudioAdapter();

  static const _musicFile = 'ambient_loop.wav';

  bool _sfx = true;
  bool _music = true;
  bool _paused = false;
  bool _loaded = false;
  final Map<Sfx, DateTime> _lastPlayed = {};

  static String fileFor(Sfx s) => 'sfx_${s.name}.wav';

  /// Landing notes, low to high (a pentatonic run). A run of coins climbs
  /// them; single moves use the first.
  static const _landVariants = [
    'sfx_land.wav',
    'sfx_land2.wav',
    'sfx_land3.wav',
    'sfx_land4.wav',
    'sfx_land5.wav',
    'sfx_land6.wav',
  ];

  final Map<String, AudioPool> _pools = {};

  /// Low-latency players never report completion, so each voice goes back
  /// to its pool once its clip has surely finished.
  static Duration _voiceLife(String file) => _short.contains(file)
      ? const Duration(milliseconds: 450)
      : file.startsWith('sfx_land')
      ? const Duration(milliseconds: 900)
      : const Duration(milliseconds: 2400);

  static const _short = {
    'sfx_select.wav',
    'sfx_deselect.wav',
    'sfx_tap.wav',
    'sfx_whoosh.wav',
  };

  static int _voices(String file) => switch (file) {
    'sfx_select.wav' || 'sfx_whoosh.wav' => 3,
    _ when file.startsWith('sfx_land') => 2,
    _ => 2,
  };

  @override
  Future<void> preload() async {
    try {
      final effects = {
        for (final s in Sfx.values) fileFor(s),
        ..._landVariants,
      };
      await FlameAudio.audioCache.loadAll([...effects, _musicFile]);
      for (final f in effects) {
        try {
          _pools[f] = await AudioPool.create(
            source: AssetSource(f),
            audioCache: FlameAudio.audioCache,
            maxPlayers: _voices(f),
            minPlayers: f.startsWith('sfx_land') ? 2 : 1,
            playerMode: PlayerMode.lowLatency,
          );
        } on Object catch (e) {
          if (kDebugMode) debugPrint('[audio] pool $f failed: $e');
        }
      }
      _loaded = true;
      FlameAudio.bgm.initialize();
      if (_music && !_paused) await _startMusic();
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[audio] preload failed: $e');
    }
  }

  @override
  void play(Sfx sfx) {
    if (!_sfx || _paused || !_loaded) return;
    // Rate-limit identical sounds to avoid loudness spikes in chains.
    final now = DateTime.now();
    final last = _lastPlayed[sfx];
    final gap = sfx == Sfx.land ? 18 : 45;
    if (last != null && now.difference(last).inMilliseconds < gap) return;
    _lastPlayed[sfx] = now;
    _start(sfx == Sfx.land ? _landVariants.first : fileFor(sfx), _volume(sfx));
  }

  @override
  void playLanding(int order) {
    if (!_sfx || _paused || !_loaded) return;
    final i = order.clamp(0, _landVariants.length - 1);
    _start(_landVariants[i], _volume(Sfx.land));
  }

  void _start(String file, double volume) {
    final pool = _pools[file];
    if (pool != null) {
      unawaited(
        pool.start(volume: volume).then((stop) {
          Timer(
            _voiceLife(file),
            () => stop().then((_) {}, onError: (Object _) {}),
          );
        }, onError: (Object _) {}),
      );
      return;
    }
    unawaited(
      FlameAudio.play(
        file,
        volume: volume,
      ).then((_) {}, onError: (Object _) {}),
    );
  }

  @override
  void setMusicEnabled(bool enabled) {
    _music = enabled;
    if (!_loaded) return;
    if (enabled && !_paused) {
      _startMusic();
    } else {
      FlameAudio.bgm.stop();
    }
  }

  @override
  void setSfxEnabled(bool enabled) => _sfx = enabled;

  @override
  void pauseAll() {
    _paused = true;
    if (_loaded) FlameAudio.bgm.pause();
  }

  @override
  void resumeAll() {
    _paused = false;
    if (_loaded && _music) {
      if (FlameAudio.bgm.isPlaying) return;
      FlameAudio.bgm.resume();
    }
  }

  Future<void> _startMusic() async {
    try {
      await FlameAudio.bgm.play(_musicFile, volume: 0.28);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[audio] music failed: $e');
    }
  }

  static double _volume(Sfx s) => switch (s) {
    Sfx.win || Sfx.seal => 0.7,
    Sfx.invalid => 0.45,
    Sfx.tap || Sfx.select || Sfx.deselect => 0.5,
    Sfx.land => 0.55,
    Sfx.whoosh => 0.35,
    _ => 0.6,
  };
}

/// Silent adapter for tests.
final class SilentAudio implements AudioPort {
  const SilentAudio();
  @override
  Future<void> preload() async {}
  @override
  void play(Sfx sfx) {}
  @override
  void playLanding(int order) {}
  @override
  void setMusicEnabled(bool enabled) {}
  @override
  void setSfxEnabled(bool enabled) {}
  @override
  void pauseAll() {}
  @override
  void resumeAll() {}
}
