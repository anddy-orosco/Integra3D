import 'dart:math' as math;
import 'dart:ui';
import '../../../../core/theme/app_colors.dart';
import '../../../calculator/domain/entities/integration_bound.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../calculator/domain/services/integral_expression_transformer.dart';
import '../../../calculator/domain/services/math_expression_evaluator.dart';
import '../../../calculator/domain/services/region_geometry_solver.dart';
import '../../../solver/domain/entities/integral_solution.dart';
import '../entities/domain_2d_model.dart';

class Domain2DExtractor {
  static const Map<String, double> defaultSymbolicParams = {
    'a': 1.0,
    'b': 1.0,
    'c': 1.0,
    'm': 1.0,
    'n': 2.0,
    'R': 2.0,
    'H': 3.0,
    'k': 1.0,
  };

  static Domain2DModel extract({
    required MultivariableIntegral integral,
    IntegralSolution? solution,
  }) {
    final params = Map<String, double>.from(defaultSymbolicParams);
    final paramNote = _detectParameterNote(integral, params);
    final domainAnalysis = solution?.domainAnalysis;

    // 1. Check if UV Jacobian data is explicitly provided in solution
    final uvModel = _extractUvMapping(integral, solution, params);

    // 2. Check if Polar 2D or Cylindrical 3D with (r, theta)
    final varNames = integral.bounds.map((b) => b.variable.toLowerCase()).toList();
    if (integral.coordinateSystem == CoordinateSystemType.polar ||
        (varNames.contains('r') && varNames.contains('theta'))) {
      return _extractPolarDomain(
        integral: integral,
        solution: solution,
        params: params,
        paramNote: paramNote,
        uvModel: uvModel,
      );
    }

    // 3. Check if Spherical 3D -> project disk of max rho onto XY plane
    if (integral.coordinateSystem == CoordinateSystemType.spherical ||
        (varNames.contains('rho') && varNames.contains('phi'))) {
      return _extractSphericalProjection(
        integral: integral,
        solution: solution,
        params: params,
        paramNote: paramNote,
        uvModel: uvModel,
      );
    }

    // 4. Check if UV_Jacobian region with 4 curves or uvData
    if (domainAnalysis?.regionType == 'UV_Jacobian' &&
        integral.boundaryCurves.isNotEmpty) {
      return _extractBoundaryCurvesDomain(
        integral: integral,
        solution: solution,
        params: params,
        paramNote: paramNote,
        uvModel: uvModel,
      );
    }

    // 5. Polygon vertices mode
    if (integral.problemMode == ProblemMode.regionVertices &&
        integral.verticesInput.isNotEmpty) {
      final polyDomain = _extractPolygonDomain(
        integral: integral,
        solution: solution,
        params: params,
        paramNote: paramNote,
        uvModel: uvModel,
      );
      if (polyDomain != null) return polyDomain;
    }

    // 6. Region by explicit/implicit curves if provided
    if (integral.boundaryCurves.isNotEmpty &&
        integral.bounds.length < 2) {
      return _extractBoundaryCurvesDomain(
        integral: integral,
        solution: solution,
        params: params,
        paramNote: paramNote,
        uvModel: uvModel,
      );
    }

    // 7. Standard Cartesian 2D or 3D (projecting XY base)
    return _extractCartesianDomain(
      integral: integral,
      solution: solution,
      params: params,
      paramNote: paramNote,
      uvModel: uvModel,
    );
  }

  static String? _detectParameterNote(
    MultivariableIntegral integral,
    Map<String, double> params,
  ) {
    final combined = [
      integral.integrand,
      ...integral.bounds.map((b) => '${b.lower} ${b.upper}'),
      ...integral.boundaryCurves,
      integral.zLowerExpr ?? '',
      integral.zUpperExpr ?? '',
      integral.densityExpr ?? '',
    ].join(' ');

    final used = <String>[];
    for (final entry in params.entries) {
      final key = entry.key;
      final regex = RegExp('\\b$key\\b');
      if (regex.hasMatch(combined)) {
        final v = entry.value;
        final vStr = v == v.roundToDouble() ? '${v.toInt()}' : '$v';
        used.add('$key = $vStr');
      }
    }
    if (used.isEmpty) return null;
    return 'Escala gráfica: ${used.join(', ')}';
  }

