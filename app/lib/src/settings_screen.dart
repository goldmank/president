import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'game_settings_service.dart';
import 'president_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _doubleDeck = false;
  double _aiDifficulty = 4;

  @override
  void initState() {
    super.initState();
    final settings = GameSettingsService.instance.currentSettings;
    _doubleDeck = settings.doubleDeck;
    _aiDifficulty = settings.aiDifficulty.toDouble();
  }

  @override
  Widget build(BuildContext context) {
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
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _SettingsHeader(),
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final singleColumn = constraints.maxWidth < 760;
                              if (singleColumn) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _buildRulesColumn(),
                                    const SizedBox(height: 24),
                                    _buildHierarchyColumn(),
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(flex: 7, child: _buildRulesColumn()),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 5,
                                    child: _buildHierarchyColumn(),
                                  ),
                                ],
                              );
                            },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRulesColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionLabel(label: 'THE RULES'),
        const SizedBox(height: 18),
        _RuleToggleTile(
          title: 'Double Deck',
          subtitle: 'Extended Match Length',
          value: _doubleDeck,
          onChanged: (bool value) {
            setState(() {
              _doubleDeck = value;
            });
            GameSettingsService.instance.setDoubleDeck(value);
          },
        ),
        const SizedBox(height: 22),
        _SliderTile(
          title: 'AI Difficulty',
          subtitle: 'Competition Level',
          valueText: _difficultyLabel(_aiDifficulty.round()),
          minLabel: 'Intern',
          maxLabel: 'Chairman',
          value: _aiDifficulty,
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: (double value) {
            setState(() {
              _aiDifficulty = value;
            });
            GameSettingsService.instance.setAiDifficulty(value.round());
          },
        ),
      ],
    );
  }

  Widget _buildHierarchyColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: presidentSurfaceContainer,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'ACTIVE HIERARCHY',
                style: TextStyle(
                  color: presidentMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              SizedBox(height: 18),
              _HierarchyRow(
                letter: 'P',
                title: 'President',
                points: '10 pts',
                color: presidentPrimary,
                widthFactor: 1,
                iconAsset: 'assets/crown.svg',
              ),
              SizedBox(height: 14),
              _HierarchyRow(
                letter: 'V',
                title: 'Vice President',
                points: '8 pts',
                color: presidentSecondary,
                widthFactor: 0.72,
                iconAsset: 'assets/military_tech.svg',
              ),
              SizedBox(height: 14),
              _HierarchyRow(
                letter: 'C',
                title: 'Citizen',
                points: '5 pts',
                color: presidentTertiary,
                widthFactor: 0.48,
                iconAsset: 'assets/sentiment_content.svg',
              ),
              SizedBox(height: 14),
              _HierarchyRow(
                letter: 'VS',
                title: 'Vice Scum',
                points: '2 pts',
                color: Color(0xFFFFA36A),
                widthFactor: 0.28,
                iconAsset: 'assets/stat_minus_2.svg',
              ),
              SizedBox(height: 14),
              _HierarchyRow(
                letter: 'S',
                title: 'Scum',
                points: '1 pt',
                color: presidentDanger,
                widthFactor: 0.16,
                iconAsset: 'assets/skull.svg',
              ),
              SizedBox(height: 18),
              Divider(color: presidentOutlineVariant, height: 1),
              SizedBox(height: 16),
              Text(
                'The finishing order sets the hierarchy. Each role also adds rank score, so the profile progression follows your actual placements over time.',
                style: TextStyle(
                  color: presidentMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[presidentPrimary, presidentPrimaryDark],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved.')),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: presidentSurfaceLowest,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              child: const Text('APPLY PROTOCOLS'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              onPressed: () {
                Navigator.of(context).maybePop();
              },
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: presidentPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'THE TABLE',
              style: TextStyle(
                color: presidentPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Settings & Rules',
          style: TextStyle(
            color: presidentText,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.8,
            height: 0.95,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Configure table rules, exchange pressure, and bot difficulty before the next session.',
          style: TextStyle(
            color: presidentMuted,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: presidentPrimary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: presidentPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

class _RuleToggleTile extends StatelessWidget {
  const _RuleToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: presidentSurfaceLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: presidentText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: presidentMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: presidentPrimary,
            activeTrackColor: presidentPrimary.withValues(alpha: 0.26),
            inactiveThumbColor: presidentMuted,
            inactiveTrackColor: presidentSurfaceHighest,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.valueText,
    required this.minLabel,
    required this.maxLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String valueText;
  final String minLabel;
  final String maxLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: presidentSurfaceLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: presidentText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: presidentMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                valueText,
                style: const TextStyle(
                  color: presidentPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: presidentPrimary,
              inactiveTrackColor: presidentSurfaceHighest,
              thumbColor: presidentPrimary,
              overlayColor: presidentPrimary.withValues(alpha: 0.16),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            children: <Widget>[
              Text(
                minLabel.toUpperCase(),
                style: const TextStyle(
                  color: presidentMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                maxLabel.toUpperCase(),
                style: const TextStyle(
                  color: presidentMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HierarchyRow extends StatelessWidget {
  const _HierarchyRow({
    required this.letter,
    required this.title,
    required this.points,
    required this.color,
    required this.widthFactor,
    required this.iconAsset,
  });

  final String letter;
  final String title;
  final String points;
  final Color color;
  final double widthFactor;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 58,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
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
                          title,
                          style: TextStyle(
                            color: color,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          points.toUpperCase(),
                          style: TextStyle(
                            color: color.withValues(alpha: 0.88),
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
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Container(
                    height: 3,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: widthFactor,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _difficultyLabel(int level) {
  switch (level) {
    case 1:
      return 'Intern';
    case 2:
      return 'Associate';
    case 3:
      return 'Vice';
    case 4:
      return 'Executive';
    default:
      return 'Chairman';
  }
}
