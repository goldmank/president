import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'app_error.dart';
import 'auth_service.dart';

class ErrorReportApi {
  ErrorReportApi._();

  static final ErrorReportApi instance = ErrorReportApi._();

  final http.Client _client = http.Client();
  static const Duration _requestTimeout = Duration(seconds: 10);

  Future<void> sendReport({
    required String title,
    required AppErrorInfo error,
    String? reportContext,
  }) async {
    final user = AuthService.instance.currentUser;
    final uri = Uri.parse(
      '${AppConfig.instance.serverEndpoint}/client-error-report',
    );

    final payload = <String, dynamic>{
      'title': title,
      'errorCode': error.code,
      'message': error.message,
      'details': error.details,
      'reportContext': reportContext,
      'buildMode': AppConfig.instance.buildMode,
      'serverEndpoint': AppConfig.instance.serverEndpoint,
      'reportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'user': <String, dynamic>{
        'uid': user?.uid,
        'displayName': user?.displayName,
        'email': user?.email,
        'photoUrl': user?.photoURL,
      },
    };

    try {
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[error_report] send.failed status=${response.statusCode} body=${response.body.trim()}',
        );
        return;
      }

      debugPrint('[error_report] send.success status=${response.statusCode}');
    } catch (error) {
      debugPrint('[error_report] send.failed error=$error');
    }
  }

  static const Map<String, String> _headers = <String, String>{
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': '1',
  };
}
