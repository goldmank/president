class UserProgress {
  const UserProgress({
    this.gamesPlayed = 0,
    this.presidentGames = 0,
    this.viceGames = 0,
    this.citizenGames = 0,
    this.viceScumGames = 0,
    this.scumGames = 0,
    this.debugScoreBonus = 0,
  });

  final int gamesPlayed;
  final int presidentGames;
  final int viceGames;
  final int citizenGames;
  final int viceScumGames;
  final int scumGames;
  final int debugScoreBonus;

  int get score =>
      presidentGames * 10 +
      viceGames * 8 +
      citizenGames * 5 +
      viceScumGames * 2 +
      scumGames +
      debugScoreBonus;

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
      presidentGames: (json['presidentGames'] as num?)?.toInt() ?? 0,
      viceGames: (json['viceGames'] as num?)?.toInt() ?? 0,
      citizenGames: (json['citizenGames'] as num?)?.toInt() ?? 0,
      viceScumGames: (json['viceScumGames'] as num?)?.toInt() ?? 0,
      scumGames: (json['scumGames'] as num?)?.toInt() ?? 0,
      debugScoreBonus: (json['debugScoreBonus'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'gamesPlayed': gamesPlayed,
    'presidentGames': presidentGames,
    'viceGames': viceGames,
    'citizenGames': citizenGames,
    'viceScumGames': viceScumGames,
    'scumGames': scumGames,
    'debugScoreBonus': debugScoreBonus,
  };

  UserProgress copyWith({
    int? gamesPlayed,
    int? presidentGames,
    int? viceGames,
    int? citizenGames,
    int? viceScumGames,
    int? scumGames,
    int? debugScoreBonus,
  }) {
    return UserProgress(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      presidentGames: presidentGames ?? this.presidentGames,
      viceGames: viceGames ?? this.viceGames,
      citizenGames: citizenGames ?? this.citizenGames,
      viceScumGames: viceScumGames ?? this.viceScumGames,
      scumGames: scumGames ?? this.scumGames,
      debugScoreBonus: debugScoreBonus ?? this.debugScoreBonus,
    );
  }

  UserProgress recordRole(String role) {
    return switch (role) {
      'President' => copyWith(
        gamesPlayed: gamesPlayed + 1,
        presidentGames: presidentGames + 1,
      ),
      'Vice' => copyWith(
        gamesPlayed: gamesPlayed + 1,
        viceGames: viceGames + 1,
      ),
      'Vice Scum' => copyWith(
        gamesPlayed: gamesPlayed + 1,
        viceScumGames: viceScumGames + 1,
      ),
      'Scum' => copyWith(
        gamesPlayed: gamesPlayed + 1,
        scumGames: scumGames + 1,
      ),
      _ => copyWith(
        gamesPlayed: gamesPlayed + 1,
        citizenGames: citizenGames + 1,
      ),
    };
  }
}
