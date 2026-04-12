import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class GameApi {
  GameApi({http.Client? client}) : _client = client ?? http.Client();
  static const String _baseUrl = 'https://assad.ngrok.dev';

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<PublicGameStateModel> createGame({int? playerCount}) async {
    final response = await _client.post(
      _uri('/game'),
      headers: _headers,
      body: jsonEncode(
        playerCount == null
            ? <String, dynamic>{}
            : <String, dynamic>{'playerCount': playerCount},
      ),
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

  static const Map<String, String> _headers = <String, String>{
    'Content-Type': 'application/json',
  };

  PublicGameStateModel _decodeState(http.Response response) {
    final payload = jsonDecode(response.body) as Object?;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload is Map<String, dynamic>
          ? payload['error'] as String?
          : null;
      throw Exception(message ?? 'Request failed with ${response.statusCode}');
    }
    return PublicGameStateModel.fromJson(payload as Map<String, dynamic>);
  }
}
