import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Utilidades de diseño responsivo y detección de plataforma (Móvil, iPad/Tablets, macOS, Windows).
class ResponsiveLayout {
  static const double compactBreakpoint = 600.0;
  static const double mediumBreakpoint = 960.0;
  static const double largeBreakpoint = 1280.0;

  /// Dispositivos móviles (iPhone, Android) en orientación vertical (< 600dp).
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactBreakpoint;

  /// Tablets e iPads en orientación vertical (600dp a 960dp).
  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compactBreakpoint && width < mediumBreakpoint;
  }

  /// Pantallas amplias: iPads en horizontal y Escritorio macOS/Windows (>= 960dp).
  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mediumBreakpoint;

  /// Monitores de escritorio amplios (>= 1280dp).
  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= largeBreakpoint;

  /// Indica si la plataforma nativa es de escritorio (macOS, Windows o Linux).
  static bool get isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  /// Indica si es un entorno Apple (macOS o iOS/iPadOS).
  static bool get isApplePlatform {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isIOS;
  }
}