  static Domain2DModel _extractCartesianDomain({
    required MultivariableIntegral integral,
    required IntegralSolution? solution,
    required Map<String, double> params,
    required String? paramNote,
    required UvMappingModel? uvModel,
  }) {
    // Select the two planar bounds (x and y)
    IntegrationBound? bInner;
    IntegrationBound? bOuter;

    if (integral.bounds.length == 2) {
      bInner = integral.bounds[0];
      bOuter = integral.bounds[1];
    } else if (integral.bounds.length >= 3) {
      // Triple integral: [z, y, x] -> planar domain is [y, x]
      final planar = integral.bounds
          .where((b) => b.variable.toLowerCase() == 'x' || b.variable.toLowerCase() == 'y')
          .toList();
      if (planar.length >= 2) {
        bInner = planar[0];
        bOuter = planar[1];
      } else {
        bInner = integral.bounds[1];
        bOuter = integral.bounds[2];
      }
    } else if (integral.bounds.length == 1) {
      bInner = const IntegrationBound(variable: 'y', lower: '0', upper: '1');
      bOuter = integral.bounds[0];
    } else {
      bInner = const IntegrationBound(variable: 'y', lower: '0', upper: 'x');
      bOuter = const IntegrationBound(variable: 'x', lower: '0', upper: '2');
    }

    final inVar = bInner.variable.toLowerCase();
    final outVar = bOuter.variable.toLowerCase();
    final bool isInitiallyTypeI = (inVar == 'y' && outVar == 'x');

    final integrandLatex = IntegralExpressionTransformer.toDisplayLatex(integral.integrand);
    final fDisplay = integrandLatex.isEmpty ? '1' : integrandLatex;

    final curves = <PlotCurve2D>[];
    final shadedRegions = <List<Offset>>[];
    final intersections = <DomainPoint2D>[];

    double xMin = -2.0, xMax = 2.0, yMin = -2.0, yMax = 2.0;
    String xMinL = '0', xMaxL = '1', yLowL = '0', yUppL = '1';
    String yMinL = '0', yMaxL = '1', xLowL = '0', xUppL = '1';
    double Function(double)? yLowFn;
    double Function(double)? yUppFn;
    double Function(double)? xLowFn;
    double Function(double)? xUppFn;

    const int nSamples = 90;

    if (isInitiallyTypeI) {
      final rawOutA = MathExpressionEvaluator.evaluate(bOuter.lower, params: params);
      final rawOutB = MathExpressionEvaluator.evaluate(bOuter.upper, params: params);
      xMin = (rawOutA.isFinite && rawOutB.isFinite) ? math.min(rawOutA, rawOutB) : -2.0;
      xMax = (rawOutA.isFinite && rawOutB.isFinite) ? math.max(rawOutA, rawOutB) : 2.0;
      if ((xMax - xMin).abs() < 1e-6) {
        xMin -= 1.0;
        xMax += 1.0;
      }

      xMinL = IntegralExpressionTransformer.toDisplayLatex(bOuter.lower);
      xMaxL = IntegralExpressionTransformer.toDisplayLatex(bOuter.upper);
      yLowL = IntegralExpressionTransformer.toDisplayLatex(bInner.lower);
      yUppL = IntegralExpressionTransformer.toDisplayLatex(bInner.upper);

      yLowFn = (x) {
        final v = MathExpressionEvaluator.evaluate(bInner!.lower, x: x, params: params);
        return v.isFinite ? v : 0.0;
      };
      yUppFn = (x) {
        final v = MathExpressionEvaluator.evaluate(bInner!.upper, x: x, params: params);
        return v.isFinite ? v : 0.0;
      };

      final topPts = <Offset>[];
      final botPts = <Offset>[];
      double obsYMin = double.infinity;
      double obsYMax = double.negativeInfinity;

      for (int i = 0; i <= nSamples; i++) {
        final t = i / nSamples;
        final x = xMin + (xMax - xMin) * t;
        final yl = MathExpressionEvaluator.evaluate(bInner.lower, x: x, params: params);
        final yu = MathExpressionEvaluator.evaluate(bInner.upper, x: x, params: params);
        if (yl.isFinite && yu.isFinite) {
          final low = math.min(yl, yu);
          final upp = math.max(yl, yu);
          botPts.add(Offset(x, low));
          topPts.add(Offset(x, upp));
          if (low < obsYMin) obsYMin = low;
          if (upp > obsYMax) obsYMax = upp;
        }
      }

      if (obsYMin.isFinite && obsYMax.isFinite) {
        yMin = obsYMin;
        yMax = obsYMax;
      }

      if (topPts.length >= 2 && botPts.length >= 2) {
        shadedRegions.add([...topPts, ...botPts.reversed]);
      }

      // Add curves
      curves.add(PlotCurve2D(
        label: 'y = ${bInner.upper}',
        kind: Curve2DKind.explicitYOfX,
        color: AppColors.electricCyan,
        minParam: xMin,
        maxParam: xMax,
        eval1D: (x) => MathExpressionEvaluator.evaluate(bInner!.upper, x: x, params: params),
      ));
      curves.add(PlotCurve2D(
        label: 'y = ${bInner.lower}',
        kind: Curve2DKind.explicitYOfX,
        color: AppColors.violetHeatmap,
        minParam: xMin,
        maxParam: xMax,
        eval1D: (x) => MathExpressionEvaluator.evaluate(bInner!.lower, x: x, params: params),
      ));
      if ((yUppFn(xMin) - yLowFn(xMin)).abs() > 1e-4) {
        curves.add(PlotCurve2D(
          label: 'x = ${bOuter.lower}',
          kind: Curve2DKind.segment,
          color: AppColors.mutedGray,
          segmentStart: Offset(xMin, yLowFn(xMin)),
          segmentEnd: Offset(xMin, yUppFn(xMin)),
        ));
      }
      if ((yUppFn(xMax) - yLowFn(xMax)).abs() > 1e-4) {
        curves.add(PlotCurve2D(
          label: 'x = ${bOuter.upper}',
          kind: Curve2DKind.segment,
          color: AppColors.mutedGray,
          segmentStart: Offset(xMax, yLowFn(xMax)),
          segmentEnd: Offset(xMax, yUppFn(xMax)),
        ));
      }

      // Build Type II numerical envelope from shaded polygon
      final inv = _inferTypeIIFromPolygon(
        polygon: shadedRegions.isNotEmpty ? shadedRegions.first : const [],
        innerBound: bInner,
        outerBound: bOuter,
        yMin: yMin,
        yMax: yMax,
        params: params,
      );
      yMinL = inv.yMinLatex;
      yMaxL = inv.yMaxLatex;
      xLowL = inv.xLowLatex;
      xUppL = inv.xUppLatex;
      xLowFn = inv.xLowFn;
      xUppFn = inv.xUppFn;

      _collectIntersectionsFromCorners(
        intersections: intersections,
        solution: solution,
        polygonPtsTop: topPts,
        polygonPtsBot: botPts,
        xMin: xMin,
        xMax: xMax,
      );
    } else {
      // Initially Type II: inner = x(y), outer = y
      final rawOutA = MathExpressionEvaluator.evaluate(bOuter.lower, params: params);
      final rawOutB = MathExpressionEvaluator.evaluate(bOuter.upper, params: params);
      yMin = (rawOutA.isFinite && rawOutB.isFinite) ? math.min(rawOutA, rawOutB) : -2.0;
      yMax = (rawOutA.isFinite && rawOutB.isFinite) ? math.max(rawOutA, rawOutB) : 2.0;
      if ((yMax - yMin).abs() < 1e-6) {
        yMin -= 1.0;
        yMax += 1.0;
      }

      yMinL = IntegralExpressionTransformer.toDisplayLatex(bOuter.lower);
      yMaxL = IntegralExpressionTransformer.toDisplayLatex(bOuter.upper);
      xLowL = IntegralExpressionTransformer.toDisplayLatex(bInner.lower);
      xUppL = IntegralExpressionTransformer.toDisplayLatex(bInner.upper);

      xLowFn = (y) {
        final v = MathExpressionEvaluator.evaluate(bInner!.lower, y: y, params: params);
        return v.isFinite ? v : 0.0;
      };
      xUppFn = (y) {
        final v = MathExpressionEvaluator.evaluate(bInner!.upper, y: y, params: params);
        return v.isFinite ? v : 0.0;
      };

      final rightPts = <Offset>[];
      final leftPts = <Offset>[];
      double obsXMin = double.infinity;
      double obsXMax = double.negativeInfinity;

      for (int i = 0; i <= nSamples; i++) {
        final t = i / nSamples;
        final y = yMin + (yMax - yMin) * t;
        final xl = MathExpressionEvaluator.evaluate(bInner.lower, y: y, params: params);
        final xu = MathExpressionEvaluator.evaluate(bInner.upper, y: y, params: params);
        if (xl.isFinite && xu.isFinite) {
          final low = math.min(xl, xu);
          final upp = math.max(xl, xu);
          leftPts.add(Offset(low, y));
          rightPts.add(Offset(upp, y));
          if (low < obsXMin) obsXMin = low;
          if (upp > obsXMax) obsXMax = upp;
        }
      }

      if (obsXMin.isFinite && obsXMax.isFinite) {
        xMin = obsXMin;
        xMax = obsXMax;
      }

      if (rightPts.length >= 2 && leftPts.length >= 2) {
        shadedRegions.add([...rightPts, ...leftPts.reversed]);
      }

      curves.add(PlotCurve2D(
        label: 'x = ${bInner.upper}',
        kind: Curve2DKind.explicitXOfY,
        color: AppColors.electricCyan,
        minParam: yMin,
        maxParam: yMax,
        eval1D: (y) => MathExpressionEvaluator.evaluate(bInner!.upper, y: y, params: params),
      ));
      curves.add(PlotCurve2D(
        label: 'x = ${bInner.lower}',
        kind: Curve2DKind.explicitXOfY,
        color: AppColors.violetHeatmap,
        minParam: yMin,
        maxParam: yMax,
        eval1D: (y) => MathExpressionEvaluator.evaluate(bInner!.lower, y: y, params: params),
      ));

      if ((xUppFn(yMin) - xLowFn(yMin)).abs() > 1e-4) {
        curves.add(PlotCurve2D(
          label: 'y = ${bOuter.lower}',
          kind: Curve2DKind.segment,
          color: AppColors.mutedGray,
          segmentStart: Offset(xLowFn(yMin), yMin),
          segmentEnd: Offset(xUppFn(yMin), yMin),
        ));
      }
      if ((xUppFn(yMax) - xLowFn(yMax)).abs() > 1e-4) {
        curves.add(PlotCurve2D(
          label: 'y = ${bOuter.upper}',
          kind: Curve2DKind.segment,
          color: AppColors.mutedGray,
          segmentStart: Offset(xLowFn(yMax), yMax),
          segmentEnd: Offset(xUppFn(yMax), yMax),
        ));
      }

      // Infer Type I from Type II
      final inv = _inferTypeIFromPolygon(
        polygon: shadedRegions.isNotEmpty ? shadedRegions.first : const [],
        innerBound: bInner,
        outerBound: bOuter,
        xMin: xMin,
        xMax: xMax,
        params: params,
      );
      xMinL = inv.xMinLatex;
      xMaxL = inv.xMaxLatex;
      yLowL = inv.yLowLatex;
      yUppL = inv.yUppLatex;
      yLowFn = inv.yLowFn;
      yUppFn = inv.yUppFn;

      _collectIntersectionsFromCorners(
        intersections: intersections,
        solution: solution,
        polygonPtsTop: rightPts,
        polygonPtsBot: leftPts,
        xMin: yMin,
        xMax: yMax,
      );
    }

    // Include explicit boundary curves if provided
    for (final rawCurve in integral.boundaryCurves) {
      _addParsedCurve(curves, rawCurve, xMin, xMax, yMin, yMax, params);
    }

    final typeILatex = '\\int_{$xMinL}^{$xMaxL} \\int_{$yLowL}^{$yUppL} $fDisplay \\, dy \\, dx';
    final typeIILatex = '\\int_{$yMinL}^{$yMaxL} \\int_{$xLowL}^{$xUppL} $fDisplay \\, dx \\, dy';

    return Domain2DModel(
      title: 'Dominio Plano R',
      curves: curves,
      shadedRegions: shadedRegions,
      intersectionPoints: intersections,
      preferredSweepOrder: isInitiallyTypeI ? SweepOrderType.typeI : SweepOrderType.typeII,
      xMin: xMin,
      xMax: xMax,
      xMinLatex: xMinL,
      xMaxLatex: xMaxL,
      yLowerLatex: yLowL,
      yUpperLatex: yUppL,
      yLowerAtX: yLowFn,
      yUpperAtX: yUppFn,
      typeIIntegralLatex: typeILatex,
      yMin: yMin,
      yMax: yMax,
      yMinLatex: yMinL,
      yMaxLatex: yMaxL,
      xLowerLatex: xLowL,
      xUpperLatex: xUppL,
      xLowerAtY: xLowFn,
      xUpperAtY: xUppFn,
      typeIIIntegralLatex: typeIILatex,
      parameterNote: paramNote,
      uvMapping: uvModel,
    );
  }

