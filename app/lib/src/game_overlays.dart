import 'package:flutter/material.dart';

import 'card_asset.dart';
import 'models.dart';
import 'president_theme.dart';

enum ExchangeDirection { sendWorst, sendBest, none }

class MatchResultsViewData {
  const MatchResultsViewData({
    required this.entries,
    required this.viewer,
    required this.shifts,
  });

  final List<PublicPlayerStateModel> entries;
  final PublicPlayerStateModel viewer;
  final List<PowerShiftViewData> shifts;
}

class PowerShiftViewData {
  const PowerShiftViewData({
    required this.left,
    required this.right,
    required this.label,
    required this.detail,
  });

  final PublicPlayerStateModel left;
  final PublicPlayerStateModel right;
  final String label;
  final String detail;
}

class ExchangeViewData {
  const ExchangeViewData({
    required this.viewer,
    required this.counterpart,
    required this.role,
    required this.counterpartRole,
    required this.requiredCount,
    required this.direction,
  });

  final PublicPlayerStateModel viewer;
  final PublicPlayerStateModel counterpart;
  final String role;
  final String counterpartRole;
  final int requiredCount;
  final ExchangeDirection direction;

  bool get required => direction != ExchangeDirection.none && requiredCount > 0;

  String get instruction {
    if (direction == ExchangeDirection.sendWorst) {
      return 'Select your $requiredCount weakest cards';
    }
    if (direction == ExchangeDirection.sendBest) {
      return 'Select your $requiredCount strongest cards';
    }
    return 'No exchange required';
  }
}

MatchResultsViewData buildMatchResultsViewData(PublicGameStateModel state) {
  final ordered = [...state.players]
    ..sort((left, right) {
      final leftRank = left.finishingPosition ?? 999;
      final rightRank = right.finishingPosition ?? 999;
      return leftRank.compareTo(rightRank);
    });

  final viewer = state.viewer;
  final shifts = <PowerShiftViewData>[];
  final president = _firstWhereOrNull(
    ordered,
    (entry) => entry.finishingPosition == 1,
  );
  final vice = _firstWhereOrNull(
    ordered,
    (entry) => entry.finishingPosition == 2,
  );
  final viceScum = _firstWhereOrNull(
    ordered,
    (entry) => entry.finishingPosition == state.players.length - 1,
  );
  final scum = _firstWhereOrNull(
    ordered,
    (entry) => entry.finishingPosition == state.players.length,
  );

  if (president != null && scum != null) {
    shifts.add(
      PowerShiftViewData(
        left: president,
        right: scum,
        label: 'PRES ↔ SCUM',
        detail: '2 Best Cards',
      ),
    );
  }

  if (vice != null && viceScum != null && vice.id != viceScum.id) {
    shifts.add(
      PowerShiftViewData(
        left: vice,
        right: viceScum,
        label: 'VICE ↔ V. SCUM',
        detail: '1 Best Card',
      ),
    );
  }

  return MatchResultsViewData(entries: ordered, viewer: viewer, shifts: shifts);
}

ExchangeViewData? buildExchangeViewData(PublicGameStateModel state) {
  final viewer = state.viewer;
  final role = roleLabel(viewer, state.players.length);
  final president = _firstWhereOrNull(
    state.players,
    (entry) => entry.finishingPosition == 1,
  );
  final vice = _firstWhereOrNull(
    state.players,
    (entry) => entry.finishingPosition == 2,
  );
  final viceScum = _firstWhereOrNull(
    state.players,
    (entry) => entry.finishingPosition == state.players.length - 1,
  );
  final scum = _firstWhereOrNull(
    state.players,
    (entry) => entry.finishingPosition == state.players.length,
  );

  return switch (role) {
    'President' when scum != null => ExchangeViewData(
      viewer: viewer,
      counterpart: scum,
      role: role,
      counterpartRole: roleLabel(scum, state.players.length),
      requiredCount: 2,
      direction: ExchangeDirection.sendWorst,
    ),
    'Vice' when viceScum != null && viceScum.id != viewer.id =>
      ExchangeViewData(
        viewer: viewer,
        counterpart: viceScum,
        role: role,
        counterpartRole: roleLabel(viceScum, state.players.length),
        requiredCount: 1,
        direction: ExchangeDirection.sendWorst,
      ),
    'Scum' when president != null => ExchangeViewData(
      viewer: viewer,
      counterpart: president,
      role: role,
      counterpartRole: roleLabel(president, state.players.length),
      requiredCount: 2,
      direction: ExchangeDirection.sendBest,
    ),
    'Vice Scum' when vice != null => ExchangeViewData(
      viewer: viewer,
      counterpart: vice,
      role: role,
      counterpartRole: roleLabel(vice, state.players.length),
      requiredCount: 1,
      direction: ExchangeDirection.sendBest,
    ),
    _ => null,
  };
}

