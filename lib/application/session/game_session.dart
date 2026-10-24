import '../../domain/model/board.dart';
import '../../domain/model/events.dart';
import '../../domain/model/level.dart';
import '../../domain/model/move.dart';
import '../../domain/rules/rules_engine.dart';

enum SessionPhase {
  /// Waiting for the player to pick a source stack.
  ready,

  /// A source is selected; legal destinations are highlighted.
  sourceSelected,

  /// Objective met. Terminal: all commands are rejected.
  completed,

  /// Authoritative check found zero legal moves.
  blocked,
}

enum TransitionKind { move, undo, restart, bonusTray, workshop, load }

/// A committed change of authoritative state, plus the ordered event log the
/// renderer animates.
final class SessionTransition {
  const SessionTransition({
    required this.kind,
    required this.from,
    required this.to,
    this.events = const [],
  });

  final TransitionKind kind;
  final BoardState from;
  final BoardState to;
  final List<DomainEvent> events;
}

/// Why a tap/command did nothing. No rejection ever mutates state.
enum CommandRejection {
  illegalMove,
  cannotLift,
  nothingToUndo,
  followTutorial,
  sessionOver,
  bonusAlreadyUsed,
}

final class CommandOutcome {
  const CommandOutcome({
    this.transition,
    this.rejection,
    this.moveRejection,
    this.selectionChanged = false,
  });

  static const unchanged = CommandOutcome();

  final SessionTransition? transition;
  final CommandRejection? rejection;
  final MoveRejection? moveRejection;
  final bool selectionChanged;

  bool get isRejected => rejection != null;
}

/// One play-through of one level. Owns authoritative board state, bounded
/// undo history, selection, and tutorial progress. Pure Dart; no I/O.
///
/// Every mutation happens in a single synchronous method so commands are
/// serialised by construction: a second tap can never interleave with a
/// half-applied move.
final class GameSession {
  GameSession({
    required this.level,
    this.engine = const RulesEngine(),
    BoardState? board,
    List<BoardState> history = const [],
    this.bonusUsed = false,
    int tutorialStep = 0,
    int workshopSlots = 0,
  }) : _workshopSlots = level.isTutorial ? 0 : workshopSlots,
       _board =
           board ??
           _initialBoard(engine, level, level.isTutorial ? 0 : workshopSlots),
       _history = List.of(history),
       _tutorialStep = level.isTutorial ? tutorialStep : 0 {
    _refreshPhase();
  }

  static BoardState _initialBoard(
    RulesEngine engine,
    LevelDefinition level,
    int slots,
  ) {
    var b = engine.settle(level.initialState);
    for (var i = 0; i < slots; i++) {
      b = engine.addWorkshopStack(b, i);
    }
    return b;
  }

  int _workshopSlots;
  int get workshopSlots => _workshopSlots;

  /// Adds newly unlocked workshop trays (empty) to the live board and to
  /// every undo snapshot, so undo never removes a permanent upgrade.
  CommandOutcome syncWorkshop(int slots) {
    if (level.isTutorial || slots <= _workshopSlots) {
      return CommandOutcome.unchanged;
    }
    final from = _board;
    for (var i = _workshopSlots; i < slots; i++) {
      if (_board.stackById('w$i') != null) continue;
      _board = engine.addWorkshopStack(_board, i);
      for (var h = 0; h < _history.length; h++) {
        _history[h] = engine.addWorkshopStack(_history[h], i);
      }
    }
    _workshopSlots = slots;
    _selected = null;
    _bump();
    return CommandOutcome(
      transition: SessionTransition(
        kind: TransitionKind.workshop,
        from: from,
        to: _board,
      ),
    );
  }

  static const int maxUndo = 200;

  final LevelDefinition level;
  final RulesEngine engine;

  BoardState _board;
  final List<BoardState> _history;
  String? _selected;
  SessionPhase _phase = SessionPhase.ready;
  int _tutorialStep;
  bool bonusUsed;

  /// Monotonic id of the current board; async results (hints, dead-end
  /// checks) carry it and are dropped when stale.
  int _revision = 0;

