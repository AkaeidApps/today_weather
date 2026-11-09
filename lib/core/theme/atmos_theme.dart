import 'package:flutter/material.dart';

/// Shared colors for ATMOS surfaces, weather content, and text.
abstract final class AtmosColors {
  static const ink = Color(0xff101922);
  static const muted = Color(0xff74818d);
  static const sea = Color(0xff267d9b);
  static const canvas = Color(0xfff6f8f7);
  static const surface = Colors.white;
  static const outline = Color(0xffe5ebea);
}

/// Application-wide Material 3 themes and typography defaults.
abstract final class AtmosTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AtmosColors.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AtmosColors.sea,
      surface: AtmosColors.canvas,
      onSurface: AtmosColors.ink,
    ),
    fontFamily: 'Manrope',
    appBarTheme: const AppBarTheme(
      backgroundColor: AtmosColors.canvas,
      foregroundColor: AtmosColors.ink,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AtmosColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: AtmosColors.outline),
  );
}
