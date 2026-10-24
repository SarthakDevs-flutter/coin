import 'package:coin/domain/model/board.dart';
import 'package:coin/domain/model/coin.dart';

/// Compact board builder for tests: `'J R R'` is a stack (bottom→top) of
/// jade, ruby, ruby. Suffix `2` = tier 2, `*n` = frost n, `?` = veiled.
BoardState board(
  List<String> stacks, {
  int capacity = 4,
  int threshold = 3,
  int maxTier = 1,
}) {
  var n = 0;
  const names = {'J': 'jade', 'R': 'ruby', 'S': 'sapphire', 'A': 'amber'};
  return BoardState(
    rules: RuleSet(mergeThreshold: threshold, maxTier: maxTier),
    stacks: [
      for (var i = 0; i < stacks.length; i++)
        StackState(
          id: 's$i',
          capacity: capacity,
          coins: [
            for (final tok in stacks[i].split(' ').where((t) => t.isNotEmpty))
              _coin(tok, 'c${n++}', names),
          ],
        ),
    ],
  );
}

CoinState _coin(String tok, String id, Map<String, String> names) {
  final family = names[tok[0]]!;
  final tierMatch = RegExp(r'^\w(\d)').firstMatch(tok);
  final frostMatch = RegExp(r'\*(\d)').firstMatch(tok);
  final hidden = tok.contains('?');
  final frost = frostMatch == null ? 0 : int.parse(frostMatch.group(1)!);
  return CoinState(
    id: id,
    familyId: family,
    tier: tierMatch == null ? 1 : int.parse(tierMatch.group(1)!),
    frost: frost,
    isRevealed: !hidden,
    specialType: hidden
        ? SpecialCoinType.hidden
        : frost > 0
        ? SpecialCoinType.frosted
        : SpecialCoinType.none,
  );
}

String describe(StackState s) => s.coins
    .map((c) => '${c.familyId[0].toUpperCase()}${c.tier == 1 ? '' : c.tier}')
    .join(' ');
