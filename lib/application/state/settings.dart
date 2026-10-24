/// Player preferences. Persisted with the profile.
final class GameSettings {
  const GameSettings({
    this.sfx = true,
    this.music = true,
    this.haptics = true,
    this.reducedMotion = false,
    this.colorBlind = false,
    this.localeCode,
    this.analyticsConsent = false,
    this.devOverlay = false,
    this.themeId = 'atelier',
  });

  final bool sfx;
  final bool music;
  final bool haptics;
  final bool reducedMotion;
  final bool colorBlind;

  /// Null follows the device language.
  final String? localeCode;

  /// Opt-in. Off by default: nothing is collected until the player agrees.
  final bool analyticsConsent;

  /// Debug builds only: FPS, state hash, legal-move count, seed.
  final bool devOverlay;

  /// Selected look (coins, board and scenery). Unknown ids fall back to the
  /// default in presentation.
  final String themeId;

  GameSettings copyWith({
    bool? sfx,
    bool? music,
    bool? haptics,
    bool? reducedMotion,
    bool? colorBlind,
    String? Function()? localeCode,
    bool? analyticsConsent,
    bool? devOverlay,
    String? themeId,
  }) => GameSettings(
    sfx: sfx ?? this.sfx,
    music: music ?? this.music,
    haptics: haptics ?? this.haptics,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    colorBlind: colorBlind ?? this.colorBlind,
    localeCode: localeCode != null ? localeCode() : this.localeCode,
    analyticsConsent: analyticsConsent ?? this.analyticsConsent,
    devOverlay: devOverlay ?? this.devOverlay,
    themeId: themeId ?? this.themeId,
  );

  Map<String, Object?> toJson() => {
    'sfx': sfx,
    'music': music,
    'haptics': haptics,
    'reducedMotion': reducedMotion,
    'colorBlind': colorBlind,
    'locale': ?localeCode,
    'analyticsConsent': analyticsConsent,
    'devOverlay': devOverlay,
    'theme': themeId,
  };

  factory GameSettings.fromJson(Map<String, Object?> j) => GameSettings(
    sfx: (j['sfx'] as bool?) ?? true,
    music: (j['music'] as bool?) ?? true,
    haptics: (j['haptics'] as bool?) ?? true,
    reducedMotion: (j['reducedMotion'] as bool?) ?? false,
    colorBlind: (j['colorBlind'] as bool?) ?? false,
    localeCode: j['locale'] as String?,
    analyticsConsent: (j['analyticsConsent'] as bool?) ?? false,
    devOverlay: (j['devOverlay'] as bool?) ?? false,
    themeId: (j['theme'] as String?) ?? 'atelier',
  );
}
