import 'package:flutter/material.dart';

/// Design tokens from design.md §4 ("The Collector's Atelier"), in the
/// luxury treatment: warm walnut darks, polished gold and emerald actions.
abstract final class AtelierColors {
  static const background = Color(0xFF22150C);
  static const backgroundDeep = Color(0xFF0E0805);
  static const backgroundGlow = Color(0xFF4A2E14);
  static const surface = Color(0xFFFFF4DF);
  static const surfaceMuted = Color(0xFFF2E1C2);
  static const primary = Color(0xFF2EB14E);
  static const primaryDeep = Color(0xFF16742F);
  static const accent = Color(0xFFE9AE2E);
  static const accentDeep = Color(0xFF9A6410);
  static const textOnLight = Color(0xFF2A1A0B);
  static const textOnLightMuted = Color(0xFF6A5236);
  static const textOnDark = Color(0xFFFFF6E4);
  static const textOnDarkMuted = Color(0xFFD2BC98);
  static const danger = Color(0xFFD9434F);
  static const success = Color(0xFF2EB14E);
  static const disabled = Color(0xFF8C8073);
  static const tray = Color(0xFF2E1708);
  static const trayEdge = Color(0xFF6B4220);

  /// Polished gold ramp for frames and trims.
  static const gold = [
    Color(0xFFFFF2B8),
    Color(0xFFF2C14E),
    Color(0xFFB5760E),
    Color(0xFFF2C14E),
    Color(0xFFFFE08A),
  ];
  static const goldStops = [0.0, 0.3, 0.55, 0.8, 1.0];

  /// Dark lacquered walnut used inside round buttons and locked cards.
  static const walnut = [Color(0xFF6A3E1A), Color(0xFF3A1E0A)];
}

abstract final class AtelierFonts {
  static const display = 'Fredoka';
  static const body = 'Nunito';
}

abstract final class AtelierSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  /// Minimum comfortable tap target (design.md §10).
  static const tapTarget = 48.0;
}

abstract final class AtelierRadii {
  static const sm = Radius.circular(10);
  static const md = Radius.circular(18);
  static const lg = Radius.circular(28);
}

/// Motion budget (design.md §4 motion principles). Multiplied by 0.5 and with
/// arcs/particles removed under reduced motion.
abstract final class AtelierMotion {
  static const pickup = Duration(milliseconds: 130);
  static const move = Duration(milliseconds: 230);
  static const moveStagger = Duration(milliseconds: 45);
  static const fuse = Duration(milliseconds: 360);
  static const win = Duration(milliseconds: 800);
  static const ui = Duration(milliseconds: 220);
}
