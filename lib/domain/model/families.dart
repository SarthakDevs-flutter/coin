/// Logical coin families. Presentation maps each id to colour, glyph and rim
/// pattern; the rules only compare ids.
abstract final class CoinFamilies {
  static const jade = 'jade';
  static const ruby = 'ruby';
  static const sapphire = 'sapphire';
  static const amber = 'amber';
  static const amethyst = 'amethyst';
  static const pearl = 'pearl';
  static const onyx = 'onyx';
  static const coral = 'coral';

  /// Order of introduction across the campaign.
  static const all = [
    jade,
    ruby,
    sapphire,
    amber,
    amethyst,
    pearl,
    onyx,
    coral,
  ];

  static bool isKnown(String id) => all.contains(id);
}
