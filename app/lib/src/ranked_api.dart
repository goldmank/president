import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'app_config.dart';
import 'ranked_models.dart';

class RankedApi {
  RankedApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _httpUri(String path) =>
      Uri.parse('${AppConfig.instance.serverEndpoint}$path');

  Uri _webSocketUri(String path, {Map<String, String>? queryParameters}) {
    final base = Uri.parse(AppConfig.instance.webSocketEndpoint);
    return base.replace(path: path, queryParameters: queryParameters);
  }

  Future<RankedQueueTicketModel> enqueue({
    required String userId,
    required String displayName,
    required int rankScore,
  }) async {
    _log('enqueue.start userId=$userId rankScore=$rankScore displayName=$displayName');
    final response = await _client.post(
      _httpUri('/ranked/queue'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'userId': userId,
        'displayName': displayName,
        'rankScore': rankScore,
      }),
    );
    _log('enqueue.response status=${response.statusCode} body=${_compactBody(response.body)}');
    return RankedQueueTicketModel.fromJson(_decodePayload(response));
  }

  Future<void> cancelQueue(String ticketId) async {
    _log('cancelQueue.start ticketId=$ticketId');
    final response = await _client.delete(
      _httpUri('/ranked/queue/$ticketId'),
      headers: _headers,
    );
    _log('cancelQueue.response status=${response.statusCode} body=${_compactBody(response.body)}');
    _decodePayload(response);
  }

  WebSocketChannel connect(String ticketId) {
    final uri = _webSocketUri('/ranked/ws', queryParameters: <String, String>{
      'ticketId': ticketId,
    });
    _log('rankedWs.connect uri=$uri');
    return WebSocketChannel.connect(
      uri,
    );
  }

  Future<PrivateRoomSnapshotModel> createPrivateRoom({
    required String userId,
    required String displayName,
    required int rankScore,
  }) async {
    _log('privateRoom.create.start userId=$userId rankScore=$rankScore displayName=$displayName');
    final response = await _client.post(
      _httpUri('/private-room'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'userId': userId,
        'displayName': displayName,
        'rankScore': rankScore,
      }),
    );
    _log('privateRoom.create.response status=${response.statusCode} body=${_compactBody(response.body)}');
    return PrivateRoomSnapshotModel.fromJson(_decodePayload(response));
  }

  Future<PrivateRoomSnapshotModel> joinPrivateRoom({
    required String code,
    required String userId,
    required String displayName,
    required int rankScore,
  }) async {
    _log('privateRoom.join.start code=${code.trim().toUpperCase()} userId=$userId rankScore=$rankScore displayName=$displayName');
    final response = await _client.post(
      _httpUri('/private-room/join'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'code': code,
        'userId': userId,
        'displayName': displayName,
        'rankScore': rankScore,
      }),
    );
    _log('privateRoom.join.response status=${response.statusCode} body=${_compactBody(response.body)}');
    return PrivateRoomSnapshotModel.fromJson(_decodePayload(response));
  }

  Future<PrivateRoomSnapshotModel> getPrivateRoom(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    _log('privateRoom.get.start code=$normalizedCode');
    final response = await _client.get(
      _httpUri('/private-room/$normalizedCode'),
      headers: _headers,
    );
    _log('privateRoom.get.response code=$normalizedCode status=${response.statusCode} body=${_compactBody(response.body)}');
    return PrivateRoomSnapshotModel.fromJson(_decodePayload(response));
  }

  static const Map<String, String> _headers = <String, String>{
    'Content-Type': 'application/json',
  };

  Map<String, dynamic> _decodePayload(http.Response response) {
    final payload = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload is Map<String, dynamic>
          ? payload['error'] as String?
          : null;
      throw Exception(message ?? 'Request failed with ${response.statusCode}');
    }
    if (payload is! Map<String, dynamic>) {
      throw Exception('Invalid server response');
    }
    return payload;
  }

  void _log(String message) {
    debugPrint('[ranked_api] $message');
  }

  String _compactBody(String body) {
    return body.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
