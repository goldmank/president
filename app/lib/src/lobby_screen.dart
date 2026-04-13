import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'game_screen.dart';
import 'president_theme.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTab = 0;
  int _debugScoreBonus = 0;

  final _GuestProfile _profile = const _GuestProfile(
    name: 'Guest',
    gamesPlayed: 0,
    roleHistory: <String>[],
  );

  @override
  Widget build(BuildContext context) {
    final score =
        _profile.roleHistory.fold<int>(
          0,
          (sum, role) => sum + _rolePoints(role),
        ) +
        _debugScoreBonus;
    final rank = _rankForScore(score);

    return Scaffold(
      key: _scaffoldKey,
      drawer: _LobbyDrawer(
        debugScoreBonus: _debugScoreBonus,
        onAddScore: _adjustDebugScore,
        onResetScore: _resetDebugScore,
      ),
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
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Expanded(
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _TopBar(
                              onMenuPressed: () {
                                _scaffoldKey.currentState?.openDrawer();
                              },
                            ),
                            const SizedBox(height: 18),
                            _ProfilePanel(
                              profile: _profile,
                              score: score,
                              rank: rank,
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: switch (_selectedTab) {
                                0 => _LobbyTab(
                                  key: const ValueKey<String>('lobby'),
                                  onStartPractice: _openBotGame,
                                  onSignUp: _showSignUpPlaceholder,
                                ),
                                1 => _RankingTab(
                                  key: const ValueKey<String>('ranking'),
                                  score: score,
                                  rank: rank,
                                ),
                                _ => _AchievementsTab(
                                  key: const ValueKey<String>('achievements'),
                                ),
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _BottomTabs(
                selectedIndex: _selectedTab,
                onSelected: (int index) {
                  setState(() {
                    _selectedTab = index;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBotGame() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const GameScreen(),
      ),
    );
  }

  void _showSignUpPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign up flow is not wired yet.')),
    );
  }

  void _adjustDebugScore(int amount) {
    Navigator.of(context).maybePop();
    setState(() {
      _debugScoreBonus += amount;
    });
  }

  void _resetDebugScore() {
    Navigator.of(context).maybePop();
    setState(() {
      _debugScoreBonus = 0;
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onMenuPressed});

  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: onMenuPressed,
          icon: const Icon(Icons.menu_rounded, color: presidentPrimary),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'THE TABLE',
            style: TextStyle(
              color: presidentPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
        ),
        const _ProfileAvatar(size: 48),
      ],
    );
  }
}

class _LobbyDrawer extends StatelessWidget {
  const _LobbyDrawer({
    required this.debugScoreBonus,
    required this.onAddScore,
    required this.onResetScore,
  });

  final int debugScoreBonus;
  final ValueChanged<int> onAddScore;
  final VoidCallback onResetScore;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: presidentSurfaceLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Text(
                    'THE TABLE',
                    style: TextStyle(
                      color: presidentPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.9,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Menu',
                    style: TextStyle(
                      color: presidentMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: presidentOutlineVariant, height: 1),
            if (kDebugMode) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Text(
                  'DEBUG SCORE (${debugScoreBonus >= 0 ? '+' : ''}$debugScoreBonus)',
                  style: const TextStyle(
                    color: presidentPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              _DrawerAction(
                icon: Icons.exposure_plus_1_rounded,
                label: 'Add 1 Point',
                onTap: () => onAddScore(1),
              ),
              _DrawerAction(
                icon: Icons.add_rounded,
                label: 'Add 10 Points',
                onTap: () => onAddScore(10),
              ),
              _DrawerAction(
                icon: Icons.add_chart_rounded,
                label: 'Add 25 Points',
                onTap: () => onAddScore(25),
              ),
              _DrawerAction(
                icon: Icons.trending_up_rounded,
                label: 'Add 50 Points',
                onTap: () => onAddScore(50),
              ),
              _DrawerAction(
                icon: Icons.restart_alt_rounded,
                label: 'Reset Debug Score',
                onTap: onResetScore,
              ),
            ],
            if (!kDebugMode)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No menu items available.',
                  style: TextStyle(
                    color: presidentMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerAction extends StatelessWidget {
  const _DrawerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: presidentPrimary),
      title: Text(
        label,
        style: const TextStyle(
          color: presidentText,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.profile,
    required this.score,
    required this.rank,
  });

  final _GuestProfile profile;
  final int score;
  final _RankProgress rank;

  @override
  Widget build(BuildContext context) {
    final progress = rank.goal <= 0 ? 0.0 : (score / rank.goal).clamp(0.0, 1.0);
    final presidentGames = profile.roleHistory
        .where((String role) => role == 'President')
        .length;
    final scumGames = profile.roleHistory
        .where((String role) => role == 'Scum')
        .length;

    return Container(
      decoration: BoxDecoration(
        color: presidentSurfaceLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: 8,
            top: 4,
            child: SvgPicture.asset(
              'assets/crown.svg',
              width: 140,
              height: 140,
              colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.05),
                BlendMode.srcIn,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.name.toUpperCase(),
                  style: const TextStyle(
                    color: presidentText,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rank.name.toUpperCase(),
                  style: const TextStyle(
                    color: presidentPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 0),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$score / ${rank.goal}',
                    style: const TextStyle(
                      color: presidentText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    backgroundColor: presidentBackground,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFE16D),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _GamesPlayedPanel(gamesPlayed: profile.gamesPlayed),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CompactStatPanel(
                        label: 'PRESIDENT GAMES',
                        value: '$presidentGames',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CompactStatPanel(
                        label: 'SCUM GAMES',
                        value: '$scumGames',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyTab extends StatelessWidget {
  const _LobbyTab({
    super.key,
    required this.onStartPractice,
    required this.onSignUp,
  });

  final VoidCallback onStartPractice;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _HeroCard(
          title: 'Solo Table',
          body:
              'Start a quick match against AI players and practice reading the table before you jump into ranked rooms.',
          buttonLabel: 'PLAY',
          icon: Icons.smart_toy_rounded,
          buttonIcon: Icons.play_arrow_rounded,
          accent: presidentText,
          background: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF2A2C2F), presidentSurfaceContainer],
          ),
          onPressed: onStartPractice,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: presidentSurfaceLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: presidentOutlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Quick Room Join',
                style: TextStyle(
                  color: presidentMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: 'Enter room code',
                        hintStyle: const TextStyle(color: presidentOutline),
                        filled: true,
                        fillColor: presidentSurfaceHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: presidentSurfaceHighest,
                      foregroundColor: presidentMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'JOIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Room codes and multiplayer become available after sign up.',
                style: TextStyle(
                  color: presidentMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _HeroCard(
          title: 'Ranked Lobbies',
          body:
              'Requires an account. Track rating, play real opponents, and carry your profile across devices.',
          buttonLabel: 'SIGN UP TO UNLOCK',
          icon: Icons.groups_rounded,
          buttonIcon: Icons.lock_open_rounded,
          accent: presidentPrimary,
          background: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF342C07), Color(0xFF1D1A10)],
          ),
          onPressed: onSignUp,
        ),
      ],
    );
  }
}

class _RankingTab extends StatelessWidget {
  const _RankingTab({super.key, required this.score, required this.rank});

  final int score;
  final _RankProgress rank;

  @override
  Widget build(BuildContext context) {
    const pointRows = <({String role, int points, Color color})>[
      (role: 'President', points: 10, color: presidentPrimary),
      (role: 'Vice President', points: 8, color: presidentSecondary),
      (role: 'Citizen', points: 5, color: presidentMuted),
      (role: 'Vice Scum', points: 2, color: presidentTertiary),
      (role: 'Scum', points: 1, color: presidentDanger),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Ranking',
          style: TextStyle(
            color: presidentText,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your current score is $score. Guest mode does not persist rating yet, but the full progression model is defined below.',
          style: const TextStyle(
            color: presidentMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: presidentSurfaceContainer,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: <Widget>[
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
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: presidentSurfaceLow,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Current Tier: ${rank.name}',
                style: const TextStyle(
                  color: presidentText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rank thresholds scale by +5 points each step: 10, 25, 45, 70, 100, and so on.',
                style: const TextStyle(
                  color: presidentMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        Text(
          'Achievements',
          style: TextStyle(
            color: presidentText,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(height: 10),
        _AchievementTile(
          title: 'First Presidency',
          description:
              'Finish a game in 1st place and claim the President role.',
          locked: true,
        ),
        SizedBox(height: 12),
        _AchievementTile(
          title: 'Consistent Citizen',
          description:
              'Finish three consecutive games without landing in scum roles.',
          locked: true,
        ),
        SizedBox(height: 12),
        _AchievementTile(
          title: 'Executive Network',
          description: 'Sign up and play your first ranked multiplayer room.',
          locked: true,
        ),
      ],
    );
  }
}

class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = <({IconData icon, String label})>[
      (icon: Icons.casino_rounded, label: 'Lobby'),
      (icon: Icons.military_tech_rounded, label: 'Ranking'),
      (icon: Icons.workspace_premium_rounded, label: 'Achievements'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
      decoration: BoxDecoration(
        color: presidentSurfaceLowest.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: presidentOutlineVariant.withValues(alpha: 0.45),
          ),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 32,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Row(
        children: List<Widget>.generate(items.length, (int index) {
          final item = items[index];
          final selected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: selected ? presidentPrimary : Colors.transparent,
                      width: 2.2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      item.icon,
                      color: selected ? presidentPrimary : presidentOutline,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label.toUpperCase(),
                      style: TextStyle(
                        color: selected ? presidentPrimary : presidentOutline,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.icon,
    required this.buttonIcon,
    required this.accent,
    required this.background,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final IconData icon;
  final IconData buttonIcon;
  final Color accent;
  final Gradient background;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final compact = constraints.maxWidth < 170;

        return Container(
          height: 252,
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: BoxDecoration(
            gradient: background,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: accent, size: compact ? 24 : 30),
              SizedBox(height: compact ? 18 : 24),
              SizedBox(
                width: double.infinity,
                child: Text(
                  title,
                  maxLines: compact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? presidentText : accent,
                    fontSize: compact ? 24 : 30,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  body,
                  maxLines: compact ? 5 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: presidentMuted,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: enabled ? accent : presidentSurfaceHighest,
                  foregroundColor: enabled ? Colors.black : presidentMuted,
                  minimumSize: const Size(140, 0),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 18,
                    vertical: compact ? 14 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(buttonIcon, size: compact ? 16 : 18),
                      const SizedBox(width: 6),
                      Text(
                        buttonLabel,
                        style: TextStyle(
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: compact ? 1.0 : 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GamesPlayedPanel extends StatelessWidget {
  const _GamesPlayedPanel({required this.gamesPlayed});

  final int gamesPlayed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: presidentSurfaceHighest.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'GAMES PLAYED',
              style: TextStyle(
                color: presidentMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Text(
            '$gamesPlayed',
            style: const TextStyle(
              color: presidentText,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStatPanel extends StatelessWidget {
  const _CompactStatPanel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: presidentSurfaceHighest.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: presidentMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: presidentText,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.title,
    required this.description,
    required this.locked,
  });

  final String title;
  final String description;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: presidentSurfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: locked
              ? presidentOutlineVariant.withValues(alpha: 0.55)
              : presidentPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: locked
                  ? presidentSurfaceHighest
                  : presidentPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              locked
                  ? Icons.lock_outline_rounded
                  : Icons.workspace_premium_rounded,
              color: locked ? presidentMuted : presidentPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: presidentText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: presidentMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: presidentSurfaceContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size * 1.22,
          height: size * 1.22,
          child: SvgPicture.asset('assets/default_avatar.svg'),
        ),
      ),
    );
  }
}

class _GuestProfile {
  const _GuestProfile({
    required this.name,
    required this.gamesPlayed,
    required this.roleHistory,
  });

  final String name;
  final int gamesPlayed;
  final List<String> roleHistory;
}

class _RankProgress {
  const _RankProgress({
    required this.index,
    required this.name,
    required this.goal,
    required this.nextName,
  });

  final int index;
  final String name;
  final int goal;
  final String nextName;
}

int _rolePoints(String role) {
  return switch (role) {
    'President' => 10,
    'Vice' => 8,
    'Citizen' => 5,
    'Vice Scum' => 2,
    'Scum' => 1,
    _ => 0,
  };
}

_RankProgress _rankForScore(int score) {
  var accumulated = 0;
  var thresholdStep = 10;
  var index = 0;

  while (score >= accumulated + thresholdStep) {
    accumulated += thresholdStep;
    thresholdStep += 5;
    index += 1;
  }

  return _RankProgress(
    index: index,
    name: 'Rank ${index + 1}',
    goal: accumulated + thresholdStep,
    nextName: 'Rank ${index + 2}',
  );
}
