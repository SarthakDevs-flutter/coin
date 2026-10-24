import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../features/boot/boot_screen.dart';
import '../features/common/theme_scope.dart';
import '../game/render/theme/coin_themes.dart';
import 'app_lifecycle_coordinator.dart';
import 'localization/gen/app_localizations.dart';
import 'theme/app_theme.dart';

class CoinAtelierApp extends ConsumerWidget {
  const CoinAtelierApp({super.key});

  static final _theme = AtelierTheme.build();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootProvider);
    final code = boot.hasValue
        ? ref.watch(saveProvider.select((s) => s.settings.localeCode))
        : null;
    final themeId = boot.hasValue
        ? ref.watch(saveProvider.select((s) => s.settings.themeId))
        : null;
    final reducedMotion =
        boot.hasValue &&
        ref.watch(saveProvider.select((s) => s.settings.reducedMotion));
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: _theme,
      locale: code == null ? null : Locale(code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => CoinThemeScope(
        theme: CoinThemes.byId(themeId),
        reducedMotion: reducedMotion,
        child: AppLifecycleCoordinator(child: child!),
      ),
      home: const BootScreen(),
    );
  }
}
