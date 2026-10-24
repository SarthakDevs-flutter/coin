import 'level.dart';

final class LevelPack {
  const LevelPack({required this.packVersion, required this.levels});

  final int packVersion;
  final List<LevelDefinition> levels;

  LevelDefinition? byId(String id) {
    for (final l in levels) {
      if (l.id == id) return l;
    }
    return null;
  }

  LevelDefinition? after(String id) {
    final i = levels.indexWhere((l) => l.id == id);
    return i < 0 || i + 1 >= levels.length ? null : levels[i + 1];
  }

  List<int> get chapters =>
      {for (final l in levels) l.chapter}.toList()..sort();

  List<LevelDefinition> chapter(int n) => [
    for (final l in levels)
      if (l.chapter == n) l,
  ];
}
