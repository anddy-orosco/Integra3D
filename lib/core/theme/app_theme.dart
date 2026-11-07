import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'math_colors.dart';

/// Configuración centralizada del tema Material 3 para Integra3D.
/// Aplica estrictamente la especificación "Dark Matrix & Spectral 3D".
abstract final class AppTheme {
  // Re-exportar colores clave para retrocompatibilidad y ergonomía
  static const Color darkBackground = AppColors.deepVoid;
  static const Color surfaceDark = AppColors.slateDark;
  static const Color surfaceElevated = AppColors.slateElevated;
  static const Color cardBorder = AppColors.borderSubtle;

  static const Color primaryAction = AppColors.cyberEmerald;
  static const Color secondaryAccent = AppColors.electricCyan;
  static const Color meshSurface = AppColors.violetHeatmap;
  static const Color alertWarning = AppColors.amberGlow;

  static const Color textLight = AppColors.pureWhite;
  static const Color textMuted = AppColors.mutedGray;

  static ThemeData get darkMatrixTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.deepVoid,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyberEmerald,
        onPrimary: AppColors.deepVoid,
        secondary: AppColors.electricCyan,
        onSecondary: AppColors.deepVoid,
        tertiary: AppColors.violetHeatmap,
        surface: AppColors.slateDark,
        onSurface: AppColors.pureWhite,
        error: AppColors.coralFlame,
        outline: AppColors.borderSubtle,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepVoid,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.pureWhite),
        titleTextStyle: TextStyle(
          color: AppColors.pureWhite,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.slateDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyberEmerald,
          foregroundColor: AppColors.deepVoid,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slateElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.electricCyan, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColors.mutedGray, fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF6E7681), fontSize: 13),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.slateDark,
        selectedColor: AppColors.electricCyan.withAlpha(40),
        side: const BorderSide(color: AppColors.borderSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.pureWhite),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
      ),
      extensions: [
        MathColors.darkMatrix(),
      ],
    );
  }

  // Alias para mantener compatibilidad existente
  static ThemeData get academicDarkTheme => darkMatrixTheme;
}
