import 'board.dart';
import 'move.dart';
import 'objective.dart';

/// A scripted tutorial step: the player must perform exactly [move] (or tap
/// undo when [expectUndo] is true) to advance.
final class TutorialStep {
  const TutorialStep({
    required this.messageKey,
    this.move,
    this.expectUndo = false,
  });

  /// Localization key looked up by the UI.
  final String messageKey;
  final MoveCommand? move;
  final bool expectUndo;

  Map<String, Object?> toJson() => {
    'message': messageKey,
    if (move != null) 'move': move!.toJson(),
    if (expectUndo) 'undo': true,
  };

  factory TutorialStep.fromJson(Map<String, Object?> json) => TutorialStep(
    messageKey: json['message']! as String,
    move: json['move'] == null
        ? null
        : MoveCommand.fromJson((json['move']! as Map).cast()),
    expectUndo: (json['undo'] as bool?) ?? false,
  );
}

/// Validation metadata attached by the offline level pipeline.
final class SolverProof {
  const SolverProof({
    required this.solution,
    required this.solutionHash,
    required this.nodesExpanded,
    required this.solverVersion,
  });

  final List<MoveCommand> solution;
  final String solutionHash;
  final int nodesExpanded;
  final int solverVersion;

  Map<String, Object?> toJson() => {
    'solverVersion': solverVersion,
    'nodes': nodesExpanded,
    'hash': solutionHash,
    'solution': [for (final m in solution) m.toJson()],
  };

  factory SolverProof.fromJson(Map<String, Object?> json) => SolverProof(
    solverVersion: json['solverVersion']! as int,
    nodesExpanded: json['nodes']! as int,
    solutionHash: json['hash']! as String,
    solution: [
      for (final m in json['solution']! as List)
        MoveCommand.fromJson((m as Map).cast()),
    ],
  );
}

final class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.number,
    required this.chapter,
    required this.version,
    required this.difficulty,
    required this.initialState,
    required this.objective,
    required this.reward,
    required this.parMoves,
    this.seed,
    this.generatorVersion,
    this.proof,
    this.tutorial = const [],
    this.introduces,
  });

  final String id;

  /// 1-based position in the campaign.
  final int number;
  final int chapter;
  final int version;

  /// Informational label: easy / medium / hard / expert.
  final String difficulty;
  final BoardState initialState;
  final ObjectiveDefinition objective;

  /// Soft currency granted on first completion.
  final int reward;

  /// Informational only, never punitive.
  final int parMoves;
  final int? seed;
  final int? generatorVersion;
  final SolverProof? proof;
  final List<TutorialStep> tutorial;

  /// Mechanic introduced by this level (drives the one-time explainer).
  final String? introduces;

  bool get isTutorial => tutorial.isNotEmpty;

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'chapter': chapter,
    'version': version,
    'difficulty': difficulty,
    'reward': reward,
    'par': parMoves,
    if (seed != null) 'seed': seed,
    if (generatorVersion != null) 'generatorVersion': generatorVersion,
    if (introduces != null) 'introduces': introduces,
    'objective': objective.toJson(),
    'board': initialState.toJson(),
    if (tutorial.isNotEmpty) 'tutorial': [for (final t in tutorial) t.toJson()],
    if (proof != null) 'proof': proof!.toJson(),
  };

  factory LevelDefinition.fromJson(Map<String, Object?> json) =>
      LevelDefinition(
        id: json['id']! as String,
        number: json['number']! as int,
        chapter: json['chapter']! as int,
        version: json['version']! as int,
        difficulty: json['difficulty']! as String,
        reward: json['reward']! as int,
        parMoves: json['par']! as int,
        seed: json['seed'] as int?,
        generatorVersion: json['generatorVersion'] as int?,
        introduces: json['introduces'] as String?,
        objective: ObjectiveDefinition.fromJson(
          (json['objective']! as Map).cast(),
        ),
        initialState: BoardState.fromJson((json['board']! as Map).cast()),
        tutorial: [
          for (final t in (json['tutorial'] as List?) ?? const [])
            TutorialStep.fromJson((t as Map).cast()),
        ],
        proof: json['proof'] == null
            ? null
            : SolverProof.fromJson((json['proof']! as Map).cast()),
      );
}
