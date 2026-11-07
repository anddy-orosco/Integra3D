import 'package:flutter/material.dart';

/// Paleta de Colores Oficial de Integra3D: Dark Matrix & Spectral 3D.
/// Define las constantes inmutables para el sistema de diseño técnico y académico.
abstract final class AppColors {
  // Canvas & Superficies Base
  static const Color deepVoid = Color(0xFF0D1117);      // Canvas / Fondo Principal & Visor 3D
  static const Color slateDark = Color(0xFF161B22);     // Superficies, Cards explicativas & Modales
  static const Color slateElevated = Color(0xFF21262D); // Campos de entrada & Componentes elevados
  static const Color borderSubtle = Color(0xFF30363D);  // Bordes tenues de tarjetas y divisores

  // Acciones y Énfasis Funcional
  static const Color cyberEmerald = Color(0xFF10B981);  // Acción Primaria / Botón Calcular
  static const Color electricCyan = Color(0xFF06B6D4);  // Acento Secundario / Derivadas / Límites
  static const Color violetHeatmap = Color(0xFF8B5CF6); // Superficies y Mallas 3D (f(x,y))
  static const Color amberGlow = Color(0xFFF59E0B);     // Alertas / Advertencias Matemáticas

  // Ejes de Coordenadas 3D Estándar (Vectores Canónicos)
  static const Color coralFlame = Color(0xFFFF5757);   // Eje X (Abscisas / î)
  static const Color limePhosphor = Color(0xFF22C55E); // Eje Y (Ordenadas / ĵ)
  static const Color neonSky = Color(0xFF3B82F6);      // Eje Z (Cotas / k̂)

  // Tipografía & Notación Científica
  static const Color pureWhite = Color(0xFFF0F6FC);    // Texto Principal & Fórmulas LaTeX
  static const Color mutedGray = Color(0xFF8B949E);    // Texto Secundario & Metadatos
}
