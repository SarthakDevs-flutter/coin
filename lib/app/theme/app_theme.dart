import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AtelierTheme {
  static ThemeData build() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AtelierColors.primary,
      onPrimary: AtelierColors.textOnLight,
      secondary: AtelierColors.accent,
      onSecondary: AtelierColors.textOnLight,
      error: AtelierColors.danger,
      onError: AtelierColors.textOnDark,
      surface: AtelierColors.background,
      onSurface: AtelierColors.textOnDark,
      surfaceContainerHighest: AtelierColors.surface,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AtelierColors.background,
      fontFamily: AtelierFonts.body,
    );
    TextStyle display(double size, FontWeight w) => TextStyle(
      fontFamily: AtelierFonts.display,
      fontSize: size,
      fontWeight: w,
      color: AtelierColors.textOnDark,
      height: 1.1,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: display(44, FontWeight.w600),
        displayMedium: display(34, FontWeight.w600),
        headlineMedium: display(26, FontWeight.w600),
        titleLarge: display(21, FontWeight.w600),
        titleMedium: display(17, FontWeight.w500),
        bodyLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        labelLarge: const TextStyle(
          fontFamily: AtelierFonts.display,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AtelierColors.textOnDark,
        titleTextStyle: TextStyle(
          fontFamily: AtelierFonts.display,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AtelierColors.textOnDark,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AtelierColors.surface
              : AtelierColors.textOnDarkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AtelierColors.primary
              : AtelierColors.trayEdge,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AtelierColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: AtelierFonts.display,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AtelierColors.textOnLight,
        ),
        contentTextStyle: TextStyle(
          fontFamily: AtelierFonts.body,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AtelierColors.textOnLightMuted,
          height: 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AtelierRadii.lg),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AtelierColors.surface,
        contentTextStyle: TextStyle(
          fontFamily: AtelierFonts.body,
          fontWeight: FontWeight.w700,
          color: AtelierColors.textOnLight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AtelierRadii.md),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AtelierColors.primaryDeep,
          minimumSize: const Size(
            AtelierSpacing.tapTarget,
            AtelierSpacing.tapTarget,
          ),
          textStyle: const TextStyle(
            fontFamily: AtelierFonts.display,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
