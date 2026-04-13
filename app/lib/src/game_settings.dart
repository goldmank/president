class GameSettings {
  const GameSettings({this.doubleDeck = false, this.aiDifficulty = 4});

  final bool doubleDeck;
  final int aiDifficulty;

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      doubleDeck: json['doubleDeck'] as bool? ?? false,
      aiDifficulty: (json['aiDifficulty'] as num?)?.toInt() ?? 4,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'doubleDeck': doubleDeck,
    'aiDifficulty': aiDifficulty,
  };

  GameSettings copyWith({bool? doubleDeck, int? aiDifficulty}) {
    return GameSettings(
      doubleDeck: doubleDeck ?? this.doubleDeck,
      aiDifficulty: aiDifficulty ?? this.aiDifficulty,
    );
  }
}
