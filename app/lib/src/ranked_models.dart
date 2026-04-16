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
