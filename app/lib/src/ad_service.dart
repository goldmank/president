import 'dart:async';

import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/foundation.dart';

import 'app_config.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool _initialized = false;
  bool _initializing = false;

  bool get isInitialized => _initialized;

  bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AppConfig.instance.appLovinAndroidBannerAdUnitId;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppConfig.instance.appLovinIosBannerAdUnitId;
    }
    return '';
  }

  bool get hasSdkKey => AppConfig.instance.appLovinSdkKey.isNotEmpty;
  bool get hasBannerAdUnitId => bannerAdUnitId.isNotEmpty;
  bool get canShowBanner =>
      isSupportedPlatform && _initialized && hasSdkKey && hasBannerAdUnitId;

  Future<void> initialize() async {
    if (_initialized || _initializing || !isSupportedPlatform || !hasSdkKey) {
      return;
    }

    _initializing = true;
    try {
      final configuration = await AppLovinMAX.initialize(
        AppConfig.instance.appLovinSdkKey,
      );
      _initialized = configuration != null;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'ad_service',
          context: ErrorDescription('initializing AppLovin MAX'),
        ),
      );
    } finally {
      _initializing = false;
    }
  }
}
