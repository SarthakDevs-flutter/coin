import '../../domain/model/board.dart';
import '../../domain/model/move.dart';
import '../session/game_session.dart';

/// Static highlight state for the board. Derived entirely from the session;
/// the renderer never computes legality itself.
final class BoardHighlights {
  const BoardHighlights({
    this.selected,
    this.liftCount = 0,
    this.targets = const {},
    this.hint,
    this.focus = const {},
    this.dealBlocked = const {},
    this.interactive = true,
  });

  static const none = BoardHighlights();

  final String? selected;

  /// How many top coins of [selected] would move (shown lifted).
  final int liftCount;
  final Set<String> targets;
  final MoveCommand? hint;

  /// Tutorial: stacks the player should tap next.
  final Set<String> focus;

  /// Trays that block the next deal (shown in warning colour).
  final Set<String> dealBlocked;
  final bool interactive;
}

/// Implemented by the renderer (Flame). The application layer pushes committed
/// state and transitions; the renderer reports taps back through a callback.
abstract interface class BoardPresenter {
  /// Rebuilds the board for [state] (load, undo, restart, booster).
  void showBoard(BoardState state, {required bool animate});

  /// Animates a committed move. Completes when the animation settles or is
  /// fast-forwarded. Never affects state.
  Future<void> playTransition(SessionTransition transition);

  void setHighlights(BoardHighlights highlights);

  /// Gentle "no" feedback on a stack.
  void nudge(String stackId);

  /// Skips any running animation to the final committed state.
  void fastForward();
}