  static Domain2DModel _extractPolarDomain({
    required MultivariableIntegral integral,
    required IntegralSolution? solution,
    required Map<String, double> params,
    required String? paramNote,
    required UvMappingModel? uvModel,
  }) {
    IntegrationBound rBound = const IntegrationBound(variable: 'r', lower: '0', upper: '2');
    IntegrationBound thBound = const IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi');

    for (final b in integral.bounds) {
      final v = b.variable.toLowerCase();
      if (v == 'r') rBound = b;
      if (v == 'theta' || v == 'θ') thBound = b;
    }

    final thA = MathExpressionEvaluator.evaluate(thBound.lower, params: params);
    final thB = MathExpressionEvaluator.evaluate(thBound.upper, params: params);
    final thMin = (thA.isFinite && thB.isFinite) ? math.min(thA, thB) : 0.0;
    final thMax = (thA.isFinite && thB.isFinite) ? math.max(thA, thB) : 2.0 * math.pi;

    double evalR(String expr, double th) {
      final v = MathExpressionEvaluator.evaluate(
        expr,
        params: {...params, 'theta': th},
      );
      return v.isFinite ? math.max(0.0, v) : 0.0;
    }

    const int n = 120;
    final outerPts = <Offset>[];
    final innerPts = <Offset>[];
    double xMin = double.infinity, xMax = double.negativeInfinity;
    double yMin = double.infinity, yMax = double.negativeInfinity;

    for (int i = 0; i <= n; i++) {
      final th = thMin + (thMax - thMin) * (i / n);
      final rIn = evalR(rBound.lower, th);
      final rOut = evalR(rBound.upper, th);
      final xo = rOut * math.cos(th);
      final yo = rOut * math.sin(th);
      final xi = rIn * math.cos(th);
      final yi = rIn * math.sin(th);
      outerPts.add(Offset(xo, yo));
      innerPts.add(Offset(xi, yi));
      for (final p in [Offset(xo, yo), Offset(xi, yi)]) {
        if (p.dx < xMin) xMin = p.dx;
        if (p.dx > xMax) xMax = p.dx;
        if (p.dy < yMin) yMin = p.dy;
        if (p.dy > yMax) yMax = p.dy;
      }
    }

    if (!xMin.isFinite || (xMax - xMin).abs() < 1e-6) {
      xMin = -2.0;
      xMax = 2.0;
      yMin = -2.0;
      yMax = 2.0;
    }

    final polygon = [...outerPts, ...innerPts.reversed];
    final curves = <PlotCurve2D>[
      PlotCurve2D(
        label: 'r = ${rBound.upper}',
        kind: Curve2DKind.polarROfTheta,
        color: AppColors.electricCyan,
        minParam: thMin,
        maxParam: thMax,
        eval1D: (th) => evalR(rBound.upper, th),
      ),
      if (rBound.lower.trim() != '0')
        PlotCurve2D(
          label: 'r = ${rBound.lower}',
          kind: Curve2DKind.polarROfTheta,
          color: AppColors.violetHeatmap,
          minParam: thMin,
          maxParam: thMax,
          eval1D: (th) => evalR(rBound.lower, th),
        ),
    ];

    final intersections = <DomainPoint2D>[];
    if (solution?.domainAnalysis != null &&
        solution!.domainAnalysis!.intersectionPoints.isNotEmpty) {
      for (final pt in solution.domainAnalysis!.intersectionPoints) {
        final px = MathExpressionEvaluator.evaluate(pt['x'] ?? '0', params: params);
        final py = MathExpressionEvaluator.evaluate(pt['y'] ?? '0', params: params);
        if (px.isFinite && py.isFinite) {
          intersections.add(DomainPoint2D(
            x: px,
            y: py,
            label: '(${pt['x']}, ${pt['y']})',
          ));
        }
      }
    } else {
      // Cardinal points at theta = thMin, thMax, and midpoint
      for (final th in {thMin, (thMin + thMax) / 2, thMax}) {
        final r = evalR(rBound.upper, th);
        final x = r * math.cos(th);
        final y = r * math.sin(th);
        _addUniquePoint(intersections, DomainPoint2D(
          x: x,
          y: y,
          label: '(${_fmtNum(x)}, ${_fmtNum(y)})',
        ));
      }
    }

    final invY = _envelopeFromPolygonX(polygon, xMin, xMax);
    final invX = _envelopeFromPolygonY(polygon, yMin, yMax);

    final fDisp = IntegralExpressionTransformer.toDisplayLatex(integral.integrand);
    final rLowL = IntegralExpressionTransformer.toDisplayLatex(rBound.lower);
    final rUppL = IntegralExpressionTransformer.toDisplayLatex(rBound.upper);
    final thLowL = IntegralExpressionTransformer.toDisplayLatex(thBound.lower);
    final thUppL = IntegralExpressionTransformer.toDisplayLatex(thBound.upper);
    final polarIntegral = '\\int_{$thLowL}^{$thUppL} \\int_{$rLowL}^{$rUppL} ($fDisp) \\, r \\, dr \\, d\\theta';

    return Domain2DModel(
      title: 'Dominio Polar R (r, θ)',
      curves: curves,
      shadedRegions: [polygon],
      intersectionPoints: intersections,
      preferredSweepOrder: SweepOrderType.typeI,
      xMin: xMin,
      xMax: xMax,
      xMinLatex: _fmtNum(xMin),
      xMaxLatex: _fmtNum(xMax),
      yLowerLatex: 'y_{\\text{inf}}(x)',
      yUpperLatex: 'y_{\\text{sup}}(x)',
      yLowerAtX: invY.$1,
      yUpperAtX: invY.$2,
      typeIIntegralLatex: polarIntegral,
      yMin: yMin,
      yMax: yMax,
      yMinLatex: _fmtNum(yMin),
      yMaxLatex: _fmtNum(yMax),
      xLowerLatex: 'x_{\\text{izq}}(y)',
      xUpperLatex: 'x_{\\text{der}}(y)',
      xLowerAtY: invX.$1,
      xUpperAtY: invX.$2,
      typeIIIntegralLatex: polarIntegral,
      parameterNote: paramNote,
      uvMapping: uvModel ??
          UvMappingModel(
            title: 'Mapeo Polar (r, θ) → (x, y)',
            transformForwardLatex: r'x = r\cos\theta, \quad y = r\sin\theta',
            transformInverseLatex: r'r = \sqrt{x^2 + y^2}, \quad \theta = \arctan(y/x)',
            jacobianLatex: r'J(r,\theta) = \begin{vmatrix} \cos\theta & -r\sin\theta \\ \sin\theta & r\cos\theta \end{vmatrix} = r',
            uVarLabel: 'r',
            vVarLabel: 'θ',
            uMin: 0.0,
            uMax: math.max(1.0, xMax.abs()),
            vMin: thMin,
            vMax: thMax,
            uMinLatex: rLowL,
            uMaxLatex: rUppL,
            vMinLatex: thLowL,
            vMaxLatex: thUppL,
            transformedIntegralLatex: polarIntegral,
            isActiveTransformation: true,
            mapUvToXy: (r, th) => Offset(r * math.cos(th), r * math.sin(th)),
          ),
    );
  }

