import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/ports/ports.dart';
import '../../application/providers.dart';
import '../../application/session/gameplay_controller.dart';
import '../../application/state/settings.dart';
import '../../domain/economy/economy.dart';
import '../../domain/model/objective.dart';
import '../../domain/progression/player_profile.dart';
import '../../game/coin_atelier_game.dart';
import '../../game/render/theme/coin_themes.dart';
import '../common/names.dart';
import '../common/widgets.dart';
import 'gameplay_hud.dart';
import 'gameplay_overlays.dart';

class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key, required this.levelId});

  final String levelId;

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen> {
  late final CoinAtelierGame _game;
  late final GameplayController _controller;
  int _lastMessage = 0;

  /// Level whose difficulty notice has been shown.
  String? _announced;

  final _gameKey = GlobalKey();
  final _boardKey = GlobalKey();
  final _dealKey = GlobalKey();
  final Map<String, GlobalKey> _goalKeys = {};

  /// Goal-tile and chain feedback live in notifiers, not screen state: a coin
  /// landing on the HUD mid-animation must not rebuild the whole screen (and
  /// the game widget under it) on every hit.
  final _goalFx = ValueNotifier<_GoalFx>(const _GoalFx());
  final _chainFx = ValueNotifier<(int chain, int serial)>((0, 0));

  @override
  void initState() {
    super.initState();
    _controller = ref.read(gameplayProvider.notifier);
    final settings = ref.read(saveProvider).settings;
    final profile = ref.read(saveProvider).profile;
    _game = CoinAtelierGame(
      onStackTap: _controller.tapStack,
      audio: ref.read(servicesProvider).audio,
      visuals: _visualsFor(settings, profile),
      pixelRatio: WidgetsBinding
          .instance
          .platformDispatcher
          .views
          .first
          .devicePixelRatio,
      hooks: GameShellHooks(
        dealOrigin: () => _centerOf(_dealKey),
        goalTarget: (key) => _centerOf(_goalKeys[key]),
        onGoalLaunch: (key) {
          if (!mounted) return;
          _goalFx.value = _goalFx.value.launch(key);
        },
        onGoalHit: (key) {
          if (!mounted) return;
          _goalFx.value = _goalFx.value.hit(key);
          ref.read(servicesProvider).haptics.play(HapticKind.light);
        },
        onChain: (n) {
          if (!mounted) return;
          _chainFx.value = (n, _chainFx.value.$2 + 1);
          ref.read(servicesProvider)
            ..audio.play(Sfx.chain)
            ..haptics.play(HapticKind.success);
        },
      ),
    );
    // Provider mutations must happen after the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller
        ..open(widget.levelId)
        ..attach(_game);
    });
  }

  @override
  void dispose() {
    _goalFx.dispose();
    _chainFx.dispose();
    _controller.detach(_game);
    // Persisting mutates providers, which is not allowed mid-teardown.
    final controller = _controller;
    Future(controller.onBackground);
    super.dispose();
  }

  /// Centre of the widget behind [key], in game-canvas coordinates.
  Offset? _centerOf(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    final game = _gameKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || game == null || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero)) -
        game.localToGlobal(Offset.zero);
  }

  int _seenWorkshopRects = 0;

  Future<void> _unlockWorkshop(int index) async {
    final l = context.l10n;
    final spec = WorkshopCatalog.slots[index];
    final ok = await confirmDialog(
      context,
      title: l.workshopTitle,
      body: l.workshopBody,
      confirm: l.workshopUnlockFor(spec.cost),
    );
    if (!ok || !mounted) return;
    final error = await _controller.unlockWorkshop(index);
    if (!mounted) return;
    showToast(
      context,
      error == null
          ? l.workshopUnlocked
          : error == EconomyError.insufficientFunds
          ? l.notEnoughGilt
          : l.levelLocked,
      bottom: 150,
    );
  }

  /// Tells the game which part of the canvas is free for the board.
  void _syncBoardArea() {
    if (_game.workshopRects.length != _seenWorkshopRects) {
      _seenWorkshopRects = _game.workshopRects.length;
      setState(() {});
    }
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final game = _gameKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || game == null) return;
    final topLeft =
        box.localToGlobal(Offset.zero) - game.localToGlobal(Offset.zero);
    _game.setBoardArea(topLeft & box.size);
  }

  BoardVisualSettings _visualsFor(GameSettings s, PlayerProfile p) =>
      BoardVisualSettings(
        finish: p.activeFinish,
        colorBlind: s.colorBlind,
        reducedMotion: s.reducedMotion,
        theme: CoinThemes.byId(s.themeId),
      );

  String _messageText(GameMessageKind k) {
    final l = context.l10n;
    return switch (k) {
      GameMessageKind.rejectMismatch => l.rejectMismatch,
      GameMessageKind.rejectFull => l.rejectFull,
      GameMessageKind.rejectDestinationFrozen => l.rejectDestinationFrozen,
      GameMessageKind.rejectSourceFrozen => l.rejectSourceFrozen,
      GameMessageKind.rejectCannotLift => l.rejectCannotLift,
      GameMessageKind.rejectNothingToUndo => l.rejectNothingToUndo,
      GameMessageKind.rejectBonusUsed => l.rejectBonusUsed,
      GameMessageKind.rejectNoneLeft => l.rejectNoneLeft,
      GameMessageKind.hintSearching => l.hintSearching,
      GameMessageKind.hintNone => l.hintNone,
      GameMessageKind.hintShown => l.hintShown,
      GameMessageKind.tutorialFollow => l.tutorialFollow,
      GameMessageKind.rejectNoDeals => l.rejectNoDeals,
      GameMessageKind.rejectDealNoRoom => l.rejectDealNoRoom,
      GameMessageKind.hintDeal => l.hintDeal,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(saveProvider, (prev, next) {
      if (prev?.settings != next.settings ||
          prev?.profile.activeFinish != next.profile.activeFinish) {
        _game.updateVisuals(_visualsFor(next.settings, next.profile));
      }
    });
    ref.listen(gameplayProvider.select((s) => s?.message), (_, m) {
      if (m == null || m.serial == _lastMessage) return;
      _lastMessage = m.serial;
      if (m.kind == GameMessageKind.hintSearching) return;
      showToast(context, _messageText(m.kind), bottom: 150);
    });
    ref.listen(gameplayProvider.select((s) => s?.sessionWasReset ?? false), (
      _,
      reset,
    ) {
      if (!reset) return;
      showToast(context, context.l10n.sessionReset);
      _controller.acknowledgeReset();
    });

    final st = ref.watch(gameplayProvider);
    final ready = st != null && st.level.id == widget.levelId;
    final settings = ref.watch(saveProvider.select((s) => s.settings));
    final profile = ref.watch(saveProvider.select((s) => s.profile));
    if (ready) {
      _game
        ..objective = st.level.objective
        ..workshopRow = st.level.isTutorial ? 0 : WorkshopCatalog.slots.length;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncBoardArea();
    });
    if (ready && _announced != st.level.id) {
      _announced = st.level.id;
      final lvl = st.level;
      // Hard levels from chapter 5 on pay a gilt bonus: say so up front.
      if (DifficultyBadge.marks(lvl.difficulty) && lvl.chapter >= 5) {
        final l = context.l10n;
        final expert = lvl.difficulty == 'expert';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showToast(
            context,
            l.difficultyBonus(
              expert ? l.difficultyExpert : l.difficultyHard,
              expert ? '2' : '1.5',
            ),
            bottom: 150,
          );
        });
      }
    }
    final hasDeals = ready && st.session.board.deals.isNotEmpty;

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: AtelierBackground(
          child: Stack(
            children: [
              // The canvas spans the whole screen so coins can fly to the HUD.
              Positioned.fill(
                // Own layer: the game repaints every frame, the HUD and the
                // backdrop (with their shadows) must not repaint with it.
                child: RepaintBoundary(
                  child: KeyedSubtree(
                    key: _gameKey,
                    child: GameWidget(game: _game),
                  ),
                ),
              ),
              if (ready)
                Positioned.fill(
                  child: _BoardSemantics(game: _game, state: st),
                ),
              if (ready && !st.level.isTutorial)
                for (final (i, r) in _game.workshopRects.indexed)
                  if (i >= profile.workshopSlots)
                    Positioned.fromRect(
                      rect: r,
                      child: WorkshopLockCard(
                        afterLevel: WorkshopCatalog.slots[i].afterLevel,
                        cost: WorkshopCatalog.slots[i].cost,
                        isNext: i == profile.workshopSlots,
                        reachable:
                            profile.completions.length >=
                            WorkshopCatalog.slots[i].afterLevel,
                        onUnlock: () => _unlockWorkshop(i),
                      ),
                    ),
              SafeArea(
                child: Column(
                  children: [
                    if (ready)
                      RepaintBoundary(child: _TopBar(state: st))
                    else
                      const SizedBox(height: 64),
                    if (ready)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: RepaintBoundary(
                            child: ValueListenableBuilder<_GoalFx>(
                              valueListenable: _goalFx,
                              builder: (context, fx, _) => GoalTiles(
                                goals: goalsFor(st),
                                keys: _goalKeys,
                                inFlight: fx.inFlight,
                                bumps: fx.bumps,
                                finish: profile.activeFinish,
                                colorBlind: settings.colorBlind,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (ready) _Callout(state: st),
                    Expanded(
                      child: Stack(
                        key: _boardKey,
                        children: [
                          Align(
                            alignment: const Alignment(0, -0.75),
                            child: RepaintBoundary(
                              child: ValueListenableBuilder<(int, int)>(
                                valueListenable: _chainFx,
                                builder: (context, fx, _) =>
                                    ChainBanner(chain: fx.$1, serial: fx.$2),
                              ),
                            ),
                          ),
                          if (kDebugMode && settings.devOverlay && ready)
                            Positioned(
                              left: 8,
                              top: 4,
                              child: _DebugOverlay(game: _game, state: st),
                            ),
                        ],
                      ),
                    ),
                    if (hasDeals)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: KeyedSubtree(
                          key: _dealKey,
                          child: DealButton(
                            board: st.session.board,
                            glow: st.hint?.isDeal ?? false,
                            finish: profile.activeFinish,
                            colorBlind: settings.colorBlind,
                            onPressed:
                                st.win == null &&
                                    st.session.board.hasPendingDeals
                                ? _controller.deal
                                : null,
                          ),
                        ),
                      ),
                    if (ready) _BottomBar(state: st, profile: profile),
                  ],
                ),
              ),
              if (ready && st.intro != null)
                IntroOverlay(
                  mechanic: st.intro!,
                  onDone: _controller.dismissIntro,
                ),
              if (ready && st.blocked && st.win == null)
                BlockedOverlay(state: st, profile: profile),
              if (ready && st.win != null) WinOverlay(state: st),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coins in flight to each goal tile and how many have landed (bumps).
final class _GoalFx {
  const _GoalFx({this.inFlight = const {}, this.bumps = const {}});

  final Map<String, int> inFlight;
  final Map<String, int> bumps;

  _GoalFx launch(String key) => _GoalFx(
    inFlight: {...inFlight, key: (inFlight[key] ?? 0) + 1},
    bumps: bumps,
  );

  _GoalFx hit(String key) => _GoalFx(
    inFlight: {...inFlight, key: math.max(0, (inFlight[key] ?? 1) - 1)},
    bumps: {...bumps, key: (bumps[key] ?? 0) + 1},
  );
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state});

  final GameplayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final level = state.level;
    final board = state.session.board;
    final objective = level.objective;
    final (label, done, total) = switch (objective) {
      ClearBoardObjective() => (l.objectiveClear, null, null),
      ForgeObjective(:final tier, :final count) => (
        l.objectiveForge(count, tier),
        board.progress.forgedOfTier(tier).clamp(0, count),
        count,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          BarButton(
            icon: Icons.pause_rounded,
            tooltip: l.pause,
            onPressed: () => showPauseSheet(context, ref, state),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l.levelN(level.number),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(width: 8),
                      DifficultyBadge(difficulty: level.difficulty),
                    ],
                  ),
                  Text(
                    total == null
                        ? '$label · ${l.coinsLeft(board.coinCount)}'
                        : '$label · ${l.progressFraction(done!, total)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AtelierColors.textOnDarkMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _RuleChip(
                threshold: board.rules.mergeThreshold,
                fill: board.rules.fillToSeal,
              ),
              const SizedBox(height: 4),
              Text(
                l.movesCount(board.moveCount),
                style: const TextStyle(
                  color: AtelierColors.textOnDarkMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.threshold, required this.fill});

  final int threshold;
  final bool fill;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0x33000000),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AtelierColors.accent.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          fill ? Icons.vertical_align_top_rounded : Icons.layers_rounded,
          size: 16,
          color: AtelierColors.accent,
        ),
        const SizedBox(width: 4),
        Text(
          fill ? context.l10n.fillRule : context.l10n.fuseRule(threshold),
          style: const TextStyle(
            fontFamily: AtelierFonts.display,
            fontWeight: FontWeight.w500,
            color: AtelierColors.textOnDark,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

/// Tutorial instruction or dead-end notice, above the board.
class _Callout extends ConsumerWidget {
  const _Callout({required this.state});

  final GameplayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final step = state.session.tutorialStep;
    String? text;
    var tone = AtelierColors.surface;
    if (step != null) {
      text = switch (step.messageKey) {
        'tutorialMove' => l.tutorialMove,
        'tutorialUndo' => l.tutorialUndo,
        'tutorialRedo' => l.tutorialRedo,
        'tutorialFuse' => l.tutorialFuse,
        'tutorialFinish' => l.tutorialFinish,
        _ => null,
      };
    } else if (state.deadEnd && !state.blocked && state.win == null) {
      text = l.deadEnd;
      tone = const Color(0xFFFFE6C2);
    }
    return AnimatedSwitcher(
      duration: AtelierMotion.ui,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              key: ValueKey(text),
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: const BorderRadius.all(AtelierRadii.md),
                    border: Border.all(color: AtelierColors.accent, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        step != null
                            ? Icons.lightbulb_rounded
                            : Icons.info_rounded,
                        color: AtelierColors.accentDeep,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: AtelierColors.textOnLight,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.state, required this.profile});

  final GameplayState state;
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(gameplayProvider.notifier);
    final s = state.session;
    final tutorial = s.level.isTutorial;
    final undoStep = s.tutorialStep?.expectUndo ?? false;
    final active = state.win == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          RoundAction(
            icon: Icons.undo_rounded,
            label: l.undo,
            highlight: undoStep,
            onPressed: active && (s.canUndo || undoStep) ? c.undo : null,
          ),
          RoundAction(
            icon: Icons.lightbulb_rounded,
            label: l.hint,
            badge: '${profile.count(InventoryItem.hint)}',
            busy: state.hintBusy,
            onPressed: active && !tutorial ? c.useHint : null,
          ),
          RoundAction(
            icon: Icons.add_box_rounded,
            label: l.extraTray,
            badge: '${profile.count(InventoryItem.bonusTray)}',
            onPressed: active && !tutorial && !s.bonusUsed
                ? c.useBonusTray
                : null,
          ),
          RoundAction(
            icon: Icons.restart_alt_rounded,
            label: l.restart,
            onPressed: active && !tutorial && s.board.moveCount > 0
                ? () async {
                    final ok = await confirmDialog(
                      context,
                      title: l.restartConfirmTitle,
                      body: l.restartConfirmBody,
                      confirm: l.restart,
                    );
                    if (ok) c.restart();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// Invisible accessibility layer: one semantic button per tray, positioned
/// over the canvas. Pointer events pass through to the game.
class _BoardSemantics extends ConsumerWidget {
  const _BoardSemantics({required this.game, required this.state});

  final CoinAtelierGame game;
  final GameplayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rects = game.trayRects;
    if (rects.isEmpty) return const SizedBox.shrink();
    final s = state.session;
    final targets = s.legalTargets.toSet();
    final c = ref.read(gameplayProvider.notifier);
    return IgnorePointer(
      child: Stack(
        children: [
          for (final (i, stack) in s.board.stacks.indexed)
            if (rects[stack.id] case final r?)
              Positioned.fromRect(
                rect: r,
                child: Semantics(
                  button: true,
                  selected: s.selected == stack.id,
                  label: l.a11yStack(
                    i + 1,
                    stack.coins.length,
                    stack.top == null
                        ? ''
                        : stack.top!.isRevealed
                        ? l.a11yTop(
                            familyDisplayName(context, stack.top!.familyId),
                            stack.top!.tier,
                          )
                        : '?',
                  ),
                  hint: targets.contains(stack.id) ? l.a11yTarget : null,
                  onTap: () => c.tapStack(stack.id),
                  child: const SizedBox.expand(),
                ),
              ),
        ],
      ),
    );
  }
}

class _DebugOverlay extends StatefulWidget {
  const _DebugOverlay({required this.game, required this.state});

  final CoinAtelierGame game;
  final GameplayState state;

  @override
  State<_DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<_DebugOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state.session;
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(6),
        color: const Color(0xAA000000),
        child: DefaultTextStyle(
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontFamily: 'monospace',
          ),
          child: Text(
            'fps ${widget.game.fps.toStringAsFixed(0)}\n'
            'level ${s.level.id} v${s.level.version} seed ${s.level.seed ?? '-'}\n'
            'hash ${s.board.stateHash} rev ${s.revision}\n'
            'legal ${s.legalMoves.length} phase ${s.phase.name}',
          ),
        ),
      ),
    );
  }
}
