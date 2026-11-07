import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:integra_3d/features/calculator/domain/services/integral_expression_transformer.dart';
import 'package:integra_3d/features/ocr/domain/services/math_ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MathOcrService Resilience & Fallback Tests', () {
    test('cleans raw LaTeX with markdown codeblocks or mode delimiters', () {
      const rawWithMarkdown = "```latex\n\\int_{0}^{1}\\int_{0}^{2-2x}(6-2x-y)\\,dy\\,dx\n```";
      final parsed = IntegralExpressionTransformer.parseFullIntegral(
        rawWithMarkdown.replaceAll('```latex', '').replaceAll('```', '').trim(),
      );

      expect(parsed, isNotNull);
      expect(parsed!.dimension, 2);
      expect(parsed.bounds[0].variable, 'y');
      expect(parsed.bounds[0].lower, '0');
      expect(parsed.bounds[0].upper, '2 - 2*x');
      expect(parsed.bounds[1].variable, 'x');
      expect(parsed.bounds[1].lower, '0');
      expect(parsed.bounds[1].upper, '1');
      expect(parsed.integrand, '6 - 2*x - y');
    });

    test('automatic fallback on 429 Rate Limit updates status and switches provider', () async {
      final dio = Dio();

      // Interceptor que simula 429 en el primer endpoint
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.host.contains('generativelanguage')) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 429,
                    statusMessage: 'Rate limit exceeded',
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            }
            // Los siguientes endpoints devuelven el LaTeX esperado
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'choices': [
                    {
                      'message': {
                        'content': r'\int_{0}^{1}\int_{0}^{2-2x}(6-2x-y)\,dy\,dx',
                      }
                    }
                  ]
                },
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final service = MathOcrService(dioClient: dio);
      final statusLogs = <String>[];

      final result = await service.transcribe(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        filename: 'exercise.jpg',
        onStatusUpdate: (msg) => statusLogs.add(msg),
      );

      expect(result.rawLatex, contains(r'\int'));
      // Verifica que se informó al estudiante amigablemente del cambio de servidor
      expect(statusLogs, contains('Optimizando conexión con servidor alternativo...'));
      expect(result.provider, isNot(OcrProviderType.geminiFlashPrimary));
    });

    test('parses prompt example accurately: int_0^1 int_0^{2-2x} (6-2x-y) dy dx', () {
      const example = r'\int_{0}^{1}\int_{0}^{2-2x}(6-2x-y)\,dy\,dx';
      final integral = IntegralExpressionTransformer.parseFullIntegral(example);

      expect(integral, isNotNull);
      expect(integral!.dimension, 2);
      expect(integral.bounds[0].variable, 'y');
      expect(integral.bounds[0].lower, '0');
      expect(integral.bounds[0].upper, '2 - 2*x');
      expect(integral.bounds[1].variable, 'x');
      expect(integral.bounds[1].lower, '0');
      expect(integral.bounds[1].upper, '1');
      expect(integral.integrand, '6 - 2*x - y');
    });
  });
}