  BoardState get board => _board;
  SessionPhase get phase => _phase;
  String? get selected => _selected;
  int get revision => _revision;
  bool get canUndo =>
      _history.isNotEmpty &&
      _phase != SessionPhase.completed &&
      !_tutorialBlocksUndo;
  List<BoardState> get history => List.unmodifiable(_history);
  int get tutorialStepIndex => _tutorialStep;

  TutorialStep? get tutorialStep =>
      level.isTutorial && _tutorialStep < level.tutorial.length
      ? level.tutorial[_tutorialStep]
      : null;

  bool get isOver => _phase == SessionPhase.completed;

  List<String> get legalTargets => _selected == null
      ? const []
      : engine.legalDestinations(_board, _selected!);

  List<MoveCommand> get legalMoves => engine.legalMoves(_board);

  /// Stacks the player can currently lift from.
  Set<String> get liftable => {
    for (final m in legalMoves)
      if (!m.isDeal) m.from,
  };

  CommandOutcome tapStack(String stackId) {
    if (isOver) {
      return const CommandOutcome(rejection: CommandRejection.sessionOver);
    }
    final step = tutorialStep;
    if (step != null && step.expectUndo) {
      return const CommandOutcome(rejection: CommandRejection.followTutorial);
    }
    final sel = _selected;
    if (sel == null) {
      if (step?.move != null && step!.move!.from != stackId) {
        return const CommandOutcome(rejection: CommandRejection.followTutorial);
      }
      if (!engine.legalMoves(_board).any((m) => m.from == stackId)) {
        return const CommandOutcome(rejection: CommandRejection.cannotLift);
      }
      _selected = stackId;
      _phase = SessionPhase.sourceSelected;
      return const CommandOutcome(selectionChanged: true);
    }
    if (sel == stackId) {
      _selected = null;
      _phase = SessionPhase.ready;
      return const CommandOutcome(selectionChanged: true);
    }
    final move = MoveCommand(sel, stackId);
    if (step?.move != null && step!.move != move) {
      return const CommandOutcome(rejection: CommandRejection.followTutorial);
    }
    final validation = engine.validate(_board, move);
    if (!validation.isLegal) {
      // Tapping another liftable stack switches the selection instead of
      // failing — the common intent when a player changes their mind.
      if (step == null &&
          engine.legalMoves(_board).any((m) => m.from == stackId)) {
        _selected = stackId;
        return const CommandOutcome(selectionChanged: true);
      }
      return CommandOutcome(
        rejection: CommandRejection.illegalMove,
        moveRejection: validation.rejection,
      );
    }
    return CommandOutcome(transition: _commitMove(move));
  }

  /// Applies [move] directly (hint execution, tests). Same rules as taps.
  CommandOutcome submitMove(MoveCommand move) {
    if (isOver) {
      return const CommandOutcome(rejection: CommandRejection.sessionOver);
    }
    final step = tutorialStep;
    if (step != null && step.move != move) {
      return const CommandOutcome(rejection: CommandRejection.followTutorial);
    }
    final v = engine.validate(_board, move);
    if (!v.isLegal) {
      return CommandOutcome(
        rejection: CommandRejection.illegalMove,
        moveRejection: v.rejection,
      );
    }
    return CommandOutcome(transition: _commitMove(move));
  }

  /// Presses Deal. Same validation, undo and tutorial rules as any move.
  CommandOutcome deal() {
    _selected = null;
    return submitMove(MoveCommand.deal);
  }

  bool get canDeal => engine.validateDeal(_board).isLegal;

  void clearSelection() {
    if (_selected == null) return;
    _selected = null;
    _refreshPhase();
  }

  CommandOutcome undo() {
    if (isOver) {
      return const CommandOutcome(rejection: CommandRejection.sessionOver);
    }
    if (_tutorialBlocksUndo) {
      return const CommandOutcome(rejection: CommandRejection.followTutorial);
    }
    if (_history.isEmpty) {
      return const CommandOutcome(rejection: CommandRejection.nothingToUndo);
    }
    final from = _board;
    _board = _history.removeLast();
    _selected = null;
    if (tutorialStep?.expectUndo ?? false) _tutorialStep++;
    _bump();
    return CommandOutcome(
      transition: SessionTransition(
        kind: TransitionKind.undo,
        from: from,
        to: _board,
      ),
    );
  }

