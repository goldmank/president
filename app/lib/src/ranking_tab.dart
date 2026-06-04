import 'dart:async';

import 'package:flutter/material.dart';

import 'president_theme.dart';
import 'ranked_api.dart';
import 'ranked_models.dart';

class RankingTab extends StatefulWidget {
  const RankingTab({super.key, this.currentUserId, required this.refreshToken});

  final String? currentUserId;
  final int refreshToken;

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  final RankedApi _api = RankedApi();

  LeaderboardWindowRange _selectedWindow = LeaderboardWindowRange.allTime;
  LeaderboardSnapshotModel? _snapshot;
  bool _loading = true;
  String? _error;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  @override
  void didUpdateWidget(covariant RankingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUserId != widget.currentUserId ||
        oldWidget.refreshToken != widget.refreshToken) {
      _loadLeaderboard();
    }
  }

  Future<void> _loadLeaderboard() async {
    final requestSerial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await _api.getLeaderboard(
        window: _selectedWindow,
        userId: widget.currentUserId,
      );
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _selectWindow(LeaderboardWindowRange window) {
    if (_selectedWindow == window) {
      return;
    }
    setState(() {
      _selectedWindow = window;
    });
    _loadLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Leaderboard',
          style: TextStyle(
            color: presidentText,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 18),
        _LeaderboardPanel(
          selectedWindow: _selectedWindow,
          onWindowSelected: _selectWindow,
          child: _buildLeaderboardContent(snapshot),
        ),
        const SizedBox(height: 18),
        _ViewerStandingCard(
          currentUserId: widget.currentUserId,
          snapshot: snapshot,
          selectedWindow: _selectedWindow,
        ),
        const SizedBox(height: 18),
        const _RankingGuideCard(),
      ],
    );
  }

  Widget _buildLeaderboardContent(LeaderboardSnapshotModel? snapshot) {
    if (_loading) {
      return const _RankingLoadingState();
    }
    if (_error != null) {
      return _RankingErrorState(
        message: _error!,
        onRetry: () {
          unawaited(_loadLeaderboard());
        },
      );
    }
    if (snapshot == null) {
      return _RankingErrorState(
        message: 'Leaderboard data is unavailable right now.',
        onRetry: () {
          unawaited(_loadLeaderboard());
        },
      );
    }
    if (snapshot.entries.isEmpty) {
      return _LeaderboardEmptyState(window: snapshot.window);
    }
    return _LeaderboardList(
      entries: snapshot.entries,
      currentUserId: widget.currentUserId,
    );
  }
}

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({
    required this.selectedWindow,
    required this.onWindowSelected,
    required this.child,
  });

  final LeaderboardWindowRange selectedWindow;
  final ValueChanged<LeaderboardWindowRange> onWindowSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: presidentSurfaceContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: LeaderboardWindowRange.values.map((window) {
                final selected = window == selectedWindow;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _LeaderboardWindowButton(
                      label: window.label,
                      selected: selected,
                      onTap: () => onWindowSelected(window),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: presidentOutlineVariant.withValues(alpha: 0.5),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

class _LeaderboardWindowButton extends StatelessWidget {
  const _LeaderboardWindowButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? presidentPrimary : presidentSurfaceHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? presidentPrimary : presidentOutlineVariant,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.black : presidentText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingLoadingState extends StatelessWidget {
  const _RankingLoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 280,
      child: Center(child: CircularProgressIndicator(color: presidentPrimary)),
    );
  }
}

class _RankingErrorState extends StatelessWidget {
  const _RankingErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.wifi_off_rounded,
              size: 34,
              color: presidentDanger.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: presidentDanger,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: presidentPrimary,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerStandingCard extends StatelessWidget {
  const _ViewerStandingCard({
    required this.currentUserId,
    required this.snapshot,
    required this.selectedWindow,
  });

  final String? currentUserId;
  final LeaderboardSnapshotModel? snapshot;
  final LeaderboardWindowRange selectedWindow;

  @override
  Widget build(BuildContext context) {
    final standing = snapshot?.viewerEntry;
    final hasStanding = standing != null;
    final positionLabel = hasStanding ? '#${standing.position}' : '--';
    final scoreLabel = hasStanding ? '${standing.score} pts' : '0 pts';
    final gamesLabel = hasStanding ? '${standing.gamesPlayed} games' : '--';
    final statusLabel = switch ((currentUserId, hasStanding)) {
      (null, _) => 'Guest',
      (_, true) => selectedWindow.label,
      _ => 'Unranked',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: presidentSurfaceLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: presidentOutlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  statusLabel.toUpperCase(),
                  style: const TextStyle(
                    color: presidentPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your Position',
                  style: TextStyle(
                    color: presidentText,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasStanding && !standing.inTopResults
                      ? 'Outside the visible top ${snapshot?.limit ?? 50}'
                      : gamesLabel,
                  style: const TextStyle(
                    color: presidentMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                positionLabel,
                style: const TextStyle(
                  color: presidentPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                scoreLabel,
                style: const TextStyle(
                  color: presidentText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardEmptyState extends StatelessWidget {
  const _LeaderboardEmptyState({required this.window});

  final LeaderboardWindowRange window;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.emoji_events_outlined,
              size: 42,
              color: presidentOutline.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 14),
            Text(
              'No ${window.label.toLowerCase()} leaders yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: presidentText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Finished registered games will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: presidentMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.entries, required this.currentUserId});

  final List<LeaderboardEntryModel> entries;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final entry = entries[index];
        final isCurrentUser = entry.userId == currentUserId;
        return _LeaderboardRow(entry: entry, highlighted: isCurrentUser);
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.highlighted});

  final LeaderboardEntryModel entry;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF342C07) : presidentSurfaceHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? presidentPrimary : Colors.transparent,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Text(
              '#${entry.position}',
              style: TextStyle(
                color: highlighted ? presidentPrimary : presidentMuted,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: presidentText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.gamesPlayed} games',
                  style: const TextStyle(
                    color: presidentMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${entry.score}',
            style: TextStyle(
              color: highlighted ? presidentPrimary : presidentText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingGuideCard extends StatelessWidget {
  const _RankingGuideCard();

  @override
  Widget build(BuildContext context) {
    const pointRows = <({String role, int points, Color color})>[
      (role: 'President', points: 10, color: presidentPrimary),
      (role: 'Vice President', points: 8, color: presidentSecondary),
      (role: 'Citizen', points: 5, color: presidentMuted),
      (role: 'Vice Scum', points: 2, color: presidentTertiary),
      (role: 'Scum', points: 1, color: presidentDanger),
    ];

    return Container(
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
            'Ranking Guide',
            style: TextStyle(
              color: presidentText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Every finished game adds score based on your final role. Daily and weekly leaderboards reset automatically. All time never resets.',
            style: TextStyle(
              color: presidentMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (final row in pointRows) ...<Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: row.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.role,
                    style: const TextStyle(
                      color: presidentText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${row.points} pts',
                  style: const TextStyle(
                    color: presidentPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (row != pointRows.last) const SizedBox(height: 14),
          ],
          const SizedBox(height: 16),
          const Text(
            'Guest matches stay local and never enter the server leaderboard.',
            style: TextStyle(
              color: presidentMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
