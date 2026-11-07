import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/api_constants.dart';
import '../../domain/entities/ocr_integral_result.dart';
import 'gemini_vision_service.dart';

class OcrNeedsApiKeyException implements Exception {
  final String message;
  const OcrNeedsApiKeyException([this.message = 'Se requiere una API Key de Gemini para transcribir fotos arbitrarias con IA.']);

  @override
  String toString() => message;
}

abstract class OcrRemoteDataSource {
  Future<OcrIntegralResult> transcribeImage(XFile imageFile, {String? customApiKey});
  Future<String?> getSavedApiKey();
  Future<void> saveApiKey(String key);
  Future<void> clearApiKey();
}

class OcrRemoteDataSourceImpl implements OcrRemoteDataSource {
  final Dio dio;
  final GeminiVisionService geminiVisionService;

  OcrRemoteDataSourceImpl({Dio? dioClient, GeminiVisionService? geminiService})
      : dio = dioClient ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 12),
              ),
            ),
        geminiVisionService = geminiService ?? GeminiVisionService();

  @override
  Future<String?> getSavedApiKey() => geminiVisionService.getApiKey();

  @override
  Future<void> saveApiKey(String key) => geminiVisionService.saveApiKey(key);

  @override
  Future<void> clearApiKey() => geminiVisionService.clearApiKey();

  @override
  Future<OcrIntegralResult> transcribeImage(XFile imageFile, {String? customApiKey}) async {
    final bytes = await imageFile.readAsBytes();

    // 1. Primer intento: Gemini Vision AI directo desde Flutter (Android, iOS y Web)
    try {
      final geminiResult = await geminiVisionService.transcribe(
        imageBytes: bytes,
        filename: imageFile.name,
        customApiKey: customApiKey,
      );
      return OcrIntegralResult(
        dimension: geminiResult.dimension,
        integrand: geminiResult.integrand,
        bounds: geminiResult.bounds,
        coordinateSystem: geminiResult.coordinateSystem,
        rawLatex: geminiResult.rawLatex,
        confidence: geminiResult.confidence,
        imagePath: imageFile.path,
      );
    } catch (e) {
      if (!e.toString().contains('KEY_REQUIRED')) {
        // Si hay una clave pero falló por cuota o red, relanzar para notificar al usuario
        rethrow;
      }
    }

    // 2. Segundo intento: Servidor Python local si está ejecutándose
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: imageFile.name,
        ),
      });

      final response = await dio.post(
        '/api/v1/ocr/transcribe',
        data: formData,
      );

      if (response.statusCode == 200) {
        return OcrIntegralResult.fromJson(
          response.data as Map<String, dynamic>,
          localImagePath: imageFile.path,
        );
      }
    } catch (_) {
      // Backend local desconectado
    }

    // 3. Si no hay clave de Gemini y el backend no está disponible, solicitar clave al usuario
    throw const OcrNeedsApiKeyException();
  }
}
