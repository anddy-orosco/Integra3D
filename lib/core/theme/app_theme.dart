import 'package:flutter/material.dart';

class AppTheme {
  // Paleta de Colores Académica y Profesional (Estilo Wolfram / Overleaf / MATLAB)
  static const Color darkBackground = Color(0xFF0A0F1D); // Obsidian Navy
  static const Color surfaceDark = Color(0xFF131B2E);    // Deep Surface Slate
  static const Color surfaceElevated = Color(0xFF1B243B); // Elevated Card
  static const Color cardBorder = Color(0xFF26334D);     // Subtle Slate Border

  static const Color primaryBlue = Color(0xFF2563EB);    // Academic Royal Blue
  static const Color primaryBlueLight = Color(0xFF60A5FA);
  static const Color accentGold = Color(0xFFF59E0B);     // Mathematical Gold
  static const Color accentEmerald = Color(0xFF10B981);  // Verified Status

  static const Color textLight = Color(0xFFF8FAFC);     // Formula White
  static const Color textMuted = Color(0xFF94A3B8);     // Secondary Text
  static const Color textDark = Color(0xFF0F172A);

  static ThemeData get academicDarkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentGold,
        surface: surfaceDark,
        onSurface: textLight,
        error: Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 1.8),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceElevated,
        selectedColor: primaryBlue.withAlpha(50),
        side: const BorderSide(color: cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontSize: 12, color: textLight),
      ),
    );
  }
}
