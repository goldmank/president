import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'president_theme.dart';
import 'ranked_api.dart';
import 'ranked_models.dart';

class PrivateRoomScreen extends StatefulWidget {
  const PrivateRoomScreen({
    super.key,
    required this.initialRoom,
    required this.isHost,
  });

  final PrivateRoomSnapshotModel initialRoom;
  final bool isHost;

  @override
  State<PrivateRoomScreen> createState() => _PrivateRoomScreenState();
}

class _PrivateRoomScreenState extends State<PrivateRoomScreen> {
  final RankedApi _api = RankedApi();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PrivateRoomSnapshotModel? _room;
  Timer? _pollTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSubscription;
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
              _log('firestore.listen.parse_error roomId=${room.roomId} error=$error');
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
      _log('poll.success code=$code seats=${room.seats.length} status=${room.status}');
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
        text: 'Join my President private match with room code: ${room.code}',
        subject: 'President private match',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
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
                    ? 'Share the room code with friends and wait for them to join.'
                    : 'You joined a private room. Wait for the host and more players to fill the table.',
                style: const TextStyle(
                  color: presidentMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(
                    color: presidentDanger,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                        '${room.seats.length} / ${room.maxPlayers} players joined',
                        style: const TextStyle(
                          color: presidentText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                              : 'Waiting For Players',
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
                                      'RANK ${seat.rankScore}',
                                      style: const TextStyle(
                                        color: presidentPrimary,
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
    );
  }

  void _log(String message) {
    debugPrint('[private_room_screen] $message');
  }
}
