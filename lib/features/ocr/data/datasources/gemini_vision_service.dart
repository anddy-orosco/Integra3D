import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../calculator/domain/entities/integration_bound.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../calculator/domain/services/integral_expression_transformer.dart';
import '../../domain/entities/ocr_integral_result.dart';

/// Servicio de Reconocimiento Óptico Matemático con Visión Multimodal (Gemini 1.5 Flash).
/// Transcribe cualquier foto de ejercicios de integrales dobles o triples (impresas o manuscritas)
/// directamente desde el dispositivo (Android, iOS o Web).
class GeminiVisionService {
  static const String _prefKey = 'integra3d_gemini_api_key';
  static const String _defaultEnvKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  final Dio _dio;

  GeminiVisionService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 25),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  /// Obtiene la clave de API guardada o la definida por entorno.
  Future<String?> getApiKey() async {
    if (_defaultEnvKey.isNotEmpty) return _defaultEnvKey;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    return (saved != null && saved.trim().isNotEmpty) ? saved.trim() : null;
  }

  /// Guarda la clave de API en almacenamiento local persistente (Android / iOS).
  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, key.trim());
  }

  /// Elimina la clave de API guardada.
  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  /// Transcribe los bytes de la imagen a una entidad formal de cálculo multivariable.
  Future<OcrIntegralResult> transcribe({
    required Uint8List imageBytes,
    required String filename,
    String? customApiKey,
  }) async {
    final apiKey = customApiKey ?? await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('KEY_REQUIRED');
    }

    final mimeType = filename.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final base64Image = base64Encode(imageBytes);

    const systemPrompt = '''
You are an expert mathematical OCR and Multivariable Calculus engine for an educational app.
Examine the image containing a multiple integral (double or triple integral).
Transcribe it into a single valid JSON object with the following exact structure:
{
  "dimension": 2,
  "coordinate_system": "cartesian",
  "integrand": "normalized integrand expression using standard arithmetic (*, ^, /, +, -)",
  "bounds": [
    {
      "variable": "inner variable name (e.g. x)",
      "lower": "lower bound expression",
      "upper": "upper bound expression"
    },
    {
      "variable": "outer variable name (e.g. y)",
      "lower": "lower bound expression",
      "upper": "upper bound expression"
    }
  ],
  "raw_latex": "\\int_{...}^{...} \\int_{...}^{...} ... \\, dx \\, dy",
  "confidence": 0.95
}

Important Rules:
1. Order of bounds MUST match the differentials from inside to outside:
   - bounds[0] corresponds to the innermost integral and innermost differential (e.g. dx).
   - bounds[1] corresponds to the outermost integral and outermost differential (e.g. dy).
   - (and bounds[2] if it is a triple integral, e.g. dz).
2. Explicitly include multiplication '*' where implied (e.g., '3*y - 5', 'x * y^2', '4*x').
3. Keep exponents with '^' (e.g. 'y^2', 'x^3').
4. If bounds are square roots, use 'sqrt(...)' (e.g., 'sqrt(4 - x^2)').
5. Do NOT include any markdown code fences like ```json or comments. Return ONLY the raw JSON string.
''';

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': systemPrompt},
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
        'temperature': 0.1,
        'response_mime_type': 'application/json',
      }
    };

    final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final response = await _dio.post(url, data: payload);

    if (response.statusCode != 200) {
      throw Exception('Error del servicio Gemini Vision: HTTP ${response.statusCode}');
    }

    final data = response.data as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No se detectó contenido matemático en la imagen.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List<dynamic>;
    final rawText = parts[0]['text'] as String;

    final cleanedJson = rawText
        .trim()
        .replaceFirst(RegExp(r'^```json\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

    final jsonMap = jsonDecode(cleanedJson) as Map<String, dynamic>;

    final dimension = jsonMap['dimension'] as int? ?? 2;
    final rawIntegrand = jsonMap['integrand'] as String? ?? '1';
    final rawLatex = jsonMap['raw_latex'] as String? ?? '';
    final confidence = (jsonMap['confidence'] as num?)?.toDouble() ?? 0.95;

    final rawBounds = (jsonMap['bounds'] as List<dynamic>?) ?? [];
    final bounds = rawBounds.map((b) {
      final map = b as Map<String, dynamic>;
      final v = (map['variable'] as String? ?? 'x').toLowerCase();
      final l = IntegralExpressionTransformer.normalizeExpression(map['lower']?.toString() ?? '0');
      final u = IntegralExpressionTransformer.normalizeExpression(map['upper']?.toString() ?? '1');
      return IntegrationBound(variable: v, lower: l, upper: u);
    }).toList();

    CoordinateSystemType coordType = CoordinateSystemType.cartesian;
    final coordStr = (jsonMap['coordinate_system'] as String? ?? 'cartesian').toLowerCase();
    if (coordStr.contains('cylindrical') || coordStr.contains('polar')) {
      coordType = CoordinateSystemType.cylindrical;
    } else if (coordStr.contains('spherical')) {
      coordType = CoordinateSystemType.spherical;
    }

    return OcrIntegralResult(
      dimension: dimension,
      integrand: IntegralExpressionTransformer.normalizeExpression(rawIntegrand),
      bounds: bounds,
      coordinateSystem: coordType,
      rawLatex: rawLatex.isNotEmpty ? rawLatex : IntegralExpressionTransformer.toLatex(
        MultivariableIntegral(
          integrand: rawIntegrand,
          bounds: bounds,
          coordinateSystem: coordType,
        ),
      ),
      confidence: confidence,
    );
  }
}