  static Domain2DModel _extractSphericalProjection({
    required MultivariableIntegral integral,
    required IntegralSolution? solution,
    required Map<String, double> params,
    required String? paramNote,
    required UvMappingModel? uvModel,
  }) {
    IntegrationBound rhoB = const IntegrationBound(variable: 'rho', lower: '0', upper: '2');
    IntegrationBound phiB = const IntegrationBound(variable: 'phi', lower: '0', upper: 'pi');
    IntegrationBound thB = const IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi');
    for (final b in integral.bounds) {
      final v = b.variable.toLowerCase();
      if (v == 'rho' || v == 'ρ') rhoB = b;
      if (v == 'phi' || v == 'φ') phiB = b;
      if (v == 'theta' || v == 'θ') thB = b;
    }

    final phiMax = MathExpressionEvaluator.evaluate(phiB.upper, params: params);
    final rhoMax = MathExpressionEvaluator.evaluate(rhoB.upper, params: {...params, 'phi': math.pi / 2, 'theta': 0.0});
    final thMin = MathExpressionEvaluator.evaluate(thB.lower, params: params);
    final thMax = MathExpressionEvaluator.evaluate(thB.upper, params: params);
    final rEff = (rhoMax.isFinite && rhoMax > 0 ? rhoMax : 2.0) *
        (phiMax.isFinite && phiMax < math.pi / 2 ? math.sin(phiMax) : 1.0);

    final thA = thMin.isFinite ? thMin : 0.0;
    final thBVal = thMax.isFinite ? thMax : 2 * math.pi;

    final pts = <Offset>[];
    for (int i = 0; i <= 90; i++) {
      final th = thA + (thBVal - thA) * (i / 90);
      pts.add(Offset(rEff * math.cos(th), rEff * math.sin(th)));
    }
    if ((thBVal - thA).abs() < 2 * math.pi - 0.05) {
      pts.add(Offset.zero);
    }

    final envY = _envelopeFromPolygonX(pts, -rEff, rEff);
    final envX = _envelopeFromPolygonY(pts, -rEff, rEff);
    final latex = solution?.originalIntegralLatex ?? IntegralExpressionTransformer.toLatex(integral);

    return Domain2DModel(
      title: 'Proyección XY del Sólido Esférico',
      curves: [
        PlotCurve2D(
          label: 'r_proy = ${_fmtNum(rEff)}',
          kind: Curve2DKind.polarROfTheta,
          color: AppColors.electricCyan,
          minParam: thA,
          maxParam: thBVal,
          eval1D: (_) => rEff,
        ),
      ],
      shadedRegions: [pts],
      intersectionPoints: [
        DomainPoint2D(x: rEff, y: 0, label: '(${_fmtNum(rEff)}, 0)'),
        DomainPoint2D(x: 0, y: rEff, label: '(0, ${_fmtNum(rEff)})'),
      ],
      preferredSweepOrder: SweepOrderType.typeI,
      xMin: -rEff,
      xMax: rEff,
      xMinLatex: '-${_fmtNum(rEff)}',
      xMaxLatex: _fmtNum(rEff),
      yLowerLatex: '-\\sqrt{${_fmtNum(rEff * rEff)} - x^2}',
      yUpperLatex: '\\sqrt{${_fmtNum(rEff * rEff)} - x^2}',
      yLowerAtX: envY.$1,
      yUpperAtX: envY.$2,
      typeIIntegralLatex: latex,
      yMin: -rEff,
      yMax: rEff,
      yMinLatex: '-${_fmtNum(rEff)}',
      yMaxLatex: _fmtNum(rEff),
      xLowerLatex: '-\\sqrt{${_fmtNum(rEff * rEff)} - y^2}',
      xUpperLatex: '\\sqrt{${_fmtNum(rEff * rEff)} - y^2}',
      xLowerAtY: envX.$1,
      xUpperAtY: envX.$2,
      typeIIIntegralLatex: latex,
      parameterNote: paramNote,
      uvMapping: uvModel,
    );
  }

