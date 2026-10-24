import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'coin_art.dart';
import 'disc_art.dart';
import 'theme/coin_theme.dart';

/// Rasterises each disc look once per size and reuses it every frame, so the
/// board renders as cheap image blits (design.md §12: atlas-like reuse).
final class CoinSpriteCache {
  CoinSpriteCache({required this.pixelRatio});

  final double pixelRatio;
  final Map<String, ui.Image> _images = {};

  /// Sprite size relative to diameter, and the face-centre anchor inside it.
  static Size spriteSize(double d) => Size(d * 1.12, d * 1.0);
  static Offset anchor(double d) =>
      Offset(d * 0.56, d * 0.06 + DiscArt.faceHeight(d) / 2);

  ui.Image disc({
    required String family,
    required int tier,
    required double diameter,
    required String finish,
    required bool colorBlind,
    required bool hidden,
    required int frost,
    required CoinTheme theme,
  }) {
    final key = hidden
        ? 'h|$frost|$diameter'
        : '${theme.id}|$family|$tier|$finish|$colorBlind|$frost|$diameter';
    return _images[key] ??= _render(diameter, (canvas) {
      DiscArt.paint(
        canvas,
        anchor(diameter),
        diameter,
        family: family,
        tier: tier,
        finish: finish,
        colorBlind: colorBlind,
        hidden: hidden,
        frost: frost,
        theme: theme,
      );
    });
  }

  /// Flat, face-on coin (no edge, no shadow) of diameter [diameter], used by
  /// the 3D flight renderer. Anchor is the image centre.
  ui.Image face({
    required String family,
    required int tier,
    required double diameter,
    required String finish,
    required bool colorBlind,
    required bool hidden,
    required int frost,
    required CoinTheme theme,
  }) {
    final key = hidden
        ? 'fh|$frost|$diameter'
        : 'f|${theme.id}|$family|$tier|$finish|$colorBlind|$frost|$diameter';
    return _images[key] ??= _render(diameter, (canvas) {
      final c = Offset(diameter / 2, diameter / 2);
      CoinArt.paintCoin(
        canvas,
        c,
        diameter / 2,
        family: family,
        tier: tier,
        finish: finish,
        colorBlind: colorBlind,
        hidden: hidden,
        shadow: false,
        theme: theme,
      );
      if (frost > 0) CoinArt.paintFrost(canvas, c, diameter / 2, frost);
    }, size: Size.square(diameter));
  }

  ui.Image _render(double d, void Function(Canvas) paint, {Size? size}) {
    size ??= spriteSize(d);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (size.width * pixelRatio).ceil(),
      (size.height * pixelRatio).ceil(),
    );
    picture.dispose();
    return image;
  }

  void clear() {
    for (final i in _images.values) {
      i.dispose();
    }
    _images.clear();
  }
}
