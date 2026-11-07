import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../domain/entities/integral_solution.dart';

abstract class SolverRemoteDataSource {
  Future<IntegralSolution> solveIntegral(MultivariableIntegral integral);
  Future<Map<String, dynamic>> getMesh(MultivariableIntegral integral);
  Future<List<PedagogicalSection>> getExplanation(MultivariableIntegral integral);
  Future<List<Map<String, dynamic>>> getPresets();
}

class SolverRemoteDataSourceImpl implements SolverRemoteDataSource {
  final Dio dio;

  SolverRemoteDataSourceImpl({Dio? dioClient})
      : dio = dioClient ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: ApiConstants.timeout,
                receiveTimeout: ApiConstants.timeout,
                headers: {'Content-Type': 'application/json'},
              ),
            );

  @override
  Future<IntegralSolution> solveIntegral(MultivariableIntegral integral) async {
    try {
      final response = await dio.post(
        ApiConstants.solveEndpoint,
        data: integral.toJson(),
      );

      if (response.statusCode == 200) {
        return IntegralSolution.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw const ServerFailure();
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkFailure(
          'No se pudo conectar al motor SymPy en ${dio.options.baseUrl}. '
          'Verifica que el servicio Python esté ejecutándose (python backend/main.py).',
        );
      }
      final msg = e.response?.data?['detail'] ?? e.message ?? 'Error de cálculo';
      throw CalculationFailure(msg.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw CalculationFailure(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getMesh(MultivariableIntegral integral) async {
    try {
      final response = await dio.post(
        ApiConstants.meshEndpoint,
        data: integral.toJson(),
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
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
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPresets() async {
    try {
      final response = await dio.get(ApiConstants.presetsEndpoint);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data as List);
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
