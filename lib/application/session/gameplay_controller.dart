import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../../domain/economy/economy.dart';
import '../../domain/model/board.dart';
import '../../domain/model/level.dart';
import '../../domain/model/move.dart';
import '../../domain/progression/player_profile.dart';
import '../../domain/rules/rules_engine.dart';
import '../../domain/solver/solver.dart';
import '../ports/board_presenter.dart';
import '../ports/ports.dart';
import '../review/review_policy.dart';
import 'game_session.dart';

enum GameMessageKind {
  rejectMismatch,
  rejectFull,
  rejectDestinationFrozen,
  rejectSourceFrozen,
  rejectCannotLift,
  rejectNothingToUndo,
  rejectBonusUsed,
  rejectNoneLeft,
  hintSearching,
  hintNone,
  hintShown,
  tutorialFollow,
  rejectNoDeals,
  rejectDealNoRoom,
  hintDeal,
}

/// Transient player-facing message. [serial] changes on every new message so
/// repeats are shown again.
final class GameMessage {
  const GameMessage(this.kind, this.serial);
  final GameMessageKind kind;
  final int serial;
}

final class WinSummary {
  const WinSummary({
    required this.moves,
    required this.granted,
    required this.alreadyClaimed,
    required this.tutorialHints,
    required this.newFamilies,
    required this.nextLevelId,
    this.askReview = false,
  });

  final int moves;
  final int granted;
  final bool alreadyClaimed;
  final int tutorialHints;
  final List<String> newFamilies;
  final String? nextLevelId;

  /// Request a store rating when the player taps Next (instead of an ad).
  final bool askReview;
}

final class GameplayState {
  const GameplayState({
    required this.session,
    required this.revision,
    this.hintBusy = false,
    this.hint,
    this.deadEnd = false,
    this.blocked = false,
    this.win,
    this.intro,
    this.sessionWasReset = false,
    this.message,
    this.coach,
  });

  final GameSession session;

  /// Mirrors [GameSession.revision] so widgets rebuild on every commit.
  final int revision;
  final bool hintBusy;
  final MoveCommand? hint;

  /// The solver proved no solution exists from this board (undo/restart fix
  /// it). Never set on a budget timeout.
  final bool deadEnd;

  /// Authoritative zero-legal-moves state; shown after animations settle.
  final bool blocked;
  final WinSummary? win;

  /// Mechanic being introduced ('forge' | 'hidden' | 'frost').
  final String? intro;
  final bool sessionWasReset;
  final GameMessage? message;

  /// One-time HUD tip being shown ('coach_hint' | 'coach_extraTray').
  final String? coach;

  LevelDefinition get level => session.level;

  GameplayState copyWith({
    int? revision,
    bool? hintBusy,
    MoveCommand? Function()? hint,
    bool? deadEnd,
    bool? blocked,
    WinSummary? Function()? win,
    String? Function()? intro,
    bool? sessionWasReset,
    GameMessage? Function()? message,
    String? Function()? coach,
  }) => GameplayState(
    session: session,
    revision: revision ?? this.revision,
    hintBusy: hintBusy ?? this.hintBusy,
    hint: hint != null ? hint() : this.hint,
    deadEnd: deadEnd ?? this.deadEnd,
    blocked: blocked ?? this.blocked,
    win: win != null ? win() : this.win,
    intro: intro != null ? intro() : this.intro,
    sessionWasReset: sessionWasReset ?? this.sessionWasReset,
    message: message != null ? message() : this.message,
    coach: coach != null ? coach() : this.coach,
  );
}

final gameplayProvider = NotifierProvider<GameplayController, GameplayState?>(
  GameplayController.new,
);

/// Coordinates one level session: input → rules → persistence → presentation.
/// Implements Flow C–H of features-and-flows.md.
final class GameplayController extends Notifier<GameplayState?> {
  static const int hintBudget = 300000;
  static const int deadEndBudget = 60000;

  /// Search budget for [board]: each node costs roughly the square of the
  /// coin count, so big boards get proportionally fewer nodes and every
  /// search stays within about the same time on device.
  static int budgetFor(int base, BoardState board) {
    var coins = board.coinCount;
    for (var i = board.dealIndex; i < board.deals.length; i++) {
      coins += board.deals[i].coinCount;
    }
    if (coins <= 40) return base;
    final scale = (40 * 40) / (coins * coins);
    return (base * scale).round().clamp(base ~/ 20, base);
  }