  static Domain2DModel? _extractPolygonDomain({
    required MultivariableIntegral integral,
    required IntegralSolution? solution,
    required Map<String, double> params,
    required String? paramNote,
    required UvMappingModel? uvModel,
  }) {
    final pts = <Offset>[];
    final labels = <String>[];
    for (final raw in integral.verticesInput) {
      final parsed = _parseVertexString(raw, params);
      if (parsed != null) {
        pts.add(parsed.$1);
        labels.add(parsed.$2);
      }
    }
    if (pts.length < 3) return null;

    // Order polygon vertices around centroid (counter-clockwise)
    final cx = pts.fold(0.0, (s, p) => s + p.dx) / pts.length;
    final cy = pts.fold(0.0, (s, p) => s + p.dy) / pts.length;
    final indexed = List.generate(pts.length, (i) => (pts[i], labels[i]));
    indexed.sort((a, b) {
      final angA = math.atan2(a.$1.dy - cy, a.$1.dx - cx);
      final angB = math.atan2(b.$1.dy - cy, b.$1.dx - cx);
      return angA.compareTo(angB);
    });
    final ordered = indexed.map((e) => e.$1).toList();
    final orderedLabels = indexed.map((e) => e.$2).toList();

    final curves = <PlotCurve2D>[];
    for (int i = 0; i < ordered.length; i++) {
      final p1 = ordered[i];
      final p2 = ordered[(i + 1) % ordered.length];
      curves.add(PlotCurve2D(
        label: 'Lado ${i + 1}',
        kind: Curve2DKind.segment,
        color: i.isEven ? AppColors.electricCyan : AppColors.violetHeatmap,
        segmentStart: p1,
        segmentEnd: p2,
      ));
    }

    double xMin = ordered.map((p) => p.dx).reduce(math.min);
    double xMax = ordered.map((p) => p.dx).reduce(math.max);
    double yMin = ordered.map((p) => p.dy).reduce(math.min);
    double yMax = ordered.map((p) => p.dy).reduce(math.max);

    final envY = _envelopeFromPolygonX(ordered, xMin, xMax);
    final envX = _envelopeFromPolygonY(ordered, yMin, yMax);

    final intersections = [
      for (int i = 0; i < ordered.length; i++)
        DomainPoint2D(x: ordered[i].dx, y: ordered[i].dy, label: orderedLabels[i]),
    ];

    final dedLatex = solution?.domainAnalysis?.deducedLimitsLatex ??
        solution?.originalIntegralLatex ??
        IntegralExpressionTransformer.toLatex(integral);
    final altLatex = solution?.domainAnalysis?.alternateOrderLatex ?? dedLatex;
    final isTypeII = solution?.domainAnalysis?.regionType == 'Type II';

    return Domain2DModel(
      title: 'Región Poligonal R',
      curves: curves,
      shadedRegions: [ordered],
      intersectionPoints: intersections,
      preferredSweepOrder: isTypeII ? SweepOrderType.typeII : SweepOrderType.typeI,
      xMin: xMin,
      xMax: xMax,
      xMinLatex: _fmtNum(xMin),
      xMaxLatex: _fmtNum(xMax),
      yLowerLatex: 'y_{\\text{inf}}(x)',
      yUpperLatex: 'y_{\\text{sup}}(x)',
      yLowerAtX: envY.$1,
      yUpperAtX: envY.$2,
      typeIIntegralLatex: isTypeII ? altLatex : dedLatex,
      yMin: yMin,
      yMax: yMax,
      yMinLatex: _fmtNum(yMin),
      yMaxLatex: _fmtNum(yMax),
      xLowerLatex: 'x_{\\text{izq}}(y)',
      xUpperLatex: 'x_{\\text{der}}(y)',
      xLowerAtY: envX.$1,
      xUpperAtY: envX.$2,
      typeIIIntegralLatex: isTypeII ? dedLatex : altLatex,
      parameterNote: paramNote,
      uvMapping: uvModel,
    );
  }

  static Domain2DModel _extractBoundaryCurvesDomain({
    required MultivariableIntegral integral,
    required IntegralSolution? solution,
    required Map<String, double> params,
    required String? paramNote,
    required UvMappingModel? uvModel,
  }) {
    final curves = <PlotCurve2D>[];
    final intersections = <DomainPoint2D>[];

    if (solution?.domainAnalysis != null) {
      for (final pt in solution!.domainAnalysis!.intersectionPoints) {
        final px = MathExpressionEvaluator.evaluate(pt['x'] ?? '0', params: params);
        final py = MathExpressionEvaluator.evaluate(pt['y'] ?? '0', params: params);
        if (px.isFinite && py.isFinite) {
          intersections.add(DomainPoint2D(
            x: px,
            y: py,
            label: '(${pt['x']}, ${pt['y']})',
          ));
        }
      }
    }

    double xMin = -3.0, xMax = 3.0, yMin = -3.0, yMax = 3.0;
    if (intersections.length >= 2) {
      xMin = intersections.map((p) => p.x).reduce(math.min);
      xMax = intersections.map((p) => p.x).reduce(math.max);
      yMin = intersections.map((p) => p.dyForSort).reduce(math.min);
      yMax = intersections.map((p) => p.dyForSort).reduce(math.max);
      if ((xMax - xMin).abs() < 0.2) {
        xMin -= 1.0;
        xMax += 1.0;
      }
      if ((yMax - yMin).abs() < 0.2) {
        yMin -= 1.0;
        yMax += 1.0;
      }
    }

    for (final rawCurve in integral.boundaryCurves) {
      _addParsedCurve(curves, rawCurve, xMin - 1.0, xMax + 1.0, yMin - 1.0, yMax + 1.0, params);
    }

    // Build shaded polygon from UV mapping if available, else from bounds
    final shaded = <List<Offset>>[];
    if (uvModel != null && uvModel.mapUvToXy != null) {
      final poly = <Offset>[];
      const steps = 25;
      for (int i = 0; i <= steps; i++) {
        final u = uvModel.uMin + (uvModel.uMax - uvModel.uMin) * (i / steps);
        poly.add(uvModel.mapUvToXy!(u, uvModel.vMin));
      }
      for (int i = 0; i <= steps; i++) {
        final v = uvModel.vMin + (uvModel.vMax - uvModel.vMin) * (i / steps);
        poly.add(uvModel.mapUvToXy!(uvModel.uMax, v));
      }
      for (int i = steps; i >= 0; i--) {
        final u = uvModel.uMin + (uvModel.uMax - uvModel.uMin) * (i / steps);
        poly.add(uvModel.mapUvToXy!(u, uvModel.vMax));
      }
      for (int i = steps; i >= 0; i--) {
        final v = uvModel.vMin + (uvModel.vMax - uvModel.vMin) * (i / steps);
        poly.add(uvModel.mapUvToXy!(uvModel.uMin, v));
      }
      shaded.add(poly);
      if (poly.isNotEmpty) {
        xMin = poly.map((p) => p.dx).reduce(math.min);
        xMax = poly.map((p) => p.dx).reduce(math.max);
        yMin = poly.map((p) => p.dy).reduce(math.min);
        yMax = poly.map((p) => p.dy).reduce(math.max);
      }
    }

    final poly = shaded.isNotEmpty ? shaded.first : <Offset>[];
    final envY = _envelopeFromPolygonX(poly, xMin, xMax);
    final envX = _envelopeFromPolygonY(poly, yMin, yMax);
    final latex = solution?.originalIntegralLatex ?? IntegralExpressionTransformer.toLatex(integral);

    return Domain2DModel(
      title: 'Dominio Curvilíneo R',
      curves: curves,
      shadedRegions: shaded,
      intersectionPoints: intersections,
      preferredSweepOrder: SweepOrderType.typeI,
      xMin: xMin,
      xMax: xMax,
      xMinLatex: _fmtNum(xMin),
      xMaxLatex: _fmtNum(xMax),
      yLowerLatex: 'y_{\\text{inf}}(x)',
      yUpperLatex: 'y_{\\text{sup}}(x)',
      yLowerAtX: envY.$1,
      yUpperAtX: envY.$2,
      typeIIntegralLatex: latex,
      yMin: yMin,
      yMax: yMax,
      yMinLatex: _fmtNum(yMin),
      yMaxLatex: _fmtNum(yMax),
      xLowerLatex: 'x_{\\text{izq}}(y)',
      xUpperLatex: 'x_{\\text{der}}(y)',
      xLowerAtY: envX.$1,
      xUpperAtY: envX.$2,
      typeIIIntegralLatex: latex,
      parameterNote: paramNote,
      uvMapping: uvModel,
    );
  }

