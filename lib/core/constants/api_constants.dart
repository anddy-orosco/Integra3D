import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 points to host loopback interface in Android Emulator
      return 'http://10.0.2.2:8000';
    }
    // macOS, iOS, Linux, Windows
    return 'http://127.0.0.1:8000';
  }

  static const String solveEndpoint = '/api/v1/integral/solve';
  static const String meshEndpoint = '/api/v1/integral/mesh';
  static const String explainEndpoint = '/api/v1/integral/explain';
  static const String presetsEndpoint = '/api/v1/integral/presets';
  static const String healthEndpoint = '/api/v1/health';

  static const Duration timeout = Duration(seconds: 15);
}
