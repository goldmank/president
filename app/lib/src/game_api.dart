import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'models.dart';

class GameApi {
  GameApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) =>
      Uri.parse('${AppConfig.instance.serverEndpoint}$path');

  Future<PublicGameStateModel> createGame({
    int? playerCount,
    Map<String, dynamic>? rules,
  }) async {
    final response = await _client.post(
      _uri('/game'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        if (playerCount case final int count) 'playerCount': count,
        if (rules case final Map<String, dynamic> value) 'rules': value,
      }),
    );
    return _decodeState(response);
  }

  Future<PublicGameStateModel> getPrivateRoomGameState({
    required String code,
    required String playerId,
  }) async {
    final response = await _client.get(
      _uri(
        '/private-room/${code.trim().toUpperCase()}/game?playerId=${Uri.encodeQueryComponent(playerId)}',
      ),
      headers: _headers,
    );
    return _decodeState(response);
  }

  Future<PublicGameStateModel> submitPrivateRoomPlay({
    required String code,
    required PlayActionPayload payload,
  }) async {
    final response = await _client.post(
      _uri('/private-room/${code.trim().toUpperCase()}/game/action'),
      headers: _headers,
      body: jsonEncode(payload.toJson()),
    );
    return _decodeState(response);
  }

  Future<PublicGameStateModel> submitPrivateRoomPass({
    required String code,
    required PassActionPayload payload,
  }) async {
    final response = await _client.post(
      _uri('/private-room/${code.trim().toUpperCase()}/game/action'),
      headers: _headers,
      body: jsonEncode(payload.toJson()),
    );
    return _decodeState(response);
  }

  Future<PublicGameStateModel> submitPlay(PlayActionPayload payload) async {
    final response = await _client.post(
      _uri('/game/action'),
      headers: _headers,
      body: jsonEncode(payload.toJson()),
    );
    return _decodeState(response);
  }

  Future<PublicGameStateModel> submitPass(PassActionPayload payload) async {
    final response = await _client.post(
      _uri('/game/action'),
      headers: _headers,
      body: jsonEncode(payload.toJson()),
    );
    return _decodeState(response);
  }

  Future<PublicGameStateModel> stepBotTurn() async {
    final response = await _client.post(
      _uri('/game/bot-turn'),
      headers: _headers,
    );
    return _decodeState(response);
  }

  Future<PublicGameStateModel> fastForwardGame() async {
    final response = await _client.post(
      _uri('/game/fast-forward'),
      headers: _headers,
    );
    return _decodeState(response);
  }

  Future<PublicGameStateModel> startNextRound() async {
    final response = await _client.post(
      _uri('/game/next-round'),
      headers: _headers,
    );
    return _decodeState(response);
  }

  Future<ExchangePreviewModel?> getExchangePreview() async {
    final response = await _client.get(
      _uri('/game/exchange-preview'),
      headers: _headers,
    );
    final payload = _decodePayload(response);
    if (payload == null) {
      return null;
    }
    return ExchangePreviewModel.fromJson(payload);
  }

  Future<ExchangePreviewModel?> getPrivateRoomExchangePreview({
    required String code,
    required String playerId,
  }) async {
    final response = await _client.get(
      _uri(
        '/private-room/${code.trim().toUpperCase()}/game/exchange-preview?playerId=${Uri.encodeQueryComponent(playerId)}',
      ),
      headers: _headers,
    );
    final payload = _decodePayload(response);
    if (payload == null) {
      return null;
    }
    return ExchangePreviewModel.fromJson(payload);
  }

  Future<PublicGameStateModel> startPrivateRoomNextRound({
    required String code,
    required String playerId,
  }) async {
    final response = await _client.post(
      _uri('/private-room/${code.trim().toUpperCase()}/game/next-round'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'playerId': playerId}),
    );
    return _decodeState(response);
  }

  static const Map<String, String> _headers = <String, String>{
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': '1',
  };

  PublicGameStateModel _decodeState(http.Response response) {
    final payload = _decodePayload(response);
    if (payload == null) {
      throw Exception(
        'Invalid server response (${response.statusCode}): '
        '${_compactBody(response.body)}',
      );
    }
    return PublicGameStateModel.fromJson(payload);
  }

  Map<String, dynamic>? _decodePayload(http.Response response) {
    final payload = _tryDecodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload is Map<String, dynamic>
          ? payload['error'] as String?
          : _fallbackErrorMessage(response);
      throw Exception(message ?? _fallbackErrorMessage(response));
    }
    return payload is Map<String, dynamic> ? payload : null;
  }

  Object? _tryDecodeJson(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final startsLikeJson =
        trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        trimmed == 'null' ||
        trimmed == 'true' ||
        trimmed == 'false' ||
        RegExp(r'^-?\d').hasMatch(trimmed);
    if (!startsLikeJson) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } on FormatException {
      return null;
    }
  }

  String _fallbackErrorMessage(http.Response response) {
    final body = _compactBody(response.body);
    final normalized = body.toLowerCase();
    if (normalized.contains('ngrok gateway error') ||
        normalized.contains('err_ngrok_3004')) {
      return 'Server unavailable. Check your dev server endpoint.';
    }
    if (body.isNotEmpty) {
      return 'Request failed with ${response.statusCode}: $body';
    }
    return 'Request failed with ${response.statusCode}';
  }

  String _compactBody(String body) {
    return body.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
