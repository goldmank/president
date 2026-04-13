import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'src/analytics_service.dart';
import 'src/app_shell.dart';
import 'src/app_config.dart';
import 'src/game_settings_service.dart';
import 'src/user_progress_service.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppConfig.load();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await AnalyticsService.instance.initialize();
      await GameSettingsService.instance.initialize();
      await UserProgressService.instance.initialize();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(
          AnalyticsService.instance.logAppError(
            'flutter_framework',
            details.exception,
            stackTrace: details.stack,
          ),
        );
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        unawaited(
          AnalyticsService.instance.logAppError(
            'platform_dispatcher',
            error,
            stackTrace: stackTrace,
          ),
        );
        return false;
      };
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      runApp(const PresidentApp());
    },
    (error, stackTrace) {
      unawaited(
        AnalyticsService.instance.logAppError(
          'run_zoned_guarded',
          error,
          stackTrace: stackTrace,
        ),
      );
    },
  );
}
