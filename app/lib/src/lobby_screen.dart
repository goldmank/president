import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_config.dart';
import 'auth_screen.dart';
import 'auth_service.dart';
import 'game_screen.dart';
import 'private_room_screen.dart';
import 'president_theme.dart';
import 'ranked_search_screen.dart';
import 'ranked_api.dart';
import 'settings_screen.dart';
import 'tutorial_screen.dart';
import 'user_progress.dart';
import 'user_progress_service.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _roomCodeController = TextEditingController();
  final RankedApi _rankedApi = RankedApi();
  int _selectedTab = 0;
  User? _user;
  StreamSubscription<User?>? _authSubscription;
  VoidCallback? _progressListener;

  @override
  void initState() {
    super.initState();
    _user = AuthService.instance.currentUser;
    _authSubscription = AuthService.instance.authStateChanges().listen((
      User? user,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _user = user;
      });
    });
    _progressListener = () {
      if (!mounted) {
        return;
      }
      setState(() {});
    };
    UserProgressService.instance.addListener(_progressListener!);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    if (_progressListener != null) {
      UserProgressService.instance.removeListener(_progressListener!);
    }
    _roomCodeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressData = UserProgressService.instance.currentProgress;
    final score = progressData.score;
    final rank = _rankForScore(score);
    final profileName = (_user?.displayName?.trim().isNotEmpty ?? false)
        ? _user!.displayName!.trim()
        : 'Guest';
    final avatarUrl = _user?.photoURL;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _LobbyDrawer(
        isSignedIn: _user != null,
        debugScoreBonus: progressData.debugScoreBonus,
        onOpenTutorial: _openTutorial,
        onOpenSettings: _openSettings,
        onAddScore: _adjustDebugScore,
        onResetScore: _resetDebugScore,
        onLogout: _logout,
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
                  controller: _scrollController,
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
                              avatarUrl: avatarUrl,
                            ),
                            const SizedBox(height: 18),
                            _ProfilePanel(
                              profileName: profileName,
                              progressData: progressData,
                              score: score,
                              rank: rank,
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: switch (_selectedTab) {
                                0 => _LobbyTab(
                                  key: const ValueKey<String>('lobby'),
                                  isSignedIn: _user != null,
                                  roomCodeController: _roomCodeController,
                                  onStartPractice: _openBotGame,
                                  onSignUp: _openAuthFlow,
                                  onJoinRoom: _handleJoinRoom,
                                  onFindMatch: _openRankedMatchmaking,
                                  onCreateMatch: _createPrivateMatch,
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

  String _formatError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> _openAuthFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AuthScreen(),
      ),
    );
    if (!mounted) {
      return;
    }
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _openTutorial() async {
    Navigator.of(context).maybePop();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const TutorialScreen(),
      ),
    );
  }

  Future<void> _openSettings() async {
    Navigator.of(context).maybePop();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SettingsScreen(),
      ),
    );
  }

  void _adjustDebugScore(int amount) {
    Navigator.of(context).maybePop();
    unawaited(UserProgressService.instance.addDebugScore(amount));
  }

  void _resetDebugScore() {
    Navigator.of(context).maybePop();
    unawaited(UserProgressService.instance.resetDebugScore());
  }

  Future<void> _logout() async {
    Navigator.of(context).maybePop();
    await AuthService.instance.signOut();
    if (!mounted) {
      return;
    }
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleJoinRoom() {
    if (_user == null) {
      _openAuthFlow();
      return;
    }

    final roomCode = _roomCodeController.text.trim().toUpperCase();
    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a room code first.')));
      return;
    }

    final displayName = (_user!.displayName?.trim().isNotEmpty ?? false)
        ? _user!.displayName!.trim()
        : 'Player';
    final rankScore = UserProgressService.instance.currentProgress.score;
    _log(
      'privateRoom.join.request code=$roomCode userId=${_user!.uid} rankScore=$rankScore',
    );

    unawaited(() async {
      try {
        final room = await _rankedApi.joinPrivateRoom(
          code: roomCode,
          userId: _user!.uid,
          displayName: displayName,
          rankScore: rankScore,
          photoUrl: _user!.photoURL,
        );
        _log(
          'privateRoom.join.success code=${room.code} seats=${room.seats.length} status=${room.status}',
        );
        if (!mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => PrivateRoomScreen(
              initialRoom: room,
              isHost: room.hostUserId == _user!.uid,
              currentUserId: _user!.uid,
            ),
          ),
        );
      } catch (error) {
        _log('privateRoom.join.error code=$roomCode error=$error');
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_formatError(error))));
      }
    }());
  }

  Future<void> _openRankedMatchmaking() async {
    if (_user == null) {
      await _openAuthFlow();
      return;
    }

    final displayName = (_user!.displayName?.trim().isNotEmpty ?? false)
        ? _user!.displayName!.trim()
        : 'Player';
    final rankScore = UserProgressService.instance.currentProgress.score;
    _log('ranked.findMatch.open userId=${_user!.uid} rankScore=$rankScore');

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RankedSearchScreen(
          userId: _user!.uid,
          displayName: displayName,
          rankScore: rankScore,
        ),
      ),
    );
  }

  Future<void> _createPrivateMatch() async {
    if (_user == null) {
      await _openAuthFlow();
      return;
    }

    final displayName = (_user!.displayName?.trim().isNotEmpty ?? false)
        ? _user!.displayName!.trim()
        : 'Player';
    final rankScore = UserProgressService.instance.currentProgress.score;
    _log(
      'privateRoom.create.request userId=${_user!.uid} rankScore=$rankScore',
    );

    try {
      final room = await _rankedApi.createPrivateRoom(
        userId: _user!.uid,
        displayName: displayName,
        rankScore: rankScore,
        photoUrl: _user!.photoURL,
      );
      _log(
        'privateRoom.create.success code=${room.code} seats=${room.seats.length} status=${room.status}',
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => PrivateRoomScreen(
            initialRoom: room,
            isHost: true,
            currentUserId: _user!.uid,
          ),
        ),
      );
    } catch (error) {
      _log('privateRoom.create.error error=$error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_formatError(error))));
    }
  }

  void _log(String message) {
    debugPrint('[lobby] $message');
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onMenuPressed, this.avatarUrl});

  final VoidCallback onMenuPressed;
  final String? avatarUrl;

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
            'PRESIDENT',
            style: TextStyle(
              color: presidentPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
        ),
        _ProfileAvatar(size: 48, photoUrl: avatarUrl),
      ],
    );
  }
}

