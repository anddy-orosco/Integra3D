import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../calculator/domain/services/integral_expression_transformer.dart';

enum OcrProviderType {
  geminiFlashPrimary,
  openRouterFreeFallback,
  siliconFlowFallback,
  academicHeuristicFallback,
}

class MathOcrApiKeyRequiredException implements Exception {
  final String message;
  const MathOcrApiKeyRequiredException([
    this.message = 'Se requiere una API Key de Google Gemini para transcribir fotos arbitrarias con IA.',
  ]);

  @override
  String toString() => message;
}

class MathOcrTranscriptionException implements Exception {
  final String message;
  const MathOcrTranscriptionException(this.message);

  @override
  String toString() => message;
}

class MathOcrResult {
  final String rawLatex;
  final OcrProviderType provider;
  final double confidence;
  final String? providerMessage;

  const MathOcrResult({
    required this.rawLatex,
    required this.provider,
    this.confidence = 0.95,
    this.providerMessage,
  });

  MultivariableIntegral? toIntegral() {
    return IntegralExpressionTransformer.parseFullIntegral(rawLatex);
  }
}

/// Servicio resiliente de transcripción matemática de fotos a LaTeX.
/// Implementa arquitectura de tolerancia a fallos con rotación automática de proveedores
/// ante errores de saturación (429 Rate Limit) o caída de servidores (503).
class MathOcrService {
  static const String _userApiKeyPref = 'integra3d_byok_gemini_key';
  static const String _defaultEnvKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  // Clave comunitaria preconfigurada para acceso sin registro ni barreras para estudiantes
  static const String _communityGeminiPool = String.fromEnvironment(
    'COMMUNITY_GEMINI_KEY',
    defaultValue: 'AIzaSyDemoCommunityKeyPoolIntegra3D',
  );

  final Dio _dio;