  /// Restores the exact initial board (same level data, same ids).
  CommandOutcome restart() {
    final from = _board;
    _board = _initialBoard(engine, level, _workshopSlots);
    _history.clear();
    _selected = null;
    _tutorialStep = 0;
    bonusUsed = false;
    _bump();
    return CommandOutcome(
      transition: SessionTransition(
        kind: TransitionKind.restart,
        from: from,
        to: _board,
      ),
    );
  }

  /// Adds the bonus tray. Booster use is a committed purchase-like action, so
  /// it clears undo history: undo can never return a spent booster's effect
  /// while keeping the booster spent, nor refund it.
  CommandOutcome addBonusTray() {
    if (isOver) {
      return const CommandOutcome(rejection: CommandRejection.sessionOver);
    }
    if (bonusUsed) {
      return const CommandOutcome(rejection: CommandRejection.bonusAlreadyUsed);
    }
    if (level.isTutorial) {
      return const CommandOutcome(rejection: CommandRejection.followTutorial);
    }
    final from = _board;
    _board = engine.addBonusStack(_board, id: 'bonus');
    _history.clear();
    bonusUsed = true;
    _selected = null;
    _bump();
    return CommandOutcome(
      transition: SessionTransition(
        kind: TransitionKind.bonusTray,
        from: from,
        to: _board,
      ),
    );
  }

  bool get _tutorialBlocksUndo {
    final step = tutorialStep;
    return step != null && !step.expectUndo;
  }

  SessionTransition _commitMove(MoveCommand move) {
    final resolution = engine.apply(_board, move, objective: level.objective);
    final violations = engine.invariantViolations(resolution.next);
    if (violations.isNotEmpty) {
      // Never commit a corrupt board. Surfaces as a diagnosed defect.
      throw RulesInvariantError(violations.join('; '));
    }
    _history.add(_board);
    if (_history.length > maxUndo) _history.removeAt(0);
    _board = resolution.next;
    _selected = null;
    if (tutorialStep?.move == move) _tutorialStep++;
    _bump();
    return SessionTransition(
      kind: TransitionKind.move,
      from: resolution.previous,
      to: resolution.next,
      events: resolution.events,
    );
  }

  void _bump() {
    _revision++;
    _refreshPhase();
  }

  void _refreshPhase() {
    _phase = switch (engine.status(_board, level.objective)) {
      BoardStatus.completed => SessionPhase.completed,
      BoardStatus.noLegalMoves => SessionPhase.blocked,
      BoardStatus.playable =>
        _selected == null ? SessionPhase.ready : SessionPhase.sourceSelected,
    };
  }

  // ---- persistence -------------------------------------------------------

  static const int _persistedHistory = 30;

  Map<String, Object?> toJson() => {
    'levelId': level.id,
    'levelVersion': level.version,
    'levelHash': level.initialState.stateHash,
    'board': _board.toJson(),
    'history': [
      for (final h in _history.skip(
        _history.length > _persistedHistory
            ? _history.length - _persistedHistory
            : 0,
      ))
        h.toJson(),
    ],
    'bonusUsed': bonusUsed,
    'tutorialStep': _tutorialStep,
    'workshopSlots': _workshopSlots,
  };

  /// Rebuilds a session from a snapshot. Returns null when the snapshot does
  /// not belong to [level] (version changed) or fails invariants: the caller
  /// then offers a free restart.
  static GameSession? fromJson(
    Map<String, Object?> json,
    LevelDefinition level, {
    RulesEngine engine = const RulesEngine(),
  }) {
    try {
      if (json['levelId'] != level.id ||
          json['levelVersion'] != level.version ||
          json['levelHash'] != level.initialState.stateHash) {
        return null;
      }
      final board = BoardState.fromJson((json['board']! as Map).cast());
      if (engine.invariantViolations(board).isNotEmpty) return null;
      final history = [
        for (final h in (json['history'] as List?) ?? const [])
          BoardState.fromJson((h as Map).cast()),
      ];
      return GameSession(
        level: level,
        engine: engine,
        board: board,
        history: history,
        bonusUsed: (json['bonusUsed'] as bool?) ?? false,
        tutorialStep: (json['tutorialStep'] as int?) ?? 0,
        workshopSlots: (json['workshopSlots'] as int?) ?? 0,
      );
    } on Object {
      return null;
    }
  }
}
