import '../../domain/model/board.dart';
import '../../domain/model/level.dart';
import '../../domain/model/level_pack.dart';

export '../../domain/model/level_pack.dart';

abstract final class LevelPackCodec {
  static LevelPack decode(Map<String, Object?> json) {
    final rules = json['rulesVersion'] as int?;
    if (rules == null || rules < 1 || rules > BoardState.rulesVersion) {
      throw FormatException('Level pack rules version $rules unsupported');
    }
    return LevelPack(
      packVersion: json['packVersion']! as int,
      levels: [
        for (final l in json['levels']! as List)
          LevelDefinition.fromJson((l as Map).cast()),
      ],
    );
  }

  /// Pack-level consistency (ids unique, numbering contiguous).
  static List<String> packIssues(LevelPack pack) {
    final issues = <String>[];
    final ids = <String>{};
    for (var i = 0; i < pack.levels.length; i++) {
      final l = pack.levels[i];
      if (!ids.add(l.id)) issues.add('duplicate level id ${l.id}');
      if (l.number != i + 1) issues.add('${l.id} numbered ${l.number}');
    }
    if (pack.levels.isEmpty) issues.add('empty pack');
    return issues;
  }
}