  static UvMappingModel? _extractUvMapping(
    MultivariableIntegral integral,
    IntegralSolution? solution,
    Map<String, double> params,
  ) {
    var effectiveDomain = solution?.domainAnalysis;
    if (effectiveDomain?.uvData == null && integral.boundaryCurves.length >= 4) {
      final deduced = RegionGeometrySolver.deduceFromCurves(
        curvesInput: integral.boundaryCurves,
        integrand: integral.integrand,
        preferredOrder: 'uv',
        customUvTransform: integral.uvTransformInput,
      );
      if (deduced?.domainAnalysis.uvData != null) {
        effectiveDomain = deduced!.domainAnalysis;
      }
    }

    final uvData = effectiveDomain?.uvData;
    if (uvData != null) {
      final uMin = (uvData['u_min'] as num?)?.toDouble() ?? 0.0;
      final uMax = (uvData['u_max'] as num?)?.toDouble() ?? 1.0;
      final vMin = (uvData['v_min'] as num?)?.toDouble() ?? 0.0;
      final vMax = (uvData['v_max'] as num?)?.toDouble() ?? 1.0;
      final xOfUvStr = uvData['x_of_uv'] as String?;
      final yOfUvStr = uvData['y_of_uv'] as String?;
      final uVar = uvData['u_var'] as String? ?? 'u';
      final vVar = uvData['v_var'] as String? ?? 'v';

      Offset Function(double, double)? mapper;
      if (xOfUvStr != null && yOfUvStr != null) {
        mapper = (u, v) {
          final evalParams = {...params, uVar: u, vVar: v, 'u': u, 'v': v};
          final x = MathExpressionEvaluator.evaluate(xOfUvStr, params: evalParams);
          final y = MathExpressionEvaluator.evaluate(yOfUvStr, params: evalParams);
          return Offset(x.isFinite ? x : 0.0, y.isFinite ? y : 0.0);
        };
      }

      return UvMappingModel(
        title: uvData['title'] as String? ?? 'Transformación Jacobiana (u, v)',
        transformForwardLatex: uvData['forward_latex'] as String? ?? '',
        transformInverseLatex: uvData['inverse_latex'] as String? ?? '',
        jacobianLatex: effectiveDomain?.jacobianLatex ?? uvData['jacobian_latex'] as String? ?? '',
        uVarLabel: uVar,
        vVarLabel: vVar,
        uMin: uMin,
        uMax: uMax,
        vMin: vMin,
        vMax: vMax,
        uMinLatex: uvData['u_min_latex'] as String? ?? _fmtNum(uMin),
        uMaxLatex: uvData['u_max_latex'] as String? ?? _fmtNum(uMax),
        vMinLatex: uvData['v_min_latex'] as String? ?? _fmtNum(vMin),
        vMaxLatex: uvData['v_max_latex'] as String? ?? _fmtNum(vMax),
        transformedIntegralLatex: uvData['transformed_integral_latex'] as String? ?? '',
        isActiveTransformation: true,
        mapUvToXy: mapper,
      );
    }

    // Check if solution domainAnalysis indicates Polar, Cylindrical, or Spherical
    final rType = solution?.domainAnalysis?.regionType ?? '';
    if (rType == 'Polar' || rType == 'Cylindrical' || integral.coordinateSystem == CoordinateSystemType.cylindrical) {
      double rMax = 2.0;
      double thMin = 0.0;
      double thMax = 2 * math.pi;
      String rMaxL = 'R';
      String thMinL = '0';
      String thMaxL = r'2\pi';

      for (final b in integral.bounds) {
        if (b.variable.toLowerCase() == 'r') {
          final v = MathExpressionEvaluator.evaluate(b.upper, params: params);
          if (v.isFinite && v > 0) rMax = v;
          rMaxL = IntegralExpressionTransformer.toDisplayLatex(b.upper);
        }
        if (b.variable.toLowerCase() == 'theta') {
          final v1 = MathExpressionEvaluator.evaluate(b.lower, params: params);
          final v2 = MathExpressionEvaluator.evaluate(b.upper, params: params);
          if (v1.isFinite && v2.isFinite) {
            thMin = v1;
            thMax = v2;
          }
          thMinL = IntegralExpressionTransformer.toDisplayLatex(b.lower);
          thMaxL = IntegralExpressionTransformer.toDisplayLatex(b.upper);
        }
      }

      return UvMappingModel(
        title: 'Transformación Polar / Cilíndrica (r, θ)',
        transformForwardLatex: r'x = r\cos\theta, \quad y = r\sin\theta',
        transformInverseLatex: r'r = \sqrt{x^2+y^2}, \quad \theta = \arctan(y/x)',
        jacobianLatex: solution?.domainAnalysis?.jacobianLatex ?? r'|J| = r',
        uVarLabel: 'r',
        vVarLabel: 'θ',
        uMin: 0.0,
        uMax: rMax,
        vMin: thMin,
        vMax: thMax,
        uMinLatex: '0',
        uMaxLatex: rMaxL,
        vMinLatex: thMinL,
        vMaxLatex: thMaxL,
        transformedIntegralLatex: solution?.domainAnalysis?.deducedLimitsLatex ??
            solution?.originalIntegralLatex ?? '',
        isActiveTransformation: true,
        mapUvToXy: (r, th) => Offset(r * math.cos(th), r * math.sin(th)),
      );
    }

    // Check if Cartesian bounds are circular radicals (e.g. sqrt(R^2 - x^2))
    final hasCircularRadical = integral.bounds.any(
      (b) => b.lower.contains('sqrt') || b.upper.contains('sqrt'),
    );
    if (hasCircularRadical && integral.bounds.length == 2) {
      final bOut = integral.bounds[1];
      final outLow = MathExpressionEvaluator.evaluate(bOut.lower, params: params);
      final outUpp = MathExpressionEvaluator.evaluate(bOut.upper, params: params);
      final rMax = outUpp.isFinite ? math.max(outUpp.abs(), 1.0) : 2.0;
      final isFirstQuad = outLow.isFinite && outLow >= 0;
      final thMin = 0.0;
      final thMax = isFirstQuad ? math.pi / 2 : 2 * math.pi;

      return UvMappingModel(
        title: 'Cambio Automático a Polares (r, θ)',
        transformForwardLatex: r'x = r\cos\theta, \quad y = r\sin\theta',
        transformInverseLatex: r'x^2 + y^2 = r^2',
        jacobianLatex: r'J(r,\theta) = r \implies dA = r\,dr\,d\theta',
        uVarLabel: 'r',
        vVarLabel: 'θ',
        uMin: 0.0,
        uMax: rMax,
        vMin: thMin,
        vMax: thMax,
        uMinLatex: '0',
        uMaxLatex: IntegralExpressionTransformer.toDisplayLatex(bOut.upper),
        vMinLatex: '0',
        vMaxLatex: isFirstQuad ? r'\frac{\pi}{2}' : r'2\pi',
        transformedIntegralLatex: solution?.domainAnalysis?.deducedLimitsLatex ??
            '\\int_{0}^{${isFirstQuad ? r'\pi/2' : r'2\pi'}} \\int_{0}^{${_fmtNum(rMax)}} f(r\\cos\\theta, r\\sin\\theta)\\, r\\, dr\\, d\\theta',
        isActiveTransformation: true,
        mapUvToXy: (r, th) => Offset(r * math.cos(th), r * math.sin(th)),
      );
    }

    return null;
  }

