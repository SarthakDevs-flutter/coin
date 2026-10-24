import '../../domain/progression/player_profile.dart';
import 'settings.dart';

/// Root of everything persisted locally.
final class SaveData {
  const SaveData({
    required this.profile,
    required this.settings,
    this.activeSession,
  });

  factory SaveData.fresh() =>
      SaveData(profile: PlayerProfile.fresh(), settings: const GameSettings());

  final PlayerProfile profile;
  final GameSettings settings;

  /// Serialized [GameSession] of the level in progress, if any.
  final Map<String, Object?>? activeSession;

  SaveData copyWith({
    PlayerProfile? profile,
    GameSettings? settings,
    Map<String, Object?>? Function()? activeSession,
  }) => SaveData(
    profile: profile ?? this.profile,
    settings: settings ?? this.settings,
    activeSession: activeSession != null ? activeSession() : this.activeSession,
  );

  Map<String, Object?> toJson() => {
    'profile': profile.toJson(),
    'settings': settings.toJson(),
    'activeSession': ?activeSession,
  };

  factory SaveData.fromJson(Map<String, Object?> j) => SaveData(
    profile: PlayerProfile.fromJson((j['profile']! as Map).cast()),
    settings: GameSettings.fromJson(
      ((j['settings'] as Map?) ?? const {}).cast(),
    ),
    activeSession: (j['activeSession'] as Map?)?.cast(),
  );
}
