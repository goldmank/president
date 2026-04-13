import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'game_screen.dart';
import 'president_theme.dart';
import 'ranked_api.dart';
import 'ranked_models.dart';

class RankedSearchScreen extends StatefulWidget {
  const RankedSearchScreen({
    super.key,
    required this.userId,
    required this.displayName,
    required this.rankScore,
  });

  final String userId;
  final String displayName;
  final int rankScore;

  @override
  State<RankedSearchScreen> createState() => _RankedSearchScreenState();
}

class _RankedSearchScreenState extends State<RankedSearchScreen> {
  final RankedApi _api = RankedApi();

  RankedQueueTicketModel? _ticket;
  RankedQueueStatusEventModel? _queueStatus;
  RankedRoomSnapshotModel? _room;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  bool _loading = true;
  bool _cancelling = false;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startSearch();
  }

  @override
  void dispose() {
    _channelSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _startSearch() async {
    try {
      final ticket = await _api.enqueue(
        userId: widget.userId,
        displayName: widget.displayName,
        rankScore: widget.rankScore,
      );
      final channel = _api.connect(ticket.ticketId);
      _channel = channel;
      _channelSubscription = channel.stream.listen(
        _handleSocketMessage,
        onError: (Object error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = error.toString();
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ticket = ticket;
        _queueStatus = RankedQueueStatusEventModel(
          ticketId: ticket.ticketId,
          queuedPlayers: 1,
          elapsedMs: 0,
          maxWaitMs: ticket.maxWaitMs,
          rankWindow: 10,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _handleSocketMessage(dynamic raw) {
    final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
    final type = decoded['type'] as String?;
    if (!mounted || type == null) {
      return;
    }

    switch (type) {
      case 'queue_status':
        setState(() {
          _queueStatus = RankedQueueStatusEventModel.fromJson(decoded);
        });
      case 'room_assigned':
        setState(() {
          _room = RankedRoomSnapshotModel.fromJson(
            decoded['room'] as Map<String, dynamic>,
          );
        });
      case 'queue_cancelled':
        setState(() {
          _error = decoded['reason'] as String? ?? 'Queue cancelled';
        });
      case 'error':
        setState(() {
          _error = decoded['message'] as String? ?? 'Unknown socket error';
        });
    }
  }

  Future<void> _cancelSearch() async {
    final ticketId = _ticket?.ticketId;
    if (ticketId == null) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _cancelling = true;
    });
    try {
      await _api.cancelQueue(ticketId);
    } catch (_) {
      // Ignore cancel errors while closing the screen.
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _openReadyMatch() async {
    final room = _room;
    if (room == null) {
      return;
    }

    final humanSeats = room.seats.where((seat) => !seat.isBot).length;
    if (humanSeats > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Live ranked multiplayer turns are not wired yet. Bot-filled ranked rooms can start now, multi-human rooms are next.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _starting = true;
    });
    try {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => GameScreen(
            initialPlayerCount: room.seats.length,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueStatus = _queueStatus;
    final room = _room;
    final secondsElapsed = ((queueStatus?.elapsedMs ?? 0) / 1000).floor();
    final secondsLeft = queueStatus == null
        ? 30
        : ((queueStatus.maxWaitMs - queueStatus.elapsedMs) / 1000).ceil().clamp(
            0,
            30,
          );

    return Scaffold(
      backgroundColor: presidentBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(
                onPressed: _cancelling ? null : _cancelSearch,
                icon: const Icon(Icons.close_rounded, color: presidentText),
              ),
              const SizedBox(height: 12),
              Text(
                room == null ? 'Finding Match' : 'Table Ready',
                style: const TextStyle(
                  color: presidentText,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                room == null
                    ? 'Searching for the best available table based on your rank and current queue activity.'
                    : 'Your ranked room has been assembled. The room scaffold is live and synced from the server.',
                style: const TextStyle(
                  color: presidentMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: presidentPrimary),
                  ),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: presidentDanger,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: <Widget>[
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
                            _InfoRow(
                              label: 'PLAYER',
                              value: widget.displayName,
                            ),
                            const SizedBox(height: 14),
                            _InfoRow(
                              label: 'RANK SCORE',
                              value: '${widget.rankScore}',
                            ),
                            const SizedBox(height: 14),
                            _InfoRow(
                              label: 'WAIT TIME',
                              value: '${secondsElapsed}s',
                            ),
                            const SizedBox(height: 14),
                            _InfoRow(
                              label: 'BOT FILL',
                              value: room == null
                                  ? 'IN ${secondsLeft}s'
                                  : (room.botFillApplied ? 'APPLIED' : 'NOT NEEDED'),
                            ),
                            if (queueStatus != null) ...<Widget>[
                              const SizedBox(height: 14),
                              _InfoRow(
                                label: 'MATCH WINDOW',
                                value: queueStatus.rankWindow == null
                                    ? 'ANY RANK'
                                    : '+/- ${queueStatus.rankWindow}',
                              ),
                              const SizedBox(height: 14),
                              _InfoRow(
                                label: 'QUEUED PLAYERS',
                                value: '${queueStatus.queuedPlayers}',
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
                          child: room == null
                              ? const Center(
                                  child: Text(
                                    'Waiting for players...',
                                    style: TextStyle(
                                      color: presidentMuted,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'ROOM ${room.roomId.toUpperCase()}',
                                      style: const TextStyle(
                                        color: presidentPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
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
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: Text(
                                                    seat.displayName,
                                                    style: const TextStyle(
                                                      color: presidentText,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                                    fontWeight:
                                                        FontWeight.w900,
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
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _cancelling || _starting
                      ? null
                      : (room == null ? _cancelSearch : _openReadyMatch),
                  style: FilledButton.styleFrom(
                    backgroundColor: room == null
                        ? presidentSurfaceHighest
                        : presidentPrimary,
                    foregroundColor: room == null ? presidentText : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    room == null
                        ? 'CANCEL SEARCH'
                        : (_starting ? 'STARTING...' : 'ENTER MATCH'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: presidentMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: presidentText,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
