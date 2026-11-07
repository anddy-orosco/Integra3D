import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../calculator/domain/services/local_math_engine.dart';
import '../../domain/entities/integral_solution.dart';

abstract class SolverRemoteDataSource {
  Future<IntegralSolution> solveIntegral(MultivariableIntegral integral);
  Future<Map<String, dynamic>> getMesh(MultivariableIntegral integral);
  Future<List<PedagogicalSection>> getExplanation(MultivariableIntegral integral);
  Future<List<Map<String, dynamic>>> getPresets();
  Future<bool> checkBackendHealth();
}

class SolverRemoteDataSourceImpl implements SolverRemoteDataSource {
  final Dio dio;

  SolverRemoteDataSourceImpl({Dio? dioClient})
      : dio = dioClient ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: const Duration(seconds: 2), // Fast fallback
                receiveTimeout: const Duration(seconds: 5),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  @override
  Future<bool> checkBackendHealth() async {
    try {
      final res = await dio.get(ApiConstants.healthEndpoint);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<IntegralSolution> solveIntegral(MultivariableIntegral integral) async {
    try {
      final response = await dio.post(
        ApiConstants.solveEndpoint,
        data: integral.toJson(),
      );

      if (response.statusCode == 200) {
        return IntegralSolution.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {
      // Backend not running -> Seamless fallback to Local Mathematical Engine
    }

    // Fallback: Calculate autonomously in Dart
    return LocalMathEngine.solveLocal(integral);
  }

  @override
  Future<Map<String, dynamic>> getMesh(MultivariableIntegral integral) async {
    try {
      final response = await dio.post(
        ApiConstants.meshEndpoint,
        data: integral.toJson(),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data.isNotEmpty && data['vertices'] != null) {
          return data;
        }
      }
    } catch (_) {
      // Fallback
    }

    // Fallback: Generate 3D mesh points in Dart
    return LocalMathEngine.generateLocalMesh(integral);
  }

  @override
  Future<List<PedagogicalSection>> getExplanation(MultivariableIntegral integral) async {
    try {
      final response = await dio.post(
        ApiConstants.explainEndpoint,
        data: integral.toJson(),
      );
      if (response.statusCode == 200) {
        final sections = (response.data['sections'] as List<dynamic>?) ?? [];
        return sections
            .map((s) => PedagogicalSection.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fallback
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getPresets() async {
    try {
      final response = await dio.get(ApiConstants.presetsEndpoint);
      if (response.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(response.data as List);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {
      // Fallback
    }
    return LocalMathEngine.builtInPresets;
  }
}
