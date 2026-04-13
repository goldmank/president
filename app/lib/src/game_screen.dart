import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_config.dart';
import 'analytics_service.dart';
import 'card_asset.dart';
import 'game_api.dart';
import 'game_settings_service.dart';
import 'game_overlays.dart';
import 'models.dart';
import 'president_theme.dart';
import 'user_progress_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final GameApi _api = GameApi();
  final AnalyticsService _analytics = AnalyticsService.instance;
  final Set<String> _selectedCardIds = <String>{};
  final Set<String> _animatingViewerCardIds = <String>{};
  final Map<String, bool> _passBubbleVisible = <String, bool>{};
  final Map<String, Timer> _passBubbleTimers = <String, Timer>{};
  final List<_CardFlight> _cardFlights = <_CardFlight>[];
  List<CardModel> _lastKnownViewerHand = <CardModel>[];
  String? _recordedFinishedGameId;
  ExchangePreviewModel? _exchangePreview;

  PublicGameStateModel? _state;
  bool _loading = true;
  bool _busy = false;
  bool _showResultsOverlay = false;
  bool _showExchangeOverlay = false;
  bool _showMockResultsOverlay = false;
  bool _showMockExchangeOverlay = false;
  bool _exchangeWaiting = false;
  bool _exchangeReadyToContinue = false;
  bool _exchangePreviewLoading = false;
  bool _debugNewGamesUseRandomRoles = false;
  List<CardModel> _receivedExchangeCards = <CardModel>[];
  String? _banner;
  Timer? _bannerTimer;
  Timer? _botTimer;
  _LayoutSnapshot? _layout;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _botTimer?.cancel();
    for (final timer in _passBubbleTimers.values) {
      timer.cancel();
    }
    for (final flight in _cardFlights) {
      flight.controller.dispose();
    }
    super.dispose();
  }

  void _clearFlights() {
    final lingeringFlights = List<_CardFlight>.from(_cardFlights);
    _cardFlights.clear();
    for (final flight in lingeringFlights) {
      flight.controller.dispose();
    }
  }

  void _showPassBubble(String playerId) {
    _passBubbleTimers.remove(playerId)?.cancel();
    setState(() {
      _passBubbleVisible[playerId] = true;
    });
    _passBubbleTimers[playerId] = Timer(const Duration(seconds: 1), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _passBubbleVisible[playerId] = false;
      });
      _passBubbleTimers[playerId] = Timer(
        const Duration(milliseconds: 240),
        () {
          if (!mounted) {
            return;
          }
          setState(() {
            _passBubbleVisible.remove(playerId);
          });
          _passBubbleTimers.remove(playerId);
        },
      );
    });
  }

  Future<void> _loadGame({int? playerCount}) async {
    _bannerTimer?.cancel();
    _botTimer?.cancel();
    setState(() {
      _loading = true;
      _busy = false;
      _banner = null;
      _showResultsOverlay = false;
      _showExchangeOverlay = false;
      _showMockResultsOverlay = false;
      _showMockExchangeOverlay = false;
      _exchangeWaiting = false;
      _exchangeReadyToContinue = false;
      _exchangePreviewLoading = false;
      _exchangePreview = null;
      _receivedExchangeCards = <CardModel>[];
      _recordedFinishedGameId = null;
      _selectedCardIds.clear();
      _animatingViewerCardIds.clear();
      _clearFlights();
    });

    try {
      final settings = GameSettingsService.instance.currentSettings;
      final state = await _api.createGame(
        playerCount: playerCount,
        rules: <String, dynamic>{'doubleDeck': settings.doubleDeck},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
        _loading = false;
      });
      if (state.viewerHand.isNotEmpty) {
        _lastKnownViewerHand = List<CardModel>.from(state.viewerHand);
      }
      unawaited(_analytics.logGameStarted(state));
      _scheduleBotTurnIfNeeded();
    } catch (error, stackTrace) {
      _reportError('load_game', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      _showBanner(_formatError(error));
    }
  }

  Future<void> _startDebugNewGame(int playerCount) async {
    if (!_debugNewGamesUseRandomRoles) {
      await _loadGame(playerCount: playerCount);
      return;
    }

    _bannerTimer?.cancel();
    _botTimer?.cancel();
    setState(() {
      _loading = true;
      _busy = false;
      _banner = null;
      _showResultsOverlay = false;
      _showExchangeOverlay = false;
      _showMockResultsOverlay = false;
      _showMockExchangeOverlay = false;
      _exchangeWaiting = false;
      _exchangeReadyToContinue = false;
      _exchangePreviewLoading = false;
      _exchangePreview = null;
      _receivedExchangeCards = <CardModel>[];
      _recordedFinishedGameId = null;
      _selectedCardIds.clear();
      _animatingViewerCardIds.clear();
      _clearFlights();
    });

    try {
      final settings = GameSettingsService.instance.currentSettings;
      await _api.createGame(
        playerCount: playerCount,
        rules: <String, dynamic>{'doubleDeck': settings.doubleDeck},
      );
      await _api.fastForwardGame();
      final state = await _api.startNextRound();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
        _loading = false;
      });
      if (state.viewerHand.isNotEmpty) {
        _lastKnownViewerHand = List<CardModel>.from(state.viewerHand);
      }
      _scheduleBotTurnIfNeeded();
    } catch (error, stackTrace) {
      _reportError('debug_new_game', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      _showBanner(_formatError(error));
    }
  }

  void _showBanner(String message) {
    _bannerTimer?.cancel();
    setState(() {
      _banner = message;
    });
    _bannerTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _banner = null;
      });
    });
  }

  String _formatError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  void _reportError(String context, Object error, StackTrace stackTrace) {
    debugPrint('[$context] ${_formatError(error)}');
    debugPrintStack(stackTrace: stackTrace);
    unawaited(_analytics.logGameError(context, error, state: _state));
  }

  Future<void> _setGameState(PublicGameStateModel next) async {
    final previous = _state;
    final shouldHoldRoundEnd =
        previous != null &&
        previous.phase == GamePhase.playing &&
        previous.pile.history.isNotEmpty &&
        next.phase == GamePhase.playing &&
        next.pile.history.isEmpty;

    if (shouldHoldRoundEnd) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) {
        return;
      }
    }

    final lingeringFlights = List<_CardFlight>.from(_cardFlights);
    setState(() {
      _cardFlights.clear();
      _state = next;
      _busy = false;
      _selectedCardIds.clear();
      _animatingViewerCardIds.clear();
      if (next.phase == GamePhase.finished) {
        _showResultsOverlay = true;
        _showExchangeOverlay = false;
        _showMockResultsOverlay = false;
        _showMockExchangeOverlay = false;
        _exchangeWaiting = false;
        _exchangeReadyToContinue = false;
        _exchangePreviewLoading = false;
        _exchangePreview = null;
        _receivedExchangeCards = <CardModel>[];
      } else {
        _showResultsOverlay = false;
        _showExchangeOverlay = false;
        _showMockResultsOverlay = false;
        _showMockExchangeOverlay = false;
        _exchangeWaiting = false;
        _exchangeReadyToContinue = false;
        _exchangePreviewLoading = false;
        _exchangePreview = null;
        _receivedExchangeCards = <CardModel>[];
      }
    });
    if (next.viewerHand.isNotEmpty) {
      _lastKnownViewerHand = List<CardModel>.from(next.viewerHand);
    }
    for (final flight in lingeringFlights) {
      flight.controller.dispose();
    }
    if (previous != null) {
      for (final player in next.players) {
        if (player.id == next.viewerPlayerId) {
          continue;
        }
        final before = previous.players.firstWhere(
          (entry) => entry.id == player.id,
          orElse: () => player,
        );
        if (before.status != PlayerStatus.passed &&
            player.status == PlayerStatus.passed) {
          _showPassBubble(player.id);
        }
      }
    }
    if (previous != null &&
        previous.phase != GamePhase.finished &&
        next.phase == GamePhase.finished) {
      final role = awardedRoleLabel(next.viewer, next.players.length);
      if (_recordedFinishedGameId != next.id) {
        _recordedFinishedGameId = next.id;
        unawaited(UserProgressService.instance.recordFinishedGame(role));
      }
      unawaited(_analytics.logGameFinished(previous, next));
      unawaited(_analytics.logRoleProgressionReady(previous, next));
    }
    _scheduleBotTurnIfNeeded();
  }

  void _scheduleBotTurnIfNeeded() {
    _botTimer?.cancel();
    final state = _state;
    if (state == null ||
        state.phase != GamePhase.playing ||
        _hasBlockingOverlay) {
      return;
    }

    final currentPlayer = state.players.firstWhere(
      (player) => player.id == state.currentTurnPlayerId,
    );

    if (currentPlayer.kind != PlayerKind.bot || _busy) {
      return;
    }

    _botTimer = Timer(const Duration(milliseconds: 850), () async {
      final previous = _state;
      if (previous == null || !mounted) {
        return;
      }

      try {
        final next = await _api.stepBotTurn();
        if (!mounted) {
          return;
        }

        final playedSet = _extractNewestPlayedSet(
          previous,
          next,
          currentPlayer.id,
        );
        if (playedSet != null) {
          await _animateSeatPlay(previous, currentPlayer.id, playedSet.cards);
        }

        if (!mounted) {
          return;
        }
        await _setGameState(next);
      } catch (error, stackTrace) {
        _reportError('bot_turn', error, stackTrace);
        _showBanner(_formatError(error));
      }
    });
  }

  PlayedSet? _extractNewestPlayedSet(
    PublicGameStateModel previous,
    PublicGameStateModel next,
    String playerId,
  ) {
    final previousTimestamp = previous.pile.history.isEmpty
        ? -1
        : previous.pile.history.last.timestamp;
    for (final entry in next.pile.history.reversed) {
      if (entry.byPlayerId == playerId && entry.timestamp > previousTimestamp) {
        return entry;
      }
    }
    final currentSet = next.pile.currentSet;
    if (currentSet != null &&
        currentSet.byPlayerId == playerId &&
        currentSet.timestamp != previous.pile.currentSet?.timestamp) {
      return currentSet;
    }
    return null;
  }

  bool get _isViewerTurn {
    final state = _state;
    return state != null &&
        state.phase == GamePhase.playing &&
        state.currentTurnPlayerId == state.viewerPlayerId &&
        !_busy &&
        !_hasBlockingOverlay;
  }

  bool get _hasBlockingOverlay =>
      _showResultsOverlay ||
      _showExchangeOverlay ||
      _showMockResultsOverlay ||
      _showMockExchangeOverlay;

  Set<String> _selectableCardIds(PublicGameStateModel state) {
    if (!_isViewerTurn) {
      return <String>{};
    }

    if (_selectedCardIds.isEmpty) {
      return state.viewerHand.map((card) => card.id).toSet();
    }

    final selectedCards = state.viewerHand
        .where((card) => _selectedCardIds.contains(card.id))
        .toList();
    if (selectedCards.isEmpty) {
      return state.viewerHand.map((card) => card.id).toSet();
    }

    final rank = selectedCards.first.rank;
    final maxCount = state.pile.currentSet?.count ?? 4;
    final ids = selectedCards.map((card) => card.id).toSet();

    if (_selectedCardIds.length >= maxCount) {
      return ids;
    }

    if (state.pile.currentSet != null && rank <= state.pile.currentSet!.rank) {
      return ids;
    }

    for (final card in state.viewerHand) {
      if (!_selectedCardIds.contains(card.id) && card.rank == rank) {
        ids.add(card.id);
      }
    }

    return ids;
  }

  bool _isSelectedPlayValid(PublicGameStateModel state) {
    if (!_isViewerTurn || _selectedCardIds.isEmpty) {
      return false;
    }

    final selectedCards = state.viewerHand
        .where((card) => _selectedCardIds.contains(card.id))
        .toList();
    if (selectedCards.length != _selectedCardIds.length) {
      return false;
    }

    final rank = selectedCards.first.rank;
    if (selectedCards.any((card) => card.rank != rank)) {
      return false;
    }

    final currentSet = state.pile.currentSet;
    if (currentSet == null) {
      return true;
    }

    if (selectedCards.length != currentSet.count) {
      return false;
    }

    return rank > currentSet.rank;
  }

  Future<void> _submitAction() async {
    final state = _state;
    if (state == null || _busy || !_isViewerTurn) {
      return;
    }

    final selectedCards = state.viewerHand
        .where((card) => _selectedCardIds.contains(card.id))
        .toList();

    setState(() {
      _busy = true;
    });

    try {
      if (selectedCards.isNotEmpty) {
        await _animateViewerPlay(state, selectedCards);
      }

      final next = selectedCards.isEmpty
          ? await _api.submitPass(
              PassActionPayload(playerId: state.viewerPlayerId),
            )
          : await _api.submitPlay(
              PlayActionPayload(
                playerId: state.viewerPlayerId,
                cardIds: selectedCards.map((card) => card.id).toList(),
              ),
            );

      if (!mounted) {
        return;
      }

      await _setGameState(next);
    } catch (error, stackTrace) {
      _reportError('submit_action', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _animatingViewerCardIds.clear();
        _clearFlights();
      });
      _showBanner(_formatError(error));
    }
  }

  void _toggleCard(CardModel card) {
    final state = _state;
    if (state == null) {
      return;
    }

    final selectable = _selectableCardIds(state);
    final isSelected = _selectedCardIds.contains(card.id);
    if (!isSelected && !selectable.contains(card.id)) {
      if (_selectedCardIds.isNotEmpty) {
        setState(() {
          _selectedCardIds.clear();
        });
      }
      return;
    }

    setState(() {
      if (isSelected) {
        _selectedCardIds.remove(card.id);
      } else {
        _selectedCardIds.add(card.id);
      }
    });
  }

  Future<void> _animateViewerPlay(
    PublicGameStateModel state,
    List<CardModel> cards,
  ) async {
    final layout = _layout;
    if (layout == null || cards.isEmpty) {
      return;
    }

    final metrics = _viewerHandMetrics(layout, state.viewerHand.length);
    final flights = <_FlightSpec>[];
    for (var index = 0; index < cards.length; index++) {
      final card = cards[index];
      final handIndex = state.viewerHand.indexWhere(
        (entry) => entry.id == card.id,
      );
      if (handIndex == -1) {
        continue;
      }
      final start = _viewerCardCenter(
        layout,
        metrics,
        handIndex,
        state.viewerHand.length,
        _selectedCardIds.contains(card.id),
      );
      final isFirstSetOnTable = state.pile.history.isEmpty;
      final end = _pileRenderedCardCenter(
        layout,
        cards,
        index,
        centerFirstSet: isFirstSetOnTable,
      );
      flights.add(
        _FlightSpec(
          card: card,
          start: start,
          end: end,
          startAngle: _viewerCardAngle(handIndex, state.viewerHand.length),
          endAngle: _pileCardAngle(card, index, tight: isFirstSetOnTable),
          startScale: 1.08,
          endScale: 1.12,
        ),
      );
    }

    final animatedIds = cards.map((card) => card.id).toSet();
    setState(() {
      _animatingViewerCardIds.addAll(animatedIds);
    });

    try {
      await _runFlights(
        flights,
        const Duration(milliseconds: 420),
        keepVisibleUntilCleared: true,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _animatingViewerCardIds.removeAll(animatedIds);
          _clearFlights();
        });
      }
      rethrow;
    }
  }

  Future<void> _animateSeatPlay(
    PublicGameStateModel state,
    String playerId,
    List<CardModel> cards,
  ) async {
    final layout = _layout;
    if (layout == null || cards.isEmpty) {
      return;
    }

    final playerIndex = state.players.indexWhere(
      (player) => player.id == playerId,
    );
    if (playerIndex == -1) {
      return;
    }

    final seatCenter = _seatCenter(
      state.players,
      playerIndex,
      state.viewerPlayerId,
      layout.tableCenter,
      layout.seatRadius,
    );
    final seatAngle = _seatAngle(
      state.players,
      playerIndex,
      state.viewerPlayerId,
    );
    final inward = Offset(
      math.cos(seatAngle + math.pi),
      math.sin(seatAngle + math.pi),
    );

    final flights = <_FlightSpec>[];
    for (var index = 0; index < cards.length; index++) {
      final spread = (index - (cards.length - 1) / 2) * 16;
      final start =
          seatCenter + inward * 48 + Offset(spread, math.sin(seatAngle) * 4);
      final isFirstSetOnTable = state.pile.history.isEmpty;
      final end = _pileRenderedCardCenter(
        layout,
        cards,
        index,
        centerFirstSet: isFirstSetOnTable,
      );
      flights.add(
        _FlightSpec(
          card: cards[index],
          start: start,
          end: end,
          startAngle: seatAngle + math.pi / 2,
          endAngle: _pileCardAngle(
            cards[index],
            index,
            tight: isFirstSetOnTable,
          ),
          startScale: 0.76,
          endScale: 1.12,
        ),
      );
    }

    await _runFlights(flights, const Duration(milliseconds: 500));
  }

  Future<void> _runFlights(
    List<_FlightSpec> specs,
    Duration duration, {
    bool keepVisibleUntilCleared = false,
  }) async {
    if (!mounted || specs.isEmpty) {
      return;
    }

    final flights = specs
        .map(
          (spec) => _CardFlight(
            card: spec.card,
            start: spec.start,
            end: spec.end,
            startAngle: spec.startAngle,
            endAngle: spec.endAngle,
            startScale: spec.startScale,
            endScale: spec.endScale,
            controller: AnimationController(vsync: this, duration: duration),
          ),
        )
        .toList();

    setState(() {
      _cardFlights.addAll(flights);
    });

    try {
      await Future.wait<void>(
        flights.map((flight) => flight.controller.forward()),
      );
    } finally {
      if (mounted && !keepVisibleUntilCleared) {
        setState(() {
          _cardFlights.removeWhere((flight) => flights.contains(flight));
        });
      }
      if (!keepVisibleUntilCleared) {
        for (final flight in flights) {
          flight.controller.dispose();
        }
      }
    }
  }

  void _onResultsContinue() {
    final state = _state;
    if (state == null) {
      return;
    }

    if (_showMockResultsOverlay && state.phase != GamePhase.finished) {
      setState(() {
        _showMockResultsOverlay = false;
        _showMockExchangeOverlay = true;
        _exchangeWaiting = false;
        _exchangeReadyToContinue = false;
        _receivedExchangeCards = <CardModel>[];
      });
      return;
    }

    final exchange = buildExchangeViewData(state);
    setState(() {
      _showResultsOverlay = false;
      _showExchangeOverlay = exchange != null;
      _exchangeWaiting = false;
      _exchangeReadyToContinue = false;
      _exchangePreviewLoading = exchange != null;
      _exchangePreview = null;
      _receivedExchangeCards = <CardModel>[];
    });

    if (exchange == null) {
      _loadGame();
      return;
    }

    unawaited(_loadExchangePreview());
  }

  void _closeExchangeAndRestart() {
    setState(() {
      _showExchangeOverlay = false;
      _showMockExchangeOverlay = false;
      _exchangeWaiting = false;
      _exchangeReadyToContinue = false;
      _exchangePreviewLoading = false;
      _exchangePreview = null;
      _receivedExchangeCards = <CardModel>[];
    });
    _loadGame();
  }

  void _closeMockExchange() {
    setState(() {
      _showMockExchangeOverlay = false;
      _exchangeWaiting = false;
      _exchangeReadyToContinue = false;
      _exchangePreviewLoading = false;
      _exchangePreview = null;
      _receivedExchangeCards = <CardModel>[];
    });
  }

  Future<void> _loadExchangePreview() async {
    try {
      final preview = await _api.getExchangePreview();
      debugPrint(
        '[exchange_preview] send=${preview == null ? "-" : preview.sendCards.map((card) => rankLabel(card.rank)).join(",")} '
        'receive=${preview == null ? "-" : preview.receiveCards.map((card) => rankLabel(card.rank)).join(",")}',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _exchangePreview = preview;
        _exchangePreviewLoading = false;
      });
    } catch (error, stackTrace) {
      _reportError('exchange_preview', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _exchangePreviewLoading = false;
      });
      _showBanner(_formatError(error));
    }
  }

  Future<void> _confirmExchangeAndContinue() async {
    final state = _state;
    if (state == null || _exchangeWaiting) {
      return;
    }
    final exchangeData = _showMockExchangeOverlay
        ? buildMockExchangeViewData(state)
        : buildExchangeViewData(state);

    if (_exchangeReadyToContinue) {
      if (_showMockExchangeOverlay) {
        setState(() {
          _showMockExchangeOverlay = false;
          _exchangeWaiting = false;
          _exchangeReadyToContinue = false;
          _receivedExchangeCards = <CardModel>[];
        });
        return;
      }

      setState(() {
        _showExchangeOverlay = false;
        _showMockExchangeOverlay = false;
        _exchangeWaiting = false;
        _exchangeReadyToContinue = false;
        _receivedExchangeCards = <CardModel>[];
        _busy = true;
      });

      try {
        final next = await _api.startNextRound();
        if (!mounted) {
          return;
        }
        await _setGameState(next);
      } catch (error, stackTrace) {
        _reportError('start_next_round', error, stackTrace);
        if (!mounted) {
          return;
        }
        setState(() {
          _showExchangeOverlay = true;
          _exchangeReadyToContinue = true;
          _busy = false;
        });
        _showBanner(_formatError(error));
      }
      return;
    }

    setState(() {
      _exchangeWaiting = true;
      _exchangeReadyToContinue = false;
      _receivedExchangeCards = <CardModel>[];
    });

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) {
      return;
    }

    setState(() {
      _exchangeWaiting = false;
      _exchangeReadyToContinue = true;
      _receivedExchangeCards =
          _exchangePreview?.receiveCards ??
          _simulatedReceivedExchangeCards(exchangeData);
    });
  }

  Future<void> _confirmExitGame() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: presidentSurfaceContainer,
          title: const Text('Leave Game?'),
          content: const Text('Your current match will be closed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: presidentDanger,
                foregroundColor: Colors.black,
              ),
              child: const Text('LEAVE'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  List<CardModel> _autoExchangeCards(
    List<CardModel> hand,
    ExchangeViewData? exchange,
  ) {
    if (exchange == null || !exchange.required || hand.isEmpty) {
      return const <CardModel>[];
    }

    final ordered = [...hand]..sort(compareCards);
    final count = math.min(exchange.requiredCount, ordered.length);
    if (exchange.direction == ExchangeDirection.sendWorst) {
      return ordered.take(count).toList();
    }
    if (exchange.direction == ExchangeDirection.sendBest) {
      return ordered.skip(ordered.length - count).toList();
    }
    return const <CardModel>[];
  }

  List<CardModel> _simulatedReceivedExchangeCards(ExchangeViewData? exchange) {
    if (exchange == null || !exchange.required) {
      return const <CardModel>[];
    }

    final ranks = exchange.direction == ExchangeDirection.sendWorst
        ? <int>[15, 14, 13, 12]
        : <int>[3, 4, 5, 6];
    final suits = <Suit>[Suit.spades, Suit.hearts, Suit.clubs, Suit.diamonds];

    return List<CardModel>.generate(exchange.requiredCount, (index) {
      final rank = ranks[index % ranks.length];
      final suit = suits[index % suits.length];
      return CardModel(
        id: 'exchange-preview-${exchange.role}-$index-$rank-${suit.name}',
        suit: suit,
        rank: rank,
      );
    });
  }

  Future<void> _handleDebugAction(_DebugMenuAction action) async {
    switch (action) {
      case _DebugMenuAction.toggleMockResults:
        setState(() {
          _showMockResultsOverlay = !_showMockResultsOverlay;
          if (_showMockResultsOverlay) {
            _showResultsOverlay = false;
            _showExchangeOverlay = false;
            _showMockExchangeOverlay = false;
          }
        });
      case _DebugMenuAction.toggleMockExchange:
        setState(() {
          _showMockExchangeOverlay = !_showMockExchangeOverlay;
          if (_showMockExchangeOverlay) {
            _showResultsOverlay = false;
            _showExchangeOverlay = false;
            _showMockResultsOverlay = false;
          }
        });
      case _DebugMenuAction.fastForwardMatch:
        if (_busy) {
          return;
        }
        _botTimer?.cancel();
        setState(() {
          _busy = true;
        });
        try {
          final next = await _api.fastForwardGame();
          if (!mounted) {
            return;
          }
          await _setGameState(next);
        } catch (error, stackTrace) {
          _reportError('debug_fast_forward', error, stackTrace);
          if (!mounted) {
            return;
          }
          setState(() {
            _busy = false;
          });
          _showBanner(_formatError(error));
        }
      case _DebugMenuAction.toggleRandomRolesForNewGames:
        setState(() {
          _debugNewGamesUseRandomRoles = !_debugNewGamesUseRandomRoles;
        });
      case _DebugMenuAction.newGame4Players:
        await _startDebugNewGame(4);
      case _DebugMenuAction.newGame5Players:
        await _startDebugNewGame(5);
      case _DebugMenuAction.newGame6Players:
        await _startDebugNewGame(6);
      case _DebugMenuAction.newGame7Players:
        await _startDebugNewGame(7);
      case _DebugMenuAction.newGame8Players:
        await _startDebugNewGame(8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: presidentBackground.withValues(alpha: 0.58),
          ),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: presidentPrimary),
                  )
                : _state == null
                ? _ErrorState(onRetry: _loadGame)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final viewPadding = MediaQuery.viewPaddingOf(context);
                      final layoutInsets = EdgeInsets.fromLTRB(
                        math.max(viewPadding.left, 16),
                        math.max(viewPadding.top, 12),
                        math.max(viewPadding.right, 16),
                        math.max(viewPadding.bottom, 16),
                      );
                      return _buildGame(
                        context,
                        constraints.biggest,
                        _state!,
                        layoutInsets,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGame(
    BuildContext context,
    Size size,
    PublicGameStateModel state,
    EdgeInsets layoutInsets,
  ) {
    const layoutShiftY = 18.0;
    const tableCenterOffsetX = 0.0;
    const tableCenterOffsetY = 0.0;
    const seatCenterOffsetX = -10.0;
    const seatCenterOffsetY = 0.0;
    const seatRadiusOffset = 20.0;
    const handBottomGap = 44.0;
    const buttonLift = 84.0;
    final compactHeight = size.height < 760;
    final uiScale = size.width <= 380 ? 0.92 : 1.0;
    final handHeight = compactHeight ? 156.0 : 170.0;
    final topInsetBias = (layoutInsets.top - 12) * 0.22;
    final bottomInsetBias = (layoutInsets.bottom - 16) * 0.18;
    final tableCenterY = _clampDouble(
      size.height * (compactHeight ? 0.345 : 0.33) -
          layoutShiftY +
          topInsetBias -
          bottomInsetBias,
      132,
      size.height - handHeight - 214,
    );
    final tableCenter = Offset(
      (size.width / 2) + tableCenterOffsetX,
      tableCenterY + tableCenterOffsetY,
    );
    final seatOrbitCenter = Offset(
      tableCenter.dx + seatCenterOffsetX,
      tableCenter.dy + seatCenterOffsetY,
    );
    final seatRadius =
        math.min(
          size.width * 0.39,
          size.height * (compactHeight ? 0.215 : 0.24),
        ) +
        seatRadiusOffset * uiScale;
    final handTop = _clampDouble(
      size.height - handHeight - handBottomGap,
      tableCenterY + 126,
      size.height - handHeight - 12,
    );
    final handRect = Rect.fromLTWH(0, handTop, size.width, handHeight);
    final buttonCenter = Offset(size.width / 2, handRect.top - buttonLift);
    final layout = _LayoutSnapshot(
      size: size,
      uiScale: uiScale,
      tableCenter: tableCenter,
      seatOrbitCenter: seatOrbitCenter,
      seatRadius: seatRadius,
      handRect: handRect,
      buttonCenter: buttonCenter,
    );
    _layout = layout;

    final currentPlayer = state.players.firstWhere(
      (player) => player.id == state.currentTurnPlayerId,
    );
    final resultsOverlayData = _showMockResultsOverlay
        ? buildMockMatchResultsViewData(state)
        : buildMatchResultsViewData(state);
    final exchangeOverlayData = _showMockExchangeOverlay
        ? buildMockExchangeViewData(state)
        : buildExchangeViewData(state);
    final autoExchangeCards = _showMockExchangeOverlay
        ? _autoExchangeCards(_lastKnownViewerHand, exchangeOverlayData)
        : (_exchangePreviewLoading
              ? const <CardModel>[]
              : (_exchangePreview?.sendCards ?? const <CardModel>[]));
    final buttonEnabled = _selectedCardIds.isEmpty
        ? _isViewerTurn
        : _isSelectedPlayValid(state);
    final selectableIds = _selectableCardIds(state);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _TableGlowPainter(
              center: tableCenter,
              radius: seatRadius * 0.96,
            ),
          ),
        ),
        if ((_banner ?? '').isNotEmpty)
          Positioned(
            top: 56,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: presidentSurfaceHigh.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: presidentOutlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _banner!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          )
        else if (currentPlayer.kind == PlayerKind.human &&
            state.phase == GamePhase.finished)
          Positioned(
            top: 58,
            left: 20,
            right: 20,
            child: Center(
              child: Text(
                'Round Finished',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        Positioned(
          top: 4,
          left: 0,
          child: _LeaveGameButton(onPressed: _confirmExitGame),
        ),
        if (AppConfig.instance.isDev)
          Positioned(
            top: 0,
            right: 0,
            child: _DebugMenuButton(
              busy: _busy,
              mockResultsVisible: _showMockResultsOverlay,
              mockExchangeVisible: _showMockExchangeOverlay,
              randomRolesForNewGames: _debugNewGamesUseRandomRoles,
              onSelected: _handleDebugAction,
            ),
          ),
        for (var index = 0; index < state.players.length; index++)
          _buildPlayerSeat(context, state, state.players[index], index, layout),
        _buildCenterPile(context, state, layout),
        Positioned(
          left: buttonCenter.dx - (100 * layout.uiScale),
          top: buttonCenter.dy + 2,
          width: 200 * layout.uiScale,
          child: _PrimaryActionButton(
            enabled: buttonEnabled,
            label: _selectedCardIds.isEmpty ? 'PASS' : 'PLAY HAND',
            scale: layout.uiScale,
            onPressed: buttonEnabled ? _submitAction : null,
          ),
        ),
        _buildViewerHand(context, state, layout, selectableIds),
        for (final flight in _cardFlights)
          _AnimatedFlightCard(
            key: ValueKey<String>(
              'flight-${flight.card.id}-${flight.controller.hashCode}',
            ),
            flight: flight,
          ),
        if ((_showResultsOverlay && state.phase == GamePhase.finished) ||
            _showMockResultsOverlay)
          ResultsOverlay(
            data: resultsOverlayData,
            onContinue: _onResultsContinue,
          ),
        if (((_showExchangeOverlay && state.phase == GamePhase.finished) ||
                _showMockExchangeOverlay) &&
            exchangeOverlayData != null)
          ExchangeOverlay(
            data: exchangeOverlayData,
            exchangeCards: autoExchangeCards,
            isWaiting: _exchangeWaiting,
            isReadyToContinue: _exchangeReadyToContinue,
            receivedCards: _receivedExchangeCards,
            onConfirm: _confirmExchangeAndContinue,
            onLeave: _showMockExchangeOverlay
                ? _closeMockExchange
                : _closeExchangeAndRestart,
          ),
      ],
    );
  }

  Widget _buildPlayerSeat(
    BuildContext context,
    PublicGameStateModel state,
    PublicPlayerStateModel player,
    int index,
    _LayoutSnapshot layout,
  ) {
    final angle = _seatAngle(state.players, index, state.viewerPlayerId);
    final center = _seatCenter(
      state.players,
      index,
      state.viewerPlayerId,
      layout.seatOrbitCenter,
      layout.seatRadius,
    );
    final isViewer = player.id == state.viewerPlayerId;
    final role = roleLabel(player, state.players.length);
    final isActive = player.isCurrentTurn && state.phase == GamePhase.playing;
    final isFinished = player.status == PlayerStatus.finished;
    final scale = isActive ? 1.08 : (isViewer ? 0.98 : 0.9);
    final opacity = isActive ? 1.0 : (isFinished ? 0.34 : 0.62);
    final widgetWidth = (isViewer ? 124.0 : 112.0) * layout.uiScale;
    final widgetHeight = (isViewer ? 142.0 : 154.0) * layout.uiScale;
    final avatarSize = (isViewer ? 74.0 : 68.0) * layout.uiScale;
    final topOffset = isViewer ? 34.0 * layout.uiScale : 0.0;
    final seatInward = Offset(
      math.cos(angle + math.pi),
      math.sin(angle + math.pi),
    );
    final fanSize = Size(94 * layout.uiScale, 46 * layout.uiScale);
    final clusterSize = isViewer
        ? avatarSize
        : avatarSize + (76 * layout.uiScale);
    final avatarLeft = (clusterSize - avatarSize) / 2;
    final avatarTop = (clusterSize - avatarSize) / 2;
    final avatarCenter = Offset(
      avatarLeft + avatarSize / 2,
      avatarTop + avatarSize / 2,
    );
    final fanCenter = avatarCenter + seatInward * (avatarSize * 0.82);

    return Positioned(
      left: center.dx - widgetWidth / 2,
      top: center.dy - widgetHeight / 2 + topOffset,
      width: widgetWidth,
      height: widgetHeight,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 220),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: widgetWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: clusterSize,
                    height: clusterSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        if (!isViewer && player.handCount > 0)
                          Positioned(
                            left: fanCenter.dx - fanSize.width / 2,
                            top: fanCenter.dy - fanSize.height / 2,
                            child: _OpponentFan(
                              count: player.handCount,
                              directionAngle: angle + math.pi,
                              scale: layout.uiScale,
                            ),
                          ),
                        Positioned(
                          left: avatarLeft,
                          top: avatarTop,
                          child: Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActive
                                    ? presidentPrimary
                                    : presidentOutlineVariant,
                                width: isActive ? 2.5 : 1.5,
                              ),
                              color: _parseColor(player.avatarColor),
                              boxShadow: isActive
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: presidentPrimary.withValues(
                                          alpha: 0.22,
                                        ),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : const <BoxShadow>[],
                            ),
                            child: ClipOval(
                              child: Transform.scale(
                                scale: 1.24,
                                child: SvgPicture.asset(
                                  'assets/default_avatar.svg',
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(
                                    isActive
                                        ? Colors.white
                                        : presidentSurfaceLowest,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: avatarTop + 2 * layout.uiScale,
                          left: avatarLeft + avatarSize - (20 * layout.uiScale),
                          child: _SeatRoleBadge(
                            role: role,
                            scale: layout.uiScale,
                          ),
                        ),
                        if (!isViewer)
                          Positioned(
                            left: 30 * layout.uiScale,
                            right: 0,
                            top: avatarTop + avatarSize - (6 * layout.uiScale),
                            child: Center(
                              child: Container(
                                constraints: BoxConstraints(
                                  minWidth: 68 * layout.uiScale,
                                  maxWidth: avatarSize + (18 * layout.uiScale),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10 * layout.uiScale,
                                  vertical: 5 * layout.uiScale,
                                ),
                                decoration: BoxDecoration(
                                  color: presidentSurfaceContainer.withValues(
                                    alpha: 0.94,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: presidentOutlineVariant.withValues(
                                      alpha: 0.38,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  player.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: presidentText,
                                    fontSize: 11.5 * layout.uiScale,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isViewer)
                    SizedBox(
                      width: widgetWidth,
                      child: Text(
                        player.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: presidentText,
                          fontSize: 13.0 * layout.uiScale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    SizedBox(height: 20 * layout.uiScale),
                  if (!isViewer)
                    AnimatedOpacity(
                      opacity: _passBubbleVisible[player.id] == true ? 1 : 0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10 * layout.uiScale,
                              vertical: 4 * layout.uiScale,
                            ),
                            decoration: BoxDecoration(
                              color: presidentPrimary,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: presidentPrimary.withValues(
                                    alpha: 0.22,
                                  ),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              'PASS',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10 * layout.uiScale,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterPile(
    BuildContext context,
    PublicGameStateModel state,
    _LayoutSnapshot layout,
  ) {
    final history = state.pile.history;

    if (history.isEmpty) {
      return Positioned(
        left: layout.tableCenter.dx - 110,
        top: layout.tableCenter.dy - 74,
        child: SizedBox(
          width: 220,
          child: Column(
            children: <Widget>[
              Icon(Icons.style_rounded, size: 72, color: presidentOutline),
              const SizedBox(height: 12),
              Text(
                'Play any valid set\nto lead',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final renderedSets = history.length > 4
        ? history.sublist(history.length - 4)
        : history;

    return Positioned(
      left: layout.tableCenter.dx - 96,
      top: layout.tableCenter.dy - 78,
      child: SizedBox(
        width: 192,
        height: 156,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            for (var setIndex = 0; setIndex < renderedSets.length; setIndex++)
              for (
                var cardIndex = 0;
                cardIndex < renderedSets[setIndex].cards.length;
                cardIndex++
              )
                Builder(
                  builder: (context) {
                    final set = renderedSets[setIndex];
                    final card = set.cards[cardIndex];
                    final isFirstSetOfRound =
                        history.isNotEmpty &&
                        set.timestamp == history.first.timestamp;
                    final center = _pileRenderedCardCenter(
                      layout,
                      set.cards,
                      cardIndex,
                      centerFirstSet: isFirstSetOfRound,
                    );

                    return Positioned(
                      left:
                          center.dx -
                          layout.tableCenter.dx -
                          (kCardSize.width * (1.14 * layout.uiScale)) / 2 +
                          96,
                      top:
                          center.dy -
                          layout.tableCenter.dy -
                          (kCardSize.height * (1.14 * layout.uiScale)) / 2 +
                          78,
                      child: Transform.rotate(
                        angle: _pileCardAngle(
                          card,
                          setIndex * 10 + cardIndex,
                          tight: isFirstSetOfRound,
                        ),
                        child: _GameCard(
                          card: card,
                          scale: 1.14 * layout.uiScale,
                        ),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerHand(
    BuildContext context,
    PublicGameStateModel state,
    _LayoutSnapshot layout,
    Set<String> selectableIds,
  ) {
    final visibleHand = state.viewerHand
        .where((card) => !_animatingViewerCardIds.contains(card.id))
        .toList();
    final metrics = _viewerHandMetrics(layout, visibleHand.length);
    final order = List<int>.generate(visibleHand.length, (index) => index)
      ..sort((left, right) {
        final leftSelected = _selectedCardIds.contains(visibleHand[left].id);
        final rightSelected = _selectedCardIds.contains(visibleHand[right].id);
        if (leftSelected != rightSelected) {
          return leftSelected ? 1 : -1;
        }

        final leftRow = _viewerCardRow(metrics, left);
        final rightRow = _viewerCardRow(metrics, right);
        if (leftRow != rightRow) {
          return leftRow.compareTo(rightRow);
        }

        final leftColumn = _viewerCardColumn(metrics, left);
        final rightColumn = _viewerCardColumn(metrics, right);
        if (leftColumn != rightColumn) {
          return leftColumn.compareTo(rightColumn);
        }
        return left.compareTo(right);
      });

    return Positioned(
      left: layout.handRect.left,
      top: layout.handRect.top,
      width: layout.handRect.width,
      height: layout.handRect.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (final index in order)
            Builder(
              builder: (context) {
                final card = visibleHand[index];
                final isSelected = _selectedCardIds.contains(card.id);
                final selectable =
                    selectableIds.contains(card.id) || isSelected;
                final row = _viewerCardRow(metrics, index);
                final column = _viewerCardColumn(metrics, index);
                final rowCount = row == 1
                    ? metrics.frontCount
                    : metrics.backCount;
                final angle = _viewerCardAngle(column, rowCount);
                final selectionNudge = isSelected
                    ? (angle <= 0 ? -0.03 : 0.03)
                    : 0.0;
                final position = _viewerCardPosition(
                  layout,
                  metrics,
                  index,
                  visibleHand.length,
                  isSelected,
                );
                return AnimatedPositioned(
                  key: ValueKey<String>('hand-${card.id}'),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  left: position.dx,
                  top: position.dy,
                  child: GestureDetector(
                    onTap: _isViewerTurn ? () => _toggleCard(card) : null,
                    child: AnimatedRotation(
                      turns: (angle + selectionNudge) / (2 * math.pi),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: AnimatedSlide(
                        offset: isSelected
                            ? const Offset(0, -0.09)
                            : Offset.zero,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutBack,
                        child: AnimatedScale(
                          scale: isSelected ? 1.15 : 1,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutBack,
                          child: _GameCard(
                            card: card,
                            scale: 1.12 * layout.uiScale,
                            selectable: selectable,
                            selected: isSelected,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

enum _DebugMenuAction {
  toggleMockResults,
  toggleMockExchange,
  fastForwardMatch,
  toggleRandomRolesForNewGames,
  newGame4Players,
  newGame5Players,
  newGame6Players,
  newGame7Players,
  newGame8Players,
}

class _DebugMenuButton extends StatelessWidget {
  const _DebugMenuButton({
    required this.busy,
    required this.mockResultsVisible,
    required this.mockExchangeVisible,
    required this.randomRolesForNewGames,
    required this.onSelected,
  });

  final bool busy;
  final bool mockResultsVisible;
  final bool mockExchangeVisible;
  final bool randomRolesForNewGames;
  final ValueChanged<_DebugMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: presidentSurfaceHigh.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: presidentOutlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: PopupMenuButton<_DebugMenuAction>(
          tooltip: 'Debug menu',
          padding: const EdgeInsets.all(12),
          icon: const Icon(Icons.bug_report_rounded, color: presidentText),
          onSelected: onSelected,
          itemBuilder: (context) => <PopupMenuEntry<_DebugMenuAction>>[
            CheckedPopupMenuItem<_DebugMenuAction>(
              value: _DebugMenuAction.toggleMockResults,
              checked: mockResultsVisible,
              child: const Text('Mock Results Overlay'),
            ),
            CheckedPopupMenuItem<_DebugMenuAction>(
              value: _DebugMenuAction.toggleMockExchange,
              checked: mockExchangeVisible,
              child: const Text('Mock Exchange Overlay'),
            ),
            PopupMenuItem<_DebugMenuAction>(
              value: _DebugMenuAction.fastForwardMatch,
              enabled: !busy,
              child: const Text('Fast-forward Match'),
            ),
            const PopupMenuDivider(),
            CheckedPopupMenuItem<_DebugMenuAction>(
              value: _DebugMenuAction.toggleRandomRolesForNewGames,
              checked: randomRolesForNewGames,
              child: const Text('New Games Use Random Roles'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<_DebugMenuAction>(
              value: _DebugMenuAction.newGame4Players,
              enabled: !busy,
              child: const Text('New Game: 4 Players'),
            ),
            PopupMenuItem<_DebugMenuAction>(
              value: _DebugMenuAction.newGame5Players,
              enabled: !busy,
              child: const Text('New Game: 5 Players'),
            ),
            PopupMenuItem<_DebugMenuAction>(
              value: _DebugMenuAction.newGame6Players,
              enabled: !busy,
              child: const Text('New Game: 6 Players'),
            ),
            PopupMenuItem<_DebugMenuAction>(
              value: _DebugMenuAction.newGame7Players,
              enabled: !busy,
              child: const Text('New Game: 7 Players'),
            ),
            PopupMenuItem<_DebugMenuAction>(
              value: _DebugMenuAction.newGame8Players,
              enabled: !busy,
              child: const Text('New Game: 8 Players'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveGameButton extends StatelessWidget {
  const _LeaveGameButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: presidentSurfaceHigh.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: presidentOutlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Tooltip(
          message: 'Leave game',
          child: IconButton(
            onPressed: onPressed,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.logout_rounded,
              size: 20,
              color: presidentText,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatRoleBadge extends StatelessWidget {
  const _SeatRoleBadge({required this.role, required this.scale});

  final String role;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final tint = switch (role) {
      'President' => presidentPrimary,
      'Vice' => presidentSecondary,
      'Vice Scum' => presidentTertiary,
      'Scum' => presidentDanger,
      _ => presidentMuted,
    };
    final size = 24.0 * scale;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: presidentSurfaceLowest.withValues(alpha: 0.96),
        border: Border.all(color: tint.withValues(alpha: 0.88), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tint.withValues(alpha: 0.22),
            blurRadius: 10 * scale,
            spreadRadius: 1 * scale,
          ),
        ],
      ),
      child: Center(
        child: SvgPicture.asset(
          _roleBadgeAsset(role),
          width: 14 * scale,
          height: 14 * scale,
          colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
        ),
      ),
    );
  }
}

String _roleBadgeAsset(String role) {
  return switch (role) {
    'President' => 'assets/crown.svg',
    'Vice' => 'assets/military_tech.svg',
    'Vice Scum' => 'assets/stat_minus_2.svg',
    'Scum' => 'assets/skull.svg',
    _ => 'assets/sentiment_content.svg',
  };
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'Unable to load game',
            style: TextStyle(
              color: presidentText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: presidentPrimary),
            child: const Text('Retry', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.enabled,
    required this.label,
    required this.scale,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final double scale;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.72,
      duration: const Duration(milliseconds: 160),
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: presidentPrimary.withValues(alpha: enabled ? 0.26 : 0.12),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: presidentPrimary,
            foregroundColor: Colors.black,
            minimumSize: Size.fromHeight(50 * scale),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.card,
    this.scale = 1,
    this.selectable = true,
    this.selected = false,
  });

  final CardModel card;
  final double scale;
  final bool selectable;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final width = kCardSize.width * scale;
    final height = kCardSize.height * scale;
    final face = PresidentCardFace(card: card, scale: scale);

    return Stack(
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9 * scale),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: selected
                    ? presidentSurfaceHighest.withValues(alpha: 0.34)
                    : presidentSurfaceLowest.withValues(alpha: 0.24),
                blurRadius: (selected ? 18 : 10) * scale,
                spreadRadius: (selected ? 1.5 : 0) * scale,
                offset: Offset(0, (selected ? 10 : 6) * scale),
              ),
            ],
          ),
          child: ColorFiltered(
            colorFilter: selectable
                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                : const ColorFilter.matrix(<double>[
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),
            child: face,
          ),
        ),
        if (!selectable)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: presidentSurfaceContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(9 * scale),
                border: Border.all(
                  color: presidentOutline.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        if (selected)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9 * scale),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.78),
                    width: 1.6,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: 10 * scale,
                      spreadRadius: 1 * scale,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedFlightCard extends StatelessWidget {
  const _AnimatedFlightCard({super.key, required this.flight});

  final _CardFlight flight;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flight.controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(flight.controller.value);
        final position = Offset.lerp(flight.start, flight.end, t)!;
        final angle =
            flight.startAngle + (flight.endAngle - flight.startAngle) * t;
        final scale =
            flight.startScale + (flight.endScale - flight.startScale) * t;
        return Positioned(
          left: position.dx - (kCardSize.width * scale) / 2,
          top: position.dy - (kCardSize.height * scale) / 2,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: angle,
              child: _GameCard(card: flight.card, scale: scale),
            ),
          ),
        );
      },
    );
  }
}

class _OpponentFan extends StatelessWidget {
  const _OpponentFan({
    required this.count,
    required this.directionAngle,
    this.scale = 1,
  });

  final int count;
  final double directionAngle;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final visible = math.min(count, 5);
    final fanRotation = directionAngle + (math.pi / 2);
    final width = 94 * scale;
    final height = 52 * scale;

    return Transform.rotate(
      angle: fanRotation,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            for (var index = 0; index < visible; index++)
              Transform.translate(
                offset: Offset((index - (visible - 1) / 2) * 10 * scale, 0),
                child: Transform.rotate(
                  angle: ((index - (visible - 1) / 2) * 0.08),
                  child: Container(
                    width: 27 * scale,
                    height: 38 * scale,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5EE),
                      borderRadius: BorderRadius.circular(6 * scale),
                      border: Border.all(
                        color: presidentSurfaceHighest.withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.star_rounded,
                      size: 12 * scale,
                      color: presidentPrimaryDark,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TableGlowPainter extends CustomPainter {
  const _TableGlowPainter({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          presidentPrimary.withValues(alpha: 0.26),
          presidentPrimary.withValues(alpha: 0.12),
          presidentPrimary.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.42));

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = presidentOutlineVariant.withValues(alpha: 0.22);

    canvas.drawCircle(center, radius * 1.16, glow);
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(
      center,
      radius * 0.78,
      ring..color = presidentOutlineVariant.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(covariant _TableGlowPainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius;
  }
}

class _LayoutSnapshot {
  const _LayoutSnapshot({
    required this.size,
    required this.uiScale,
    required this.tableCenter,
    required this.seatOrbitCenter,
    required this.seatRadius,
    required this.handRect,
    required this.buttonCenter,
  });

  final Size size;
  final double uiScale;
  final Offset tableCenter;
  final Offset seatOrbitCenter;
  final double seatRadius;
  final Rect handRect;
  final Offset buttonCenter;
}

class _HandMetrics {
  const _HandMetrics({
    required this.startX,
    required this.spacing,
    required this.cardTop,
    required this.frontCount,
    required this.backCount,
    required this.rowGap,
  });

  final double startX;
  final double spacing;
  final double cardTop;
  final int frontCount;
  final int backCount;
  final double rowGap;
}

class _FlightSpec {
  const _FlightSpec({
    required this.card,
    required this.start,
    required this.end,
    required this.startAngle,
    required this.endAngle,
    required this.startScale,
    required this.endScale,
  });

  final CardModel card;
  final Offset start;
  final Offset end;
  final double startAngle;
  final double endAngle;
  final double startScale;
  final double endScale;
}

class _CardFlight {
  const _CardFlight({
    required this.card,
    required this.start,
    required this.end,
    required this.startAngle,
    required this.endAngle,
    required this.startScale,
    required this.endScale,
    required this.controller,
  });

  final CardModel card;
  final Offset start;
  final Offset end;
  final double startAngle;
  final double endAngle;
  final double startScale;
  final double endScale;
  final AnimationController controller;
}

_HandMetrics _viewerHandMetrics(_LayoutSnapshot layout, int count) {
  final useTwoRows = count >= 10;
  final backCount = useTwoRows ? count ~/ 2 : 0;
  final frontCount = useTwoRows ? count - backCount : count;
  final columns = math.max(frontCount, backCount);

  if (count <= 1) {
    return _HandMetrics(
      startX: (layout.handRect.width - kCardSize.width) / 2,
      spacing: 0,
      cardTop: 26,
      frontCount: 1,
      backCount: 0,
      rowGap: 38,
    );
  }

  final available = math.max(
    24.0,
    layout.handRect.width - kCardSize.width - 40,
  );
  final spacing = (available / math.max(1, columns - 1))
      .clamp(20.0, 34.0)
      .toDouble();
  final totalWidth = kCardSize.width + spacing * (columns - 1);
  final startX = (layout.handRect.width - totalWidth) / 2;
  return _HandMetrics(
    startX: startX,
    spacing: spacing,
    cardTop: 16,
    frontCount: frontCount,
    backCount: backCount,
    rowGap: 40,
  );
}

Offset _viewerCardPosition(
  _LayoutSnapshot layout,
  _HandMetrics metrics,
  int index,
  int count,
  bool isSelected,
) {
  final row = _viewerCardRow(metrics, index);
  final column = _viewerCardColumn(metrics, index);
  final rowCount = row == 1 ? metrics.frontCount : metrics.backCount;
  final normalized = rowCount <= 1 ? 0.0 : ((column / (rowCount - 1)) * 2) - 1;
  final arc = math.pow(normalized.abs(), 1.45).toDouble();
  final baseTop = metrics.cardTop + (row == 0 ? 0 : metrics.rowGap) + arc * 24;
  final top = baseTop - (isSelected ? 36 : 0);
  final x =
      _viewerRowStartX(layout, metrics, rowCount) + metrics.spacing * column;
  return Offset(x, top);
}

int _viewerCardRow(_HandMetrics metrics, int index) {
  if (metrics.backCount == 0) {
    return 1;
  }
  return index < metrics.frontCount ? 1 : 0;
}

int _viewerCardColumn(_HandMetrics metrics, int index) {
  if (metrics.backCount == 0) {
    return index;
  }
  if (index < metrics.frontCount) {
    return index;
  }
  return index - metrics.frontCount;
}

double _viewerRowStartX(
  _LayoutSnapshot layout,
  _HandMetrics metrics,
  int rowCount,
) {
  if (rowCount <= 1) {
    return (layout.handRect.width - kCardSize.width) / 2;
  }
  final totalWidth = kCardSize.width + metrics.spacing * (rowCount - 1);
  return (layout.handRect.width - totalWidth) / 2;
}

Offset _viewerCardCenter(
  _LayoutSnapshot layout,
  _HandMetrics metrics,
  int index,
  int count,
  bool isSelected,
) {
  final position = _viewerCardPosition(
    layout,
    metrics,
    index,
    count,
    isSelected,
  );
  return Offset(
    layout.handRect.left + position.dx + kCardSize.width / 2,
    layout.handRect.top + position.dy + kCardSize.height / 2,
  );
}

double _clampDouble(double value, double min, double max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

double _viewerCardAngle(int index, int count) {
  if (count <= 1) {
    return 0;
  }
  final normalized = ((index / (count - 1)) * 2) - 1;
  final spread = count >= 8 ? 0.42 : 0.34;
  return normalized * spread;
}

double _seatAngle(
  List<PublicPlayerStateModel> players,
  int playerIndex,
  String viewerPlayerId,
) {
  final viewerIndex = players.indexWhere(
    (player) => player.id == viewerPlayerId,
  );
  final total = players.length;
  final normalizedIndex = viewerIndex == -1
      ? playerIndex
      : (playerIndex - viewerIndex + total) % total;
  final step = (math.pi * 2) / total;
  return math.pi / 2 + step * normalizedIndex;
}

Offset _seatCenter(
  List<PublicPlayerStateModel> players,
  int playerIndex,
  String viewerPlayerId,
  Offset tableCenter,
  double radius,
) {
  final angle = _seatAngle(players, playerIndex, viewerPlayerId);
  return tableCenter +
      Offset(math.cos(angle) * radius, math.sin(angle) * radius);
}

Offset _pileSetOffset(List<CardModel> cards) {
  final bucket = cards
      .expand((card) => card.id.codeUnits)
      .fold<int>(17, (value, unit) => ((value * 31) + unit) & 0x7fffffff);
  final horizontal = ((bucket % 49) - 24).toDouble();
  final vertical = ((((bucket ~/ 49) % 21) - 10) * 0.9).toDouble();
  return Offset(horizontal, vertical);
}

Offset _pileRenderedCardCenter(
  _LayoutSnapshot layout,
  List<CardModel> cards,
  int index, {
  bool centerFirstSet = false,
}) {
  if (centerFirstSet) {
    final cardOffsetX = (index - (cards.length - 1) / 2) * 10.0;
    final cardOffsetY = ((index % 2) * 3 - 1.5).toDouble();
    return layout.tableCenter + Offset(cardOffsetX, cardOffsetY);
  }

  final setOffset = _pileSetOffset(cards);
  final cardOffsetX = (index - (cards.length - 1) / 2) * 10.0;
  final cardOffsetY = ((index % 2) * 3 - 1.5).toDouble();
  return layout.tableCenter +
      Offset(setOffset.dx + cardOffsetX, setOffset.dy + cardOffsetY);
}

double _pileCardAngle(CardModel card, int index, {bool tight = false}) {
  final hash = card.id.codeUnits.fold<int>(
    index * 131 + 17,
    (value, unit) => ((value * 31) + unit) & 0x7fffffff,
  );
  final degrees = tight ? (hash % 7) - 3 : (hash % 21) - 10;
  return degrees * (math.pi / 180);
}

Color _parseColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}
