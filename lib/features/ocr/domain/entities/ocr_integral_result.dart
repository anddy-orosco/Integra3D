import '../../../calculator/domain/entities/integration_bound.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';

class OcrIntegralResult {
  final String integrand;
  final int dimension;
  final CoordinateSystemType coordinateSystem;
  final List<IntegrationBound> bounds;
  final String rawLatex;
  final double confidence;
  final String? imagePath;

  const OcrIntegralResult({
    required this.integrand,
    required this.dimension,
    required this.coordinateSystem,
    required this.bounds,
    required this.rawLatex,
    this.confidence = 0.95,
    this.imagePath,
  });

  MultivariableIntegral toMultivariableIntegral() {
    return MultivariableIntegral(
      integrand: integrand,
      bounds: bounds,
      coordinateSystem: coordinateSystem,
    );
  }

  factory OcrIntegralResult.fromJson(Map<String, dynamic> json, {String? localImagePath}) {
    final rawBounds = (json['bounds'] as List<dynamic>?) ?? [];
    final bounds = rawBounds
        .map((b) => IntegrationBound.fromJson(b as Map<String, dynamic>))
        .toList();

    CoordinateSystemType coordType = CoordinateSystemType.cartesian;
    final coordStr = (json['coordinate_system'] as String?)?.toLowerCase() ?? 'cartesian';
    if (coordStr == 'cylindrical') {
      coordType = CoordinateSystemType.cylindrical;
    } else if (coordStr == 'spherical') {
      coordType = CoordinateSystemType.spherical;
    }

    return OcrIntegralResult(
      integrand: json['integrand'] as String? ?? '4 - x^2 - y^2',
      dimension: json['dimension'] as int? ?? (bounds.length == 3 ? 3 : 2),
      coordinateSystem: coordType,
      bounds: bounds,
      rawLatex: json['raw_latex'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.92,
      imagePath: localImagePath,
    );
  }
}
