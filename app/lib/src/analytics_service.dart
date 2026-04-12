import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> initialize() async {
    await _analytics.setAnalyticsCollectionEnabled(true);
  }

  Future<void> logGameStarted(PublicGameStateModel state) {
    return _logEvent(
      'game_start',
      <String, Object>{
        'game_id': _compact(state.id),
        'player_count': state.players.length,
        'phase_name': state.phase.name,
        'has_roles': _hasAssignedRoles(state) ? 1 : 0,
        'game_stage': _hasAssignedRoles(state) ? 'role_based' : 'phase_1',
      },
    );
  }

  Future<void> logGameFinished(
    PublicGameStateModel previous,
    PublicGameStateModel next,
  ) {
    final rankedPlayers = next.players
        .where((player) => player.finishingPosition != null)
        .length;

    return _logEvent(
      'game_end',
      <String, Object>{
        'game_id': _compact(next.id),
        'player_count': next.players.length,
        'started_with_roles': _hasAssignedRoles(previous) ? 1 : 0,
        'finished_with_roles': _hasAssignedRoles(next) ? 1 : 0,
        'ranked_players': rankedPlayers,
        'viewer_role': _compact(roleLabel(next.viewer, next.players.length)),
      },
    );
  }

  Future<void> logRoleProgressionReady(
    PublicGameStateModel previous,
    PublicGameStateModel next,
  ) {
    if (_hasAssignedRoles(previous) || !_hasAssignedRoles(next)) {
      return SynchronousFuture<void>(null);
    }

    return _logEvent(
      'role_progression_ready',
      <String, Object>{
        'game_id': _compact(next.id),
        'player_count': next.players.length,
        'ranked_players': next.players
            .where((player) => player.finishingPosition != null)
            .length,
      },
    );
  }

  Future<void> logGameError(
    String context,
    Object error, {
    PublicGameStateModel? state,
  }) {
    return _logEvent(
      'game_error',
      <String, Object>{
        'error_context': _compact(context),
        'error_type': _compact(error.runtimeType.toString()),
        'error_message': _compact(error.toString()),
        'has_game_state': state == null ? 0 : 1,
        if (state != null) 'game_id': _compact(state.id),
        if (state != null) 'phase_name': state.phase.name,
      },
    );
  }

  Future<void> logAppError(
    String source,
    Object error, {
    StackTrace? stackTrace,
  }) {
    return _logEvent(
      'app_error',
      <String, Object>{
        'source': _compact(source),
        'error_type': _compact(error.runtimeType.toString()),
        'error_message': _compact(error.toString()),
        if (stackTrace != null) 'stack_hint': _compact(stackTrace.toString()),
      },
    );
  }

  bool _hasAssignedRoles(PublicGameStateModel state) {
    return state.players.every((player) => player.finishingPosition != null);
  }

  Future<void> _logEvent(String name, Map<String, Object> parameters) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (error, stackTrace) {
      debugPrint('[analytics] failed to log $name: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _compact(String value, {int maxLength = 100}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return normalized.substring(0, maxLength);
  }
}
