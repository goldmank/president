import 'package:flutter/material.dart';

import 'app_lovin_banner.dart';
import 'lobby_screen.dart';
import 'president_theme.dart';

class PresidentApp extends StatelessWidget {
  const PresidentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PRESIDENT',
      debugShowCheckedModeBanner: false,
      theme: buildPresidentTheme(),
      builder: (context, child) {
        return Column(
          children: <Widget>[
            Expanded(child: child ?? const SizedBox.shrink()),
            const AppLovinBanner(),
          ],
        );
      },
      home: const LobbyScreen(),
    );
  }
}
