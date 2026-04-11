import 'package:flutter/material.dart';

const presidentBackground = Color(0xFF0F1113);
const presidentSurfaceLowest = Color(0xFF0C0E10);
const presidentSurface = Color(0xFF121416);
const presidentSurfaceLow = Color(0xFF1A1C1E);
const presidentSurfaceContainer = Color(0xFF1E2022);
const presidentSurfaceHigh = Color(0xFF282A2C);
const presidentSurfaceHighest = Color(0xFF333537);
const presidentPrimary = Color(0xFFFFD700);
const presidentPrimaryDark = Color(0xFF9B8200);
const presidentSecondary = Color(0xFFC0C0C0);
const presidentTertiary = Color(0xFFCD7F32);
const presidentText = Color(0xFFE2E2E5);
const presidentMuted = Color(0xFFC5C6CA);
const presidentOutline = Color(0xFF8F9194);
const presidentOutlineVariant = Color(0xFF44474A);
const presidentDanger = Color(0xFFFFB4AB);
const presidentDangerContainer = Color(0xFF93000A);

ThemeData buildPresidentTheme() {
  final scheme = ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: presidentPrimary,
    primary: presidentPrimary,
    secondary: presidentSecondary,
    surface: presidentSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: presidentBackground,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        color: presidentText,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
        color: presidentText,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: presidentText,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: presidentText,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: presidentMuted,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: presidentSurfaceLowest,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: presidentText,
      ),
    ),
  );
}
