enum LeaderboardWindowRange { allTime, weekly, daily }

extension LeaderboardWindowRangeApi on LeaderboardWindowRange {
  String get apiValue => switch (this) {
    LeaderboardWindowRange.allTime => 'all_time',
    LeaderboardWindowRange.weekly => 'weekly',
    LeaderboardWindowRange.daily => 'daily',
  };

  String get label => switch (this) {
    LeaderboardWindowRange.allTime => 'All Time',
    LeaderboardWindowRange.weekly => 'Weekly',
    LeaderboardWindowRange.daily => 'Daily',
  };
}

LeaderboardWindowRange leaderboardWindowRangeFromJson(String value) {
  return switch (value) {
    'all_time' => LeaderboardWindowRange.allTime,
    'weekly' => LeaderboardWindowRange.weekly,
    'daily' => LeaderboardWindowRange.daily,
    _ => LeaderboardWindowRange.allTime,
  };
}

class LeaderboardEntryModel {
  const LeaderboardEntryModel({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.score,
    required this.gamesPlayed,
    required this.position,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final int score;
  final int gamesPlayed;
  final int position;

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      score: (json['score'] as num).toInt(),
      gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num).toInt(),
    );
  }
}

class LeaderboardStandingModel extends LeaderboardEntryModel {
  const LeaderboardStandingModel({
    required super.userId,
    required super.displayName,
    super.photoUrl,
    required super.score,
    required super.gamesPlayed,
    required super.position,
    required this.inTopResults,
  });

  final bool inTopResults;

  factory LeaderboardStandingModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardStandingModel(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      score: (json['score'] as num).toInt(),
      gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num).toInt(),
      inTopResults: json['inTopResults'] as bool? ?? false,
    );
  }
}

class LeaderboardSnapshotModel {
  const LeaderboardSnapshotModel({
    required this.window,
    required this.limit,
    required this.generatedAt,
    required this.entries,
    required this.viewerEntry,
  });

  final LeaderboardWindowRange window;
  final int limit;
  final int generatedAt;
  final List<LeaderboardEntryModel> entries;
  final LeaderboardStandingModel? viewerEntry;

  factory LeaderboardSnapshotModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardSnapshotModel(
      window: leaderboardWindowRangeFromJson(json['window'] as String),
      limit: (json['limit'] as num).toInt(),
      generatedAt: (json['generatedAt'] as num).toInt(),
      entries: (json['entries'] as List<dynamic>)
          .map(
            (entry) =>
                LeaderboardEntryModel.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      viewerEntry: json['viewerEntry'] == null
          ? null
          : LeaderboardStandingModel.fromJson(
              json['viewerEntry'] as Map<String, dynamic>,
            ),
    );
  }
}

class RankedQueueTicketModel {
  const RankedQueueTicketModel({
    required this.ticketId,
    required this.userId,
    required this.displayName,
    required this.rankScore,
    required this.queuedAt,
    required this.maxWaitMs,
    required this.status,
    this.roomId,
  });

  final String ticketId;
  final String userId;
  final String displayName;
  final int rankScore;
  final int queuedAt;
  final int maxWaitMs;
  final String status;
  final String? roomId;

  factory RankedQueueTicketModel.fromJson(Map<String, dynamic> json) {
    return RankedQueueTicketModel(
      ticketId: json['ticketId'] as String,
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      rankScore: (json['rankScore'] as num).toInt(),
      queuedAt: (json['queuedAt'] as num).toInt(),
      maxWaitMs: (json['maxWaitMs'] as num).toInt(),
      status: json['status'] as String,
      roomId: json['roomId'] as String?,
    );
  }
}

class RankedRoomSeatModel {
  const RankedRoomSeatModel({
    required this.playerId,
    required this.displayName,
    required this.rankScore,
    this.photoUrl,
    required this.isBot,
    required this.connectionStatus,
  });

  final String playerId;
  final String displayName;
  final int rankScore;
  final String? photoUrl;
  final bool isBot;
  final String connectionStatus;

  factory RankedRoomSeatModel.fromJson(Map<String, dynamic> json) {
    return RankedRoomSeatModel(
      playerId: json['playerId'] as String,
      displayName: json['displayName'] as String,
      rankScore: (json['rankScore'] as num).toInt(),
      photoUrl: json['photoUrl'] as String?,
      isBot: json['isBot'] as bool,
      connectionStatus: json['connectionStatus'] as String,
    );
  }
}

class RankedRoomSnapshotModel {
  const RankedRoomSnapshotModel({
    required this.roomId,
    required this.status,
    required this.seats,
    required this.createdAt,
    required this.startedAt,
    required this.botFillApplied,
  });

  final String roomId;
  final String status;
  final List<RankedRoomSeatModel> seats;
  final int createdAt;
  final int startedAt;
  final bool botFillApplied;

  factory RankedRoomSnapshotModel.fromJson(Map<String, dynamic> json) {
    return RankedRoomSnapshotModel(
      roomId: json['roomId'] as String,
      status: json['status'] as String,
      seats: (json['seats'] as List<dynamic>)
          .map(
            (entry) =>
                RankedRoomSeatModel.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      createdAt: (json['createdAt'] as num).toInt(),
      startedAt: (json['startedAt'] as num).toInt(),
      botFillApplied: json['botFillApplied'] as bool,
    );
  }
}

class PrivateRoomSnapshotModel {
  const PrivateRoomSnapshotModel({
    required this.roomId,
    required this.code,
    required this.hostUserId,
    required this.status,
    required this.seats,
    required this.createdAt,
    required this.maxPlayers,
  });

  final String roomId;
  final String code;
  final String hostUserId;
  final String status;
  final List<RankedRoomSeatModel> seats;
  final int createdAt;
  final int maxPlayers;

  factory PrivateRoomSnapshotModel.fromJson(Map<String, dynamic> json) {
    return PrivateRoomSnapshotModel(
      roomId: json['roomId'] as String,
      code: json['code'] as String,
      hostUserId: json['hostUserId'] as String,
      status: json['status'] as String,
      seats: (json['seats'] as List<dynamic>)
          .map(
            (entry) =>
                RankedRoomSeatModel.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      createdAt: (json['createdAt'] as num).toInt(),
      maxPlayers: (json['maxPlayers'] as num).toInt(),
    );
  }
}

class RankedQueueStatusEventModel {
  const RankedQueueStatusEventModel({
    required this.ticketId,
    required this.queuedPlayers,
    required this.elapsedMs,
    required this.maxWaitMs,
    required this.rankWindow,
  });

  final String ticketId;
  final int queuedPlayers;
  final int elapsedMs;
  final int maxWaitMs;
  final int? rankWindow;

  factory RankedQueueStatusEventModel.fromJson(Map<String, dynamic> json) {
    return RankedQueueStatusEventModel(
      ticketId: json['ticketId'] as String,
      queuedPlayers: (json['queuedPlayers'] as num).toInt(),
      elapsedMs: (json['elapsedMs'] as num).toInt(),
      maxWaitMs: (json['maxWaitMs'] as num).toInt(),
      rankWindow: (json['rankWindow'] as num?)?.toInt(),
    );
  }
}
