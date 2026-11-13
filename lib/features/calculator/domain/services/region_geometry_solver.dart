import 'dart:math' as math;
import '../../../solver/domain/entities/integral_solution.dart';
import '../entities/integration_bound.dart';
import '../entities/multivariable_integral.dart';
import 'integral_expression_transformer.dart';
import 'math_expression_evaluator.dart';
import 'symbolic_calculus_engine.dart';

class RegionDeductionResult {
  final MultivariableIntegral primaryIntegral;
  final List<MultivariableIntegral> subIntegrals;
  final SolverStep step0;
  final DomainAnalysis domainAnalysis;

  const RegionDeductionResult({
    required this.primaryIntegral,
    required this.subIntegrals,
    required this.step0,
    required this.domainAnalysis,
  });
}

class RegionGeometrySolver {
  static const Map<String, double> _previewParams = {
    'a': 1.0,
    'b': 1.0,
    'c': 1.0,
    'm': 1.0,
    'n': 2.0,
    'R': 2.0,
    'H': 3.0,
    'k': 1.0,
  };

  /// Deduces iterated integral(s), intersection points, and Step 0 from polygon vertices.
  static RegionDeductionResult? deduceFromVertices({
    required List<String> verticesInput,
    String integrand = '1',
    String? preferredOrder, // 'auto', 'type1', 'type2'
  }) {
    final parsedPts = <_NamedVertex>[];
    for (int i = 0; i < verticesInput.length; i++) {
      final v = _parseVertex(verticesInput[i], 'V${i + 1}');
      if (v != null) parsedPts.add(v);
    }
    if (parsedPts.length < 3) return null;

    // Sort vertices counter-clockwise around centroid
    final cx = parsedPts.fold(0.0, (s, p) => s + p.x) / parsedPts.length;
    final cy = parsedPts.fold(0.0, (s, p) => s + p.y) / parsedPts.length;
    parsedPts.sort((a, b) {
      final aa = math.atan2(a.y - cy, a.x - cx);
      final ab = math.atan2(b.y - cy, b.x - cx);
      return aa.compareTo(ab);
    });

    final edges = <_PolyEdge>[];
    for (int i = 0; i < parsedPts.length; i++) {
      final p1 = parsedPts[i];
      final p2 = parsedPts[(i + 1) % parsedPts.length];
      edges.add(_PolyEdge(p1, p2));
    }

    // Build Type I decomposition (vertical slices: dy dx)
    final typeISubs = _slicePolygonTypeI(parsedPts, edges, integrand);
    // Build Type II decomposition (horizontal slices: dx dy)
    final typeIISubs = _slicePolygonTypeII(parsedPts, edges, integrand);

    bool chooseTypeII;
    if (preferredOrder == 'type1') {
      chooseTypeII = false;
    } else if (preferredOrder == 'type2') {
      chooseTypeII = true;
    } else {
      // Prefer whichever yields fewer sub-integrals (e.g., A(0,0),B(10,1),C(1,1) -> 1 integral in Type II!)
      chooseTypeII = typeIISubs.length < typeISubs.length;
    }

    final chosenSubs = chooseTypeII ? typeIISubs : typeISubs;
    if (chosenSubs.isEmpty) return null;

    final typeILatex = _joinIntegralsLatex(typeISubs);
    final typeIILatex = _joinIntegralsLatex(typeIISubs);
    final chosenLatex = chooseTypeII ? typeIILatex : typeILatex;
    final altLatex = chooseTypeII ? typeILatex : typeIILatex;

    final edgeDescriptions = edges.map((e) => e.equationDescription).join(', \\; ');
    final verticesDesc = parsedPts.map((v) => '${v.name}(${v.xStr}, ${v.yStr})').join(', ');

    final step0 = SolverStep(
      stepNumber: 0,
      variable: chosenSubs.first.bounds.first.variable,
      lowerBoundLatex: IntegralExpressionTransformer.toDisplayLatex(chosenSubs.first.bounds.first.lower),
      upperBoundLatex: IntegralExpressionTransformer.toDisplayLatex(chosenSubs.first.bounds.first.upper),
      currentIntegrandLatex: IntegralExpressionTransformer.toDisplayLatex(integrand),
      stepTitle: 'Paso 0: Deducción Geométrica de los Límites de Integración',
      stepIntegralLatex: chosenLatex,
      constantTreatmentText:
          'Calculamos las ecuaciones de las rectas entre los vértices $verticesDesc y seleccionamos el barrido ${chooseTypeII ? 'Tipo II (dx dy)' : 'Tipo I (dy dx)'} (${chosenSubs.length} ${chosenSubs.length == 1 ? 'integral simple' : 'sub-regiones'}):',
      antiderivativeWorkLatex: edgeDescriptions,
      limitsEvaluationText: 'Integral iterada deducida a partir de la región poligonal R:',
      antiderivativeLatex: chosenLatex,
      evaluatedLatex: chosenLatex,
      simplifiedResultLatex: chosenLatex,
      explanation: chooseTypeII
          ? 'En el orden Tipo II (horizontal, dx dy), y varía en un solo intervalo continuo y x queda acotada entre las rectas izquierda y derecha (${chosenSubs.length} integral).'
          : 'En el orden Tipo I (vertical, dy dx), x recorre el dominio y la altura y queda acotada entre la recta inferior y superior.',
      appliedMethod: 'Geometría Analítica & Deducción de Dominio R',
    );

    final intersections = parsedPts
        .map((v) => {'x': v.xStr, 'y': v.yStr})
        .toList();

    final primary = chosenSubs.first.copyWith(
      problemMode: ProblemMode.regionVertices,
      verticesInput: verticesInput,
    );

    final domainAnalysis = DomainAnalysis(
      regionType: chooseTypeII ? 'Type II' : 'Type I',
      intersectionPoints: intersections,
      deducedLimitsLatex: chosenLatex,
      alternateOrderLatex: altLatex,
      boundaryCurves: edges.map((e) => e.curveEquation).toList(),
    );

    return RegionDeductionResult(
      primaryIntegral: primary,
      subIntegrals: chosenSubs,
      step0: step0,
      domainAnalysis: domainAnalysis,
    );
  }

  /// Deduces integral(s) from boundary curve equations (explicit, implicit, polar, or 4-curve UV families).
  static RegionDeductionResult? deduceFromCurves({
    required List<String> curvesInput,
    String integrand = '1',
    String? preferredOrder, // 'auto', 'type1', 'type2', 'polar', 'uv'
    String? customUvTransform,
  }) {
    final cleanCurves = curvesInput.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    if (cleanCurves.isEmpty) return null;

    // 1. Check for 4-curve UV Jacobian families (unless explicitly forced otherwise)
    if (preferredOrder != 'type1' && preferredOrder != 'type2' && preferredOrder != 'polar') {
      final uvResult = _tryDeduceUvFamily(cleanCurves, integrand, customUvTransform);
      if (uvResult != null) return uvResult;
    }

    // 2. Check for Polar / Circular / Shifted Circle / Cardioid / Sector
    if (preferredOrder != 'type1' && preferredOrder != 'type2') {
      final polarResult = _tryDeducePolarFromCurves(cleanCurves, integrand);
      if (polarResult != null) return polarResult;
    }

    // 3. Explicit Cartesian curves (y = f(x), x = g(y), vertical/horizontal lines)
    return _deduceCartesianCurves(cleanCurves, integrand, preferredOrder);
  }

  // =========================================================================
  // UV FAMILY DEDUCTION (xy = c1..c2, y = m1*x..m2*x; a1*x+b1*y = c1..c2; y^2 = c*x)
  // =========================================================================