  static const Duration settleTimeout = Duration(seconds: 4);
  static const introducible = {'fill', 'deal', 'forge', 'hidden', 'frost'};

  /// Early levels show the next solver move, free, after this much idling.
  static const Duration idleNudgeDelay = Duration(seconds: 10);
  static const int firstNudgeLevel = 2;
  static const int lastNudgeLevel = 5;
  static const int maxNudgesPerLevel = 3;

  /// Extra-tray tip waits until the boards are big enough to need it.
  static const int extraTrayTipLevel = 6;

  static const reviewPolicy = ReviewPolicy();

  BoardPresenter? _presenter;
  int _messageSerial = 0;
  bool _onScreen = false;

  /// A level screen is open (app-open ads never cover one).
  bool get isInLevel => _onScreen;
  Timer? _idle;
  int _nudges = 0;
  int _tutorialStep = 0;

  /// No restart and no blocked board since the level was opened.
  bool _cleanAttempt = true;

  @override
  GameplayState? build() {
    ref.onDispose(() => _idle?.cancel());
    return null;
  }

  AppServices get _s => ref.read(servicesProvider);
  SaveController get _save => ref.read(saveProvider.notifier);
  PlayerProfile get _profile => ref.read(saveProvider).profile;
  GameSession? get _session => state?.session;

  // ---- lifecycle -----------------------------------------------------------

  void attach(BoardPresenter presenter) {
    _presenter = presenter;
    final st = state;
    if (st == null) return;
    presenter.showBoard(st.session.board, animate: false);
    _pushHighlights();
  }

  void detach(BoardPresenter presenter) {
    if (identical(_presenter, presenter)) _presenter = null;
  }

  /// Opens [levelId], resuming the saved session when it belongs to it.
  void open(String levelId) {
    final level = ref.read(packProvider).byId(levelId);
    if (level == null) return;
    _onScreen = true;
    _presenter?.fastForward();
    final saved = ref.read(saveProvider).activeSession;
    GameSession? session;
    var reset = false;
    if (saved != null && saved['levelId'] == levelId) {
      session = GameSession.fromJson(saved, level);
      reset = session == null;
    }
    session ??= GameSession(
      level: level,
      workshopSlots: _profile.workshopSlots,
    );
    // Slots unlocked since this session was saved join the board now.
    session.syncWorkshop(_profile.workshopSlots);
    final intro = level.introduces;
    _nudges = 0;
    _cleanAttempt = true;
    _tutorialStep = session.tutorialStepIndex;
    state = GameplayState(
      session: session,
      revision: session.revision,
      sessionWasReset: reset,
      intro:
          intro != null &&
              introducible.contains(intro) &&
              !_profile.seenIntroductions.contains(intro)
          ? intro
          : null,
      blocked: session.phase == SessionPhase.blocked,
    );
    _showCoach();
    _persistSession();
    _presenter?.showBoard(session.board, animate: false);
    _pushHighlights();
    _s.analytics.log(
      level.isTutorial
          ? AnalyticsEvent.tutorialStarted
          : AnalyticsEvent.levelStarted,
      {'level': level.id, 'version': level.version},
    );
    if (session.phase == SessionPhase.completed) {
      unawaited(_complete());
    } else if (session.board.moveCount > 0) {
      _checkDeadEnd();
    }
    _armIdle();
  }

  void dismissIntro() {
    final st = state;
    if (st?.intro == null) return;
    final key = st!.intro!;
    state = st.copyWith(intro: () => null);
    _save.updateProfile(
      (p) => p.copyWith(seenIntroductions: {...p.seenIntroductions, key}),
    );
    _showCoach();
    _pushHighlights();
    _armIdle();
  }

  /// Hides the HUD tip for good.
  void dismissCoach() {
    final key = state?.coach;
    if (key == null) return;
    state = state!.copyWith(coach: () => null);
    _save.updateProfile(
      (p) => p.copyWith(seenIntroductions: {...p.seenIntroductions, key}),
    );
  }

  /// The player left the screen. An unfinished lesson counts as abandoned.
  void leave() {
    _idle?.cancel();
    _onScreen = false;
    final st = state;
    if (st == null || !st.level.isTutorial || st.win != null) return;
    _s.analytics.log(AnalyticsEvent.tutorialAbandoned, {
      'level': st.level.id,
      'step': st.session.tutorialStepIndex,
    });
  }