  static void _addParsedCurve(
    List<PlotCurve2D> curves,
    String rawCurve,
    double xMin,
    double xMax,
    double yMin,
    double yMax,
    Map<String, double> params,
  ) {
    final s = rawCurve.trim();
    if (!s.contains('=')) return;
    final parts = s.split('=');
    if (parts.length != 2) return;
    final lhs = parts[0].trim();
    final rhs = parts[1].trim();
    final color = curves.length.isEven ? AppColors.electricCyan : AppColors.violetHeatmap;

    if (lhs.toLowerCase() == 'y' && !rhs.toLowerCase().contains('y')) {
      curves.add(PlotCurve2D(
        label: s,
        kind: Curve2DKind.explicitYOfX,
        color: color,
        minParam: xMin,
        maxParam: xMax,
        eval1D: (x) => MathExpressionEvaluator.evaluate(rhs, x: x, params: params),
      ));
    } else if (lhs.toLowerCase() == 'x' && !rhs.toLowerCase().contains('x')) {
      curves.add(PlotCurve2D(
        label: s,
        kind: Curve2DKind.explicitXOfY,
        color: color,
        minParam: yMin,
        maxParam: yMax,
        eval1D: (y) => MathExpressionEvaluator.evaluate(rhs, y: y, params: params),
      ));
    } else if (lhs.toLowerCase() == 'r' && !rhs.toLowerCase().contains('r')) {
      curves.add(PlotCurve2D(
        label: s,
        kind: Curve2DKind.polarROfTheta,
        color: color,
        minParam: 0.0,
        maxParam: 2 * math.pi,
        eval1D: (th) => MathExpressionEvaluator.evaluate(rhs, params: {...params, 'theta': th}),
      ));
    } else {
      final fExpr = '($lhs) - ($rhs)';
      curves.add(PlotCurve2D(
        label: s,
        kind: Curve2DKind.implicitFxy,
        color: color,
        evalImplicit: (x, y) => MathExpressionEvaluator.evaluate(fExpr, x: x, y: y, params: params),
      ));
    }
  }

  static (Offset, String)? _parseVertexString(String raw, Map<String, double> params) {
    final clean = raw.trim();
    final m = RegExp(r'^([A-Za-z][A-Za-z0-9]*)?\s*\(\s*([^,]+)\s*,\s*([^)]+)\s*\)$').firstMatch(clean);
    if (m == null) return null;
    final name = m.group(1) ?? '';
    final xStr = m.group(2)!.trim();
    final yStr = m.group(3)!.trim();
    final xVal = MathExpressionEvaluator.evaluate(xStr, params: params);
    final yVal = MathExpressionEvaluator.evaluate(yStr, params: params);
    if (!xVal.isFinite || !yVal.isFinite) return null;
    final label = name.isNotEmpty ? '$name($xStr, $yStr)' : '($xStr, $yStr)';
    return (Offset(xVal, yVal), label);
  }

  static void _collectIntersectionsFromCorners({
    required List<DomainPoint2D> intersections,
    required IntegralSolution? solution,
    required List<Offset> polygonPtsTop,
    required List<Offset> polygonPtsBot,
    required double xMin,
    required double xMax,
  }) {
    final da = solution?.domainAnalysis;
    if (da != null && da.intersectionPoints.isNotEmpty) {
      for (final pt in da.intersectionPoints) {
        final px = MathExpressionEvaluator.evaluate(pt['x'] ?? '0');
        final py = MathExpressionEvaluator.evaluate(pt['y'] ?? '0');
        if (px.isFinite && py.isFinite) {
          _addUniquePoint(intersections, DomainPoint2D(
            x: px,
            y: py,
            label: '(${pt['x']}, ${pt['y']})',
          ));
        }
      }
      if (intersections.isNotEmpty) return;
    }

    if (polygonPtsTop.isNotEmpty && polygonPtsBot.isNotEmpty) {
      final candidates = [
        polygonPtsBot.first,
        polygonPtsTop.first,
        polygonPtsBot.last,
        polygonPtsTop.last,
      ];
      for (final p in candidates) {
        _addUniquePoint(intersections, DomainPoint2D(
          x: p.dx,
          y: p.dy,
          label: '(${_fmtNum(p.dx)}, ${_fmtNum(p.dy)})',
        ));
      }
    }
  }

  static void _addUniquePoint(List<DomainPoint2D> list, DomainPoint2D pt) {
    for (final existing in list) {
      if ((existing.x - pt.x).abs() < 1e-3 && (existing.y - pt.y).abs() < 1e-3) {
        return;
      }
    }
    list.add(pt);
  }

