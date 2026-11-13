import 'integration_bound.dart';

enum CoordinateSystemType {
  cartesian,
  polar,
  cylindrical,
  spherical;

  String get label {
    switch (this) {
      case CoordinateSystemType.cartesian:
        return 'Cartesianas (x, y, z)';
      case CoordinateSystemType.polar:
        return 'Polares (r, θ)';
      case CoordinateSystemType.cylindrical:
        return 'Cilíndricas (r, θ, z)';
      case CoordinateSystemType.spherical:
        return 'Esféricas (ρ, θ, φ)';
    }
  }

  String get apiValue => name;
}

enum ProblemMode {
  direct,
  regionCurves,
  regionVertices,
  planarArea,
  surfaceArea,
  volumeBetweenSurfaces,
  massAndCenterOfMass;

  String get label {
    switch (this) {
      case ProblemMode.direct:
        return 'Iterada Directa';
      case ProblemMode.regionCurves:
        return 'Región por Curvas';
      case ProblemMode.regionVertices:
        return 'Región por Vértices';
      case ProblemMode.planarArea:
        return 'Área Plana';
      case ProblemMode.surfaceArea:
        return 'Área de Superficie';
      case ProblemMode.volumeBetweenSurfaces:
        return 'Volumen entre Superficies';
      case ProblemMode.massAndCenterOfMass:
        return 'Masa y Centro de Masa';
    }
  }
}

class MultivariableIntegral {
  final String integrand;
  final List<IntegrationBound> bounds;
  final CoordinateSystemType coordinateSystem;
  final ProblemMode problemMode;
  final List<String> boundaryCurves;
  final List<String> verticesInput;
  final String? zLowerExpr;
  final String? zUpperExpr;
  final String? densityExpr;
  final String? uvTransformInput;
  final String? preferredOrder;

  const MultivariableIntegral({
    required this.integrand,
    required this.bounds,
    this.coordinateSystem = CoordinateSystemType.cartesian,
    this.problemMode = ProblemMode.direct,
    this.boundaryCurves = const [],
    this.verticesInput = const [],
    this.zLowerExpr,
    this.zUpperExpr,
    this.densityExpr,
    this.uvTransformInput,
    this.preferredOrder,
  });

  int get dimension => bounds.length;

  MultivariableIntegral copyWith({
    String? integrand,
    List<IntegrationBound>? bounds,
    CoordinateSystemType? coordinateSystem,
    ProblemMode? problemMode,
    List<String>? boundaryCurves,
    List<String>? verticesInput,
    String? zLowerExpr,
    String? zUpperExpr,
    String? densityExpr,
    String? uvTransformInput,
    String? preferredOrder,
  }) {
    return MultivariableIntegral(
      integrand: integrand ?? this.integrand,
      bounds: bounds ?? this.bounds,
      coordinateSystem: coordinateSystem ?? this.coordinateSystem,
      problemMode: problemMode ?? this.problemMode,
      boundaryCurves: boundaryCurves ?? this.boundaryCurves,
      verticesInput: verticesInput ?? this.verticesInput,
      zLowerExpr: zLowerExpr ?? this.zLowerExpr,
      zUpperExpr: zUpperExpr ?? this.zUpperExpr,
      densityExpr: densityExpr ?? this.densityExpr,
      uvTransformInput: uvTransformInput ?? this.uvTransformInput,
      preferredOrder: preferredOrder ?? this.preferredOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'integrand': integrand,
      'bounds': bounds.map((b) => b.toJson()).toList(),
      'coordinate_system': coordinateSystem.apiValue,
      if (problemMode != ProblemMode.direct) 'problem_mode': problemMode.name,
      if (boundaryCurves.isNotEmpty) 'boundary_curves': boundaryCurves,
      if (verticesInput.isNotEmpty) 'vertices_input': verticesInput,
      if (zLowerExpr != null) 'z_lower_expr': zLowerExpr,
      if (zUpperExpr != null) 'z_upper_expr': zUpperExpr,
      if (densityExpr != null) 'density_expr': densityExpr,
      if (uvTransformInput != null) 'uv_transform_input': uvTransformInput,
      if (preferredOrder != null) 'preferred_order': preferredOrder,
    };
  }
}