  /// Asks the platform for a rating; called from the win sheet's Next.
  Future<void> requestReview() async {
    final st = state;
    if (st == null || !(st.win?.askReview ?? false)) return;
    final now = _s.clock.now();
    await _save.updateSettings(
      (s) => s.copyWith(reviewRequests: [...s.reviewRequests, now]),
    );
    _s.analytics.log(AnalyticsEvent.reviewRequested, {'level': st.level.id});
    try {
      await _s.review.request();
    } on Object catch (e, stack) {
      _s.crash.record(e, stack, context: {'where': 'review'});
    }
  }

  void acknowledgeReset() {
    final st = state;
    if (st != null) state = st.copyWith(sessionWasReset: false);
  }

  /// App going to background: settle visuals, persist.
  void onBackground() {
    _presenter?.fastForward();
    if (state != null) _persistSession();
    unawaited(_save.flush());
  }

  // ---- commands ------------------------------------------------------------

  void tapStack(String stackId) {
    final st = state;
    if (st == null || st.win != null || st.intro != null) return;
    _armIdle();
    final outcome = st.session.tapStack(stackId);
    if (outcome.transition != null) {
      _onTransition(outcome.transition!);
      return;
    }
    if (outcome.isRejected) {
      _reject(outcome, stackId);
      return;
    }
    if (outcome.selectionChanged) {
      _s.audio.play(st.session.selected == null ? Sfx.deselect : Sfx.select);
      _s.haptics.play(HapticKind.light);
      state = st.copyWith(revision: st.session.revision, message: () => null);
      _pushHighlights();
    }
  }

  void undo() {
    final st = state;
    if (st == null || st.win != null) return;
    _armIdle();
    final outcome = st.session.undo();
    if (outcome.transition == null) {
      _reject(outcome, null);
      return;
    }
    _s.audio.play(Sfx.undo);
    _s.analytics.log(AnalyticsEvent.undoUsed, {'level': st.level.id});
    _onTransition(outcome.transition!);
  }

  void restart() {
    final st = state;
    if (st == null) return;
    final outcome = st.session.restart();
    _cleanAttempt = false;
    _s.analytics.log(AnalyticsEvent.levelRestarted, {'level': st.level.id});
    state = st.copyWith(win: () => null);
    _onTransition(outcome.transition!);
  }

  /// Deal button (Flow C for the deal action). Rejections highlight the
  /// trays that need room instead of failing silently.
  void deal() {
    final st = state;
    if (st == null || st.win != null || st.intro != null) return;
    _armIdle();
    final outcome = st.session.deal();
    if (outcome.transition != null) {
      _dealBlocked = const {};
      _onTransition(outcome.transition!);
      return;
    }
    if (outcome.moveRejection == MoveRejection.dealNoRoom) {
      _dealBlocked = st.session.engine
          .dealBlockedStacks(st.session.board)
          .toSet();
      for (final id in _dealBlocked) {
        _presenter?.nudge(id);
      }
      _pushHighlights();
    }
    _reject(outcome, null);
  }

  Set<String> _dealBlocked = const {};

  /// Unlocks top-row workshop slot [index] with earned gilt and adds it to
  /// the live board immediately. Returns the reason when it can't.
  Future<EconomyError?> unlockWorkshop(int index) async {
    final result = Economy.unlockWorkshopSlot(
      _profile,
      index,
      now: _s.clock.now(),
    );
    if (!result.isOk) return result.error;
    await _save.updateProfile((_) => result.profile);
    _s.audio.play(Sfx.reward);
    _s.haptics.play(HapticKind.success);
    _s.analytics.log(AnalyticsEvent.boosterUsed, {
      'item': 'workshopSlot',
      'slot': index,
    });
    final st = state;
    if (st == null || !ref.mounted) return null;
    final outcome = st.session.syncWorkshop(result.profile.workshopSlots);
    if (outcome.transition != null) _onTransition(outcome.transition!);
    return null;
  }

  void useBonusTray() {
    final st = state;
    if (st == null || st.win != null) return;
    if (st.session.bonusUsed) {
      _message(GameMessageKind.rejectBonusUsed);
      return;
    }
    if (_profile.count(InventoryItem.bonusTray) <= 0) {
      _message(GameMessageKind.rejectNoneLeft);
      return;
    }
    final outcome = st.session.addBonusTray();
    if (outcome.transition == null) {
      _reject(outcome, null);
      return;
    }
    // Spend only after the tray was actually added.
    final spent = Economy.consume(_profile, InventoryItem.bonusTray);
    if (spent.isOk) _save.updateProfile((_) => spent.profile);
    if (st.coach == 'coach_extraTray') dismissCoach();
    _s.analytics.log(AnalyticsEvent.boosterUsed, {
      'level': st.level.id,
      'item': 'bonusTray',
    });
    _onTransition(outcome.transition!);
  }

