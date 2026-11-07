import 'integration_bound.dart';

enum CoordinateSystemType {
  cartesian,
  cylindrical,
  spherical;

  String get label {
    switch (this) {
      case CoordinateSystemType.cartesian:
        return 'Cartesianas (x, y, z)';
      case CoordinateSystemType.cylindrical:
        return 'Cilíndricas (r, θ, z)';
      case CoordinateSystemType.spherical:
        return 'Esféricas (ρ, θ, φ)';
    }
  }

  String get apiValue => name;
}

class MultivariableIntegral {
  final String integrand;
  final List<IntegrationBound> bounds;
  final CoordinateSystemType coordinateSystem;

  const MultivariableIntegral({
    required this.integrand,
    required this.bounds,
    this.coordinateSystem = CoordinateSystemType.cartesian,
  });

  int get dimension => bounds.length;

  MultivariableIntegral copyWith({
    String? integrand,
    List<IntegrationBound>? bounds,
    CoordinateSystemType? coordinateSystem,
  }) {
    return MultivariableIntegral(
      integrand: integrand ?? this.integrand,
      bounds: bounds ?? this.bounds,
      coordinateSystem: coordinateSystem ?? this.coordinateSystem,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'integrand': integrand,
      'bounds': bounds.map((b) => b.toJson()).toList(),
      'coordinate_system': coordinateSystem.apiValue,
    };
  }
}
