import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'card_asset.dart';
import 'game_api.dart';
import 'game_overlays.dart';
import 'models.dart';
import 'president_theme.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final GameApi _api = GameApi();
  final Set<String> _selectedCardIds = <String>{};
  final Set<String> _animatingViewerCardIds = <String>{};
  final List<_CardFlight> _cardFlights = <_CardFlight>[];

  PublicGameStateModel? _state;
  bool _loading = true;
  bool _busy = false;
  bool _showResultsOverlay = false;
  bool _showExchangeOverlay = false;
  String? _banner;
  Timer? _bannerTimer;
  Timer? _botTimer;
  _LayoutSnapshot? _layout;
  List<CardModel> _exchangeSelection = <CardModel>[];

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _botTimer?.cancel();
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

  Future<void> _loadGame() async {
    _bannerTimer?.cancel();
    _botTimer?.cancel();
    setState(() {
      _loading = true;
      _busy = false;
      _banner = null;
      _showResultsOverlay = false;
      _showExchangeOverlay = false;
      _exchangeSelection = <CardModel>[];
      _selectedCardIds.clear();
      _animatingViewerCardIds.clear();
      _clearFlights();
    });

    try {
      final state = await _api.createGame();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
        _loading = false;
      });
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
        _exchangeSelection = <CardModel>[];
      }
    });
    for (final flight in lingeringFlights) {
      flight.controller.dispose();
    }
    _scheduleBotTurnIfNeeded();
  }

  void _scheduleBotTurnIfNeeded() {
    _botTimer?.cancel();
    final state = _state;
    if (state == null ||
        state.phase != GamePhase.playing ||
        _showExchangeOverlay ||
        _showResultsOverlay) {
      return;
    }

    final currentPlayer = state.players.firstWhere(
      (player) => player.id == state.currentTurnPlayerId,
    );

    if (currentPlayer.kind != PlayerKind.bot || _busy) {
      return;
    }

    setState(() {
      _banner = '${currentPlayer.name} is thinking';
    });

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

        setState(() {
          _banner = null;
        });
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
        !_showExchangeOverlay &&
        !_showResultsOverlay;
  }

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
      final end = _pileRenderedCardCenter(layout, cards, index);
      flights.add(
        _FlightSpec(
          card: card,
          start: start,
          end: end,
          startAngle: _viewerCardAngle(handIndex, state.viewerHand.length),
          endAngle: _pileCardAngle(card, index),
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
      final end = _pileRenderedCardCenter(layout, cards, index);
      flights.add(
        _FlightSpec(
          card: cards[index],
          start: start,
          end: end,
          startAngle: seatAngle + math.pi / 2,
          endAngle: _pileCardAngle(cards[index], index),
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

    final exchange = buildExchangeViewData(state);
    setState(() {
      _showResultsOverlay = false;
      _showExchangeOverlay = exchange != null;
      _exchangeSelection = <CardModel>[];
    });

    if (exchange == null) {
      _loadGame();
    }
  }

  void _toggleExchangeCard(CardModel card) {
    setState(() {
      final existing = _exchangeSelection.indexWhere(
        (entry) => entry.id == card.id,
      );
      if (existing >= 0) {
        _exchangeSelection.removeAt(existing);
      } else {
        _exchangeSelection.add(card);
        _exchangeSelection.sort(compareCards);
      }
    });
  }

  void _closeExchangeAndRestart() {
    setState(() {
      _showExchangeOverlay = false;
      _exchangeSelection = <CardModel>[];
    });
    _loadGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1B1D1F), presidentBackground],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: presidentPrimary),
                )
              : _state == null
              ? _ErrorState(onRetry: _loadGame)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildGame(context, constraints.biggest, _state!);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildGame(
    BuildContext context,
    Size size,
    PublicGameStateModel state,
  ) {
    final tableCenter = Offset(size.width / 2, size.height * 0.33);
    final seatRadius = math.min(size.width * 0.39, size.height * 0.24);
    final handRect = Rect.fromLTWH(0, size.height - 184, size.width, 170);
    final buttonCenter = Offset(size.width / 2, handRect.top - 50);
    final layout = _LayoutSnapshot(
      size: size,
      tableCenter: tableCenter,
      seatRadius: seatRadius,
      handRect: handRect,
      buttonCenter: buttonCenter,
    );
    _layout = layout;

    final currentPlayer = state.players.firstWhere(
      (player) => player.id == state.currentTurnPlayerId,
    );
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
        for (var index = 0; index < state.players.length; index++)
          _buildPlayerSeat(context, state, state.players[index], index, layout),
        _buildCenterPile(context, state, layout),
        Positioned(
          left: buttonCenter.dx - 100,
          top: buttonCenter.dy - 24,
          width: 200,
          child: _PrimaryActionButton(
            enabled: buttonEnabled,
            label: _selectedCardIds.isEmpty ? 'PASS' : 'PLAY HAND',
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
        if (_showResultsOverlay && state.phase == GamePhase.finished)
          ResultsOverlay(
            data: buildMatchResultsViewData(state),
            onContinue: _onResultsContinue,
            onClose: () => setState(() => _showResultsOverlay = false),
          ),
        if (_showExchangeOverlay && state.phase == GamePhase.finished)
          ExchangeOverlay(
            data: buildExchangeViewData(state)!,
            hand: state.viewerHand,
            selectedCards: _exchangeSelection,
            onToggleCard: _toggleExchangeCard,
            onConfirm: _closeExchangeAndRestart,
            onLeave: _closeExchangeAndRestart,
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
      layout.tableCenter,
      layout.seatRadius,
    );
    final isViewer = player.id == state.viewerPlayerId;
    final role = roleLabel(player, state.players.length);
    final isActive = player.isCurrentTurn && state.phase == GamePhase.playing;
    final isFinished = player.status == PlayerStatus.finished;
    final scale = isActive ? 1.08 : (isViewer ? 0.98 : 0.9);
    final opacity = isActive ? 1.0 : (isFinished ? 0.34 : 0.62);
    final widgetWidth = isViewer ? 124.0 : 112.0;
    final widgetHeight = isViewer ? 142.0 : 154.0;

    return Positioned(
      left: center.dx - widgetWidth / 2,
      top: center.dy - widgetHeight / 2,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? presidentSurfaceHigh
                          : presidentSurfaceContainer,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        color: presidentText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: isViewer ? 74 : 68,
                    height: isViewer ? 74 : 68,
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
                                color: presidentPrimary.withValues(alpha: 0.22),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ]
                          : const <BoxShadow>[],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      player.name.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isViewer ? 26 : 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: widgetWidth,
                    child: Text(
                      player.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: presidentText,
                        fontSize: isViewer ? 13 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!isViewer && player.handCount > 0) ...<Widget>[
                    const SizedBox(height: 8),
                    _OpponentFan(
                      count: player.handCount,
                      directionAngle: angle + math.pi,
                    ),
                  ],
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
        top: layout.tableCenter.dy - 54,
        child: SizedBox(
          width: 220,
          child: Column(
            children: <Widget>[
              Text(
                'New Round',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: presidentPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Play any valid set to lead',
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
              for (var cardIndex = 0;
                  cardIndex < renderedSets[setIndex].cards.length;
                  cardIndex++)
                Builder(
                  builder: (context) {
                    final set = renderedSets[setIndex];
                    final card = set.cards[cardIndex];
                    final center = _pileRenderedCardCenter(
                      layout,
                      set.cards,
                      cardIndex,
                    );

                    return Positioned(
                      left:
                          center.dx -
                          layout.tableCenter.dx -
                          (kCardSize.width * 1.14) / 2 +
                          96,
                      top:
                          center.dy -
                          layout.tableCenter.dy -
                          (kCardSize.height * 1.14) / 2 +
                          78,
                      child: Transform.rotate(
                        angle: _pileCardAngle(
                          card,
                          setIndex * 10 + cardIndex,
                        ),
                        child: _GameCard(card: card, scale: 1.14),
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
        final leftSelected = _selectedCardIds.contains(
          visibleHand[left].id,
        );
        final rightSelected = _selectedCardIds.contains(
          visibleHand[right].id,
        );
        if (leftSelected == rightSelected) {
          return left.compareTo(right);
        }
        return leftSelected ? 1 : -1;
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
                      turns:
                          (_viewerCardAngle(index, visibleHand.length) +
                              (isSelected
                                  ? (index.isEven ? -0.03 : 0.03)
                                  : 0)) /
                          (2 * math.pi),
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
                            scale: 1.2,
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
    required this.onPressed,
  });

  final bool enabled;
  final String label;
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
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
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
  const _OpponentFan({required this.count, required this.directionAngle});

  final int count;
  final double directionAngle;

  @override
  Widget build(BuildContext context) {
    final visible = math.min(count, 5);
    return SizedBox(
      width: 94,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (var index = 0; index < visible; index++)
            Transform.translate(
              offset: Offset((index - (visible - 1) / 2) * 10, 0),
              child: Transform.rotate(
                angle: directionAngle + ((index - (visible - 1) / 2) * 0.08),
                child: Container(
                  width: 27,
                  height: 38,
                  decoration: BoxDecoration(
                    color: presidentSurfaceHigh,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: presidentOutlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: presidentPrimary,
                  ),
                ),
              ),
            ),
        ],
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
          presidentPrimary.withValues(alpha: 0.14),
          presidentPrimary.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.32));

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = presidentOutlineVariant.withValues(alpha: 0.22);

    canvas.drawCircle(center, radius * 1.08, glow);
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
    required this.tableCenter,
    required this.seatRadius,
    required this.handRect,
    required this.buttonCenter,
  });

  final Size size;
  final Offset tableCenter;
  final double seatRadius;
  final Rect handRect;
  final Offset buttonCenter;
}

class _HandMetrics {
  const _HandMetrics({
    required this.startX,
    required this.spacing,
    required this.cardTop,
  });

  final double startX;
  final double spacing;
  final double cardTop;
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
  if (count <= 1) {
    return _HandMetrics(
      startX: (layout.handRect.width - kCardSize.width) / 2,
      spacing: 0,
      cardTop: 34,
    );
  }

  final available = math.max(
    24.0,
    layout.handRect.width - kCardSize.width - 40,
  );
  final spacing = (available / (count - 1)).clamp(18.0, 28.0).toDouble();
  final totalWidth = kCardSize.width + spacing * (count - 1);
  final startX = (layout.handRect.width - totalWidth) / 2;
  return _HandMetrics(startX: startX, spacing: spacing, cardTop: 34);
}

Offset _viewerCardPosition(
  _LayoutSnapshot layout,
  _HandMetrics metrics,
  int index,
  int count,
  bool isSelected,
) {
  final normalized = count <= 1 ? 0.0 : ((index / (count - 1)) * 2) - 1;
  final arc = math.pow(normalized.abs(), 1.45).toDouble();
  final top = metrics.cardTop + arc * 28 - (isSelected ? 34 : 0);
  return Offset(metrics.startX + metrics.spacing * index, top);
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
  int index,
) {
  final setOffset = _pileSetOffset(cards);
  final cardOffsetX = (index - (cards.length - 1) / 2) * 10.0;
  final cardOffsetY = ((index % 2) * 3 - 1.5).toDouble();
  return layout.tableCenter +
      Offset(setOffset.dx + cardOffsetX, setOffset.dy + cardOffsetY);
}

double _pileCardAngle(CardModel card, int index) {
  final hash = card.id.codeUnits.fold<int>(
    index * 131 + 17,
    (value, unit) => ((value * 31) + unit) & 0x7fffffff,
  );
  final degrees = (hash % 21) - 10;
  return degrees * (math.pi / 180);
}

Color _parseColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}
