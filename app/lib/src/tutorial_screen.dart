import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'card_asset.dart';
import 'models.dart';
import 'president_theme.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  static const List<_TutorialLesson> _lessons = <_TutorialLesson>[
    _TutorialLesson(
      title: 'Play Out Your Hand',
      description:
          'The goal of the game is to get rid of all your cards before everyone else. In each round, you beat the current table by playing a higher rank, or you pass.',
      strategyTitle: 'Core Objective',
      strategyBody:
          'Every decision serves one purpose: empty your hand. Use stronger cards to take control when needed, but never lose sight of finishing first.',
      ctaLabel: 'Next',
      visual: _LessonVisual.goal,
    ),
    _TutorialLesson(
      title: 'Power Levels',
      description:
          'The deck climbs from 3 up to A, and the 2 stands above everything else. Playing a 2 clears the board and gives you control of the next play.',
      strategyTitle: 'Control Reset',
      strategyBody:
          'Save your strongest reset cards for a moment when control matters. A well-timed 2 can stop momentum and reopen the table on your terms.',
      ctaLabel: 'Next',
      visual: _LessonVisual.powerLevels,
    ),
    _TutorialLesson(
      title: 'Strength In Numbers',
      description:
          'Pairs beat pairs and triples beat triples. You must always match the number of cards already on the table before rank even matters.',
      strategyTitle: 'Executive Strategy',
      strategyBody:
          'High singles do not help against grouped plays. Protect strong pairs and triples until they can actually win the exchange.',
      ctaLabel: 'Next',
      visual: _LessonVisual.pairs,
    ),
    _TutorialLesson(
      title: 'The Joker: Absolute Authority',
      description:
          'The Joker overrides the normal ladder. It is the one card that can dominate any sequence and immediately seize the initiative.',
      strategyTitle: 'Last Resort Or Finisher',
      strategyBody:
          'Do not waste the Joker just because it is strong. It is often worth more when it closes a key exchange or guarantees your finishing position.',
      ctaLabel: 'Next',
      visual: _LessonVisual.joker,
    ),
    _TutorialLesson(
      title: 'Climb The Hierarchy',
      description:
          'Finish first to become President. Every seat in the ranking matters because it decides the next round hierarchy and also how many rank points you earn for your profile.',
      strategyTitle: 'Executive Read',
      strategyBody:
          'The game is not only about winning a hand. It is about finishing in the best possible position so the next round starts in your favor and your long-term rank climbs faster.',
      ctaLabel: 'Next',
      visual: _LessonVisual.hierarchy,
    ),
    _TutorialLesson(
      title: 'Power Shift',
      description:
          'After each round, the hierarchy triggers an exchange. President and Vice take strength from the bottom seats, which can reshape the entire next deal.',
      strategyTitle: 'Position Matters',
      strategyBody:
          'Even if you cannot finish first, pushing out of Scum or Vice Scum changes the next round dramatically. Late-round decisions affect future hands.',
      ctaLabel: 'Complete Tutorial',
      visual: _LessonVisual.exchange,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _TutorialLesson lesson = _lessons[_currentIndex];

    return Scaffold(
      backgroundColor: presidentBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              presidentSurfaceLowest,
              presidentBackground,
              Color(0xFF0D0F11),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned(
              top: -120,
              right: -90,
              child: _AmbientGlow(size: 360),
            ),
            const Positioned(
              bottom: -80,
              left: -40,
              child: _AmbientGlow(size: 260, secondary: true),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  const _TutorialCloseButton(),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _lessons.length,
                      onPageChanged: (int index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final _TutorialLesson current = _lessons[index];
                        return _TutorialPage(
                          lesson: current,
                          totalCount: _lessons.length,
                          currentIndex: index,
                        );
                      },
                    ),
                  ),
                  _TutorialFooter(
                    currentIndex: _currentIndex,
                    totalCount: _lessons.length,
                    ctaLabel: lesson.ctaLabel,
                    onBack: _currentIndex == 0 ? null : _goBack,
                    onNext: _goNext,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goBack() {
    if (_currentIndex <= 0) {
      return;
    }
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _goNext() {
    if (_currentIndex >= _lessons.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }
}

class _TutorialCloseButton extends StatelessWidget {
  const _TutorialCloseButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: presidentSurfaceHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).maybePop();
              },
              icon: const Icon(Icons.close_rounded, color: presidentMuted),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({
    required this.lesson,
    required this.totalCount,
    required this.currentIndex,
  });

  final _TutorialLesson lesson;
  final int totalCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 760;
        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  compact ? 14 : 18,
                  20,
                  compact ? 148 : 156,
                ),
                child: Column(
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        children: <Widget>[
                          Text(
                            lesson.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFFFF5E7),
                              fontSize: compact ? 38 : 62,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2.0,
                              height: 0.95,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Text(
                              lesson.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: presidentMuted.withValues(alpha: 0.9),
                                fontSize: compact ? 16 : 20,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 16 : 22),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: _LessonVisualWidget(
                            lesson: lesson,
                            compact: compact,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 24 : 30),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: _StrategyCard(
                        title: lesson.strategyTitle,
                        body: lesson.strategyBody,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LessonVisualWidget extends StatelessWidget {
  const _LessonVisualWidget({required this.lesson, required this.compact});

  final _TutorialLesson lesson;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    switch (lesson.visual) {
      case _LessonVisual.goal:
        return _GoalLessonVisual(compact: compact);
      case _LessonVisual.hierarchy:
        return _HierarchyLessonVisual(compact: compact);
      case _LessonVisual.powerLevels:
        return _PowerLevelsVisual(compact: compact);
      case _LessonVisual.pairs:
        return _PairsLessonVisual(compact: compact);
      case _LessonVisual.exchange:
        return _ExchangeLessonVisual(compact: compact);
      case _LessonVisual.joker:
        return _JokerLessonVisual(compact: compact);
    }
  }
}

class _GoalLessonVisual extends StatelessWidget {
  const _GoalLessonVisual({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PlayCluster(
              alignEnd: false,
              textCentered: true,
              label: 'Current Play',
              headline: 'Single 9',
              clusterWidth: 104,
              stackHeight: 132,
              cardWidth: 84,
              cardHeight: 118,
              cards: const <_CardFace>[
                _CardFace(
                  rank: '9',
                  suit: Icons.favorite_rounded,
                  tone: presidentMuted,
                ),
              ],
            ),
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(top: 46, left: 8, right: 8),
              decoration: BoxDecoration(
                color: presidentSurfaceHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: presidentOutlineVariant.withValues(alpha: 0.4),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.trending_flat_rounded,
                color: presidentPrimary,
                size: 20,
              ),
            ),
            _PlayCluster(
              alignEnd: false,
              textCentered: true,
              label: 'Your Response',
              headline: 'Play higher or pass',
              highlight: true,
              clusterWidth: 104,
              stackHeight: 132,
              cardWidth: 84,
              cardHeight: 118,
              cards: const <_CardFace>[
                _CardFace(
                  rank: 'J',
                  suit: Icons.diamond_rounded,
                  tone: presidentPrimary,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: _PlayCluster(
            alignEnd: true,
            label: 'Current Play',
            headline: 'Single 9',
            clusterWidth: compact ? 122 : 168,
            stackHeight: compact ? 140 : 168,
            cardWidth: compact ? 88 : 112,
            cardHeight: compact ? 124 : 156,
            cards: const <_CardFace>[
              _CardFace(
                rank: '9',
                suit: Icons.favorite_rounded,
                tone: presidentMuted,
              ),
            ],
          ),
        ),
        Container(
          width: compact ? 44 : 72,
          height: compact ? 44 : 72,
          margin: EdgeInsets.symmetric(horizontal: compact ? 8 : 24),
          decoration: BoxDecoration(
            color: presidentSurfaceHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: presidentOutlineVariant.withValues(alpha: 0.4),
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.trending_flat_rounded,
            color: presidentPrimary,
            size: 24,
          ),
        ),
        Expanded(
          child: _PlayCluster(
            alignEnd: false,
            label: 'Your Response',
            headline: 'Play higher or pass',
            highlight: true,
            clusterWidth: compact ? 122 : 168,
            stackHeight: compact ? 140 : 168,
            cardWidth: compact ? 88 : 112,
            cardHeight: compact ? 124 : 156,
            cards: const <_CardFace>[
              _CardFace(
                rank: 'J',
                suit: Icons.diamond_rounded,
                tone: presidentPrimary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HierarchyLessonVisual extends StatelessWidget {
  const _HierarchyLessonVisual({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 28),
      decoration: BoxDecoration(
        color: presidentSurfaceContainer.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: presidentOutlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          _HierarchyLessonRow(
            rank: '01',
            role: 'President',
            points: '10 pts',
            iconAsset: 'assets/crown.svg',
            color: presidentPrimary,
            widthFactor: 1,
          ),
          SizedBox(height: 16),
          _HierarchyLessonRow(
            rank: '02',
            role: 'Vice President',
            points: '8 pts',
            iconAsset: 'assets/military_tech.svg',
            color: presidentSecondary,
            widthFactor: 0.76,
          ),
          SizedBox(height: 16),
          _HierarchyLessonRow(
            rank: '03',
            role: 'Citizen',
            points: '5 pts',
            iconAsset: 'assets/sentiment_content.svg',
            color: presidentTertiary,
            widthFactor: 0.52,
          ),
          SizedBox(height: 16),
          _HierarchyLessonRow(
            rank: '04',
            role: 'Vice Scum',
            points: '2 pts',
            iconAsset: 'assets/stat_minus_2.svg',
            color: Color(0xFFFFA36A),
            widthFactor: 0.28,
          ),
          SizedBox(height: 16),
          _HierarchyLessonRow(
            rank: '05',
            role: 'Scum',
            points: '1 pt',
            iconAsset: 'assets/skull.svg',
            color: presidentDanger,
            widthFactor: 0.12,
          ),
        ],
      ),
    );
  }
}

class _PairsLessonVisual extends StatelessWidget {
  const _PairsLessonVisual({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PlayCluster(
              alignEnd: false,
              textCentered: true,
              label: 'Current Play',
              headline: 'Pair of 8s',
              clusterWidth: 118,
              stackHeight: 146,
              cardWidth: 74,
              cardHeight: 104,
              overlap: 18,
              cards: const <_CardFace>[
                _CardFace(
                  rank: '8',
                  suit: Icons.diamond_rounded,
                  tone: presidentMuted,
                ),
                _CardFace(
                  rank: '8',
                  suit: Icons.change_history_rounded,
                  tone: presidentMuted,
                  tilt: 0.1,
                ),
              ],
            ),
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(top: 48, left: 8, right: 8),
              decoration: BoxDecoration(
                color: presidentSurfaceHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: presidentOutlineVariant.withValues(alpha: 0.4),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.trending_flat_rounded,
                color: presidentPrimary,
                size: 20,
              ),
            ),
            _PlayCluster(
              alignEnd: false,
              textCentered: true,
              label: 'Winning Response',
              headline: 'Pair of 10s',
              highlight: true,
              clusterWidth: 118,
              stackHeight: 146,
              cardWidth: 74,
              cardHeight: 104,
              overlap: 18,
              cards: const <_CardFace>[
                _CardFace(
                  rank: '10',
                  suit: Icons.favorite_rounded,
                  tone: presidentPrimary,
                ),
                _CardFace(
                  rank: '10',
                  suit: Icons.auto_awesome_motion_rounded,
                  tone: presidentPrimary,
                  tilt: -0.08,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: _PlayCluster(
            alignEnd: true,
            label: 'Current Play',
            headline: 'Pair of 8s',
            clusterWidth: compact ? 146 : 220,
            stackHeight: compact ? 154 : 220,
            cardWidth: compact ? 82 : 132,
            cardHeight: compact ? 116 : 190,
            overlap: compact ? 26 : 42,
            cards: const <_CardFace>[
              _CardFace(
                rank: '8',
                suit: Icons.diamond_rounded,
                tone: presidentMuted,
              ),
              _CardFace(
                rank: '8',
                suit: Icons.change_history_rounded,
                tone: presidentMuted,
                tilt: 0.1,
              ),
            ],
          ),
        ),
        Container(
          width: compact ? 44 : 72,
          height: compact ? 44 : 72,
          margin: EdgeInsets.symmetric(horizontal: compact ? 8 : 24),
          decoration: BoxDecoration(
            color: presidentSurfaceHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: presidentOutlineVariant.withValues(alpha: 0.4),
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.trending_flat_rounded,
            color: presidentPrimary,
            size: 24,
          ),
        ),
        Expanded(
          child: _PlayCluster(
            alignEnd: false,
            label: 'Winning Response',
            headline: 'Pair of 10s',
            highlight: true,
            clusterWidth: compact ? 146 : 220,
            stackHeight: compact ? 154 : 220,
            cardWidth: compact ? 82 : 132,
            cardHeight: compact ? 116 : 190,
            overlap: compact ? 26 : 42,
            cards: const <_CardFace>[
              _CardFace(
                rank: '10',
                suit: Icons.favorite_rounded,
                tone: presidentPrimary,
              ),
              _CardFace(
                rank: '10',
                suit: Icons.auto_awesome_motion_rounded,
                tone: presidentPrimary,
                tilt: -0.08,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PowerLevelsVisual extends StatelessWidget {
  const _PowerLevelsVisual({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _SingleCardShowcase(
                card: const _CardFace(
                  rank: '3',
                  suit: Icons.diamond_rounded,
                  tone: presidentText,
                ),
                label: 'Lowest',
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 22),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: presidentPrimary.withValues(alpha: 0.38),
                  size: compact ? 32 : 40,
                ),
              ),
              _SingleCardShowcase(
                card: const _CardFace(
                  rank: '2',
                  suit: Icons.backspace_rounded,
                  tone: presidentPrimary,
                ),
                label: 'Highest',
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: presidentSurfaceLow.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: presidentOutlineVariant.withValues(alpha: 0.28),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _OrderText('3', active: true),
                _OrderDivider(),
                _OrderText('4'),
                _OrderDivider(),
                _OrderText('5'),
                _OrderDivider(),
                _OrderText('...'),
                _OrderDivider(),
                _OrderText('A'),
                _OrderDivider(),
                _OrderText('2', highlight: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExchangeLessonVisual extends StatelessWidget {
  const _ExchangeLessonVisual({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget left = Center(
      child: _ExchangeSeat(
        title: 'President',
        subtitle: 'Receives strongest cards',
        color: presidentPrimary,
        iconAsset: 'assets/crown.svg',
        cards: const <_CardFace>[
          _CardFace(
            rank: 'A',
            suit: Icons.favorite_rounded,
            tone: presidentPrimary,
          ),
          _CardFace(
            rank: 'K',
            suit: Icons.diamond_rounded,
            tone: presidentPrimary,
            tilt: -0.08,
          ),
        ],
      ),
    );
    final Widget right = Center(
      child: _ExchangeSeat(
        title: 'Scum',
        subtitle: 'Sends strongest cards',
        color: presidentDanger,
        iconAsset: 'assets/skull.svg',
        cards: const <_CardFace>[
          _CardFace(
            rank: '4',
            suit: Icons.diamond_rounded,
            tone: presidentDanger,
          ),
          _CardFace(
            rank: '3',
            suit: Icons.change_history_rounded,
            tone: presidentDanger,
            tilt: 0.08,
          ),
        ],
      ),
    );

    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          left,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Icon(
              Icons.swap_vert_rounded,
              color: presidentPrimary,
              size: 40,
            ),
          ),
          right,
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: left),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Icon(
            Icons.swap_horiz_rounded,
            color: presidentPrimary,
            size: 42,
          ),
        ),
        Expanded(child: right),
      ],
    );
  }
}

class _JokerLessonVisual extends StatelessWidget {
  const _JokerLessonVisual({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final jokerCard = CardModel(
      id: 'tutorial-joker',
      suit: Suit.joker,
      rank: 16,
    );

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Icon(
          Icons.change_history_rounded,
          size: compact ? 260 : 440,
          color: presidentPrimary.withValues(alpha: 0.07),
        ),
        Container(
          padding: EdgeInsets.all(compact ? 10 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 34,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: PresidentCardFace(
            card: jokerCard,
            scale: compact ? 2.15 : 2.55,
          ),
        ),
      ],
    );
  }
}

class _TutorialFooter extends StatelessWidget {
  const _TutorialFooter({
    required this.currentIndex,
    required this.totalCount,
    required this.ctaLabel,
    required this.onBack,
    required this.onNext,
  });

  final int currentIndex;
  final int totalCount;
  final String ctaLabel;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool compact = width < 420;

    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 12 : 16, 16, 24),
      decoration: BoxDecoration(
        color: presidentSurfaceLowest.withValues(alpha: 0.92),
        border: const Border(
          top: BorderSide(color: presidentOutlineVariant, width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('BACK'),
                  style: TextButton.styleFrom(
                    foregroundColor: onBack == null
                        ? presidentOutline
                        : presidentMuted,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${currentIndex + 1} / $totalCount',
                  style: const TextStyle(
                    color: presidentMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _ProgressDots(
                      count: totalCount,
                      currentIndex: currentIndex,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFFFFF5E7), Color(0xFFFFD478)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextButton(
                        onPressed: onNext,
                        style: TextButton.styleFrom(
                          foregroundColor: presidentSurfaceLowest,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 14 : 20,
                            vertical: 14,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(ctaLabel.toUpperCase()),
                              const SizedBox(width: 8),
                              Icon(
                                currentIndex == totalCount - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StrategyCard extends StatelessWidget {
  const _StrategyCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: presidentSurfaceLow.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: presidentOutlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: presidentSurfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: presidentPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: presidentPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: presidentMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(count, (int index) {
        final bool active = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 30 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? presidentPrimary : presidentSurfaceHighest,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _HierarchyLessonRow extends StatelessWidget {
  const _HierarchyLessonRow({
    required this.rank,
    required this.role,
    required this.points,
    required this.iconAsset,
    required this.color,
    required this.widthFactor,
  });

  final String rank;
  final String role;
  final String points;
  final String iconAsset;
  final Color color;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          rank,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.4,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: presidentSurfaceLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            role,
                            style: TextStyle(
                              color: color,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            points.toUpperCase(),
                            style: TextStyle(
                              color: color.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SvgPicture.asset(
                      iconAsset,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widthFactor,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayCluster extends StatelessWidget {
  const _PlayCluster({
    required this.label,
    required this.headline,
    required this.cards,
    required this.alignEnd,
    this.highlight = false,
    this.textCentered = false,
    this.clusterWidth = 280,
    this.stackHeight = 220,
    this.cardWidth = 132,
    this.cardHeight = 190,
    this.overlap = 42,
  });

  final String label;
  final String headline;
  final List<_CardFace> cards;
  final bool alignEnd;
  final bool highlight;
  final bool textCentered;
  final double clusterWidth;
  final double stackHeight;
  final double cardWidth;
  final double cardHeight;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : (textCentered
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start),
      children: <Widget>[
        SizedBox(
          width: clusterWidth,
          height: stackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: List<Widget>.generate(cards.length, (int index) {
              return Positioned(
                left: overlap * index,
                top: index.isOdd ? 10 : 0,
                child: Transform.rotate(
                  angle: cards[index].tilt,
                  child: _TutorialCard(
                    rank: cards[index].rank,
                    icon: cards[index].suit,
                    tone: cards[index].tone,
                    width: cardWidth,
                    height: cardHeight,
                    highlight: highlight,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label.toUpperCase(),
          textAlign: textCentered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: highlight ? presidentPrimary : presidentMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          headline,
          textAlign: textCentered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: highlight ? presidentPrimary : presidentOutline,
            fontSize: textCentered ? 18 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            fontStyle: highlight ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _SingleCardShowcase extends StatelessWidget {
  const _SingleCardShowcase({
    required this.card,
    required this.label,
    this.highlight = false,
  });

  final _CardFace card;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _TutorialCard(
          rank: card.rank,
          icon: card.suit,
          tone: card.tone,
          width: 144,
          height: 208,
          highlight: highlight,
        ),
        const SizedBox(height: 12),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: highlight ? presidentPrimary : presidentMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

class _ExchangeSeat extends StatelessWidget {
  const _ExchangeSeat({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconAsset,
    required this.cards,
  });

  final String title;
  final String subtitle;
  final Color color;
  final String iconAsset;
  final List<_CardFace> cards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: presidentSurfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: presidentOutlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  iconAsset,
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: presidentMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 230,
            height: 140,
            child: Stack(
              clipBehavior: Clip.none,
              children: List<Widget>.generate(cards.length, (int index) {
                return Positioned(
                  left: 50.0 * index,
                  child: Transform.rotate(
                    angle: cards[index].tilt,
                    child: _TutorialCard(
                      rank: cards[index].rank,
                      icon: cards[index].suit,
                      tone: cards[index].tone,
                      width: 110,
                      height: 140,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderText extends StatelessWidget {
  const _OrderText(this.text, {this.active = false, this.highlight = false});

  final String text;
  final bool active;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: highlight
            ? presidentPrimary
            : (active ? presidentText : presidentMuted),
        fontSize: highlight ? 24 : 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    );
  }
}

class _OrderDivider extends StatelessWidget {
  const _OrderDivider();

  @override
  Widget build(BuildContext context) {
    return Text(
      '<',
      style: TextStyle(
        color: presidentMuted.withValues(alpha: 0.28),
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({
    required this.rank,
    required this.icon,
    required this.tone,
    required this.width,
    required this.height,
    this.highlight = false,
  });

  final String rank;
  final IconData icon;
  final Color tone;
  final double width;
  final double height;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final card = _tutorialCardModel(rank, icon);
    final face = PresidentCardFace(card: card, scale: width / kCardSize.width);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          if (highlight)
            BoxShadow(
              color: presidentPrimary.withValues(alpha: 0.18),
              blurRadius: 34,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: face),
          if (highlight)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: presidentPrimary.withValues(alpha: 0.22),
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

CardModel _tutorialCardModel(String rankLabel, IconData icon) {
  final suit = switch (icon) {
    Icons.favorite_rounded => Suit.hearts,
    Icons.diamond_rounded => Suit.diamonds,
    Icons.auto_awesome_motion_rounded => Suit.clubs,
    Icons.change_history_rounded => Suit.spades,
    Icons.backspace_rounded => Suit.spades,
    _ => Suit.spades,
  };

  final rank = switch (rankLabel) {
    'J' => 11,
    'Q' => 12,
    'K' => 13,
    'A' => 14,
    '2' => 15,
    _ => int.tryParse(rankLabel) ?? 3,
  };

  return CardModel(
    id: 'tutorial-$rankLabel-${icon.codePoint}',
    suit: suit,
    rank: rank,
  );
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, this.secondary = false});

  final double size;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (secondary ? presidentDangerContainer : presidentPrimary)
              .withValues(alpha: secondary ? 0.1 : 0.06),
        ),
      ),
    );
  }
}

class _TutorialLesson {
  const _TutorialLesson({
    required this.title,
    required this.description,
    required this.strategyTitle,
    required this.strategyBody,
    required this.ctaLabel,
    required this.visual,
  });

  final String title;
  final String description;
  final String strategyTitle;
  final String strategyBody;
  final String ctaLabel;
  final _LessonVisual visual;
}

class _CardFace {
  const _CardFace({
    required this.rank,
    required this.suit,
    required this.tone,
    this.tilt = 0,
  });

  final String rank;
  final IconData suit;
  final Color tone;
  final double tilt;
}

enum _LessonVisual { goal, hierarchy, powerLevels, pairs, exchange, joker }
