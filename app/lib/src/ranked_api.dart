import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'app_config.dart';
import 'app_error.dart';
import 'ranked_models.dart';

class RankedApi {
  RankedApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _requestTimeout = Duration(seconds: 10);

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
    _log(
      'enqueue.start userId=$userId rankScore=$rankScore displayName=$displayName',
    );
    final response = await _send(
      () => _client.post(
        _httpUri('/ranked/queue'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'userId': userId,
          'displayName': displayName,
          'rankScore': rankScore,
        }),
      ),
    );
    _log(
      'enqueue.response status=${response.statusCode} body=${_compactBody(response.body)}',
    );
    return RankedQueueTicketModel.fromJson(_decodePayload(response));
  }

  Future<void> cancelQueue(String ticketId) async {
    _log('cancelQueue.start ticketId=$ticketId');
    final response = await _send(
      () => _client.delete(
        _httpUri('/ranked/queue/$ticketId'),
        headers: _headers,
      ),
    );
    _log(
      'cancelQueue.response status=${response.statusCode} body=${_compactBody(response.body)}',
    );
    _decodePayload(response);
  }

  WebSocketChannel connect(String ticketId) {
    final uri = _webSocketUri(
      '/ranked/ws',
      queryParameters: <String, String>{'ticketId': ticketId},
    );
    _log('rankedWs.connect uri=$uri');
    return WebSocketChannel.connect(uri);
  }

  Future<PrivateRoomSnapshotModel> createPrivateRoom({
    required String userId,
    required String displayName,
    required int rankScore,
    String? photoUrl,
  }) async {
    _log(
      'privateRoom.create.start userId=$userId rankScore=$rankScore displayName=$displayName',
    );
    final response = await _send(
      () => _client.post(
        _httpUri('/private-room'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'userId': userId,
          'displayName': displayName,
          'rankScore': rankScore,
          'photoUrl': photoUrl,
        }),
      ),
    );
    _log(
      'privateRoom.create.response status=${response.statusCode} body=${_compactBody(response.body)}',
    );
    return PrivateRoomSnapshotModel.fromJson(_decodePayload(response));
  }

  Future<PrivateRoomSnapshotModel> joinPrivateRoom({
    required String code,
    required String userId,
    required String displayName,
    required int rankScore,
    String? photoUrl,
  }) async {
    _log(
      'privateRoom.join.start code=${code.trim().toUpperCase()} userId=$userId rankScore=$rankScore displayName=$displayName',
    );
    final response = await _send(
      () => _client.post(
        _httpUri('/private-room/join'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'code': code,
          'userId': userId,
          'displayName': displayName,
          'rankScore': rankScore,
          'photoUrl': photoUrl,
        }),
      ),
    );
    _log(
      'privateRoom.join.response status=${response.statusCode} body=${_compactBody(response.body)}',
    );
    return PrivateRoomSnapshotModel.fromJson(_decodePayload(response));
  }

  Future<PrivateRoomSnapshotModel> getPrivateRoom(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    _log('privateRoom.get.start code=$normalizedCode');
    final response = await _send(
      () => _client.get(
        _httpUri('/private-room/$normalizedCode'),
        headers: _headers,
      ),
    );
    _log(
      'privateRoom.get.response code=$normalizedCode status=${response.statusCode} body=${_compactBody(response.body)}',
    );
    return PrivateRoomSnapshotModel.fromJson(_decodePayload(response));
  }

  Future<PrivateRoomSnapshotModel> startPrivateRoom({
    required String code,
    required String userId,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    _log('privateRoom.start.start code=$normalizedCode userId=$userId');
    final response = await _send(
      () => _client.post(
        _httpUri('/private-room/start'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'code': normalizedCode,
          'userId': userId,
        }),
      ),
    );
    _log(
      'privateRoom.start.response code=$normalizedCode status=${response.statusCode} body=${_compactBody(response.body)}',
    );
    return PrivateRoomSnapshotModel.fromJson(_decodePayload(response));
  }

  static const Map<String, String> _headers = <String, String>{
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': '1',
  };

  Map<String, dynamic> _decodePayload(http.Response response) {
    final String trimmedBody = response.body.trim();
    final Object? payload = _tryDecodeJson(trimmedBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String? message = payload is Map<String, dynamic>
          ? payload['error'] as String?
          : null;
      if (_looksLikeHtml(trimmedBody)) {
        throw AppException(
          code: 1003,
          userMessage:
              'The server returned a web page instead of game data. Check that the configured server endpoint is correct.',
          details: _truncate(trimmedBody),
        );
      }
      throw AppException(
        code: response.statusCode,
        userMessage: _userMessageForHttpStatus(
          response.statusCode,
          message?.trim(),
        ),
        details: trimmedBody.isEmpty ? null : _truncate(trimmedBody),
      );
    }

    if (payload is! Map<String, dynamic>) {
      throw AppException(
        code: _looksLikeHtml(trimmedBody) ? 1003 : 1100,
        userMessage: _looksLikeHtml(trimmedBody)
            ? 'The server returned a web page instead of game data.'
            : 'The server returned data in an unexpected format.',
        details: trimmedBody.isEmpty ? null : _truncate(trimmedBody),
      );
    }
    return payload;
  }

  Object? _tryDecodeJson(String body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  bool _looksLikeHtml(String body) {
    final String normalized = body.trimLeft().toLowerCase();
    return normalized.startsWith('<!doctype html') ||
        normalized.startsWith('<html') ||
        normalized.contains('<head') ||
        normalized.contains('<body');
  }

  String _truncate(String text, {int maxLength = 1200}) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException catch (error) {
      throw AppException(
        code: 1002,
        userMessage:
            'The server took too long to respond. Please try again in a moment.',
        details: error.toString(),
      );
    } on SocketException catch (error) {
      throw AppException(
        code: 1001,
        userMessage:
            'The network connection is unavailable. Check your internet and try again.',
        details: error.toString(),
      );
    } on http.ClientException catch (error) {
      final String details = error.toString();
      final String normalized = details.toLowerCase();
      if (normalized.contains('failed host lookup') ||
          normalized.contains('socketexception') ||
          normalized.contains('no address associated with hostname') ||
          normalized.contains('connection refused')) {
        throw AppException(
          code: 1001,
          userMessage:
              'The network connection is unavailable. Check your internet and try again.',
          details: details,
        );
      }
      throw AppException(
        code: 1004,
        userMessage:
            'The app could not reach the game server. Please try again in a moment.',
        details: details,
      );
    }
  }

  String _userMessageForHttpStatus(int statusCode, String? message) {
    if (statusCode >= 500) {
      return 'The server is unavailable right now. Please try again in a moment.';
    }
    if (statusCode >= 400) {
      return message?.isNotEmpty == true
          ? message!
          : 'The request could not be completed.';
    }
    return message?.isNotEmpty == true
        ? message!
        : 'The request could not be completed right now.';
  }

  void _log(String message) {
    debugPrint('[ranked_api] $message');
  }

  String _compactBody(String body) {
    return body.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
