import 'package:flutter/painting.dart';

import '../coin_art.dart';

/// Outline of a coin face.
enum CoinShape {
  round,

  /// Seven curved sides (UK 20p / 50p).
  heptagon,

  /// Twelve flat sides (UK £1, India ₹20).
  dodecagon,

  /// Round with seven shallow notches (euro 20 cent).
  notched,
}

/// How the side of a coin is finished. Shown on the edge band of stacked
/// coins, next to the stamped value.
enum EdgeStyle { reeded, smooth, grooved, interrupted, lettered }

/// Raised design in the middle of a currency coin. Silhouettes live in
/// `emblems.dart`, in unit space (-1..1 on both axes).
enum Emblem {
  none,
  // Europe
  spire,
  bridge,
  // Japan
  sakura,
  pagoda,
  riceEar,
  paulownia,
  sapling,
  phoenix,
  // United Kingdom
  portcullis,
  shield,
  rose,
  crown,
  thistle,
  // United States
  profile,
  torch,
  eagle,
  dome,
  // India
  lotus,
  wheat,
  chakra,
  peacock,
  elephant,
  // Northeast India
  rhino,
  hornbill,
  orchid,
  teaLeaf,
  hills,
}

/// Enamel colour that identifies a coin family in every currency theme.
///
/// Real coins of one currency share a handful of metals, so on the board
/// they blur together. Each family gets its own vivid enamel centre (and a
/// matching stripe on its edge), the same in every theme, so players learn
/// one colour per family. Hues follow the atelier gems and are spread
/// around the wheel; emblem, value and shape still differ too.
abstract final class FamilyTint {
  static const jade = Color(0xFF1FA34E); // green
  static const ruby = Color(0xFFD42A35); // red
  static const sapphire = Color(0xFF2563D9); // blue
  static const amber = Color(0xFFF39A12); // orange
  static const amethyst = Color(0xFF8E44D6); // purple
  static const pearl = Color(0xFF1FB8CF); // cyan
  static const onyx = Color(0xFF23252C); // black
  static const coral = Color(0xFFE8509A); // pink

  static const all = <String, Color>{
    'jade': jade,
    'ruby': ruby,
    'sapphire': sapphire,
    'amber': amber,
    'amethyst': amethyst,
    'pearl': pearl,
    'onyx': onyx,
    'coral': coral,
  };
}

/// One denomination: what a coin family looks like in a currency theme.
final class CurrencyCoin {
  const CurrencyCoin({
    required this.value,
    required this.name,
    required this.metal,
    this.unit = '',
    this.legend = '',
    this.ring,
    this.shape = CoinShape.round,
    this.edge = EdgeStyle.reeded,
    this.emblem = Emblem.none,
    this.hole = false,
    this.enamel,
  });

  /// Big numeral on the face and the edge, e.g. `10`, `€2`, `₹5`.
  final String value;

  /// Small line under the numeral, e.g. `CENT`, `PENCE`.
  final String unit;

  /// Text that runs around the inside of the rim, e.g. `EURO CENT`.
  final String legend;

  /// Player-facing name, e.g. `10 cent`.
  final String name;

  /// Body metal (the core for bimetal coins).
  final Metal metal;

  /// Outer ring of a bimetal coin. Null for single-metal coins.
  final Metal? ring;

  final CoinShape shape;
  final EdgeStyle edge;
  final Emblem emblem;

  /// Centre hole (Japanese 5 and 50 yen).
  final bool hole;

  /// Coloured enamel centre: the family's identity colour ([FamilyTint]).
  final Color? enamel;

  /// Metal of the outer edge: what the edge band shows.
  Metal get outer => ring ?? metal;
}

/// Woodwork and trim of the board and its tray wells.
enum BoardMotif { none, stars, sakura, crowns, starsStripes, paisley, weave }

final class BoardStyle {
  const BoardStyle({
    required this.woodLight,
    required this.woodMid,
    required this.woodDark,
    required this.edge,
    required this.wellLight,
    required this.wellDark,
    this.inlay = Metal.gold,
    this.panel,
    this.motif = BoardMotif.none,
    this.motifColor = const Color(0xFFFFFFFF),
    this.grain = true,
  });

  final Color woodLight;
  final Color woodMid;
  final Color woodDark;

  /// The board's visible thickness below its top.
  final Color edge;

  /// Inside of each tray well, lit side and shaded side.
  final Color wellLight;
  final Color wellDark;

  /// Inlay line and rivets.
  final Metal inlay;

  /// Enamel band inside the inlay that carries the motif. Null: plain wood.
  final List<Color>? panel;

  final BoardMotif motif;
  final Color motifColor;

  /// Wood grain strokes (off for lacquer and bamboo).
  final bool grain;
}

/// Backdrop scenery. Painted procedurally by `scene_backdrop.dart`.
enum SceneKind { atelier, paris, kyoto, london, newYork, delhi, northeast }

/// Ambient particles drifting over the backdrop.
enum Ambient { bokeh, petals, sparkles, fireflies, lanterns }

final class SceneStyle {
  const SceneStyle({
    required this.kind,
    required this.sky,
    required this.glow,
    required this.ground,
    this.ambient = Ambient.bokeh,
  });

  final SceneKind kind;

  /// Top to horizon.
  final List<Color> sky;

  /// Sun or city glow near the horizon.
  final Color glow;

  /// Floor colour behind the board.
  final Color ground;

  final Ambient ambient;
}

/// A complete look: coin designs, board, backdrop and UI accent.
final class CoinTheme {
  const CoinTheme({
    required this.id,
    required this.name,
    required this.currency,
    required this.symbol,
    required this.board,
    required this.scene,
    required this.accent,
    this.coins,
  });

  final String id;

  /// Theme name, e.g. `Europe`.
  final String name;

  /// Currency line, e.g. `Euro`.
  final String currency;

  /// Currency sign, e.g. `€`.
  final String symbol;

  /// Family id → denomination. Null keeps the atelier's gem coins.
  final Map<String, CurrencyCoin>? coins;

  final BoardStyle board;
  final SceneStyle scene;

  /// Banner and highlight colour for this theme's UI.
  final Color accent;

  bool get isCurrency => coins != null;

  CurrencyCoin? coin(String family) => coins?[family];
}
