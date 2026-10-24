import '../model/level.dart';
import '../model/level_pack.dart';
import 'player_profile.dart';

/// Campaign unlock rules: a level is playable when it is the first level or
/// the previous level has been completed. Completed levels stay replayable.
abstract final class Progression {
  static bool isUnlocked(
    LevelPack pack,
    PlayerProfile p,
    LevelDefinition level,
  ) {
    final i = pack.levels.indexOf(level);
    if (i <= 0) return true;
    return p.isCompleted(pack.levels[i - 1].id);
  }

  /// The level "Continue" should open: first unlocked, uncompleted level, or
  /// the last level when everything is done.
  static LevelDefinition currentLevel(LevelPack pack, PlayerProfile p) {
    for (final l in pack.levels) {
      if (!p.isCompleted(l.id)) return l;
    }
    return pack.levels.last;
  }

  static bool campaignComplete(LevelPack pack, PlayerProfile p) =>
      pack.levels.every((l) => p.isCompleted(l.id));

  static int completedInChapter(LevelPack pack, PlayerProfile p, int chapter) =>
      pack.chapter(chapter).where((l) => p.isCompleted(l.id)).length;
}