class ResultsOverlay extends StatelessWidget {
  const ResultsOverlay({
    super.key,
    required this.data,
    required this.onContinue,
    required this.onClose,
  });

  final MatchResultsViewData data;
  final VoidCallback onContinue;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _OverlayShell(
      child: Column(
        children: [
          _OverlayHeader(
            eyebrow: 'Session Results',
            title: 'The Hierarchy',
            onClose: onClose,
          ),
          const SizedBox(height: 16),
          ...data.entries.map(
            (player) => _ResultRow(
              player: player,
              totalPlayers: data.entries.length,
              isViewer: player.id == data.viewer.id,
            ),
          ),
          if (data.shifts.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PowerShiftSection(shifts: data.shifts),
          ],
          const SizedBox(height: 20),
          _ActionPillButton(
            label: 'CONTINUE TO EXCHANGE',
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class ExchangeOverlay extends StatelessWidget {
  const ExchangeOverlay({
    super.key,
    required this.data,
    required this.hand,
    required this.selectedCards,
    required this.onToggleCard,
    required this.onConfirm,
    required this.onLeave,
  });

  final ExchangeViewData data;
  final List<CardModel> hand;
  final List<CardModel> selectedCards;
  final ValueChanged<CardModel> onToggleCard;
  final VoidCallback onConfirm;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final selectedIds = selectedCards.map((card) => card.id).toSet();
    final availableCards = hand
        .where((card) => !selectedIds.contains(card.id))
        .toList();

    return _OverlayShell(
      child: Column(
        children: [
          _OverlayHeader(eyebrow: null, title: 'POWER SHIFT', onClose: onLeave),
          Text(
            data.instruction,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: presidentMuted),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ExchangePlayerChip(player: data.viewer, role: data.role),
              const Icon(Icons.swap_horiz_rounded, color: presidentPrimary),
              _ExchangePlayerChip(
                player: data.counterpart,
                role: data.counterpartRole,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(data.requiredCount, (index) {
              final card = index < selectedCards.length
                  ? selectedCards[index]
                  : null;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: card == null ? null : () => onToggleCard(card),
                  child: Container(
                    width: 84,
                    height: 116,
                    decoration: BoxDecoration(
                      color: presidentSurfaceLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: card == null
                            ? presidentOutlineVariant
                            : presidentPrimary,
                        width: 1.5,
                      ),
                    ),
                    child: card == null
                        ? const Center(
                            child: Icon(
                              Icons.add_rounded,
                              color: presidentOutline,
                              size: 30,
                            ),
                          )
                        : Center(child: _FlutterCard(card: card, scale: 1.06)),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'YOUR ASSETS',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(letterSpacing: 1.6),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 126,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: availableCards.length,
              itemBuilder: (context, index) {
                final card = availableCards[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: selectedCards.length >= data.requiredCount
                        ? null
                        : () => onToggleCard(card),
                    child: _FlutterCard(card: card),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _ActionPillButton(
            label: 'CONFIRM EXCHANGE',
            onPressed: selectedCards.length == data.requiredCount
                ? onConfirm
                : null,
            icon: Icons.swap_horiz_rounded,
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: onLeave,
            child: const Text(
              'LEAVE GAME',
              style: TextStyle(
                color: presidentMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

PublicPlayerStateModel? _firstWhereOrNull(
  Iterable<PublicPlayerStateModel> players,
  bool Function(PublicPlayerStateModel player) predicate,
) {
  for (final player in players) {
    if (predicate(player)) {
      return player;
    }
  }
  return null;
}

class _OverlayShell extends StatelessWidget {
  const _OverlayShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                color: presidentSurfaceContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: presidentPrimary.withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: presidentSurfaceLowest.withValues(alpha: 0.45),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayHeader extends StatelessWidget {
  const _OverlayHeader({
    required this.eyebrow,
    required this.title,
    required this.onClose,
  });

  final String? eyebrow;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Spacer(),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: presidentMuted),
            ),
          ],
        ),
        if (eyebrow != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: presidentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              eyebrow!.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: presidentPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: presidentText,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.player,
    required this.totalPlayers,
    required this.isViewer,
  });

  final PublicPlayerStateModel player;
  final int totalPlayers;
  final bool isViewer;

  @override
  Widget build(BuildContext context) {
    final role = roleLabel(player, totalPlayers);
    final rank = player.finishingPosition ?? totalPlayers;
    final accent = switch (role) {
      'President' => presidentPrimary,
      'Vice' => presidentSecondary,
      'Vice Scum' => presidentTertiary,
      'Scum' => presidentDanger,
      _ => presidentText,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isViewer ? presidentSurfaceHigh : presidentSurfaceLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isViewer
              ? presidentPrimary.withValues(alpha: 0.35)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            rank.toString().padLeft(2, '0'),
            style: TextStyle(
              color: accent.withValues(alpha: 0.28),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(
                int.parse(
                  'FF${player.avatarColor.replaceFirst('#', '')}',
                  radix: 16,
                ),
              ),
              border: Border.all(color: accent, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              player.name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: presidentText,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (isViewer) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: presidentPrimary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 8,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
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

class _PowerShiftSection extends StatelessWidget {
  const _PowerShiftSection({required this.shifts});

  final List<PowerShiftViewData> shifts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: presidentSurfaceHigh.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: presidentOutlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'THE POWER SHIFT',
                style: TextStyle(
                  color: presidentMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              Spacer(),
              Icon(Icons.swap_horiz_rounded, color: presidentPrimary, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final shift in shifts)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: presidentSurfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 70,
                            height: 34,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  left: 10,
                                  child: _MiniAvatar(
                                    player: shift.left,
                                    borderColor: presidentPrimary,
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  child: _MiniAvatar(
                                    player: shift.right,
                                    borderColor: presidentTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            shift.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: presidentText,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shift.detail,
                            style: const TextStyle(
                              color: presidentMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExchangePlayerChip extends StatelessWidget {
  const _ExchangePlayerChip({required this.player, required this.role});

  final PublicPlayerStateModel player;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: presidentSurfaceHigh,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            role.toUpperCase(),
            style: const TextStyle(
              color: presidentText,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(
              int.parse(
                'FF${player.avatarColor.replaceFirst('#', '')}',
                radix: 16,
              ),
            ),
            border: Border.all(color: presidentOutlineVariant),
          ),
          alignment: Alignment.center,
          child: Text(
            player.name.characters.first.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 84,
          child: Text(
            player.name,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              color: presidentText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.chevron_right_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: presidentPrimary,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.7,
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 22),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.player, required this.borderColor});

  final PublicPlayerStateModel player;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(
          int.parse('FF${player.avatarColor.replaceFirst('#', '')}', radix: 16),
        ),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      alignment: Alignment.center,
      child: Text(
        player.name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FlutterCard extends StatelessWidget {
  const _FlutterCard({required this.card, this.scale = 1});

  final CardModel card;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return PresidentCardFace(card: card, scale: scale);
  }
}