  static ({
    String yMinLatex,
    String yMaxLatex,
    String xLowLatex,
    String xUppLatex,
    double Function(double) xLowFn,
    double Function(double) xUppFn,
  }) _inferTypeIIFromPolygon({
    required List<Offset> polygon,
    required IntegrationBound innerBound,
    required IntegrationBound outerBound,
    required double yMin,
    required double yMax,
    required Map<String, double> params,
  }) {
    final env = _envelopeFromPolygonY(polygon, yMin, yMax);
    final inL = innerBound.lower.replaceAll(' ', '').toLowerCase();
    final inU = innerBound.upper.replaceAll(' ', '').toLowerCase();
    final outL = outerBound.lower.replaceAll(' ', '').toLowerCase();
    final outU = outerBound.upper.replaceAll(' ', '').toLowerCase();

    // Common exact symbolic inversions for Type I -> Type II display
    String yMinL = _fmtNum(yMin);
    String yMaxL = _fmtNum(yMax);
    String xLowL = 'x_{\\text{izq}}(y)';
    String xUppL = 'x_{\\text{der}}(y)';

    if (!IntegralExpressionTransformer.normalizeExpression(inL).contains('x') &&
        !IntegralExpressionTransformer.normalizeExpression(inU).contains('x')) {
      // Rectangular
      yMinL = IntegralExpressionTransformer.toDisplayLatex(innerBound.lower);
      yMaxL = IntegralExpressionTransformer.toDisplayLatex(innerBound.upper);
      xLowL = IntegralExpressionTransformer.toDisplayLatex(outerBound.lower);
      xUppL = IntegralExpressionTransformer.toDisplayLatex(outerBound.upper);
    } else if (inL == '0' && inU == 'x' && outL == '0') {
      yMinL = '0';
      yMaxL = IntegralExpressionTransformer.toDisplayLatex(outerBound.upper);
      xLowL = 'y';
      xUppL = yMaxL;
    } else if (inL == 'x' && outL == '0' && inU == outU) {
      yMinL = '0';
      yMaxL = IntegralExpressionTransformer.toDisplayLatex(outerBound.upper);
      xLowL = '0';
      xUppL = 'y';
    } else if (inL == '0' && (inU == 'x^2' || inU == 'x**2') && outL == '0') {
      yMinL = '0';
      yMaxL = _fmtNum(yMax);
      xLowL = r'\sqrt{y}';
      xUppL = IntegralExpressionTransformer.toDisplayLatex(outerBound.upper);
    } else if ((inL == 'x^2' || inL == 'x**2') && inU == '2*x') {
      yMinL = '0';
      yMaxL = '4';
      xLowL = r'\frac{y}{2}';
      xUppL = r'\sqrt{y}';
    } else if (inL.contains('sqrt') && inU.contains('sqrt')) {
      yMinL = IntegralExpressionTransformer.toDisplayLatex(outerBound.lower);
      yMaxL = IntegralExpressionTransformer.toDisplayLatex(outerBound.upper);
      xLowL = IntegralExpressionTransformer.toDisplayLatex(innerBound.lower.replaceAll('x', 'y'));
      xUppL = IntegralExpressionTransformer.toDisplayLatex(innerBound.upper.replaceAll('x', 'y'));
    }

    return (
      yMinLatex: yMinL,
      yMaxLatex: yMaxL,
      xLowLatex: xLowL,
      xUppLatex: xUppL,
      xLowFn: env.$1,
      xUppFn: env.$2,
    );
  }

  static ({
    String xMinLatex,
    String xMaxLatex,
    String yLowLatex,
    String yUppLatex,
    double Function(double) yLowFn,
    double Function(double) yUppFn,
  }) _inferTypeIFromPolygon({
    required List<Offset> polygon,
    required IntegrationBound innerBound,
    required IntegrationBound outerBound,
    required double xMin,
    required double xMax,
    required Map<String, double> params,
  }) {
    final env = _envelopeFromPolygonX(polygon, xMin, xMax);
    final inL = innerBound.lower.replaceAll(' ', '').toLowerCase();
    final inU = innerBound.upper.replaceAll(' ', '').toLowerCase();
    final outL = outerBound.lower.replaceAll(' ', '').toLowerCase();

    String xMinL = _fmtNum(xMin);
    String xMaxL = _fmtNum(xMax);
    String yLowL = 'y_{\\text{inf}}(x)';
    String yUppL = 'y_{\\text{sup}}(x)';

    if (!IntegralExpressionTransformer.normalizeExpression(inL).contains('y') &&
        !IntegralExpressionTransformer.normalizeExpression(inU).contains('y')) {
      xMinL = IntegralExpressionTransformer.toDisplayLatex(innerBound.lower);
      xMaxL = IntegralExpressionTransformer.toDisplayLatex(innerBound.upper);
      yLowL = IntegralExpressionTransformer.toDisplayLatex(outerBound.lower);
      yUppL = IntegralExpressionTransformer.toDisplayLatex(outerBound.upper);
    } else if (inL == 'y/2' && inU == '1' && outL == '0') {
      xMinL = '0';
      xMaxL = '1';
      yLowL = '0';
      yUppL = '2x';
    } else if (inL == 'y' && inU == '1' && outL == '0') {
      xMinL = '0';
      xMaxL = '1';
      yLowL = '0';
      yUppL = 'x';
    } else if (inL == '0' && inU == 'y' && outL == '0') {
      xMinL = '0';
      xMaxL = IntegralExpressionTransformer.toDisplayLatex(outerBound.upper);
      yLowL = 'x';
      yUppL = xMaxL;
    }

    return (
      xMinLatex: xMinL,
      xMaxLatex: xMaxL,
      yLowLatex: yLowL,
      yUppLatex: yUppL,
      yLowFn: env.$1,
      yUppFn: env.$2,
    );
  }

  /// Intersects vertical line x = x0 with polygon edges to find exact yMin(x0), yMax(x0)
  static (double Function(double), double Function(double)) _envelopeFromPolygonX(
    List<Offset> poly,
    double xMin,
    double xMax,
  ) {
    List<double> yHitsAt(double x0) {
      if (poly.length < 3) return [0.0, 1.0];
      final hits = <double>[];
      for (int i = 0; i < poly.length; i++) {
        final a = poly[i];
        final b = poly[(i + 1) % poly.length];
        if ((a.dx <= x0 && b.dx >= x0) || (b.dx <= x0 && a.dx >= x0)) {
          final dx = b.dx - a.dx;
          if (dx.abs() < 1e-9) {
            hits.add(a.dy);
            hits.add(b.dy);
          } else {
            final t = (x0 - a.dx) / dx;
            if (t >= -1e-6 && t <= 1.0 + 1e-6) {
              hits.add(a.dy + t * (b.dy - a.dy));
            }
          }
        }
      }
      if (hits.isEmpty) return [0.0, 0.0];
      hits.sort();
      return [hits.first, hits.last];
    }

    return ((x) => yHitsAt(x)[0], (x) => yHitsAt(x)[1]);
  }

  /// Intersects horizontal line y = y0 with polygon edges to find exact xMin(y0), xMax(y0)
  static (double Function(double), double Function(double)) _envelopeFromPolygonY(
    List<Offset> poly,
    double yMin,
    double yMax,
  ) {
    List<double> xHitsAt(double y0) {
      if (poly.length < 3) return [0.0, 1.0];
      final hits = <double>[];
      for (int i = 0; i < poly.length; i++) {
        final a = poly[i];
        final b = poly[(i + 1) % poly.length];
        if ((a.dy <= y0 && b.dy >= y0) || (b.dy <= y0 && a.dy >= y0)) {
          final dy = b.dy - a.dy;
          if (dy.abs() < 1e-9) {
            hits.add(a.dx);
            hits.add(b.dx);
          } else {
            final t = (y0 - a.dy) / dy;
            if (t >= -1e-6 && t <= 1.0 + 1e-6) {
              hits.add(a.dx + t * (b.dx - a.dx));
            }
          }
        }
      }
      if (hits.isEmpty) return [0.0, 0.0];
      hits.sort();
      return [hits.first, hits.last];
    }

    return ((y) => xHitsAt(y)[0], (y) => xHitsAt(y)[1]);
  }

  static String _fmtNum(double v) {
    if (!v.isFinite) return '0';
    if ((v - v.roundToDouble()).abs() < 1e-6) return '${v.round()}';
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}

extension on DomainPoint2D {
  double get dyForSort => y;
}
