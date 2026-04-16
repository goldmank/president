import 'package:flutter/material.dart';

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
      home: const LobbyScreen(),
    );
  }
}