class _LobbyDrawer extends StatelessWidget {
  const _LobbyDrawer({
    required this.isSignedIn,
    required this.debugScoreBonus,
    required this.onOpenTutorial,
    required this.onOpenSettings,
    required this.onAddScore,
    required this.onResetScore,
    required this.onLogout,
  });

  final bool isSignedIn;
  final int debugScoreBonus;
  final Future<void> Function() onOpenTutorial;
  final Future<void> Function() onOpenSettings;
  final ValueChanged<int> onAddScore;
  final VoidCallback onResetScore;
  final Future<void> Function() onLogout;

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
                    'PRESIDENT',
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
            _DrawerAction(
              icon: Icons.school_rounded,
              label: 'Tutorial',
              onTap: () {
                onOpenTutorial();
              },
            ),
            _DrawerAction(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () {
                onOpenSettings();
              },
            ),
            if (AppConfig.instance.isDev) ...<Widget>[
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
            if (!AppConfig.instance.isDev)
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
            const Spacer(),
            if (isSignedIn) ...<Widget>[
              const Divider(color: presidentOutlineVariant, height: 1),
              _DrawerAction(
                icon: Icons.logout_rounded,
                label: 'Logout',
                onTap: () {
                  onLogout();
                },
              ),
              const SizedBox(height: 12),
            ],
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
    required this.profileName,
    required this.progressData,
    required this.score,
    required this.rank,
  });

  final String profileName;
  final UserProgress progressData;
  final int score;
  final _RankProgress rank;

  @override
  Widget build(BuildContext context) {
    final progress = rank.goal <= 0 ? 0.0 : (score / rank.goal).clamp(0.0, 1.0);
    final presidentGames = progressData.presidentGames;
    final scumGames = progressData.scumGames;

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
                  profileName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                _GamesPlayedPanel(gamesPlayed: progressData.gamesPlayed),
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
    required this.isSignedIn,
    required this.roomCodeController,
    required this.onStartPractice,
    required this.onSignUp,
    required this.onJoinRoom,
    required this.onFindMatch,
    required this.onCreateMatch,
  });

  final bool isSignedIn;
  final TextEditingController roomCodeController;
  final VoidCallback onStartPractice;
  final VoidCallback onSignUp;
  final VoidCallback onJoinRoom;
  final VoidCallback onFindMatch;
  final VoidCallback onCreateMatch;

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
          iconAsset: 'assets/cards.svg',
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
                      controller: roomCodeController,
                      readOnly: !isSignedIn,
                      textCapitalization: TextCapitalization.characters,
                      onTap: isSignedIn ? null : onSignUp,
                      onSubmitted: isSignedIn ? (_) => onJoinRoom() : null,
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
                    onPressed: isSignedIn ? onJoinRoom : onSignUp,
                    style: FilledButton.styleFrom(
                      backgroundColor: presidentSurfaceHighest,
                      foregroundColor: presidentText,
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
              Text(
                isSignedIn
                    ? 'Enter a room code to join a multiplayer table.'
                    : 'Room codes and multiplayer become available after sign up.',
                style: const TextStyle(
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
          body: isSignedIn
              ? 'Search for real opponents, prioritize similar rank, and let the server fill empty seats with bots if the queue runs long.'
              : 'Requires an account. Track rating, play real opponents, and carry your profile across devices.',
          buttonLabel: isSignedIn ? 'FIND MATCH' : 'SIGN UP TO UNLOCK',
          secondaryButtonLabel: isSignedIn ? 'CREATE MATCH' : null,
          icon: Icons.groups_rounded,
          buttonIcon: isSignedIn
              ? Icons.radar_rounded
              : Icons.lock_open_rounded,
          secondaryButtonIcon: Icons.add_rounded,
          accent: presidentPrimary,
          background: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF342C07), Color(0xFF1D1A10)],
          ),
          onPressed: isSignedIn ? onFindMatch : onSignUp,
          onSecondaryPressed: isSignedIn ? onCreateMatch : null,
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
    this.secondaryButtonLabel,
    this.icon,
    this.iconAsset,
    required this.buttonIcon,
    this.secondaryButtonIcon,
    required this.accent,
    required this.background,
    required this.onPressed,
    this.onSecondaryPressed,
  }) : assert(icon != null || iconAsset != null);

  final String title;
  final String body;
  final String buttonLabel;
  final String? secondaryButtonLabel;
  final IconData? icon;
  final String? iconAsset;
  final IconData buttonIcon;
  final IconData? secondaryButtonIcon;
  final Color accent;
  final Gradient background;
  final VoidCallback? onPressed;
  final VoidCallback? onSecondaryPressed;

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
              if (iconAsset != null)
                SvgPicture.asset(
                  iconAsset!,
                  width: compact ? 24 : 30,
                  height: compact ? 24 : 30,
                  colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                )
              else
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
              if (secondaryButtonLabel == null)
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
                )
              else
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: onPressed,
                        style: FilledButton.styleFrom(
                          backgroundColor: enabled
                              ? accent
                              : presidentSurfaceHighest,
                          foregroundColor: enabled
                              ? Colors.black
                              : presidentMuted,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 14,
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
                                  letterSpacing: compact ? 1.0 : 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: onSecondaryPressed,
                        style: FilledButton.styleFrom(
                          backgroundColor: presidentSurfaceHighest,
                          foregroundColor: presidentText,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 14,
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
                              Icon(
                                secondaryButtonIcon ?? Icons.add_rounded,
                                size: compact ? 16 : 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                secondaryButtonLabel!,
                                style: TextStyle(
                                  fontSize: compact ? 10 : 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: compact ? 1.0 : 1.2,
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
  const _ProfileAvatar({required this.size, this.photoUrl});

  final double size;
  final String? photoUrl;

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
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? Image.network(photoUrl!, fit: BoxFit.cover)
          : FittedBox(
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
