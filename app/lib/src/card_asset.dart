import 'package:flutter/material.dart';

import 'models.dart';
import 'president_theme.dart';

const Size kCardSize = Size(72, 102);

class PresidentCardFace extends StatelessWidget {
  const PresidentCardFace({super.key, required this.card, this.scale = 1});

  final CardModel card;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (card.suit == Suit.joker || card.rank == 16) {
      return JokerCardFace(scale: scale);
    }

    final width = kCardSize.width * scale;
    final height = kCardSize.height * scale;
    final radius = 9.0 * scale;
    final pipColor = _pipColor(card.suit);
    final rank = rankLabel(card.rank);

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5EE),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: presidentSurfaceHighest.withValues(alpha: 0.8),
            width: 1.15 * scale,
          ),
          boxShadow: [
            BoxShadow(
              color: presidentSurfaceLowest.withValues(alpha: 0.12),
              blurRadius: 12 * scale,
              offset: Offset(0, 6 * scale),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.96),
                      const Color(0xFFF2ECE0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(3.5 * scale),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6.5 * scale),
                    border: Border.all(
                      color: pipColor.withValues(alpha: 0.18),
                      width: 0.75 * scale,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 6 * scale,
              top: 8 * scale,
              child: _CornerMark(
                rank: rank,
                color: pipColor,
                scale: scale,
              ),
            ),
            Positioned(
              right: 6 * scale,
              bottom: 8 * scale,
              child: RotatedBox(
                quarterTurns: 2,
                child: _CornerMark(
                  rank: rank,
                  color: pipColor,
                  scale: scale,
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 11 * scale,
                  vertical: 14 * scale,
                ),
                child: _CenterArtwork(card: card, scale: scale, color: pipColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JokerCardFace extends StatelessWidget {
  const JokerCardFace({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final width = kCardSize.width * scale;
    final height = kCardSize.height * scale;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: presidentSurfaceLow,
        borderRadius: BorderRadius.circular(9 * scale),
        border: Border.all(color: presidentPrimaryDark, width: 1.4 * scale),
        boxShadow: [
          BoxShadow(
            color: presidentSurfaceLowest.withValues(alpha: 0.28),
            blurRadius: 14 * scale,
            offset: Offset(0, 8 * scale),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 6 * scale,
            top: 6 * scale,
            child: Text(
              'JKR',
              style: TextStyle(
                color: presidentPrimary,
                fontSize: 9 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 34 * scale,
              height: 34 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: presidentPrimary.withValues(alpha: 0.08),
                border: Border.all(
                  color: presidentPrimary.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                Icons.star_rounded,
                color: presidentPrimary,
                size: 22 * scale,
              ),
            ),
          ),
          Positioned(
            right: 6 * scale,
            bottom: 6 * scale,
            child: RotatedBox(
              quarterTurns: 2,
              child: Text(
                'JKR',
                style: TextStyle(
                  color: presidentPrimary,
                  fontSize: 9 * scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerMark extends StatelessWidget {
  const _CornerMark({
    required this.rank,
    required this.color,
    required this.scale,
  });

  final String rank;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16 * scale,
      child: Text(
        rank,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          height: 0.95,
          fontSize: rank.length > 1 ? 8.6 * scale : 10.5 * scale,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CenterArtwork extends StatelessWidget {
  const _CenterArtwork({
    required this.card,
    required this.scale,
    required this.color,
  });

  final CardModel card;
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _suitSymbol(card.suit),
        style: TextStyle(
          color: color,
          fontSize: 30 * scale,
          fontWeight: FontWeight.w700,
          height: 0.9,
        ),
      ),
    );
  }
}

Color _pipColor(Suit suit) {
  return switch (suit) {
    Suit.hearts => const Color(0xFFB03A2E),
    Suit.diamonds => const Color(0xFFC0392B),
    Suit.clubs => const Color(0xFF202326),
    Suit.spades => const Color(0xFF15181B),
    Suit.joker => presidentPrimary,
  };
}

String _suitSymbol(Suit suit) {
  return switch (suit) {
    Suit.clubs => '♣',
    Suit.diamonds => '♦',
    Suit.hearts => '♥',
    Suit.spades => '♠',
    Suit.joker => '★',
  };
}
