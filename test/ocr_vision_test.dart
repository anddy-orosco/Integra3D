import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/ocr/data/datasources/gemini_vision_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiVisionService Tests', () {
    test('parses structured JSON into OcrIntegralResult accurately', () async {
      // Mock Dio adapter returning standard Gemini multimodal payload
      final dio = Dio();
      final sampleJsonResponse = {
        'dimension': 2,
        'coordinate_system': 'cartesian',
        'integrand': 'x * y^2',
        'bounds': [
          {'variable': 'x', 'lower': '0', 'upper': '3*y - 5'},
          {'variable': 'y', 'lower': '-2', 'upper': '1'},
        ],
        'raw_latex': r'\int_{-2}^{1} \int_{0}^{3y-5} x y^2 \, dx \, dy',
        'confidence': 0.96,
      };

      final geminiWrapperResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': jsonEncode(sampleJsonResponse)}
              ]
            }
          }
        ]
      };

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: geminiWrapperResponse,
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final service = GeminiVisionService(dio: dio);
      final result = await service.transcribe(
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        filename: 'integral.jpg',
        customApiKey: 'TEST_KEY',
      );

      expect(result.dimension, 2);
      expect(result.integrand, 'x*y^2');
      expect(result.bounds.length, 2);
      expect(result.bounds[0].variable, 'x');
      expect(result.bounds[0].lower, '0');
      expect(result.bounds[0].upper, '3*y - 5');
      expect(result.bounds[1].variable, 'y');
      expect(result.bounds[1].lower, '-2');
      expect(result.bounds[1].upper, '1');
      expect(result.coordinateSystem, CoordinateSystemType.cartesian);
      expect(result.confidence, 0.96);
    });

    test('parses triple integral accurately', () async {
      final dio = Dio();
      final sampleJsonResponse = {
        'dimension': 3,
        'coordinate_system': 'cartesian',
        'integrand': 'z',
        'bounds': [
          {'variable': 'z', 'lower': '0', 'upper': '1 - x - y'},
          {'variable': 'y', 'lower': '0', 'upper': '1 - x'},
          {'variable': 'x', 'lower': '0', 'upper': '1'},
        ],
        'raw_latex': r'\int_0^1 \int_0^{1-x} \int_0^{1-x-y} z \, dz \, dy \, dx',
        'confidence': 0.99,
      };

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': jsonEncode(sampleJsonResponse)}
                        ]
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

      final service = GeminiVisionService(dio: dio);
      final result = await service.transcribe(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        filename: 'triple.png',
        customApiKey: 'TEST_KEY',
      );

      expect(result.dimension, 3);
      expect(result.integrand, 'z');
      expect(result.bounds.length, 3);
      expect(result.bounds[0].variable, 'z');
      expect(result.bounds[1].variable, 'y');
      expect(result.bounds[2].variable, 'x');
    });
  });
}