  Future<void> useHint() async {
    final st = state;
    if (st == null || st.win != null || st.hintBusy) return;
    if (st.level.isTutorial) {
      _message(GameMessageKind.tutorialFollow);
      return;
    }
    if (_profile.count(InventoryItem.hint) <= 0) {
      _message(GameMessageKind.rejectNoneLeft);
      return;
    }
    if (st.coach == 'coach_hint') dismissCoach();
    _idle?.cancel();
    final session = st.session;
    final rev = session.revision;
    state = state!.copyWith(hintBusy: true);
    _message(GameMessageKind.hintSearching);
    SolveResult result;
    try {
      result = await _s.solver.solve(
        session.board,
        session.level.objective,
        maxNodes: budgetFor(hintBudget, session.board),
      );
    } on Object catch (e, stack) {
      _s.crash.record(
        e,
        stack,
        context: {'where': 'hint', 'level': session.level.id},
      );
      result = const SolveResult(SolveStatus.unknownBudgetExceeded);
    }
    if (!ref.mounted) return;
    final now = state;
    if (now == null || !identical(now.session, session)) return;
    if (session.revision != rev) {
      // Board changed while searching: drop the stale hint, charge nothing.
      state = now.copyWith(hintBusy: false);
      return;
    }
    if (result.isSolved && result.path.isNotEmpty) {
      final spent = Economy.consume(_profile, InventoryItem.hint);
      if (spent.isOk) await _save.updateProfile((_) => spent.profile);
      _s.analytics.log(AnalyticsEvent.hintUsed, {'level': session.level.id});
      state = now.copyWith(hintBusy: false, hint: () => result.path.first);
      _message(
        result.path.first.isDeal
            ? GameMessageKind.hintDeal
            : GameMessageKind.hintShown,
      );
    } else {
      state = now.copyWith(
        hintBusy: false,
        deadEnd: result.status == SolveStatus.unsolvedProven ? true : null,
      );
      _message(GameMessageKind.hintNone);
    }
    _pushHighlights();
  }

  /// Tutorial/QA helper: executes the highlighted hint move.
  void playHint() {
    final h = state?.hint;
    if (h == null) return;
    final outcome = state!.session.submitMove(h);
    if (outcome.transition != null) _onTransition(outcome.transition!);
  }

  // ---- internals -----------------------------------------------------------

  void _onTransition(SessionTransition t) {
    _dealBlocked = const {};
    final st = state!;
    final session = st.session;
    state = st.copyWith(
      revision: session.revision,
      hint: () => null,
      deadEnd: false,
      blocked: false,
      message: () => null,
    );
    _persistSession();
    _pushHighlights();
    _armIdle();
    if (session.tutorialStepIndex > _tutorialStep) {
      _tutorialStep = session.tutorialStepIndex;
      _s.analytics.log(AnalyticsEvent.tutorialStep, {
        'level': session.level.id,
        'step': _tutorialStep,
      });
    }
    final settled = switch (t.kind) {
      TransitionKind.move =>
        _presenter?.playTransition(t) ?? Future<void>.value(),
      _ => () {
        _presenter?.showBoard(t.to, animate: true);
        return Future<void>.value();
      }(),
    };
    if (t.kind == TransitionKind.move) _s.haptics.play(HapticKind.medium);

    switch (session.phase) {
      case SessionPhase.completed:
        unawaited(_afterSettled(settled, session, _complete));
      case SessionPhase.blocked:
        unawaited(
          _afterSettled(settled, session, () async {
            _s.analytics.log(AnalyticsEvent.verifiedNoMovesState, {
              'level': session.level.id,
            });
            final now = state;
            if (now != null && identical(now.session, session)) {
              _cleanAttempt = false;
              state = now.copyWith(blocked: true);
              _s.haptics.play(HapticKind.warning);
            }
          }),
        );
      case SessionPhase.ready || SessionPhase.sourceSelected:
        if (t.kind == TransitionKind.move) _checkDeadEnd();
    }
  }

