import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';

import 'ad_service.dart';

class AppLovinBanner extends StatelessWidget {
  const AppLovinBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final adService = AdService.instance;
    if (!adService.canShowBanner) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Center(
          child: MaxAdView(
            adUnitId: adService.bannerAdUnitId,
            adFormat: AdFormat.banner,
            listener: AdViewAdListener(
              onAdLoadedCallback: (ad) {
                debugPrint('AppLovin banner loaded from ${ad.networkName}');
              },
              onAdLoadFailedCallback: (adUnitId, error) {
                debugPrint(
                  'AppLovin banner failed to load for $adUnitId: '
                  '${error.code} ${error.message}',
                );
              },
              onAdClickedCallback: (ad) {
                debugPrint('AppLovin banner clicked: ${ad.adUnitId}');
              },
              onAdExpandedCallback: (ad) {
                debugPrint('AppLovin banner expanded: ${ad.adUnitId}');
              },
              onAdCollapsedCallback: (ad) {
                debugPrint('AppLovin banner collapsed: ${ad.adUnitId}');
              },
            ),
          ),
        ),
      ),
    );
  }
}
