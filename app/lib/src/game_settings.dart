class GameSettings {
  const GameSettings({
    this.doubleDeck = false,
    this.aiDifficulty = 4,
    this.musicEnabled = true,
    this.sfxEnabled = true,
  });

  final bool doubleDeck;
  final int aiDifficulty;
  final bool musicEnabled;
  final bool sfxEnabled;

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      doubleDeck: json['doubleDeck'] as bool? ?? false,
      aiDifficulty: (json['aiDifficulty'] as num?)?.toInt() ?? 4,
      musicEnabled: json['musicEnabled'] as bool? ?? true,
      sfxEnabled: json['sfxEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'doubleDeck': doubleDeck,
    'aiDifficulty': aiDifficulty,
    'musicEnabled': musicEnabled,
    'sfxEnabled': sfxEnabled,
  };

  GameSettings copyWith({
    bool? doubleDeck,
    int? aiDifficulty,
    bool? musicEnabled,
    bool? sfxEnabled,
  }) {
    return GameSettings(
      doubleDeck: doubleDeck ?? this.doubleDeck,
      aiDifficulty: aiDifficulty ?? this.aiDifficulty,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
    );
  }
}