  Future<void> _afterSettled(
    Future<void> settled,
    GameSession session,
    Future<void> Function() then,
  ) async {
    final rev = session.revision;
    try {
      await settled.timeout(settleTimeout);
    } on TimeoutException {
      // Presentation stalled; state is already committed, carry on.
    }
    if (!ref.mounted) return;
    final now = state;
    if (now == null ||
        !identical(now.session, session) ||
        session.revision != rev) {
      return;
    }
    await then();
  }

  Future<void> _complete() async {
    final st = state;
    if (st == null || st.win != null) return;
    final level = st.level;
    final before = _profile;
    final result = Economy.completeLevel(
      before,
      level,
      moves: st.session.board.moveCount,
      now: _s.clock.now(),
    );
    final families = {
      for (final s in level.initialState.stacks)
        for (final c in s.coins) c.familyId,
    };
    final newFamilies = [
      for (final f in families)
        if (!before.discoveredFamilies.contains(f)) f,
    ];
    final profile = result.profile.copyWith(
      discoveredFamilies: {...result.profile.discoveredFamilies, ...families},
    );
    await _save.commit(profile: profile, activeSession: () => null);
    if (!ref.mounted) return;
    final next = ref.read(packProvider).after(level.id);
    _idle?.cancel();
    final askReview = reviewPolicy.shouldRequest(
      level: level,
      firstClear: !before.completions.containsKey(level.id),
      cleanAttempt: _cleanAttempt,
      history: ref.read(saveProvider).settings.reviewRequests,
      now: _s.clock.now(),
    );
    state = state?.copyWith(
      win: () => WinSummary(
        moves: st.session.board.moveCount,
        granted: result.granted,
        alreadyClaimed: result.granted == 0,
        tutorialHints: level.isTutorial && result.granted > 0
            ? Economy.tutorialHintBonus
            : 0,
        newFamilies: newFamilies,
        nextLevelId: next?.id,
        askReview: askReview,
      ),
      coach: () => null,
    );
    _pushHighlights();
    _s.audio.play(Sfx.win);
    _s.haptics.play(HapticKind.success);
    _s.analytics.log(
      level.isTutorial
          ? AnalyticsEvent.tutorialCompleted
          : AnalyticsEvent.levelCompleted,
      {
        'level': level.id,
        'moves': st.session.board.moveCount,
        'par': level.parMoves,
      },
    );
  }

  void _checkDeadEnd() {
    final session = _session;
    if (session == null) return;
    final rev = session.revision;
    unawaited(() async {
      SolveResult r;
      try {
        r = await _s.solver.solve(
          session.board,
          session.level.objective,
          maxNodes: budgetFor(deadEndBudget, session.board),
          // A newer move supersedes this check before it even starts.
          isStale: () =>
              !ref.mounted ||
              !identical(_session, session) ||
              session.revision != rev,
        );
      } on Object catch (e, stack) {
        _s.crash.record(e, stack, context: {'where': 'deadEnd'});
        return;
      }
      if (!ref.mounted) return;
      final now = state;
      if (now == null ||
          !identical(now.session, session) ||
          session.revision != rev) {
        return;
      }
      if (r.status == SolveStatus.unsolvedProven) {
        if (session.board.moveCount == 0) {
          // Should be impossible for validated levels: record a diagnostic.
          _s.crash.record(
            StateError('level_unsolvable'),
            StackTrace.current,
            context: {
              'level': session.level.id,
              'hash': session.board.stateHash,
            },
          );
        }
        state = now.copyWith(deadEnd: true);
      }
    }());
  }

  void _reject(CommandOutcome outcome, String? stackId) {
    final kind = switch (outcome.rejection) {
      CommandRejection.illegalMove => switch (outcome.moveRejection) {
        MoveRejection.destinationFull => GameMessageKind.rejectFull,
        MoveRejection.destinationFrozen =>
          GameMessageKind.rejectDestinationFrozen,
        MoveRejection.sourceFrozen => GameMessageKind.rejectSourceFrozen,
        MoveRejection.sourceEmpty => GameMessageKind.rejectCannotLift,
        MoveRejection.noDealsLeft => GameMessageKind.rejectNoDeals,
        MoveRejection.dealNoRoom => GameMessageKind.rejectDealNoRoom,
        _ => GameMessageKind.rejectMismatch,
      },
      CommandRejection.cannotLift =>
        _frozenTop(stackId)
            ? GameMessageKind.rejectSourceFrozen
            : GameMessageKind.rejectCannotLift,
      CommandRejection.nothingToUndo => GameMessageKind.rejectNothingToUndo,
      CommandRejection.followTutorial => GameMessageKind.tutorialFollow,
      CommandRejection.bonusAlreadyUsed => GameMessageKind.rejectBonusUsed,
      CommandRejection.sessionOver || null => null,
    };
    if (kind == null) return;
    _s.audio.play(Sfx.invalid);
    if (stackId != null) _presenter?.nudge(stackId);
    _message(kind);
  }

