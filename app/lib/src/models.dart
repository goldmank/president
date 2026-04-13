import 'dart:math' as math;

enum PlayerKind { human, bot }

enum PlayerStatus { active, passed, finished }

enum GamePhase { playing, finished }

enum Suit { clubs, diamonds, hearts, spades, joker }

class CardModel {
  const CardModel({required this.id, required this.suit, required this.rank});

  final String id;
  final Suit suit;
  final int rank;

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as String,
      suit: _suitFromString(json['suit'] as String),
      rank: (json['rank'] as num).toInt(),
    );
  }
}

class PlayedSet {
  const PlayedSet({
    required this.cards,
    required this.rank,
    required this.count,
    required this.byPlayerId,
    required this.byPlayerName,
    required this.timestamp,
  });

  final List<CardModel> cards;
  final int rank;
  final int count;
  final String byPlayerId;
  final String byPlayerName;
  final int timestamp;

  factory PlayedSet.fromJson(Map<String, dynamic> json) {
    return PlayedSet(
      cards: (json['cards'] as List<dynamic>)
          .map((entry) => CardModel.fromJson(entry as Map<String, dynamic>))
          .toList(),
      rank: (json['rank'] as num).toInt(),
      count: (json['count'] as num).toInt(),
      byPlayerId: json['byPlayerId'] as String,
      byPlayerName: json['byPlayerName'] as String,
      timestamp: (json['timestamp'] as num).toInt(),
    );
  }
}

class PileState {
  const PileState({required this.currentSet, required this.history});

  final PlayedSet? currentSet;
  final List<PlayedSet> history;

