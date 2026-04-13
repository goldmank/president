import 'package:flutter/services.dart';

class AppConfig {
  AppConfig._({required this.serverEndpoint, required this.buildMode});

  static AppConfig instance = AppConfig._(
    serverEndpoint: 'https://assad.ngrok.dev',
    buildMode: 'dev',
  );

  final String serverEndpoint;
  final String buildMode;

  bool get isDev => buildMode.toLowerCase() == 'dev';
  bool get isProd => buildMode.toLowerCase() == 'prod';

  static Future<void> load() async {
    final raw = await rootBundle.loadString('.env');
    final Map<String, String> values = <String, String>{};

    for (final String line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      final int separator = trimmed.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final String key = trimmed.substring(0, separator).trim();
      final String value = trimmed.substring(separator + 1).trim();
      values[key] = value;
    }

    instance = AppConfig._(
      serverEndpoint: values['SERVER_ENDPOINT']?.isNotEmpty == true
          ? values['SERVER_ENDPOINT']!
          : instance.serverEndpoint,
      buildMode: values['BUILD_MODE']?.isNotEmpty == true
          ? values['BUILD_MODE']!
          : instance.buildMode,
    );
  }
}