  bool _frozenTop(String? stackId) {
    if (stackId == null) return false;
    final top = _session?.board.stackById(stackId)?.top;
    return top != null && top.isFrozen;
  }

  void _message(GameMessageKind kind) {
    final st = state;
    if (st == null) return;
    state = st.copyWith(message: () => GameMessage(kind, ++_messageSerial));
  }

  void _persistSession() {
    final session = _session;
    if (session == null || session.isOver) return;
    unawaited(_save.setActiveSession(session.toJson()));
  }

  /// Picks the next unseen HUD tip, if any. Intro cards always go first.
  void _showCoach() {
    final st = state;
    if (st == null || st.intro != null || st.coach != null) return;
    if (st.level.isTutorial || st.win != null) return;
    final p = _profile;
    final seen = p.seenIntroductions;
    final String? key;
    if (!seen.contains('coach_hint') && p.count(InventoryItem.hint) > 0) {
      key = 'coach_hint';
    } else if (st.level.number >= extraTrayTipLevel &&
        !seen.contains('coach_extraTray') &&
        p.count(InventoryItem.bonusTray) > 0) {
      key = 'coach_extraTray';
    } else {
      key = null;
    }
    if (key == null) return;
    state = st.copyWith(coach: () => key);
    _s.analytics.log(AnalyticsEvent.coachTipShown, {'tip': key});
  }

  bool _nudgeable(GameplayState st) =>
      !st.level.isTutorial &&
      st.level.number >= firstNudgeLevel &&
      st.level.number <= lastNudgeLevel &&
      _nudges < maxNudgesPerLevel &&
      st.win == null &&
      !st.session.isOver;

  /// Restarts the idle countdown after any input.
  void _armIdle() {
    _idle?.cancel();
    final st = state;
    if (st == null || !_nudgeable(st)) return;
    _idle = Timer(idleNudgeDelay, () => unawaited(_nudge()));
  }

  /// Tests: fire the idle nudge now.
  Future<void> debugIdleNudge() => _nudge();

  /// Shows the next solver move with the hand pointer, free of charge.
  Future<void> _nudge() async {
    final st = state;
    if (st == null || !ref.mounted || !_nudgeable(st)) return;
    if (st.intro != null || st.hint != null || st.hintBusy || st.blocked) {
      return;
    }
    final session = st.session;
    if (session.selected != null) return;
    final rev = session.revision;
    SolveResult r;
    try {
      r = await _s.solver.solve(
        session.board,
        session.level.objective,
        maxNodes: budgetFor(hintBudget, session.board),
        isStale: () =>
            !ref.mounted ||
            !identical(_session, session) ||
            session.revision != rev,
      );
    } on Object catch (e, stack) {
      _s.crash.record(e, stack, context: {'where': 'nudge'});
      return;
    }
    if (!ref.mounted) return;
    final now = state;
    if (now == null ||
        !identical(now.session, session) ||
        session.revision != rev ||
        session.selected != null ||
        now.hint != null ||
        !r.isSolved ||
        r.path.isEmpty) {
      return;
    }
    _nudges++;
    state = now.copyWith(hint: () => r.path.first);
    _s.analytics.log(AnalyticsEvent.idleNudgeShown, {
      'level': session.level.id,
    });
    _pushHighlights();
  }

  void _pushHighlights() {
    final p = _presenter;
    final st = state;
    if (p == null || st == null) return;
    final s = st.session;
    final sel = s.selected;
    final step = s.tutorialStep;
    final focus = <String>{
      if (step?.move != null) sel == null ? step!.move!.from : step!.move!.to,
    };
    p.setHighlights(
      BoardHighlights(
        selected: sel,
        liftCount: sel == null
            ? 0
            : (s.board.stackById(sel)?.topRunLength ?? 0),
        targets: s.legalTargets.toSet(),
        hint: st.hint,
        focus: focus,
        dealBlocked: _dealBlocked,
        interactive: st.win == null && st.intro == null && !s.isOver,
      ),
    );
  }
}
