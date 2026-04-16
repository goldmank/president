import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import 'game_screen.dart';
import 'president_theme.dart';
import 'ranked_api.dart';
import 'ranked_models.dart';

class PrivateRoomScreen extends StatefulWidget {
  const PrivateRoomScreen({
    super.key,
    required this.initialRoom,
    required this.isHost,
    required this.currentUserId,
  });

  final PrivateRoomSnapshotModel initialRoom;
  final bool isHost;
  final String currentUserId;

  @override
  State<PrivateRoomScreen> createState() => _PrivateRoomScreenState();
}

class _PrivateRoomScreenState extends State<PrivateRoomScreen> {
  final RankedApi _api = RankedApi();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PrivateRoomSnapshotModel? _room;
  Timer? _pollTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSubscription;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _startFirestoreListener();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _roomSubscription?.cancel();
    super.dispose();
  }

  void _startFirestoreListener() {
    final room = _room;
    if (room == null) {
      return;
    }
    _log('firestore.listen.start roomId=${room.roomId}');
    _roomSubscription = _firestore
        .collection('multiplayerRooms')
        .doc(room.roomId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) {
              _log('firestore.listen.miss roomId=${room.roomId}');
              return;
            }
            final data = snapshot.data();
            if (data == null || !mounted) {
              return;
            }
            try {
              final nextRoom = PrivateRoomSnapshotModel.fromJson(data);
              _log(
                'firestore.listen.update roomId=${nextRoom.roomId} seats=${nextRoom.seats.length} status=${nextRoom.status}',
              );
              setState(() {
                _room = nextRoom;
                _error = null;
              });
            } catch (error) {
              _log(
                'firestore.listen.parse_error roomId=${room.roomId} error=$error',
              );
            }
          },
          onError: (Object error) {
            _log('firestore.listen.error roomId=${room.roomId} error=$error');
          },
        );
  }

  void _startPolling() {
    final room = _room;
    if (room == null) {
      return;
    }
    _log('poll.start code=${room.code} isHost=${widget.isHost}');
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshRoom(room.code));
    });
    unawaited(_refreshRoom(room.code));
  }

  Future<void> _refreshRoom(String code) async {
    try {
      _log('poll.tick code=$code');
      final room = await _api.getPrivateRoom(code);
      _log(
        'poll.success code=$code seats=${room.seats.length} status=${room.status}',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _room = room;
        _error = null;
      });
    } catch (error) {
      _log('poll.error code=$code error=$error');
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _shareCode() async {
    final room = _room;
    if (room == null) {
      return;
    }
    _log('shareCode code=${room.code}');
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join my PRESIDENT private match with room code: ${room.code}',
        subject: 'PRESIDENT private match',
      ),
    );
  }

  Future<void> _startMatch() async {
    final room = _room;
    if (room == null || _actionBusy) {
      return;
    }

    setState(() {
      _actionBusy = true;
      _error = null;
    });

    try {
      _log('start.request code=${room.code} userId=${widget.currentUserId}');
      final nextRoom = await _api.startPrivateRoom(
        code: room.code,
        userId: widget.currentUserId,
      );
      _log(
        'start.success code=${nextRoom.code} seats=${nextRoom.seats.length} status=${nextRoom.status}',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _room = nextRoom;
      });
    } catch (error) {
      _log('start.error code=${room.code} error=$error');
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _enterMatch() async {
    final room = _room;
    if (room == null || _actionBusy) {
      return;
    }

    final humanSeats = room.seats.where((seat) => !seat.isBot).length;
    if (humanSeats > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Live private multiplayer turns are not wired yet. The host can lock the table and fill bots, but shared human turns are still next.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _actionBusy = true;
    });
    try {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              GameScreen(initialPlayerCount: room.seats.length),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final seatCount = room?.seats.length ?? 0;
    final botCount = room?.seats.where((seat) => seat.isBot).length ?? 0;
    final humanCount = seatCount - botCount;

    return Scaffold(
      backgroundColor: presidentBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: presidentText),
              ),
              const SizedBox(height: 12),
              const Text(
                'Private Match',
                style: TextStyle(
                  color: presidentText,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.isHost
                    ? 'Share the room code, then start when the table looks right. If fewer than 4 players have joined, bots will fill the empty seats.'
                    : 'You joined a private room. The host decides when to start, and bots will fill any empty seats needed to reach 4 players.',
                style: const TextStyle(
                  color: presidentMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...<Widget>[
                Text(
                  _error!,
                  style: const TextStyle(
                    color: presidentDanger,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (room != null) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: presidentSurfaceLow,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'ROOM CODE',
                        style: TextStyle(
                          color: presidentMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              room.code,
                              style: const TextStyle(
                                color: presidentPrimary,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: _shareCode,
                            style: FilledButton.styleFrom(
                              backgroundColor: presidentSurfaceHighest,
                              foregroundColor: presidentText,
                            ),
                            child: const Text('SHARE'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '$seatCount / ${room.maxPlayers} seats at table',
                        style: const TextStyle(
                          color: presidentText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (botCount > 0) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          '$humanCount joined, $botCount bot${botCount == 1 ? '' : 's'} added by host',
                          style: const TextStyle(
                            color: presidentMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: presidentSurfaceContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          room.status == 'ready'
                              ? 'Table Ready'
                              : 'Waiting For Host',
                          style: const TextStyle(
                            color: presidentText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: ListView.separated(
                            itemCount: room.seats.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final seat = room.seats[index];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: presidentSurfaceHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    _RoomSeatAvatar(
                                      playerId: seat.playerId,
                                      photoUrl: seat.photoUrl,
                                      isBot: seat.isBot,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        seat.displayName,
                                        style: const TextStyle(
                                          color: presidentText,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      seat.isBot
                                          ? 'BOT'
                                          : 'RANK ${seat.rankScore}',
                                      style: TextStyle(
                                        color: seat.isBot
                                            ? presidentMuted
                                            : presidentPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: room == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: FilledButton(
                onPressed: _actionBusy
                    ? null
                    : room.status == 'ready'
                    ? _enterMatch
                    : (widget.isHost ? _startMatch : null),
                style: FilledButton.styleFrom(
                  backgroundColor: room.status == 'ready'
                      ? presidentPrimary
                      : presidentSurfaceHighest,
                  foregroundColor: room.status == 'ready'
                      ? Colors.black
                      : presidentText,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  _actionBusy
                      ? (room.status == 'ready' ? 'OPENING...' : 'STARTING...')
                      : room.status == 'ready'
                      ? 'ENTER MATCH'
                      : (widget.isHost ? 'START MATCH' : 'WAITING FOR HOST'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
    );
  }

  void _log(String message) {
    debugPrint('[private_room_screen] $message');
  }
}

class _RoomSeatAvatar extends StatelessWidget {
  const _RoomSeatAvatar({
    required this.playerId,
    required this.photoUrl,
    required this.isBot,
  });

  final String playerId;
  final String? photoUrl;
  final bool isBot;

  @override
  Widget build(BuildContext context) {
    final String? normalizedPhotoUrl = photoUrl?.trim().isNotEmpty == true
        ? photoUrl!.trim()
        : null;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _avatarBackground(playerId, isBot),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: normalizedPhotoUrl != null
          ? Image.network(normalizedPhotoUrl, fit: BoxFit.cover)
          : Padding(
              padding: const EdgeInsets.all(5),
              child: SvgPicture.asset(
                'assets/default_avatar.svg',
                fit: BoxFit.contain,
              ),
            ),
    );
  }
}

Color _avatarBackground(String playerId, bool isBot) {
  if (isBot) {
    return presidentSurfaceLow;
  }

  const List<Color> palette = <Color>[
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFFA855F7),
    Color(0xFF06B6D4),
  ];

  final int index = playerId.codeUnits.fold<int>(
    0,
    (total, value) => total + value,
  );
  return palette[index % palette.length];
}