  factory PileState.fromJson(Map<String, dynamic> json) {
    return PileState(
      currentSet: json['currentSet'] == null
          ? null
          : PlayedSet.fromJson(json['currentSet'] as Map<String, dynamic>),
      history: (json['history'] as List<dynamic>)
          .map((entry) => PlayedSet.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LogEntryModel {
  const LogEntryModel({
    required this.id,
    required this.text,
    required this.timestamp,
  });

  final String id;
  final String text;
  final int timestamp;

  factory LogEntryModel.fromJson(Map<String, dynamic> json) {
    return LogEntryModel(
      id: json['id'] as String,
      text: json['text'] as String,
      timestamp: (json['timestamp'] as num).toInt(),
    );
  }
}

class PublicPlayerStateModel {
  const PublicPlayerStateModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.avatarColor,
    required this.handCount,
    required this.status,
    required this.finishingPosition,
    required this.currentRole,
    required this.isCurrentTurn,
  });

  final String id;
  final String name;
  final PlayerKind kind;
  final String avatarColor;
  final int handCount;
  final PlayerStatus status;
  final int? finishingPosition;
  final String? currentRole;
  final bool isCurrentTurn;

  factory PublicPlayerStateModel.fromJson(Map<String, dynamic> json) {
    return PublicPlayerStateModel(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: _playerKindFromString(json['kind'] as String),
      avatarColor: json['avatarColor'] as String,
      handCount: (json['handCount'] as num).toInt(),
      status: _playerStatusFromString(json['status'] as String),
      finishingPosition: (json['finishingPosition'] as num?)?.toInt(),
      currentRole: json['currentRole'] as String?,
      isCurrentTurn: json['isCurrentTurn'] as bool,
    );
  }
}

class PublicGameStateModel {
  const PublicGameStateModel({
    required this.id,
    required this.phase,
    required this.players,
    required this.viewerPlayerId,
    required this.viewerHand,
    required this.currentTurnPlayerId,
    required this.lastSuccessfulPlayerId,
    required this.pile,
    required this.requirementText,
    required this.log,
  });

  final String id;
  final GamePhase phase;
  final List<PublicPlayerStateModel> players;
  final String viewerPlayerId;
  final List<CardModel> viewerHand;
  final String currentTurnPlayerId;
  final String? lastSuccessfulPlayerId;
  final PileState pile;
  final String requirementText;
  final List<LogEntryModel> log;

  factory PublicGameStateModel.fromJson(Map<String, dynamic> json) {
    return PublicGameStateModel(
      id: json['id'] as String,
      phase: _phaseFromString(json['phase'] as String),
      players: (json['players'] as List<dynamic>)
          .map(
            (entry) =>
                PublicPlayerStateModel.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      viewerPlayerId: json['viewerPlayerId'] as String,
      viewerHand: (json['viewerHand'] as List<dynamic>)
          .map((entry) => CardModel.fromJson(entry as Map<String, dynamic>))
          .toList(),
      currentTurnPlayerId: json['currentTurnPlayerId'] as String,
      lastSuccessfulPlayerId: json['lastSuccessfulPlayerId'] as String?,
      pile: PileState.fromJson(json['pile'] as Map<String, dynamic>),
      requirementText: json['requirementText'] as String,
      log: (json['log'] as List<dynamic>)
          .map((entry) => LogEntryModel.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }

  PublicPlayerStateModel get viewer =>
      players.firstWhere((player) => player.id == viewerPlayerId);
}

class PlayActionPayload {
  const PlayActionPayload({required this.playerId, required this.cardIds});

  final String playerId;
  final List<String> cardIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'play',
    'playerId': playerId,
    'cardIds': cardIds,
  };
}

class PassActionPayload {
  const PassActionPayload({required this.playerId});

  final String playerId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'pass',
    'playerId': playerId,
  };
}

Suit _suitFromString(String value) {
  switch (value) {
    case 'clubs':
      return Suit.clubs;
    case 'diamonds':
      return Suit.diamonds;
    case 'hearts':
      return Suit.hearts;
    case 'spades':
      return Suit.spades;
    case 'joker':
      return Suit.joker;
    default:
      throw ArgumentError('Unknown suit: $value');
  }
}

PlayerKind _playerKindFromString(String value) {
  switch (value) {
    case 'human':
      return PlayerKind.human;
    case 'bot':
      return PlayerKind.bot;
    default:
      throw ArgumentError('Unknown player kind: $value');
  }
}

PlayerStatus _playerStatusFromString(String value) {
  switch (value) {
    case 'active':
      return PlayerStatus.active;
    case 'passed':
      return PlayerStatus.passed;
    case 'finished':
      return PlayerStatus.finished;
    default:
      throw ArgumentError('Unknown player status: $value');
  }
}

GamePhase _phaseFromString(String value) {
  switch (value) {
    case 'playing':
      return GamePhase.playing;
    case 'finished':
      return GamePhase.finished;
    default:
      throw ArgumentError('Unknown phase: $value');
  }
}

String rankLabel(int rank) {
  return switch (rank) {
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    14 => 'A',
    15 => '2',
    16 => 'JKR',
    _ => '$rank',
  };
}

String roleLabel(PublicPlayerStateModel player, int playerCount) {
  if (player.currentRole != null) {
    return player.currentRole!;
  }
  return roleFromFinishingPosition(player.finishingPosition, playerCount);
}

String roleFromFinishingPosition(int? finishingPosition, int playerCount) {
  if (finishingPosition == 1) {
    return 'President';
  }
  if (finishingPosition == 2) {
    return 'Vice';
  }
  if (finishingPosition == playerCount - 1) {
    return 'Vice Scum';
  }
  if (finishingPosition == playerCount) {
    return 'Scum';
  }
  return 'Citizen';
}

String awardedRoleLabel(PublicPlayerStateModel player, int playerCount) {
  if (player.finishingPosition != null) {
    return roleFromFinishingPosition(player.finishingPosition, playerCount);
  }
  return roleLabel(player, playerCount);
}

String previousRoleLabel(PublicPlayerStateModel player) {
  return player.currentRole ?? 'Citizen';
}

int compareCards(CardModel a, CardModel b) {
  if (a.rank != b.rank) {
    return a.rank.compareTo(b.rank);
  }

  return suitSortOrder(a.suit).compareTo(suitSortOrder(b.suit));
}

int suitSortOrder(Suit suit) {
  return switch (suit) {
    Suit.clubs => 0,
    Suit.diamonds => 1,
    Suit.hearts => 2,
    Suit.spades => 3,
    Suit.joker => 4,
  };
}

double normalizeAngle(int index, int total) {
  final start = math.pi / 2;
  final step = (math.pi * 2) / total;
  return start + step * index;
}
