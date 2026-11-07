import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Extensión de tema personalizada para conceptos matemáticos y coordenadas 3D en Integra3D.
/// Permite acceder de forma semántica y tipada a los colores técnicos mediante:
/// `Theme.of(context).extension<MathColors>()` o `context.mathColors`.
@immutable
class MathColors extends ThemeExtension<MathColors> {
  final Color axisX;          // Eje X (Abscisas / î) - Coral Flame
  final Color axisY;          // Eje Y (Ordenadas / ĵ) - Lime Phosphor
  final Color axisZ;          // Eje Z (Cotas / k̂) - Neon Sky
  final Color meshSurface;    // Malla f(x,y) - Violet Heatmap
  final Color secondaryAccent;// Derivadas / Límites - Electric Cyan
  final Color primaryAction;  // Acción Principal - Cyber Emerald
  final Color mathWarning;    // Alertas Matemáticas - Amber Glow
  final Color formulaText;    // Fórmulas LaTeX - Pure White
  final Color metadataText;   // Metadatos - Muted Gray

  const MathColors({
    required this.axisX,
    required this.axisY,
    required this.axisZ,
    required this.meshSurface,
    required this.secondaryAccent,
    required this.primaryAction,
    required this.mathWarning,
    required this.formulaText,
    required this.metadataText,
  });

  /// Configuración predeterminada basada en la especificación Dark Matrix & Spectral 3D.
  factory MathColors.darkMatrix() => const MathColors(
        axisX: AppColors.coralFlame,
        axisY: AppColors.limePhosphor,
        axisZ: AppColors.neonSky,
        meshSurface: AppColors.violetHeatmap,
        secondaryAccent: AppColors.electricCyan,
        primaryAction: AppColors.cyberEmerald,
        mathWarning: AppColors.amberGlow,
        formulaText: AppColors.pureWhite,
        metadataText: AppColors.mutedGray,
      );

  @override
  ThemeExtension<MathColors> copyWith({
    Color? axisX,
    Color? axisY,
    Color? axisZ,
    Color? meshSurface,
    Color? secondaryAccent,
    Color? primaryAction,
    Color? mathWarning,
    Color? formulaText,
    Color? metadataText,
  }) {
    return MathColors(
      axisX: axisX ?? this.axisX,
      axisY: axisY ?? this.axisY,
      axisZ: axisZ ?? this.axisZ,
      meshSurface: meshSurface ?? this.meshSurface,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      primaryAction: primaryAction ?? this.primaryAction,
      mathWarning: mathWarning ?? this.mathWarning,
      formulaText: formulaText ?? this.formulaText,
      metadataText: metadataText ?? this.metadataText,
    );
  }

  @override
  ThemeExtension<MathColors> lerp(
    covariant ThemeExtension<MathColors>? other,
    double t,
  ) {
    if (other is! MathColors) return this;
    return MathColors(
      axisX: Color.lerp(axisX, other.axisX, t)!,
      axisY: Color.lerp(axisY, other.axisY, t)!,
      axisZ: Color.lerp(axisZ, other.axisZ, t)!,
      meshSurface: Color.lerp(meshSurface, other.meshSurface, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      primaryAction: Color.lerp(primaryAction, other.primaryAction, t)!,
      mathWarning: Color.lerp(mathWarning, other.mathWarning, t)!,
      formulaText: Color.lerp(formulaText, other.formulaText, t)!,
      metadataText: Color.lerp(metadataText, other.metadataText, t)!,
    );
  }
}

/// Azúcar sintáctico para acceso rápido desde cualquier widget en el árbol.
extension MathColorsContextExtension on BuildContext {
  MathColors get mathColors =>
      Theme.of(this).extension<MathColors>() ?? MathColors.darkMatrix();
}
