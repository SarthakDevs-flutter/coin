import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/providers.dart';
import '../../domain/model/level.dart';
import '../../domain/progression/progression.dart';
import '../common/widgets.dart';
import '../gameplay/gameplay_screen.dart';
import '../home/home_screen.dart';

class ChapterMapScreen extends ConsumerWidget {
  const ChapterMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final pack = ref.watch(packProvider);
    final profile = ref.watch(saveProvider.select((s) => s.profile));
    final current = Progression.currentLevel(pack, profile);
    // QA aid: the developer overlay (debug builds only) unlocks every level.
    final qaUnlock =
        kDebugMode &&
        ref.watch(saveProvider.select((s) => s.settings.devOverlay));
    return Scaffold(
      appBar: AppBar(title: Text(l.chapters)),
      extendBodyBehindAppBar: true,
      body: AtelierBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AtelierSpacing.md,
              8,
              AtelierSpacing.md,
              32,
            ),
            children: [
              for (final ch in pack.chapters) ...[
                SectionTitle(l.chapterN(ch)),
                IvoryPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              HomeScreen.chapterName(context, ch),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: AtelierColors.textOnLight),
                            ),
                          ),
                          Text(
                            l.progressFraction(
                              Progression.completedInChapter(pack, profile, ch),
                              pack.chapter(ch).length,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AtelierColors.textOnLightMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        HomeScreen.chapterDesc(context, ch),
                        style: const TextStyle(
                          color: AtelierColors.textOnLightMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: [
                          for (final level in pack.chapter(ch))
                            _LevelNode(
                              level: level,
                              completed: profile.isCompleted(level.id),
                              unlocked:
                                  qaUnlock ||
                                  Progression.isUnlocked(pack, profile, level),
                              current:
                                  level.id == current.id &&
                                  !profile.isCompleted(level.id),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.level,
    required this.completed,
    required this.unlocked,
    required this.current,
  });

  final LevelDefinition level;
  final bool completed;
  final bool unlocked;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final Color fill;
    final Color fg;
    if (completed) {
      fill = AtelierColors.primary;
      fg = AtelierColors.textOnLight;
    } else if (current) {
      fill = AtelierColors.accent;
      fg = AtelierColors.textOnLight;
    } else if (unlocked) {
      fill = const Color(0xFFF7EBD6);
      fg = AtelierColors.textOnLight;
    } else {
      fill = const Color(0xFFDCD3C3);
      fg = AtelierColors.disabled;
    }
    return Semantics(
      button: true,
      enabled: unlocked,
      label: '${l.levelN(level.number)}${unlocked ? '' : ', ${l.levelLocked}'}',
      excludeSemantics: true,
      child: InkResponse(
        radius: 30,
        onTap: () {
          if (!unlocked) {
            showToast(context, l.levelLocked);
            return;
          }
          Navigator.of(context)
              .push(atelierRoute(GameplayScreen(levelId: level.id)));
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _node(fg, fill),
            if (DifficultyBadge.marks(level.difficulty))
              Positioned(
                right: -4,
                top: -4,
                child: DifficultyBadge(
                  difficulty: level.difficulty,
                  compact: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _node(Color fg, Color fill) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: fill,
      border: Border.all(
        color: current
            ? AtelierColors.accentDeep
            : DifficultyBadge.marks(level.difficulty)
            ? DifficultyBadge.colors(level.difficulty).last
            : const Color(0x22000000),
        width: current || DifficultyBadge.marks(level.difficulty) ? 3 : 1.5,
      ),
      boxShadow: [
        if (unlocked)
          const BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
      ],
    ),
    alignment: Alignment.center,
    child: unlocked
        ? Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '${level.number}',
                style: TextStyle(
                  fontFamily: AtelierFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: 19,
                  color: fg,
                ),
              ),
              if (completed)
                const Positioned(
                  bottom: 3,
                  child: Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AtelierColors.textOnLight,
                  ),
                ),
            ],
          )
        : Icon(Icons.lock_rounded, color: fg, size: 20),
  );
}
