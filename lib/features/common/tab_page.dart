import 'package:flutter/material.dart';

import 'game_ui.dart';

/// Body of a bottom-bar tab: a ribbon title over the content. The shell
/// supplies the scenery, the top HUD and the tab bar.
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: RibbonBanner(title, fontSize: 22),
        ),
      ),
      Expanded(child: child),
    ],
  );
}

/// Stroked section label with a gold rule, for lists inside tabs.
class GameSectionTitle extends StatelessWidget {
  const GameSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
    child: Semantics(
      header: true,
      child: Row(
        children: [
          Flexible(
            child: StrokeText(
              text,
              size: 17,
              align: TextAlign.left,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(color: Color(0x66FFE08A), thickness: 2),
          ),
        ],
      ),
    ),
  );
}