  MathOcrService({Dio? dioClient})
      : _dio = dioClient ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 22),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  /// Prompt determinista para extracción matemática estricta sin texto conversacional.
  static const String visionPrompt = '''
Analiza la imagen adjunta con el ejercicio de cálculo integral multivariable.
Tu única tarea es transcribir la integral matemáticamente exacta a formato LaTeX puro.
Reglas:
1. Responde ÚNICAMENTE con la cadena de texto LaTeX. Sin bloques de código markdown (sin ```latex), sin saludos, sin explicaciones.
2. Identifica correctamente integrales dobles (\\iint o \\int \\int) o triples (\\iiint).
3. Asegura que los límites inferiores y superiores correspondan exactamente a los diferenciales respectivos (dy, dx, dz).
Ejemplo de salida esperada: \\int_{0}^{1}\\int_{0}^{2-2x}(6-2x-y)\\,dy\\,dx
''';

  // ==========================================
  // GESTIÓN BYOK (Bring Your Own Key) OPCIONAL
  // ==========================================

  Future<String?> getUserApiKey() async {
    if (_defaultEnvKey.isNotEmpty) return _defaultEnvKey;
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_userApiKeyPref);
    return (key != null && key.trim().isNotEmpty) ? key.trim() : null;
  }

  Future<void> saveUserApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userApiKeyPref, key.trim());
  }

  Future<void> clearUserApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userApiKeyPref);
  }

  Future<bool> hasCustomApiKey() async {
    final key = await getUserApiKey();
    return key != null && key.isNotEmpty;
  }

  // ==========================================
  // CADENA DE FALLBACK RESILIENTE
  // ==========================================

  /// Transcribe los bytes comprimidos de la imagen con reintento y rotación transparente.
  Future<MathOcrResult> transcribe({
    required Uint8List imageBytes,
    String filename = 'exercise.jpg',
    void Function(String statusMessage)? onStatusUpdate,
  }) async {
    onStatusUpdate?.call('Analizando ejercicio con visión multimodal...');

    final userKey = await getUserApiKey();
    final hasUserKey = userKey != null && userKey.trim().isNotEmpty;
    final primaryKey = hasUserKey ? userKey.trim() : _communityGeminiPool;

    // Si no hay clave real configurada ni por entorno ni por usuario
    if (!hasUserKey && (_communityGeminiPool.isEmpty || _communityGeminiPool.contains('DemoCommunity'))) {
      throw const MathOcrApiKeyRequiredException();
    }

    // TIER 1: Proveedor Primario (Gemini Flash oficial Google AI Studio)
    try {
      final latex = await _callGeminiFlash(imageBytes, filename, primaryKey);
      if (_isValidLatex(latex)) {
        return MathOcrResult(
          rawLatex: latex,
          provider: OcrProviderType.geminiFlashPrimary,
          confidence: 0.98,
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 429 || statusCode == 503 || statusCode == 403) {
        onStatusUpdate?.call('Optimizando conexión con servidor alternativo...');
      }
    } catch (_) {
      onStatusUpdate?.call('Optimizando conexión con servidor alternativo...');
    }

    // TIER 2: Proveedor Secundario de Respaldo (OpenRouter Free Vision)
    try {
      onStatusUpdate?.call('Optimizando conexión con servidor alternativo...');
      final latex = await _callOpenRouterFreeVision(imageBytes, filename);
      if (_isValidLatex(latex)) {
        return MathOcrResult(
          rawLatex: latex,
          provider: OcrProviderType.openRouterFreeFallback,
          confidence: 0.94,
          providerMessage: 'Procesado con servidor alternativo',
        );
      }
    } catch (_) {
      // Continuar al siguiente nivel de resiliencia
    }

    // TIER 3: Proveedor de Respaldo Rápido (SiliconFlow / Cloudflare OpenAI format)
    try {
      final latex = await _callSiliconFlowVision(imageBytes, filename);
      if (_isValidLatex(latex)) {
        return MathOcrResult(
          rawLatex: latex,
          provider: OcrProviderType.siliconFlowFallback,
          confidence: 0.92,
        );
      }
    } catch (_) {
      // Continuar al manejo honesto de error
    }

    // NUNCA devolver un resultado falso inventado: si los servicios no pudieron leer la foto,
    // se notifica con honestidad al usuario para que vuelva a enfocar o use el teclado.
    throw const MathOcrTranscriptionException(
      'No se pudo transcribir la integral de la imagen. Verifica que esté nítida y bien iluminada, o ingrésala con el teclado matemático.',
    );
  }

  // ==========================================
  // LLAMADAS HTTP ESPECÍFICAS POR PROVEEDOR
  // ==========================================

  Future<String> _callGeminiFlash(Uint8List imageBytes, String filename, String apiKey) async {
    final mimeType = filename.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final base64Image = base64Encode(imageBytes);

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': visionPrompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.0, // Máximo determinismo
        'maxOutputTokens': 256,
      }
    };

    final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';
    final response = await _dio.post(url, data: payload);

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>;
        final parts = content['parts'] as List<dynamic>;
        final raw = parts[0]['text'] as String;
        return _cleanLatexResponse(raw);
      }
    }
    throw Exception('Gemini response invalid');
  }

  Future<String> _callOpenRouterFreeVision(Uint8List imageBytes, String filename) async {
    final mimeType = filename.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final base64Image = base64Encode(imageBytes);
    final dataUri = 'data:$mimeType;base64,$base64Image';

    final payload = {
      'model': 'qwen/qwen-2.5-vl-72b-instruct:free',
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': visionPrompt},
            {'type': 'image_url', 'image_url': {'url': dataUri}}
          ]
        }
      ],
      'temperature': 0.0,
      'max_tokens': 200,
    };

    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      data: payload,
      options: Options(
        headers: {
          'HTTP-Referer': 'https://integra3d.app',
          'X-Title': 'Integra3D Mobile',
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>;
        final raw = message['content'] as String;
        return _cleanLatexResponse(raw);
      }
    }
    throw Exception('OpenRouter response invalid');
  }

  Future<String> _callSiliconFlowVision(Uint8List imageBytes, String filename) async {
    final mimeType = filename.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final base64Image = base64Encode(imageBytes);
    final dataUri = 'data:$mimeType;base64,$base64Image';

    final payload = {
      'model': 'Pro/Qwen/Qwen2-VL-7B-Instruct',
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': visionPrompt},
            {'type': 'image_url', 'image_url': {'url': dataUri}}
          ]
        }
      ],
      'temperature': 0.0,
      'max_tokens': 180,
    };

    final response = await _dio.post(
      'https://api.siliconflow.cn/v1/chat/completions',
      data: payload,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>;
        final raw = message['content'] as String;
        return _cleanLatexResponse(raw);
      }
    }
    throw Exception('SiliconFlow response invalid');
  }

  // ==========================================
  // SANITIZACIÓN Y VALIDACIÓN MATEMÁTICA
  // ==========================================

  static String _cleanLatexResponse(String raw) {
    String clean = raw.trim();

    // Eliminar bloques markdown (```latex ... ``` o ``` ...)
    clean = clean.replaceFirst(RegExp(r'^```(?:latex|tex)?\s*', caseSensitive: false), '');
    clean = clean.replaceFirst(RegExp(r'\s*```$', caseSensitive: false), '');

    // Eliminar envoltorios de modo matemático $$ ... $$ o $ ... $
    clean = clean.replaceFirst(RegExp(r'^\$\$?\s*'), '');
    clean = clean.replaceFirst(RegExp(r'\s*\$\$?$'), '');

    // Eliminar posibles prefijos de texto introductorio
    final intIndex = clean.indexOf(r'\int');
    if (intIndex > 0) {
      clean = clean.substring(intIndex);
    }

    return clean.trim();
  }

  static bool _isValidLatex(String latex) {
    if (latex.isEmpty) return false;
    final containsIntegral = latex.contains(r'\int') || latex.contains(r'\iint') || latex.contains(r'\iiint');
    final containsDifferential = latex.contains('dx') || latex.contains('dy') || latex.contains('dz') || latex.contains('dr') || latex.contains(r'd\theta');
    return containsIntegral && containsDifferential;
  }
}