  static RegionDeductionResult? _tryDeduceUvFamily(
    List<String> curves,
    String integrand,
    String? customUvTransform,
  ) {
    // Pattern A: Hyperbolas xy = c1, xy = c2 and lines y = m1*x, y = m2*x
    final xyConsts = <double>[];
    final yOverXSlopes = <double>[];
    for (final raw in curves) {
      final norm = IntegralExpressionTransformer.normalizeExpression(raw.replaceAll('=', '==')).replaceAll(' ', '').toLowerCase();
      final parts = raw.split('=');
      if (parts.length != 2) continue;
      final lhs = IntegralExpressionTransformer.normalizeExpression(parts[0]).replaceAll(' ', '').toLowerCase();
      final rhs = IntegralExpressionTransformer.normalizeExpression(parts[1]).replaceAll(' ', '').toLowerCase();
      final rhsVal = MathExpressionEvaluator.evaluate(rhs);
      final lhsVal = MathExpressionEvaluator.evaluate(lhs);

      if ((lhs == 'x*y' || lhs == 'y*x') && rhsVal.isFinite && !SymbolicCalculusEngine.containsVariable(rhs)) {
        xyConsts.add(rhsVal);
      } else if ((rhs == 'x*y' || rhs == 'y*x') && lhsVal.isFinite && !SymbolicCalculusEngine.containsVariable(lhs)) {
        xyConsts.add(lhsVal);
      } else if (lhs == 'y') {
        final symR = SymbolicCalculusEngine.parse(rhs);
        final lin = symR != null ? SymbolicCalculusEngine.matchLinear(symR, 'x') : null;
        if (lin != null && lin.$2 is SymNum && (lin.$2 as SymNum).rat.isZero) {
          yOverXSlopes.add(lin.$1.eval({}));
        }
      } else if (lhs == 'y/x' && rhsVal.isFinite && !SymbolicCalculusEngine.containsVariable(rhs)) {
        yOverXSlopes.add(rhsVal);
      }
      if (norm.isEmpty) continue;
    }

    if (xyConsts.length == 2 && yOverXSlopes.length == 2) {
      xyConsts.sort();
      yOverXSlopes.sort();
      final u1 = xyConsts[0];
      final u2 = xyConsts[1];
      final v1 = yOverXSlopes[0];
      final v2 = yOverXSlopes[1];

      // u = x*y, v = y/x => x = sqrt(u/v), y = sqrt(u*v), |J| = 1/(2v)
      final fAst = SymbolicCalculusEngine.parse(integrand) ?? SymNum.intVal(1);
      var fInUv = SymbolicCalculusEngine.substitute(
        fAst,
        'x',
        SymFunc('sqrt', SymDiv(SymVar('u'), SymVar('v'))),
      );
      fInUv = SymbolicCalculusEngine.substitute(
        fInUv,
        'y',
        SymFunc('sqrt', SymMul([SymVar('u'), SymVar('v')])),
      );
      final effectiveInUv = SymbolicCalculusEngine.simplify(
        SymMul([fInUv, SymDiv(SymNum.intVal(1), SymMul([SymNum.intVal(2), SymVar('v')]))]),
      );

      final u1Str = _fmtClean(u1);
      final u2Str = _fmtClean(u2);
      final v1Str = _fmtClean(v1);
      final v2Str = _fmtClean(v2);

      // Compute 4 intersection points in Q1: (sqrt(u/v), sqrt(u*v))
      final pts = <Map<String, String>>[];
      for (final uVal in [u1, u2]) {
        for (final vVal in [v1, v2]) {
          final px = math.sqrt(uVal / vVal);
          final py = math.sqrt(uVal * vVal);
          pts.add({'x': _fmtClean(px), 'y': _fmtClean(py)});
        }
      }

      final compiled = MultivariableIntegral(
        integrand: _astToInputString(effectiveInUv),
        bounds: [
          IntegrationBound(variable: 'u', lower: u1Str, upper: u2Str),
          IntegrationBound(variable: 'v', lower: v1Str, upper: v2Str),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
        problemMode: ProblemMode.regionCurves,
        boundaryCurves: curves,
      );

      final transformedLatex =
          '\\int_{$v1Str}^{$v2Str} \\int_{$u1Str}^{$u2Str} ${SymbolicCalculusEngine.toLatex(effectiveInUv)} \\, du \\, dv';

      final jacobianLatex =
          r'\frac{\partial(u,v)}{\partial(x,y)} = \begin{vmatrix} y & x \\ -y/x^2 & 1/x \end{vmatrix} = \frac{2y}{x} = 2v \implies |J| = \frac{1}{2v}';

      final step0 = SolverStep(
        stepNumber: 0,
        variable: 'u',
        lowerBoundLatex: u1Str,
        upperBoundLatex: u2Str,
        currentIntegrandLatex: IntegralExpressionTransformer.toDisplayLatex(integrand),
        stepTitle: 'Paso 0: Transformación (u, v) y Determinante Jacobiano',
        stepIntegralLatex: transformedLatex,
        constantTreatmentText:
            'Identificamos las familias de curvas xy = u y y/x = v. Calculamos el Jacobiano inverso y transformamos R al rectángulo [$u1Str, $u2Str] × [$v1Str, $v2Str]:',
        antiderivativeWorkLatex: jacobianLatex,
        limitsEvaluationText: 'Integral transformada en el plano (u, v):',
        antiderivativeLatex: transformedLatex,
        evaluatedLatex: transformedLatex,
        simplifiedResultLatex: transformedLatex,
        explanation:
            'El cambio u = xy, v = y/x convierte la región curvilínea delimitada por hipérbolas y rectas en un rectángulo simple en el plano UV con factor Jacobiano |J| = 1/(2v).',
        appliedMethod: 'Cambio de Variables & Determinante Jacobiano',
      );

      final domainAnalysis = DomainAnalysis(
        regionType: 'UV_Jacobian',
        intersectionPoints: pts,
        deducedLimitsLatex: transformedLatex,
        jacobianLatex: jacobianLatex,
        boundaryCurves: curves,
        uvTransformSummary: 'u = xy, v = y/x',
        uvData: {
          'title': 'Cambio Hiperbólico u = xy, v = y/x',
          'u_var': 'u',
          'v_var': 'v',
          'u_min': u1,
          'u_max': u2,
          'v_min': v1,
          'v_max': v2,
          'u_min_latex': u1Str,
          'u_max_latex': u2Str,
          'v_min_latex': v1Str,
          'v_max_latex': v2Str,
          'x_of_uv': 'sqrt(u / v)',
          'y_of_uv': 'sqrt(u * v)',
          'forward_latex': r'x = \sqrt{u/v}, \quad y = \sqrt{uv}',
          'inverse_latex': r'u = xy, \quad v = y/x',
          'jacobian_latex': r'|J| = \frac{1}{2v}',
          'transformed_integral_latex': transformedLatex,
        },
      );

      return RegionDeductionResult(
        primaryIntegral: compiled,
        subIntegrals: [compiled],
        step0: step0,
        domainAnalysis: domainAnalysis,
      );
    }

    // Pattern B: Affine linear family a1*x + b1*y = c1, c2 and a2*x + b2*y = d1, d2
    if (curves.length == 4) {
      final affineLines = <({double a, double b, double c, String exprStr})>[];
      for (final raw in curves) {
        final parts = raw.split('=');
        if (parts.length != 2) continue;
        final lhsAst = SymbolicCalculusEngine.parse(parts[0]);
        final rhsAst = SymbolicCalculusEngine.parse(parts[1]);
        if (lhsAst == null || rhsAst == null) continue;
        final diffAst = SymbolicCalculusEngine.simplify(
          SymAdd([lhsAst, SymMul([SymNum.intVal(-1), rhsAst])]),
        );
        // Check purely linear in x, y: a*x + b*y - c = 0
        final ax = SymbolicCalculusEngine.diff(diffAst, 'x');
        final by = SymbolicCalculusEngine.diff(diffAst, 'y');
        if (!ax.dependsOn('x') && !ax.dependsOn('y') && !by.dependsOn('x') && !by.dependsOn('y') &&
            !SymbolicCalculusEngine.hasSymbolicParameters(diffAst)) {
          final aVal = ax.eval({});
          final bVal = by.eval({});
          final cVal = -SymbolicCalculusEngine.substitute(
            SymbolicCalculusEngine.substitute(diffAst, 'x', SymNum.intVal(0)),
            'y',
            SymNum.intVal(0),
          ).eval({});
          if (aVal.isFinite && bVal.isFinite && cVal.isFinite && (aVal.abs() > 1e-9 || bVal.abs() > 1e-9)) {
            // Normalize direction sign so parallel families match
            final normSign = (aVal < 0 || (aVal.abs() < 1e-9 && bVal < 0)) ? -1.0 : 1.0;
            final scale = math.max(aVal.abs(), bVal.abs());
            final na = (aVal * normSign) / (scale == 0 ? 1 : 1); // preserve raw scale for first line
            affineLines.add((a: aVal * normSign, b: bVal * normSign, c: cVal * normSign, exprStr: parts[0].trim()));
            if (na.isNaN) continue;
          }
        }
      }

      if (affineLines.length == 4) {
        // Group into 2 parallel families
        final fam1 = <({double a, double b, double c})>[];
        final fam2 = <({double a, double b, double c})>[];
        final l0 = affineLines[0];
        fam1.add((a: l0.a, b: l0.b, c: l0.c));
        for (int i = 1; i < 4; i++) {
          final li = affineLines[i];
          final det = l0.a * li.b - l0.b * li.a;
          if (det.abs() < 1e-6) {
            // Parallel to l0: scale c relative to l0
            final ratio = l0.a.abs() > 1e-6 ? li.a / l0.a : li.b / l0.b;
            fam1.add((a: l0.a, b: l0.b, c: li.c / ratio));
          } else {
            fam2.add((a: li.a, b: li.b, c: li.c));
          }
        }

        if (fam1.length == 2 && fam2.length == 2) {
          final f20 = fam2[0];
          final f21 = fam2[1];
          final detCheck = f20.a * f21.b - f20.b * f21.a;
          if (detCheck.abs() < 1e-6) {
            final ratio = f20.a.abs() > 1e-6 ? f21.a / f20.a : f21.b / f20.b;
            final c2A = f20.c;
            final c2B = f21.c / ratio;

            final a1 = fam1[0].a, b1 = fam1[0].b;
            final a2 = f20.a, b2 = f20.b;
            final det = a1 * b2 - a2 * b1;

            // Only apply UV Jacobian when non-axis-aligned (otherwise regular rectangle)
            final isAxisAligned = (a1.abs() < 1e-6 || b1.abs() < 1e-6) && (a2.abs() < 1e-6 || b2.abs() < 1e-6);
            if (!isAxisAligned && det.abs() > 1e-6) {
              final uBounds = [fam1[0].c, fam1[1].c]..sort();
              final vBounds = [c2A, c2B]..sort();
              final u1 = uBounds[0], u2 = uBounds[1];
              final v1 = vBounds[0], v2 = vBounds[1];

              // Solve: a1 x + b1 y = u, a2 x + b2 y = v
              // x = (b2*u - b1*v)/det, y = (-a2*u + a1*v)/det, |J| = 1/|det|
              final jAbs = 1.0 / det.abs();
              final jRat = SymRat.tryFromDouble(jAbs);
              final jExpr = jRat != null ? SymNum(jRat) : SymFloat(jAbs);

              final xOfUv = '(${_fmtClean(b2)}*u - (${_fmtClean(b1)})*v) / (${_fmtClean(det)})';
              final yOfUv = '(-(${_fmtClean(a2)})*u + ${_fmtClean(a1)}*v) / (${_fmtClean(det)})';
              final xAst = SymbolicCalculusEngine.parse(xOfUv)!;
              final yAst = SymbolicCalculusEngine.parse(yOfUv)!;

              final fAst = SymbolicCalculusEngine.parse(integrand) ?? SymNum.intVal(1);
              var fUv = SymbolicCalculusEngine.substitute(fAst, 'x', xAst);
              fUv = SymbolicCalculusEngine.substitute(fUv, 'y', yAst);
              final effUv = SymbolicCalculusEngine.simplify(SymMul([fUv, jExpr]));

              final u1S = _fmtClean(u1), u2S = _fmtClean(u2);
              final v1S = _fmtClean(v1), v2S = _fmtClean(v2);

              final pts = <Map<String, String>>[];
              for (final uVal in [u1, u2]) {
                for (final vVal in [v1, v2]) {
                  final px = (b2 * uVal - b1 * vVal) / det;
                  final py = (-a2 * uVal + a1 * vVal) / det;
                  pts.add({'x': _fmtClean(px), 'y': _fmtClean(py)});
                }
              }

              final compiled = MultivariableIntegral(
                integrand: _astToInputString(effUv),
                bounds: [
                  IntegrationBound(variable: 'u', lower: u1S, upper: u2S),
                  IntegrationBound(variable: 'v', lower: v1S, upper: v2S),
                ],
                coordinateSystem: CoordinateSystemType.cartesian,
                problemMode: ProblemMode.regionCurves,
                boundaryCurves: curves,
              );

              final transLatex =
                  '\\int_{$v1S}^{$v2S} \\int_{$u1S}^{$u2S} ${SymbolicCalculusEngine.toLatex(effUv)} \\, du \\, dv';
              final uDefLatex = SymbolicCalculusEngine.toLatex(
                SymbolicCalculusEngine.parse('${_fmtClean(a1)}*x + ${_fmtClean(b1)}*y')!,
              );
              final vDefLatex = SymbolicCalculusEngine.toLatex(
                SymbolicCalculusEngine.parse('${_fmtClean(a2)}*x + ${_fmtClean(b2)}*y')!,
              );
              final jacLatex =
                  '\\frac{\\partial(u,v)}{\\partial(x,y)} = \\begin{vmatrix} ${_fmtClean(a1)} & ${_fmtClean(b1)} \\\\ ${_fmtClean(a2)} & ${_fmtClean(b2)} \\end{vmatrix} = ${_fmtClean(det)} \\implies |J| = ${SymbolicCalculusEngine.toLatex(jExpr)}';

              final step0 = SolverStep(
                stepNumber: 0,
                variable: 'u',
                lowerBoundLatex: u1S,
                upperBoundLatex: u2S,
                currentIntegrandLatex: IntegralExpressionTransformer.toDisplayLatex(integrand),
                stepTitle: 'Paso 0: Transformación Lineal (u, v) y Jacobiano Constante',
                stepIntegralLatex: transLatex,
                constantTreatmentText:
                    'Definimos u = $uDefLatex y v = $vDefLatex para transformar el paralelogramo en el rectángulo [$u1S, $u2S] × [$v1S, $v2S]:',
                antiderivativeWorkLatex: jacLatex,
                limitsEvaluationText: 'Integral transformada en (u, v):',
                antiderivativeLatex: transLatex,
                evaluatedLatex: transLatex,
                simplifiedResultLatex: transLatex,
                explanation:
                    'Las 4 rectas forman dos pares de fronteras paralelas. Con u = $uDefLatex y v = $vDefLatex, el Jacobiano es constante |J| = ${SymbolicCalculusEngine.toLatex(jExpr)}.',
                appliedMethod: 'Cambio de Variables Afín & Jacobiano',
              );

              final domainAnalysis = DomainAnalysis(
                regionType: 'UV_Jacobian',
                intersectionPoints: pts,
                deducedLimitsLatex: transLatex,
                jacobianLatex: jacLatex,
                boundaryCurves: curves,
                uvTransformSummary: 'u = $uDefLatex, v = $vDefLatex',
                uvData: {
                  'title': 'Transformación Afín (u, v)',
                  'u_var': 'u',
                  'v_var': 'v',
                  'u_min': u1,
                  'u_max': u2,
                  'v_min': v1,
                  'v_max': v2,
                  'u_min_latex': u1S,
                  'u_max_latex': u2S,
                  'v_min_latex': v1S,
                  'v_max_latex': v2S,
                  'x_of_uv': xOfUv,
                  'y_of_uv': yOfUv,
                  'forward_latex': 'x = ${SymbolicCalculusEngine.toLatex(xAst)}, \\quad y = ${SymbolicCalculusEngine.toLatex(yAst)}',
                  'inverse_latex': 'u = $uDefLatex, \\quad v = $vDefLatex',
                  'jacobian_latex': '|J| = ${SymbolicCalculusEngine.toLatex(jExpr)}',
                  'transformed_integral_latex': transLatex,
                },
              );

              return RegionDeductionResult(
                primaryIntegral: compiled,
                subIntegrals: [compiled],
                step0: step0,
                domainAnalysis: domainAnalysis,
              );
            }
          }
        }
      }
    }

    return null;
  }

  // =========================================================================
  // POLAR DEDUCTION (Centered Circles, Shifted Circles x^2+y^2 = 2ax, Cardioids, Sectors)
  // =========================================================================

  static RegionDeductionResult? _tryDeducePolarFromCurves(
    List<String> curves,
    String integrand,
  ) {
    final joined = curves.map((c) => c.replaceAll(' ', '').toLowerCase()).join('|');

    // 1. Direct polar curve r = f(theta), e.g., r = 1 + cos(theta)
    for (final raw in curves) {
      final parts = raw.split('=');
      if (parts.length == 2 && parts[0].trim().toLowerCase() == 'r') {
        final rUpper = IntegralExpressionTransformer.normalizeExpression(parts[1].trim());
        final rDisp = IntegralExpressionTransformer.toDisplayLatex(rUpper);
        const thLow = '0';
        const thUpp = '2*pi';
        final polarIntegral = MultivariableIntegral(
          integrand: integrand,
          bounds: [
            IntegrationBound(variable: 'r', lower: '0', upper: rUpper),
            const IntegrationBound(variable: 'theta', lower: thLow, upper: thUpp),
          ],
          coordinateSystem: CoordinateSystemType.polar,
          problemMode: ProblemMode.regionCurves,
          boundaryCurves: curves,
        );
        final polarLatex =
            '\\int_{0}^{2\\pi} \\int_{0}^{$rDisp} (${IntegralExpressionTransformer.toDisplayLatex(integrand)}) \\, r \\, dr \\, d\\theta';

        return RegionDeductionResult(
          primaryIntegral: polarIntegral,
          subIntegrals: [polarIntegral],
          step0: SolverStep(
            stepNumber: 0,
            variable: 'r',
            lowerBoundLatex: '0',
            upperBoundLatex: rDisp,
            currentIntegrandLatex: IntegralExpressionTransformer.toDisplayLatex(integrand),
            stepTitle: 'Paso 0: Deducción Polar de la Curva r(θ)',
            stepIntegralLatex: polarLatex,
            constantTreatmentText: 'La región está definida en coordenadas polares por 0 ≤ r ≤ $rDisp y 0 ≤ θ ≤ 2π con Jacobiano dA = r dr dθ:',
            antiderivativeWorkLatex: '0 \\le r \\le $rDisp, \\quad 0 \\le \\theta \\le 2\\pi',
            limitsEvaluationText: 'Integral polar planteada:',
            antiderivativeLatex: polarLatex,
            evaluatedLatex: polarLatex,
            simplifiedResultLatex: polarLatex,
            explanation: 'Se integra radialmente desde el origen hasta r = $rDisp a lo largo de toda la vuelta θ ∈ [0, 2π].',
            appliedMethod: 'Coordenadas Polares (dA = r dr dθ)',
          ),
          domainAnalysis: DomainAnalysis(
            regionType: 'Polar',
            intersectionPoints: const [{'x': '0', 'y': '0'}],
            deducedLimitsLatex: polarLatex,
            jacobianLatex: r'J(r,\theta) = r \implies dA = r\,dr\,d\theta',
            boundaryCurves: curves,
          ),
        );
      }
    }

    // 2. Shifted circle: x^2 + y^2 = 2*a*x or x^2 + y^2 = C*x (or 2*a*y)
    final shiftedXMatch = RegExp(r'x\^2\+y\^2=([0-9.*a-zA-Z]+)\*?[xX]|([0-9.*a-zA-Z]+)\*?[xX]=x\^2\+y\^2')
        .firstMatch(joined.replaceAll('**', '^'));
    if (shiftedXMatch != null) {
      final coeffRaw = (shiftedXMatch.group(1) ?? shiftedXMatch.group(2) ?? '2')
          .replaceAll('*', '');
      final isFirstQuadrant = joined.contains('y=0') || joined.contains('y>=0');
      final thLow = isFirstQuadrant ? '0' : '-pi/2';
      const thUpp = 'pi/2';
      final thLowLatex = isFirstQuadrant ? '0' : r'-\frac{\pi}{2}';
      const thUppLatex = r'\frac{\pi}{2}';

      final rUpperExpr = coeffRaw.isEmpty ? 'cos(theta)' : '$coeffRaw*cos(theta)';
      final rUpperNorm = IntegralExpressionTransformer.normalizeExpression(rUpperExpr);
      final rUpperLatex = IntegralExpressionTransformer.toDisplayLatex(rUpperNorm);
      final fDisp = IntegralExpressionTransformer.toDisplayLatex(integrand);
      final polarLatex =
          '\\int_{$thLowLatex}^{$thUppLatex} \\int_{0}^{$rUpperLatex} ($fDisp) \\, r \\, dr \\, d\\theta';

      final polarIntegral = MultivariableIntegral(
        integrand: integrand,
        bounds: [
          IntegrationBound(variable: 'r', lower: '0', upper: rUpperNorm),
          IntegrationBound(variable: 'theta', lower: thLow, upper: thUpp),
        ],
        coordinateSystem: CoordinateSystemType.polar,
        problemMode: ProblemMode.regionCurves,
        boundaryCurves: curves,
      );

      return RegionDeductionResult(
        primaryIntegral: polarIntegral,
        subIntegrals: [polarIntegral],
        step0: SolverStep(
          stepNumber: 0,
          variable: 'r',
          lowerBoundLatex: '0',
          upperBoundLatex: rUpperLatex,
          currentIntegrandLatex: fDisp,
          stepTitle: 'Paso 0: Conversión de Circunferencia Desplazada a Polares',
          stepIntegralLatex: polarLatex,
          constantTreatmentText:
              'Sustituyendo x = r cosθ, y = r sinθ en la circunferencia desplazada obtenemos r² = $coeffRaw r cosθ ⇒ r = $rUpperLatex:',
          antiderivativeWorkLatex:
              'x^2 + y^2 = $coeffRaw x \\implies r = $rUpperLatex, \\quad \\theta \\in [$thLowLatex, $thUppLatex]',
          limitsEvaluationText: 'Integral en coordenadas polares con dA = r dr dθ:',
          antiderivativeLatex: polarLatex,
          evaluatedLatex: polarLatex,
          simplifiedResultLatex: polarLatex,
          explanation:
              'Las circunferencias desplazadas tangentes al eje Y cubren el semiplano x ≥ 0 para θ ∈ [$thLowLatex, $thUppLatex].',
          appliedMethod: 'Coordenadas Polares (Circunferencia Desplazada)',
        ),
        domainAnalysis: DomainAnalysis(
          regionType: 'Polar',
          intersectionPoints: [
            const {'x': '0', 'y': '0'},
            {'x': coeffRaw.isEmpty ? '1' : coeffRaw, 'y': '0'},
          ],
          deducedLimitsLatex: polarLatex,
          jacobianLatex: r'J(r,\theta) = r \implies dA = r\,dr\,d\theta',
          boundaryCurves: curves,
        ),
      );
    }

    // 3. Centered circle x^2 + y^2 = R^2 (possibly bounded by y=0, y=x, x=0 -> sector!)
    final circleMatch = RegExp(r'x\^2\+y\^2=([^|]+)').firstMatch(joined.replaceAll('**', '^'));
    if (circleMatch != null) {
      final rhsStr = circleMatch.group(1)!;
      final rUpper = _extractRadiusFromSquared(rhsStr);
      String thLow = '0';
      String thUpp = '2*pi';
      String thLowL = '0';
      String thUppL = r'2\pi';

      if (joined.contains('y=x') && joined.contains('y=0')) {
        thLow = '0';
        thUpp = 'pi/4';
        thLowL = '0';
        thUppL = r'\frac{\pi}{4}';
      } else if (joined.contains('y=x') && joined.contains('x=0')) {
        thLow = 'pi/4';
        thUpp = 'pi/2';
        thLowL = r'\frac{\pi}{4}';
        thUppL = r'\frac{\pi}{2}';
      } else if (joined.contains('x=0') && joined.contains('y=0')) {
        thLow = '0';
        thUpp = 'pi/2';
        thLowL = '0';
        thUppL = r'\frac{\pi}{2}';
      } else if (joined.contains('y=0')) {
        thLow = '0';
        thUpp = 'pi';
        thLowL = '0';
        thUppL = r'\pi';
      } else if (joined.contains('x=0')) {
        thLow = '-pi/2';
        thUpp = 'pi/2';
        thLowL = r'-\frac{\pi}{2}';
        thUppL = r'\frac{\pi}{2}';
      }

      final rUppL = IntegralExpressionTransformer.toDisplayLatex(rUpper);
      final fDisp = IntegralExpressionTransformer.toDisplayLatex(integrand);
      final polarLatex =
          '\\int_{$thLowL}^{$thUppL} \\int_{0}^{$rUppL} ($fDisp) \\, r \\, dr \\, d\\theta';

      final polarIntegral = MultivariableIntegral(
        integrand: integrand,
        bounds: [
          IntegrationBound(variable: 'r', lower: '0', upper: rUpper),
          IntegrationBound(variable: 'theta', lower: thLow, upper: thUpp),
        ],
        coordinateSystem: CoordinateSystemType.polar,
        problemMode: ProblemMode.regionCurves,
        boundaryCurves: curves,
      );

      return RegionDeductionResult(
        primaryIntegral: polarIntegral,
        subIntegrals: [polarIntegral],
        step0: SolverStep(
          stepNumber: 0,
          variable: 'r',
          lowerBoundLatex: '0',
          upperBoundLatex: rUppL,
          currentIntegrandLatex: fDisp,
          stepTitle: 'Paso 0: Deducción Polar del Recinto Circular',
          stepIntegralLatex: polarLatex,
          constantTreatmentText:
              'La frontera circular x² + y² = $rhsStr tiene radio r = $rUppL con ángulo θ ∈ [$thLowL, $thUppL]:',
          antiderivativeWorkLatex: '0 \\le r \\le $rUppL, \\quad $thLowL \\le \\theta \\le $thUppL',
          limitsEvaluationText: 'Integral convertida a coordenadas polares (dA = r dr dθ):',
          antiderivativeLatex: polarLatex,
          evaluatedLatex: polarLatex,
          simplifiedResultLatex: polarLatex,
          explanation:
              'Al pasar a coordenadas polares (x = r cosθ, y = r sinθ), las fronteras curvilíneas se simplifican a cotas constantes.',
          appliedMethod: 'Coordenadas Polares (dA = r dr dθ)',
        ),
        domainAnalysis: DomainAnalysis(
          regionType: 'Polar',
          intersectionPoints: [
            {'x': rUpper, 'y': '0'},
            {'x': '0', 'y': rUpper},
          ],
          deducedLimitsLatex: polarLatex,
          jacobianLatex: r'J(r,\theta) = r \implies dA = r\,dr\,d\theta',
          boundaryCurves: curves,
        ),
      );
    }

    return null;
  }

  static String _extractRadiusFromSquared(String rhsSquared) {
    final s = IntegralExpressionTransformer.normalizeExpression(rhsSquared).replaceAll(' ', '');
    final numVal = MathExpressionEvaluator.evaluate(s);
    if (!SymbolicCalculusEngine.containsVariable(s) && numVal.isFinite && numVal > 0) {
      final root = math.sqrt(numVal);
      if ((root - root.roundToDouble()).abs() < 1e-6) {
        return '${root.round()}';
      }
      return 'sqrt($s)';
    }
    if (s.endsWith('^2')) {
      return s.substring(0, s.length - 2);
    }
    return 'sqrt($s)';
  }

  // =========================================================================
  // CARTESIAN CURVES DEDUCTION (e.g. y = 2*x, y = x^2; y = x^2, y = 4 - x^2)
  // =========================================================================

  static RegionDeductionResult? _deduceCartesianCurves(
    List<String> curves,
    String integrand,
    String? preferredOrder,
  ) {
    final yCurves = <({String raw, String expr})>[];
    final xCurves = <({String raw, String expr})>[];

    for (final raw in curves) {
      final parts = raw.split('=');
      if (parts.length != 2) continue;
      final lhs = parts[0].trim().toLowerCase();
      final rhs = IntegralExpressionTransformer.normalizeExpression(parts[1].trim());
      if (lhs == 'y' && !rhs.toLowerCase().contains('y')) {
        yCurves.add((raw: raw, expr: rhs));
      } else if (lhs == 'x' && !rhs.toLowerCase().contains('x')) {
        xCurves.add((raw: raw, expr: rhs));
      } else if (parts[1].trim().toLowerCase() == 'y' && !parts[0].toLowerCase().contains('y')) {
        yCurves.add((raw: raw, expr: IntegralExpressionTransformer.normalizeExpression(parts[0].trim())));
      } else if (parts[1].trim().toLowerCase() == 'x' && !parts[0].toLowerCase().contains('x')) {
        xCurves.add((raw: raw, expr: IntegralExpressionTransformer.normalizeExpression(parts[0].trim())));
      }
    }

    // Two curves y = f1(x), y = f2(x) (plus optional vertical lines x = a, x = b)
    if (yCurves.length >= 2) {
      final f1 = yCurves[0].expr;
      final f2 = yCurves[1].expr;
      final xConsts = xCurves
          .where((c) => !SymbolicCalculusEngine.containsVariable(c.expr))
          .map((c) => (str: c.expr, val: MathExpressionEvaluator.evaluate(c.expr, params: _previewParams)))
          .toList()
        ..sort((a, b) => a.val.compareTo(b.val));

      double? xA, xB;
      String? xAStr, xBStr;

      if (xConsts.length >= 2) {
        xA = xConsts.first.val;
        xB = xConsts.last.val;
        xAStr = xConsts.first.str;
        xBStr = xConsts.last.str;
      } else {
        // Find intersections of f1(x) = f2(x)
        final roots = _findRealRoots('$f1 - ($f2)', -12.0, 12.0);
        if (roots.length >= 2) {
          xA = roots.first;
          xB = roots.last;
          xAStr = _fmtClean(xA);
          xBStr = _fmtClean(xB);
        } else if (roots.length == 1 && xConsts.length == 1) {
          final r0 = roots.first;
          final c0 = xConsts.first.val;
          if (r0 <= c0) {
            xA = r0;
            xB = c0;
            xAStr = _fmtClean(r0);
            xBStr = xConsts.first.str;
          } else {
            xA = c0;
            xB = r0;
            xAStr = xConsts.first.str;
            xBStr = _fmtClean(r0);
          }
        }
      }

      if (xA != null && xB != null && xAStr != null && xBStr != null && (xB - xA).abs() > 1e-6) {
        final xMid = (xA + xB) / 2.0;
        final y1Mid = MathExpressionEvaluator.evaluate(f1, x: xMid, params: _previewParams);
        final y2Mid = MathExpressionEvaluator.evaluate(f2, x: xMid, params: _previewParams);
        final yLower = y1Mid <= y2Mid ? f1 : f2;
        final yUpper = y1Mid <= y2Mid ? f2 : f1;

        final yA = MathExpressionEvaluator.evaluate(yLower, x: xA, params: _previewParams);
        final yB = MathExpressionEvaluator.evaluate(yUpper, x: xB, params: _previewParams);
        final intersections = [
          {'x': xAStr, 'y': _fmtClean(yA)},
          {'x': xBStr, 'y': _fmtClean(yB)},
        ];

        final compiled = MultivariableIntegral(
          integrand: integrand,
          bounds: [
            IntegrationBound(variable: 'y', lower: yLower, upper: yUpper),
            IntegrationBound(variable: 'x', lower: xAStr, upper: xBStr),
          ],
          coordinateSystem: CoordinateSystemType.cartesian,
          problemMode: ProblemMode.regionCurves,
          boundaryCurves: curves,
        );

        final fDisp = IntegralExpressionTransformer.toDisplayLatex(integrand);
        final yLowL = IntegralExpressionTransformer.toDisplayLatex(yLower);
        final yUppL = IntegralExpressionTransformer.toDisplayLatex(yUpper);
        final xLowL = IntegralExpressionTransformer.toDisplayLatex(xAStr);
        final xUppL = IntegralExpressionTransformer.toDisplayLatex(xBStr);
        final integralLatex = '\\int_{$xLowL}^{$xUppL} \\int_{$yLowL}^{$yUppL} $fDisp \\, dy \\, dx';

        final ptsStr = intersections.map((p) => '(${p['x']}, ${p['y']})').join(', ');

        final step0 = SolverStep(
          stepNumber: 0,
          variable: 'y',
          lowerBoundLatex: yLowL,
          upperBoundLatex: yUppL,
          currentIntegrandLatex: fDisp,
          stepTitle: 'Paso 0: Deducción Geométrica de los Límites de Integración',
          stepIntegralLatex: integralLatex,
          constantTreatmentText:
              'Igualamos las curvas frontera para hallar los puntos de corte $ptsStr y verificamos cuál curva acota por debajo y cuál por encima en [$xLowL, $xUppL]:',
          antiderivativeWorkLatex:
              '$yLowL = $yUppL \\implies x \\in \\{$xLowL, $xUppL\\}, \\quad $yLowL \\le y \\le $yUppL',
          limitsEvaluationText: 'Integral iterada Tipo I deducida:',
          antiderivativeLatex: integralLatex,
          evaluatedLatex: integralLatex,
          simplifiedResultLatex: integralLatex,
          explanation:
              'La región R queda encerrada entre x = $xLowL y x = $xUppL, entrando por y_inf = $yLowL y saliendo por y_sup = $yUppL.',
          appliedMethod: 'Intersección de Curvas & Límites Tipo I',
        );

        return RegionDeductionResult(
          primaryIntegral: compiled,
          subIntegrals: [compiled],
          step0: step0,
          domainAnalysis: DomainAnalysis(
            regionType: 'Type I',
            intersectionPoints: intersections,
            deducedLimitsLatex: integralLatex,
            boundaryCurves: curves,
          ),
        );
      }
    }

    // Two curves x = g1(y), x = g2(y) (plus optional y = c, y = d)
    if (xCurves.length >= 2) {
      final g1 = xCurves[0].expr;
      final g2 = xCurves[1].expr;
      final yConsts = yCurves
          .where((c) => !SymbolicCalculusEngine.containsVariable(c.expr))
          .map((c) => (str: c.expr, val: MathExpressionEvaluator.evaluate(c.expr, params: _previewParams)))
          .toList()
        ..sort((a, b) => a.val.compareTo(b.val));

      double? yA, yB;
      String? yAStr, yBStr;
      if (yConsts.length >= 2) {
        yA = yConsts.first.val;
        yB = yConsts.last.val;
        yAStr = yConsts.first.str;
        yBStr = yConsts.last.str;
      } else {
        final roots = _findRealRoots(
          '${g1.replaceAll('y', 'x')} - (${g2.replaceAll('y', 'x')})',
          -12.0,
          12.0,
        );
        if (roots.length >= 2) {
          yA = roots.first;
          yB = roots.last;
          yAStr = _fmtClean(yA);
          yBStr = _fmtClean(yB);
        } else if (roots.length == 1 && yConsts.length == 1) {
          final r0 = roots.first;
          final c0 = yConsts.first.val;
          yA = math.min(r0, c0);
          yB = math.max(r0, c0);
          yAStr = r0 <= c0 ? _fmtClean(r0) : yConsts.first.str;
          yBStr = r0 <= c0 ? yConsts.first.str : _fmtClean(r0);
        }
      }

      if (yA != null && yB != null && yAStr != null && yBStr != null && (yB - yA).abs() > 1e-6) {
        final yMid = (yA + yB) / 2.0;
        final x1Mid = MathExpressionEvaluator.evaluate(g1, y: yMid, params: _previewParams);
        final x2Mid = MathExpressionEvaluator.evaluate(g2, y: yMid, params: _previewParams);
        final xLeft = x1Mid <= x2Mid ? g1 : g2;
        final xRight = x1Mid <= x2Mid ? g2 : g1;

        final xA = MathExpressionEvaluator.evaluate(xLeft, y: yA, params: _previewParams);
        final xB = MathExpressionEvaluator.evaluate(xRight, y: yB, params: _previewParams);
        final intersections = [
          {'x': _fmtClean(xA), 'y': yAStr},
          {'x': _fmtClean(xB), 'y': yBStr},
        ];

        final compiled = MultivariableIntegral(
          integrand: integrand,
          bounds: [
            IntegrationBound(variable: 'x', lower: xLeft, upper: xRight),
            IntegrationBound(variable: 'y', lower: yAStr, upper: yBStr),
          ],
          coordinateSystem: CoordinateSystemType.cartesian,
          problemMode: ProblemMode.regionCurves,
          boundaryCurves: curves,
        );

        final fDisp = IntegralExpressionTransformer.toDisplayLatex(integrand);
        final xLowL = IntegralExpressionTransformer.toDisplayLatex(xLeft);
        final xUppL = IntegralExpressionTransformer.toDisplayLatex(xRight);
        final yLowL = IntegralExpressionTransformer.toDisplayLatex(yAStr);
        final yUppL = IntegralExpressionTransformer.toDisplayLatex(yBStr);
        final integralLatex = '\\int_{$yLowL}^{$yUppL} \\int_{$xLowL}^{$xUppL} $fDisp \\, dx \\, dy';

        final step0 = SolverStep(
          stepNumber: 0,
          variable: 'x',
          lowerBoundLatex: xLowL,
          upperBoundLatex: xUppL,
          currentIntegrandLatex: fDisp,
          stepTitle: 'Paso 0: Deducción Geométrica de los Límites de Integración',
          stepIntegralLatex: integralLatex,
          constantTreatmentText:
              'Igualamos las curvas frontera x(y) para hallar los cortes y acotamos horizontalmente (Tipo II):',
          antiderivativeWorkLatex: '$yLowL \\le y \\le $yUppL, \\quad $xLowL \\le x \\le $xUppL',
          limitsEvaluationText: 'Integral iterada Tipo II deducida:',
          antiderivativeLatex: integralLatex,
          evaluatedLatex: integralLatex,
          simplifiedResultLatex: integralLatex,
          explanation:
              'La región R queda encerrada entre y = $yLowL y y = $yUppL, entrando por x_izq = $xLowL y saliendo por x_der = $xUppL.',
          appliedMethod: 'Intersección de Curvas & Límites Tipo II',
        );

        return RegionDeductionResult(
          primaryIntegral: compiled,
          subIntegrals: [compiled],
          step0: step0,
          domainAnalysis: DomainAnalysis(
            regionType: 'Type II',
            intersectionPoints: intersections,
            deducedLimitsLatex: integralLatex,
            boundaryCurves: curves,
          ),
        );
      }
    }

    // 4. Rectangular fallback if 2 vertical + 2 horizontal lines (x=a, x=b, y=c, y=d)
    if (xCurves.isNotEmpty && yCurves.isNotEmpty) {
      final xVals = xCurves.map((e) => (str: e.expr, val: MathExpressionEvaluator.evaluate(e.expr, params: _previewParams))).toList()
        ..sort((a, b) => a.val.compareTo(b.val));
      final yVals = yCurves.map((e) => (str: e.expr, val: MathExpressionEvaluator.evaluate(e.expr, params: _previewParams))).toList()
        ..sort((a, b) => a.val.compareTo(b.val));
      final xL = xVals.first.str;
      final xU = xVals.length > 1 ? xVals.last.str : '1';
      final yL = yVals.first.str;
      final yU = yVals.length > 1 ? yVals.last.str : '1';
      final compiled = MultivariableIntegral(
        integrand: integrand,
        bounds: [
          IntegrationBound(variable: 'y', lower: yL, upper: yU),
          IntegrationBound(variable: 'x', lower: xL, upper: xU),
        ],
        problemMode: ProblemMode.regionCurves,
        boundaryCurves: curves,
      );
      final latex = IntegralExpressionTransformer.toLatex(compiled);
      return RegionDeductionResult(
        primaryIntegral: compiled,
        subIntegrals: [compiled],
        step0: SolverStep(
          stepNumber: 0,
          variable: 'y',
          lowerBoundLatex: yL,
          upperBoundLatex: yU,
          currentIntegrandLatex: integrand,
          stepTitle: 'Paso 0: Deducción Geométrica de los Límites de Integración',
          stepIntegralLatex: latex,
          antiderivativeLatex: latex,
          evaluatedLatex: latex,
          simplifiedResultLatex: latex,
          explanation: 'Región rectangular delimitada por x ∈ [$xL, $xU], y ∈ [$yL, $yU].',
          appliedMethod: 'Deducción de Límites de Dominio',
        ),
        domainAnalysis: DomainAnalysis(
          regionType: 'Type I',
          intersectionPoints: [
            {'x': xL, 'y': yL},
            {'x': xU, 'y': yL},
            {'x': xU, 'y': yU},
            {'x': xL, 'y': yU},
          ],
          deducedLimitsLatex: latex,
          boundaryCurves: curves,
        ),
      );
    }

    return null;
  }

  static List<double> _findRealRoots(String fMinusG, double minX, double maxX) {
    const int n = 240;
    final dx = (maxX - minX) / n;
    final roots = <double>[];
    double prevX = minX;
    double prevV = MathExpressionEvaluator.evaluate(fMinusG, x: prevX, params: _previewParams);

    for (int i = 1; i <= n; i++) {
      final curX = minX + i * dx;
      final curV = MathExpressionEvaluator.evaluate(fMinusG, x: curX, params: _previewParams);
      if (prevV.isFinite && curV.isFinite) {
        if (prevV.abs() < 1e-6) {
          _addUniqueRoot(roots, prevX);
        } else if (prevV * curV < 0) {
          // Bisection
          double lo = prevX;
          double hi = curX;
          double vlo = prevV;
          for (int it = 0; it < 36; it++) {
            final mid = 0.5 * (lo + hi);
            final vmid = MathExpressionEvaluator.evaluate(fMinusG, x: mid, params: _previewParams);
            if (!vmid.isFinite) break;
            if (vlo * vmid <= 0) {
              hi = mid;
            } else {
              lo = mid;
              vlo = vmid;
            }
          }
          _addUniqueRoot(roots, 0.5 * (lo + hi));
        }
      }
      prevX = curX;
      prevV = curV;
    }
    if (prevV.isFinite && prevV.abs() < 1e-6) {
      _addUniqueRoot(roots, prevX);
    }
    return roots;
  }

  static void _addUniqueRoot(List<double> roots, double r) {
    final snapped = (r - r.roundToDouble()).abs() < 1e-4 ? r.roundToDouble() : r;
    for (final ex in roots) {
      if ((ex - snapped).abs() < 1e-3) return;
    }
    roots.add(snapped);
  }

  // =========================================================================
  // POLYGON SLICING (TYPE I & TYPE II)
  // =========================================================================

  static List<MultivariableIntegral> _slicePolygonTypeI(
    List<_NamedVertex> pts,
    List<_PolyEdge> edges,
    String integrand,
  ) {
    final xs = <double>[];
    for (final p in pts) {
      if (!xs.any((v) => (v - p.x).abs() < 1e-6)) xs.add(p.x);
    }
    xs.sort();

    final subs = <MultivariableIntegral>[];
    for (int i = 0; i < xs.length - 1; i++) {
      final xA = xs[i];
      final xB = xs[i + 1];
      if ((xB - xA).abs() < 1e-6) continue;
      final xMid = 0.5 * (xA + xB);

      final hits = <({double y, _PolyEdge edge})>[];
      for (final e in edges) {
        final minEx = math.min(e.p1.x, e.p2.x);
        final maxEx = math.max(e.p1.x, e.p2.x);
        if (maxEx - minEx < 1e-7) continue; // skip vertical edge
        if (xMid >= minEx - 1e-7 && xMid <= maxEx + 1e-7) {
          final yAtMid = e.yAtX(xMid);
          hits.add((y: yAtMid, edge: e));
        }
      }
      if (hits.length < 2) continue;
      hits.sort((a, b) => a.y.compareTo(b.y));
      final lowEdge = hits.first.edge;
      final uppEdge = hits.last.edge;

      subs.add(MultivariableIntegral(
        integrand: integrand,
        bounds: [
          IntegrationBound(variable: 'y', lower: lowEdge.yOfXExpr, upper: uppEdge.yOfXExpr),
          IntegrationBound(variable: 'x', lower: _fmtClean(xA), upper: _fmtClean(xB)),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      ));
    }
    return subs;
  }

  static List<MultivariableIntegral> _slicePolygonTypeII(
    List<_NamedVertex> pts,
    List<_PolyEdge> edges,
    String integrand,
  ) {
    final ys = <double>[];
    for (final p in pts) {
      if (!ys.any((v) => (v - p.y).abs() < 1e-6)) ys.add(p.y);
    }
    ys.sort();

    final subs = <MultivariableIntegral>[];
    for (int i = 0; i < ys.length - 1; i++) {
      final yA = ys[i];
      final yB = ys[i + 1];
      if ((yB - yA).abs() < 1e-6) continue;
      final yMid = 0.5 * (yA + yB);

      final hits = <({double x, _PolyEdge edge})>[];
      for (final e in edges) {
        final minEy = math.min(e.p1.y, e.p2.y);
        final maxEy = math.max(e.p1.y, e.p2.y);
        if (maxEy - minEy < 1e-7) continue; // skip horizontal edge
        if (yMid >= minEy - 1e-7 && yMid <= maxEy + 1e-7) {
          final xAtMid = e.xAtY(yMid);
          hits.add((x: xAtMid, edge: e));
        }
      }
      if (hits.length < 2) continue;
      hits.sort((a, b) => a.x.compareTo(b.x));
      final leftEdge = hits.first.edge;
      final rightEdge = hits.last.edge;

      subs.add(MultivariableIntegral(
        integrand: integrand,
        bounds: [
          IntegrationBound(variable: 'x', lower: leftEdge.xOfYExpr, upper: rightEdge.xOfYExpr),
          IntegrationBound(variable: 'y', lower: _fmtClean(yA), upper: _fmtClean(yB)),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      ));
    }
    return subs;
  }

  static String _joinIntegralsLatex(List<MultivariableIntegral> list) {
    if (list.isEmpty) return '';
    return list.map(IntegralExpressionTransformer.toLatex).join(' + ');
  }

  static _NamedVertex? _parseVertex(String raw, String fallbackName) {
    final m = RegExp(r'^([A-Za-z][A-Za-z0-9]*)?\s*\(\s*([^,]+)\s*,\s*([^)]+)\s*\)$').firstMatch(raw.trim());
    if (m == null) return null;
    final name = m.group(1)?.trim().isNotEmpty == true ? m.group(1)!.trim() : fallbackName;
    final xStr = m.group(2)!.trim();
    final yStr = m.group(3)!.trim();
    final x = MathExpressionEvaluator.evaluate(xStr, params: _previewParams);
    final y = MathExpressionEvaluator.evaluate(yStr, params: _previewParams);
    if (!x.isFinite || !y.isFinite) return null;
    return _NamedVertex(name: name, x: x, y: y, xStr: xStr, yStr: yStr);
  }

  static String _fmtClean(double v) {
    if (!v.isFinite) return '0';
    if ((v - v.roundToDouble()).abs() < 1e-6) return '${v.round()}';
    final rat = SymRat.tryFromDouble(v, maxDenom: 120);
    if (rat != null) return rat.q == 1 ? '${rat.p}' : '${rat.p}/${rat.q}';
    return v.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
  }

  static String _astToInputString(SymExpr e) {
    return switch (e) {
      SymNum(:final rat) => rat.isInt ? '${rat.p}' : '(${rat.p}/${rat.q})',
      SymFloat(:final value) => '$value',
      SymConst(:final name) => name,
      SymVar(:final name) => name,
      SymAdd(:final terms) => terms.map(_astToInputString).join(' + '),
      SymMul(:final factors) => factors.map((f) => f is SymAdd ? '(${_astToInputString(f)})' : _astToInputString(f)).join('*'),
      SymDiv(:final num, :final den) => '(${_astToInputString(num)})/(${_astToInputString(den)})',
      SymPow(:final base, :final exp) => '(${_astToInputString(base)})^(${_astToInputString(exp)})',
      SymFunc(:final name, :final arg) => '$name(${_astToInputString(arg)})',
    };
  }
}

class _NamedVertex {
  final String name;
  final double x;
  final double y;
  final String xStr;
  final String yStr;
  const _NamedVertex({
    required this.name,
    required this.x,
    required this.y,
    required this.xStr,
    required this.yStr,
  });
}

class _PolyEdge {
  final _NamedVertex p1;
  final _NamedVertex p2;

  _PolyEdge(this.p1, this.p2);

  double yAtX(double x) {
    final dx = p2.x - p1.x;
    if (dx.abs() < 1e-9) return p1.y;
    return p1.y + (x - p1.x) * (p2.y - p1.y) / dx;
  }

  double xAtY(double y) {
    final dy = p2.y - p1.y;
    if (dy.abs() < 1e-9) return p1.x;
    return p1.x + (y - p1.y) * (p2.x - p1.x) / dy;
  }

  String get yOfXExpr {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    if (dy.abs() < 1e-9) return RegionGeometrySolver._fmtClean(p1.y);
    final m = dy / dx;
    final b = p1.y - m * p1.x;
    return _formatLinear('x', m, b);
  }

  String get xOfYExpr {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    if (dx.abs() < 1e-9) return RegionGeometrySolver._fmtClean(p1.x);
    final m = dx / dy;
    final b = p1.x - m * p1.y;
    return _formatLinear('y', m, b);
  }

  String get curveEquation {
    if ((p2.x - p1.x).abs() < 1e-9) return 'x = ${RegionGeometrySolver._fmtClean(p1.x)}';
    return 'y = $yOfXExpr';
  }

  String get equationDescription {
    final segName = '${p1.name}${p2.name}';
    if ((p2.x - p1.x).abs() < 1e-9) {
      return '$segName: x = ${RegionGeometrySolver._fmtClean(p1.x)}';
    }
    if ((p2.y - p1.y).abs() < 1e-9) {
      return '$segName: y = ${RegionGeometrySolver._fmtClean(p1.y)}';
    }
    return '$segName: y = ${IntegralExpressionTransformer.toDisplayLatex(yOfXExpr)} \\iff x = ${IntegralExpressionTransformer.toDisplayLatex(xOfYExpr)}';
  }

  String _formatLinear(String v, double m, double b) {
    final mRat = SymRat.tryFromDouble(m, maxDenom: 120);
    final bRat = SymRat.tryFromDouble(b, maxDenom: 120);
    String mPart;
    if (m.abs() < 1e-9) {
      mPart = '';
    } else if ((m - 1.0).abs() < 1e-9) {
      mPart = v;
    } else if ((m + 1.0).abs() < 1e-9) {
      mPart = '-$v';
    } else if (mRat != null) {
      mPart = mRat.q == 1 ? '${mRat.p}*$v' : '${mRat.p}*$v/${mRat.q}';
    } else {
      mPart = '${m.toStringAsFixed(3)}*$v';
    }

    if (b.abs() < 1e-9) return mPart.isEmpty ? '0' : mPart;
    final bStr = bRat != null ? (bRat.q == 1 ? '${bRat.p.abs()}' : '${bRat.p.abs()}/${bRat.q}') : b.abs().toStringAsFixed(3);
    if (mPart.isEmpty) return b < 0 ? '-$bStr' : bStr;
    return b < 0 ? '$mPart - $bStr' : '$mPart + $bStr';
  }
}
