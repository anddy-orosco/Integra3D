import 'dart:math' as math;
import '../../../solver/domain/entities/integral_solution.dart';
import '../entities/integration_bound.dart';
import '../entities/multivariable_integral.dart';
import 'integral_expression_transformer.dart';
import 'local_math_engine.dart';
import 'math_expression_evaluator.dart';
import 'region_geometry_solver.dart';
import 'symbolic_calculus_engine.dart';

class Mat212SolverService {
  static const Map<String, double> previewParams = {
    'a': 1.0,
    'b': 1.0,
    'c': 1.0,
    'm': 1.0,
    'n': 2.0,
    'R': 2.0,
    'H': 3.0,
    'k': 1.0,
  };

  /// Dispatches Mode 2 (Region/Vertices) and Mode 3 (Applications) problems.
  static IntegralSolution? solveProblemMode(
    MultivariableIntegral integral,
    DateTime startTime,
  ) {
    switch (integral.problemMode) {
      case ProblemMode.direct:
        return null;
      case ProblemMode.regionVertices:
      case ProblemMode.regionCurves:
      case ProblemMode.planarArea:
        return _solveRegionOrPlanarArea(integral, startTime);
      case ProblemMode.surfaceArea:
        return _solveSurfaceArea(integral, startTime);
      case ProblemMode.volumeBetweenSurfaces:
        return _solveVolumeBetweenSurfaces(integral, startTime);
      case ProblemMode.massAndCenterOfMass:
        return _solveMassAndCentroid(integral, startTime);
    }
  }

  static IntegralSolution _solveRegionOrPlanarArea(
    MultivariableIntegral integral,
    DateTime startTime,
  ) {
    final integrand = integral.problemMode == ProblemMode.planarArea ? '1' : integral.integrand;
    RegionDeductionResult? deduced;

    if (integral.verticesInput.isNotEmpty) {
      deduced = RegionGeometrySolver.deduceFromVertices(
        verticesInput: integral.verticesInput,
        integrand: integrand,
        preferredOrder: integral.preferredOrder,
      );
    } else if (integral.boundaryCurves.isNotEmpty) {
      deduced = RegionGeometrySolver.deduceFromCurves(
        curvesInput: integral.boundaryCurves,
        integrand: integrand,
        preferredOrder: integral.preferredOrder,
        customUvTransform: integral.uvTransformInput,
      );
    }

    if (deduced == null) {
      return LocalMathEngine.solveLocal(
        integral.copyWith(problemMode: ProblemMode.direct),
      );
    }

    if (deduced.subIntegrals.length == 1) {
      final base = LocalMathEngine.solveLocal(
        deduced.primaryIntegral.copyWith(problemMode: ProblemMode.direct),
      );
      if (!base.isSuccess) return base;
      final shiftedSteps = <SolverStep>[
        deduced.step0,
        ...base.steps.map((s) => _copyStepWithNumber(s, s.stepNumber)),
      ];
      return base.copyWith(
        originalIntegralLatex: deduced.domainAnalysis.deducedLimitsLatex,
        steps: shiftedSteps,
        domainAnalysis: deduced.domainAnalysis,
      );
    }

    // Multiple sub-regions (e.g. polygon sliced in Type I): solve each and sum
    final allSteps = <SolverStep>[deduced.step0];
    final exactAsts = <SymExpr>[];
    double sumNumeric = 0.0;
    bool allNumeric = true;

    for (int idx = 0; idx < deduced.subIntegrals.length; idx++) {
      final sub = deduced.subIntegrals[idx].copyWith(problemMode: ProblemMode.direct);
      final sol = LocalMathEngine.solveLocal(sub);
      if (!sol.isSuccess) return sol;

      if (sol.approxNumeric != null) {
        sumNumeric += sol.approxNumeric!;
      } else {
        allNumeric = false;
      }

      final parsedSub = SymbolicCalculusEngine.parse(sol.exactLatex.replaceAll(r'\approx', ''));
      if (parsedSub != null) exactAsts.add(parsedSub);

      final subLatex = IntegralExpressionTransformer.toLatex(sub);
      allSteps.add(SolverStep(
        stepNumber: idx + 1,
        variable: sub.bounds.first.variable,
        lowerBoundLatex: IntegralExpressionTransformer.toDisplayLatex(sub.bounds.first.lower),
        upperBoundLatex: IntegralExpressionTransformer.toDisplayLatex(sub.bounds.first.upper),
        currentIntegrandLatex: IntegralExpressionTransformer.toDisplayLatex(sub.integrand),
        stepTitle: 'Sub-región R_${idx + 1}: Evaluación de $subLatex',
        stepIntegralLatex: subLatex,
        constantTreatmentText: 'Calculamos la contribución de la sub-región R_${idx + 1}:',
        antiderivativeLatex: '$subLatex = ${sol.exactLatex}',
        antiderivativeWorkLatex: '$subLatex = ${sol.exactLatex}',
        evaluatedLatex: '$subLatex = ${sol.exactLatex}',
        simplifiedResultLatex: sol.exactLatex,
        explanation: 'Evaluación exacta sobre la sub-región R_${idx + 1}.',
        appliedMethod: 'Aditividad de la Integral sobre Dominios',
      ));
    }

    final totalAst = exactAsts.length == deduced.subIntegrals.length
        ? SymbolicCalculusEngine.simplify(SymAdd(exactAsts))
        : null;
    final exactLatex = totalAst != null
        ? SymbolicCalculusEngine.toLatex(totalAst)
        : (allNumeric ? sumNumeric.toStringAsFixed(4) : '0');

    allSteps.add(SolverStep(
      stepNumber: allSteps.length,
      variable: deduced.subIntegrals.first.bounds.last.variable,
      lowerBoundLatex: '',
      upperBoundLatex: '',
      currentIntegrandLatex: exactLatex,
      stepTitle: 'Paso Final: Suma total de sub-regiones',
      stepIntegralLatex: 'I = \\sum I_k = $exactLatex',
      antiderivativeLatex: exactLatex,
      evaluatedLatex: 'I = $exactLatex',
      simplifiedResultLatex: exactLatex,
      explanation: 'Sumamos los resultados parciales de cada sub-región obteniendo $exactLatex.',
      appliedMethod: 'Aditividad de Integrales Dobles',
    ));

    return IntegralSolution(
      isSuccess: true,
      exactLatex: exactLatex,
      approxNumeric: allNumeric ? double.parse(sumNumeric.toStringAsFixed(5)) : null,
      originalIntegralLatex: deduced.domainAnalysis.deducedLimitsLatex,
      executionTimeMs: math.max(DateTime.now().difference(startTime).inMilliseconds.toDouble(), 15.0),
      regionDefinition: 'Región compuesta R dividida en ${deduced.subIntegrals.length} sub-regiones.',
      steps: allSteps,
      domainAnalysis: deduced.domainAnalysis,
      formulasAndMethods: LocalMathEngine.defaultFormulasFor(deduced.primaryIntegral),
    );
  }

  static (MultivariableIntegral, DomainAnalysis?, SolverStep?) _withDeducedDomain(
    MultivariableIntegral integral, {
    required String integrandOverride,
  }) {
    RegionDeductionResult? deduced;
    if (integral.verticesInput.isNotEmpty) {
      deduced = RegionGeometrySolver.deduceFromVertices(
        verticesInput: integral.verticesInput,
        integrand: integrandOverride,
        preferredOrder: integral.preferredOrder,
      );
    } else if (integral.boundaryCurves.isNotEmpty) {
      deduced = RegionGeometrySolver.deduceFromCurves(
        curvesInput: integral.boundaryCurves,
        integrand: integrandOverride,
        preferredOrder: integral.preferredOrder,
        customUvTransform: integral.uvTransformInput,
      );
    }
    if (deduced != null) {
      return (
        deduced.primaryIntegral.copyWith(
          integrand: integrandOverride,
          problemMode: ProblemMode.direct,
        ),
        deduced.domainAnalysis,
        deduced.step0,
      );
    }
    return (
      integral.copyWith(integrand: integrandOverride, problemMode: ProblemMode.direct),
      null,
      null,
    );
  }

  static IntegralSolution _solveSurfaceArea(
    MultivariableIntegral integral,
    DateTime startTime,
  ) {
    final zStr = integral.zUpperExpr ?? integral.integrand;
    final zAst = SymbolicCalculusEngine.parse(zStr);
    if (zAst == null) {
      return LocalMathEngine.solveLocal(integral.copyWith(problemMode: ProblemMode.direct));
    }

    final zx = SymbolicCalculusEngine.diff(zAst, 'x');
    final zy = SymbolicCalculusEngine.diff(zAst, 'y');
    final radicand = SymbolicCalculusEngine.simplify(
      SymAdd([
        SymNum.intVal(1),
        SymPow(zx, SymNum.intVal(2)),
        SymPow(zy, SymNum.intVal(2)),
      ]),
    );
    final dsAst = SymbolicCalculusEngine.simplify(SymFunc('sqrt', radicand));
    final dsInputStr = _astToInput(dsAst);

    final zxL = SymbolicCalculusEngine.toLatex(zx);
    final zyL = SymbolicCalculusEngine.toLatex(zy);
    final dsL = SymbolicCalculusEngine.toLatex(dsAst);

    final (areaIntegral, deducedDomain, _) = _withDeducedDomain(
      integral,
      integrandOverride: dsInputStr,
    );

    final base = LocalMathEngine.solveLocal(areaIntegral);
    final step0 = SolverStep(
      stepNumber: 0,
      variable: 'z',
      lowerBoundLatex: '',
      upperBoundLatex: '',
      currentIntegrandLatex: SymbolicCalculusEngine.toLatex(zAst),
      stepTitle: 'Paso 0: Elemento Diferencial de Área de Superficie dS',
      stepIntegralLatex: r'A_S = \iint_R \sqrt{1 + \left(\frac{\partial z}{\partial x}\right)^2 + \left(\frac{\partial z}{\partial y}\right)^2} \, dA',
      constantTreatmentText: 'Calculamos las derivadas parciales de z = ${SymbolicCalculusEngine.toLatex(zAst)}:',
      antiderivativeWorkLatex: '\\frac{\\partial z}{\\partial x} = $zxL, \\quad \\frac{\\partial z}{\\partial y} = $zyL \\implies dS = $dsL \\, dA',
      limitsEvaluationText: 'Integral planteada para el área superficial:',
      antiderivativeLatex: dsL,
      evaluatedLatex: '\\iint_R $dsL \\, dA',
      simplifiedResultLatex: dsL,
      explanation: 'Cada elemento plano dA proyectado en XY se escala por el factor geométrico √(1 + z_x² + z_y²) para medir el área real de la superficie curva.',
      appliedMethod: 'Área de Superficie 3D (Jacobiano Superficial)',
    );

    return base.copyWith(
      originalIntegralLatex: '\\iint_R $dsL \\, dA',
      steps: [step0, ...base.steps],
      domainAnalysis: base.domainAnalysis ?? deducedDomain,
    );
  }

  static IntegralSolution _solveVolumeBetweenSurfaces(
    MultivariableIntegral integral,
    DateTime startTime,
  ) {
    final zSup = integral.zUpperExpr ?? integral.integrand;
    final zInf = integral.zLowerExpr ?? '0';
    final diffExpr = '($zSup) - ($zInf)';
    final diffAst = SymbolicCalculusEngine.parse(diffExpr);
    final diffLatex = diffAst != null
        ? SymbolicCalculusEngine.toLatex(diffAst)
        : IntegralExpressionTransformer.toDisplayLatex(diffExpr);

    final (volIntegral, deducedDomain, _) = _withDeducedDomain(
      integral,
      integrandOverride: diffAst != null ? _astToInput(diffAst) : diffExpr,
    );

    final base = LocalMathEngine.solveLocal(volIntegral);
    final step0 = SolverStep(
      stepNumber: 0,
      variable: 'z',
      lowerBoundLatex: IntegralExpressionTransformer.toDisplayLatex(zInf),
      upperBoundLatex: IntegralExpressionTransformer.toDisplayLatex(zSup),
      currentIntegrandLatex: diffLatex,
      stepTitle: 'Paso 0: Planteamiento del Volumen entre Dos Superficies',
      stepIntegralLatex: 'V = \\iint_R \\left(${IntegralExpressionTransformer.toDisplayLatex(zSup)} - (${IntegralExpressionTransformer.toDisplayLatex(zInf)})\\right) dA = \\iint_R ($diffLatex) \\, dA',
      constantTreatmentText: 'Restamos la superficie inferior z_inf a la superficie superior z_sup sobre la proyección R en XY:',
      antiderivativeLatex: 'h(x, y) = $diffLatex',
      antiderivativeWorkLatex: 'h(x, y) = z_{\\text{sup}} - z_{\\text{inf}} = $diffLatex',
      evaluatedLatex: 'V = \\iint_R ($diffLatex) \\, dA',
      simplifiedResultLatex: diffLatex,
      explanation: 'El volumen del sólido V acotado verticalmente entre z_inf y z_sup equivale a la integral doble de la altura neta (z_sup - z_inf) sobre el dominio R.',
      appliedMethod: 'Volumen Acotado entre Superficies',
    );

    return base.copyWith(
      steps: [step0, ...base.steps],
      domainAnalysis: base.domainAnalysis ?? deducedDomain,
    );
  }

  static IntegralSolution _solveMassAndCentroid(
    MultivariableIntegral integral,
    DateTime startTime,
  ) {
    final (baseDomainInt, deducedDomain, deducedStep0) = _withDeducedDomain(
      integral,
      integrandOverride: integral.densityExpr ?? integral.integrand,
    );
    final rhoStr = integral.densityExpr ?? integral.integrand;
    final rhoAst = SymbolicCalculusEngine.parse(rhoStr) ?? SymNum.intVal(1);
    final is3D = baseDomainInt.dimension >= 3;

    // Coordinate mapping for moments x, y, z depending on coordinateSystem
    final SymExpr xCoordAst;
    final SymExpr yCoordAst;
    final SymExpr zCoordAst;
    if (baseDomainInt.coordinateSystem == CoordinateSystemType.polar ||
        baseDomainInt.coordinateSystem == CoordinateSystemType.cylindrical) {
      xCoordAst = SymMul([SymVar('r'), SymFunc('cos', SymVar('theta'))]);
      yCoordAst = SymMul([SymVar('r'), SymFunc('sin', SymVar('theta'))]);
      zCoordAst = SymVar('z');
    } else if (baseDomainInt.coordinateSystem == CoordinateSystemType.spherical) {
      xCoordAst = SymMul([SymVar('rho'), SymFunc('sin', SymVar('phi')), SymFunc('cos', SymVar('theta'))]);
      yCoordAst = SymMul([SymVar('rho'), SymFunc('sin', SymVar('phi')), SymFunc('sin', SymVar('theta'))]);
      zCoordAst = SymMul([SymVar('rho'), SymFunc('cos', SymVar('phi'))]);
    } else {
      xCoordAst = SymVar('x');
      yCoordAst = SymVar('y');
      zCoordAst = SymVar('z');
    }

    // Substitute x, y, z inside rho if using polar/cylindrical/spherical
    SymExpr rhoConverted = rhoAst;
    if (baseDomainInt.coordinateSystem != CoordinateSystemType.cartesian) {
      rhoConverted = SymbolicCalculusEngine.substitute(rhoConverted, 'x', xCoordAst);
      rhoConverted = SymbolicCalculusEngine.substitute(rhoConverted, 'y', yCoordAst);
      if (is3D) {
        rhoConverted = SymbolicCalculusEngine.substitute(rhoConverted, 'z', zCoordAst);
      }
    }

    final massIntegral = baseDomainInt.copyWith(
      integrand: _astToInput(rhoConverted),
      problemMode: ProblemMode.direct,
    );
    final massSol = LocalMathEngine.solveLocal(massIntegral);

    final mxAst = SymbolicCalculusEngine.simplify(SymMul([xCoordAst, rhoConverted]));
    final myAst = SymbolicCalculusEngine.simplify(SymMul([yCoordAst, rhoConverted]));
    final mzAst = SymbolicCalculusEngine.simplify(SymMul([zCoordAst, rhoConverted]));

    final myzSol = LocalMathEngine.solveLocal(
      baseDomainInt.copyWith(integrand: _astToInput(mxAst), problemMode: ProblemMode.direct),
    );
    final mxzSol = LocalMathEngine.solveLocal(
      baseDomainInt.copyWith(integrand: _astToInput(myAst), problemMode: ProblemMode.direct),
    );
    final mxySol = is3D
        ? LocalMathEngine.solveLocal(
            baseDomainInt.copyWith(integrand: _astToInput(mzAst), problemMode: ProblemMode.direct),
          )
        : null;

    String divideCenter(IntegralSolution momentSol, IntegralSolution mSol) {
      final mAst = SymbolicCalculusEngine.parse(mSol.exactLatex.replaceAll(r'\approx', ''));
      final momAst = SymbolicCalculusEngine.parse(momentSol.exactLatex.replaceAll(r'\approx', ''));
      if (mAst != null && momAst != null) {
        final q = SymbolicCalculusEngine.simplify(SymDiv(momAst, mAst));
        return SymbolicCalculusEngine.toLatex(q);
      }
      if (momentSol.approxNumeric != null && mSol.approxNumeric != null && mSol.approxNumeric!.abs() > 1e-12) {
        final val = momentSol.approxNumeric! / mSol.approxNumeric!;
        return val.toStringAsFixed(4);
      }
      return '\\frac{${momentSol.exactLatex}}{${mSol.exactLatex}}';
    }

    final xBar = divideCenter(myzSol, massSol);
    final yBar = divideCenter(mxzSol, massSol);
    final zBar = is3D && mxySol != null ? divideCenter(mxySol, massSol) : null;

    final centroidLatex = is3D
        ? '(\\bar{x}, \\bar{y}, \\bar{z}) = \\left($xBar, \\; $yBar, \\; $zBar\\right)'
        : '(\\bar{x}, \\bar{y}) = \\left($xBar, \\; $yBar\\right)';

    final steps = <SolverStep>[
      ?deducedStep0,
      SolverStep(
        stepNumber: 1,
        variable: baseDomainInt.bounds.first.variable,
        lowerBoundLatex: '',
        upperBoundLatex: '',
        currentIntegrandLatex: SymbolicCalculusEngine.toLatex(rhoConverted),
        stepTitle: 'Paso 1: Cálculo de la Masa Total M',
        stepIntegralLatex: is3D
            ? 'M = \\iiint_V \\rho \\, dV = ${massSol.exactLatex}'
            : 'M = \\iint_R \\rho \\, dA = ${massSol.exactLatex}',
        constantTreatmentText: 'Integramos la función de densidad ρ = ${SymbolicCalculusEngine.toLatex(rhoAst)} sobre toda la región:',
        antiderivativeLatex: massSol.exactLatex,
        antiderivativeWorkLatex: 'M = ${massSol.exactLatex}',
        evaluatedLatex: 'M = ${massSol.exactLatex}',
        simplifiedResultLatex: massSol.exactLatex,
        explanation: 'La masa total M acumula la densidad diferencial en todo el dominio.',
        appliedMethod: 'Cálculo de Masa M',
      ),
      ...massSol.steps.map((s) => _copyStepWithNumber(s, s.stepNumber + 1)),
      SolverStep(
        stepNumber: massSol.steps.length + 2,
        variable: 'x',
        lowerBoundLatex: '',
        upperBoundLatex: '',
        currentIntegrandLatex: SymbolicCalculusEngine.toLatex(mxAst),
        stepTitle: is3D
            ? 'Paso ${massSol.steps.length + 2}: Primer Momento M_{yz} (coordenada x)'
            : 'Paso ${massSol.steps.length + 2}: Primer Momento M_y (coordenada x)',
        stepIntegralLatex: is3D
            ? 'M_{yz} = \\iiint_V x \\rho \\, dV = ${myzSol.exactLatex}'
            : 'M_y = \\iint_R x \\rho \\, dA = ${myzSol.exactLatex}',
        antiderivativeLatex: myzSol.exactLatex,
        evaluatedLatex: 'M_{yz} = ${myzSol.exactLatex}',
        simplifiedResultLatex: myzSol.exactLatex,
        explanation: 'Calculamos el momento estático respecto al plano YZ (o eje Y en 2D).',
        appliedMethod: 'Primer Momento Estático M_yz',
      ),
      SolverStep(
        stepNumber: massSol.steps.length + 3,
        variable: 'y',
        lowerBoundLatex: '',
        upperBoundLatex: '',
        currentIntegrandLatex: SymbolicCalculusEngine.toLatex(myAst),
        stepTitle: is3D
            ? 'Paso ${massSol.steps.length + 3}: Primer Momento M_{xz} (coordenada y)'
            : 'Paso ${massSol.steps.length + 3}: Primer Momento M_x (coordenada y)',
        stepIntegralLatex: is3D
            ? 'M_{xz} = \\iiint_V y \\rho \\, dV = ${mxzSol.exactLatex}'
            : 'M_x = \\iint_R y \\rho \\, dA = ${mxzSol.exactLatex}',
        antiderivativeLatex: mxzSol.exactLatex,
        evaluatedLatex: 'M_{xz} = ${mxzSol.exactLatex}',
        simplifiedResultLatex: mxzSol.exactLatex,
        explanation: 'Calculamos el momento estático respecto al plano XZ (o eje X en 2D).',
        appliedMethod: 'Primer Momento Estático M_xz',
      ),
      if (is3D && mxySol != null)
        SolverStep(
          stepNumber: massSol.steps.length + 4,
          variable: 'z',
          lowerBoundLatex: '',
          upperBoundLatex: '',
          currentIntegrandLatex: SymbolicCalculusEngine.toLatex(mzAst),
          stepTitle: 'Paso ${massSol.steps.length + 4}: Primer Momento M_{xy} (coordenada z)',
          stepIntegralLatex: 'M_{xy} = \\iiint_V z \\rho \\, dV = ${mxySol.exactLatex}',
          antiderivativeLatex: mxySol.exactLatex,
          evaluatedLatex: 'M_{xy} = ${mxySol.exactLatex}',
          simplifiedResultLatex: mxySol.exactLatex,
          explanation: 'Calculamos el momento estático respecto al plano base XY (z = 0).',
          appliedMethod: 'Primer Momento Estático M_xy',
        ),
      SolverStep(
        stepNumber: is3D ? massSol.steps.length + 5 : massSol.steps.length + 4,
        variable: 'x',
        lowerBoundLatex: '',
        upperBoundLatex: '',
        currentIntegrandLatex: centroidLatex,
        stepTitle: 'Paso Final: Coordenadas del Centro de Masa',
        stepIntegralLatex: centroidLatex,
        constantTreatmentText: 'Dividimos cada momento estático por la masa total M = ${massSol.exactLatex}:',
        antiderivativeLatex: centroidLatex,
        antiderivativeWorkLatex: centroidLatex,
        evaluatedLatex: 'M = ${massSol.exactLatex}, \\quad $centroidLatex',
        simplifiedResultLatex: centroidLatex,
        explanation: 'Las coordenadas exactas del centro de masa se obtienen normalizando los momentos por la masa total M (cancelando la constante k cuando es homogénea).',
        appliedMethod: 'Centro de Masa & Centroidal',
      ),
    ];

    return IntegralSolution(
      isSuccess: massSol.isSuccess,
      exactLatex: 'M = ${massSol.exactLatex}, \\; $centroidLatex',
      approxNumeric: massSol.approxNumeric,
      originalIntegralLatex: massSol.originalIntegralLatex,
      executionTimeMs: math.max(DateTime.now().difference(startTime).inMilliseconds.toDouble(), 20.0),
      regionDefinition: massSol.regionDefinition,
      steps: steps,
      domainAnalysis: massSol.domainAnalysis ?? deducedDomain,
      formulasAndMethods: massSol.formulasAndMethods,
      applicationSummary: {
        'mass_latex': massSol.exactLatex,
        'myz_latex': myzSol.exactLatex,
        'mxz_latex': mxzSol.exactLatex,
        if (mxySol != null) 'mxy_latex': mxySol.exactLatex,
        'x_bar_latex': xBar,
        'y_bar_latex': yBar,
        'z_bar_latex': ?zBar,
      },
    );
  }

  // =========================================================================
  // COORDINATE SYSTEM SOLVER (POLAR, CYLINDRICAL, SPHERICAL) WITH JACOBIAN
  // =========================================================================

  static IntegralSolution? solveCoordinateSystem(
    MultivariableIntegral integral,
    DateTime startTime,
  ) {
    final sys = integral.coordinateSystem;
    if (sys == CoordinateSystemType.cartesian) return null;

    final fAst = SymbolicCalculusEngine.parse(integral.integrand);
    if (fAst == null) return null;

    final SymExpr jacobianAst;
    final String jacobianLatex;
    final String regionTypeStr;

    if (sys == CoordinateSystemType.polar) {
      jacobianAst = SymVar('r');
      jacobianLatex = r'J(r,\theta) = r \implies dA = r\,dr\,d\theta';
      regionTypeStr = 'Polar';
    } else if (sys == CoordinateSystemType.cylindrical) {
      jacobianAst = SymVar('r');
      jacobianLatex = r'J(r,\theta,z) = r \implies dV = r\,dz\,dr\,d\theta';
      regionTypeStr = 'Cylindrical';
    } else {
      jacobianAst = SymMul([
        SymPow(SymVar('rho'), SymNum.intVal(2)),
        SymFunc('sin', SymVar('phi')),
      ]);
      jacobianLatex = r'J(\rho,\phi,\theta) = \rho^2\sin\phi \implies dV = \rho^2\sin\phi\,d\rho\,d\phi\,d\theta';
      regionTypeStr = 'Spherical';
    }

    var currentAst = SymbolicCalculusEngine.simplify(SymMul([fAst, jacobianAst]));
    final steps = <SolverStep>[];

    // Step 1: Coordinate system & Jacobian factor
    final origLatex = _formatCoordinateIntegralLatex(integral, jacobianAst);
    steps.add(SolverStep(
      stepNumber: 1,
      variable: integral.bounds.first.variable,
      lowerBoundLatex: IntegralExpressionTransformer.toDisplayLatex(integral.bounds.first.lower),
      upperBoundLatex: IntegralExpressionTransformer.toDisplayLatex(integral.bounds.first.upper),
      currentIntegrandLatex: SymbolicCalculusEngine.toLatex(currentAst),
      stepTitle: 'Paso 1: Transformación a Coordenadas ${sys.label} y Factor Jacobiano',
      stepIntegralLatex: origLatex,
      constantTreatmentText: 'Incorporamos el determinante Jacobiano del cambio de coordenadas al integrando:',
      antiderivativeWorkLatex: jacobianLatex,
      limitsEvaluationText: 'Integrando efectivo con Jacobiano incluido:',
      antiderivativeLatex: SymbolicCalculusEngine.toLatex(currentAst),
      evaluatedLatex: origLatex,
      simplifiedResultLatex: SymbolicCalculusEngine.toLatex(currentAst),
      explanation: 'Todo cambio de coordenadas curvilíneas requiere multiplicar el integrando por el valor absoluto del determinante Jacobiano.',
      appliedMethod: 'Cambio a ${sys.label} & Jacobiano',
    ));

    // Integrate iteratively from inner (index 0) to outer
    for (int i = 0; i < integral.bounds.length; i++) {
      final b = integral.bounds[i];
      final v = b.variable;
      final lowAst = SymbolicCalculusEngine.parse(b.lower);
      final uppAst = SymbolicCalculusEngine.parse(b.upper);
      if (lowAst == null || uppAst == null) return null;

      final outcome = SymbolicCalculusEngine.integrate(currentAst, v);
      if (!outcome.isSymbolic || outcome.antiderivative == null) {
        return null; // Fallback to numeric Simpson if non-elementary
      }

      final fAnti = outcome.antiderivative!;
      final subUpp = SymbolicCalculusEngine.substitute(fAnti, v, uppAst);
      final subLow = SymbolicCalculusEngine.substitute(fAnti, v, lowAst);
      final diffExpr = SymbolicCalculusEngine.expand(
        SymbolicCalculusEngine.simplify(
          SymAdd([subUpp, SymMul([SymNum.intVal(-1), subLow])]),
        ),
      );

      final curL = SymbolicCalculusEngine.toLatex(currentAst);
      final antiL = outcome.antiderivativeLatex;
      final lowL = SymbolicCalculusEngine.toLatex(lowAst);
      final uppL = SymbolicCalculusEngine.toLatex(uppAst);
      final resL = SymbolicCalculusEngine.toLatex(diffExpr);

      final stepNumAnti = steps.length + 1;
      steps.add(SolverStep(
        stepNumber: stepNumAnti,
        variable: v,
        lowerBoundLatex: lowL,
        upperBoundLatex: uppL,
        currentIntegrandLatex: curL,
        stepTitle: 'Paso $stepNumAnti: Integración parcial respecto a ${_varLatex(v)}',
        stepIntegralLatex: '\\int_{$lowL}^{$uppL} \\left($curL\\right) d${_varLatex(v)}',
        constantTreatmentText: 'Aplicamos ${outcome.method} manteniendo constantes las variables exteriores:',
        antiderivativeWorkLatex: '\\int \\left($curL\\right) d${_varLatex(v)} = $antiL',
        limitsEvaluationText: 'Antiderivada calculada:',
        antiderivativeLatex: antiL,
        evaluatedLatex: '\\left[$antiL\\right]_{$lowL}^{$uppL}',
        simplifiedResultLatex: antiL,
        explanation: outcome.explanation,
        appliedMethod: outcome.method,
      ));

      final stepNumEval = steps.length + 1;
      steps.add(SolverStep(
        stepNumber: stepNumEval,
        variable: v,
        lowerBoundLatex: lowL,
        upperBoundLatex: uppL,
        currentIntegrandLatex: antiL,
        stepTitle: 'Paso $stepNumEval: Evaluación en los límites ${_varLatex(v)} ∈ [$lowL, $uppL]',
        stepIntegralLatex: '\\left[$antiL\\right]_{$lowL}^{$uppL}',
        constantTreatmentText: 'Aplicamos la Regla de Barrow sustituyendo ${_varLatex(v)} = $uppL y ${_varLatex(v)} = $lowL:',
        antiderivativeWorkLatex: '\\left(${SymbolicCalculusEngine.toLatex(subUpp)}\\right) - \\left(${SymbolicCalculusEngine.toLatex(subLow)}\\right) = $resL',
        limitsEvaluationText: 'Expresión resultante tras la evaluación:',
        antiderivativeLatex: antiL,
        evaluatedLatex: '\\left[$antiL\\right]_{$lowL}^{$uppL} = $resL',
        simplifiedResultLatex: resL,
        explanation: 'Simplificamos algebraica y trigonométricamente el resultado para alimentar la siguiente capa.',
        appliedMethod: 'Teorema Fundamental del Cálculo (Barrow)',
      ));

      currentAst = diffExpr;
    }

    final finalAst = SymbolicCalculusEngine.simplify(currentAst);
    final exactLatex = SymbolicCalculusEngine.toLatex(finalAst);
    final hasSymParams = SymbolicCalculusEngine.hasSymbolicParameters(finalAst);
    double? approxNum;
    if (!hasSymParams && finalAst.variables().isEmpty) {
      final v = finalAst.eval({});
      if (v.isFinite) approxNum = double.parse(v.toStringAsFixed(5));
    }

    final parts = [
      for (final b in integral.bounds.reversed)
        '${IntegralExpressionTransformer.toDisplayLatex(b.lower)} \\le ${_varLatex(b.variable)} \\le ${IntegralExpressionTransformer.toDisplayLatex(b.upper)}'
    ];

    return IntegralSolution(
      isSuccess: true,
      exactLatex: exactLatex,
      approxNumeric: approxNum,
      originalIntegralLatex: origLatex,
      executionTimeMs: math.max(DateTime.now().difference(startTime).inMilliseconds.toDouble(), 16.0),
      regionDefinition: 'Esta integral está definida en coordenadas ${sys.label} sobre ${parts.join(' y ')}.',
      steps: steps,
      domainAnalysis: DomainAnalysis(
        regionType: regionTypeStr,
        deducedLimitsLatex: origLatex,
        jacobianLatex: jacobianLatex,
      ),
      formulasAndMethods: LocalMathEngine.defaultFormulasFor(integral),
    );
  }

  // =========================================================================
  // CARTESIAN 2D -> POLAR CONVERSION (Centered Symbolic & Shifted Circles 2ax)
  // =========================================================================

  static IntegralSolution? trySolveSymbolicPolarConversion(
    MultivariableIntegral integral,
    DateTime startTime,
  ) {
    if (integral.dimension != 2 || integral.bounds.length != 2) return null;
    final inner = integral.bounds[0];
    final outer = integral.bounds[1];
    final iv = inner.variable.toLowerCase();
    final ov = outer.variable.toLowerCase();
    if (!((iv == 'y' && ov == 'x') || (iv == 'x' && ov == 'y'))) return null;

    final inLow = IntegralExpressionTransformer.normalizeExpression(inner.lower).replaceAll(' ', '');
    final inUpp = IntegralExpressionTransformer.normalizeExpression(inner.upper).replaceAll(' ', '');
    final outLow = IntegralExpressionTransformer.normalizeExpression(outer.lower).replaceAll(' ', '');
    final outUpp = IntegralExpressionTransformer.normalizeExpression(outer.upper).replaceAll(' ', '');

    String? rUpperExpr;
    String? thetaLow;
    String? thetaUpp;
    String? regionDesc;

    // Case A: Shifted circle sqrt(2*a*x - x^2) or sqrt(C*x - x^2)
    final shiftedMatch = RegExp(r'^sqrt\((.+?)\*?' + ov + r'-' + ov + r'\^2\)$').firstMatch(inUpp);
    if (shiftedMatch != null) {
      final coeff = shiftedMatch.group(1)!.replaceAll('*', '').trim();
      final isSymm = inLow == '-$inUpp';
      final isUpperHalf = inLow == '0';
      if ((isSymm || isUpperHalf) && outLow == '0') {
        rUpperExpr = coeff.isEmpty ? 'cos(theta)' : '$coeff*cos(theta)';
        thetaLow = isSymm ? '-pi/2' : '0';
        thetaUpp = 'pi/2';
        regionDesc = 'circunferencia desplazada $ov² + $iv² = ${coeff.isEmpty ? '1' : coeff}$ov';
      }
    }

    // Case B: Centered symbolic/numeric circle sqrt(R^2 - x^2) or sqrt(a^2 - x^2)
    if (rUpperExpr == null) {
      final centeredMatch = RegExp(r'^sqrt\((.+?)-' + ov + r'\^2\)$').firstMatch(inUpp);
      if (centeredMatch != null) {
        final rSqStr = centeredMatch.group(1)!;
        final isSymm = inLow == '-$inUpp';
        final isUpperHalf = inLow == '0';
        if (isSymm || isUpperHalf) {
          final rStr = _extractSqrtConst(rSqStr);
          rUpperExpr = rStr;
          if (isSymm && (outLow == '-$rStr' || outLow == '-($rStr)')) {
            thetaLow = '0';
            thetaUpp = '2*pi';
          } else if (isUpperHalf && outLow == '0' && outUpp == rStr) {
            thetaLow = '0';
            thetaUpp = 'pi/2';
          } else if (isUpperHalf && (outLow == '-$rStr' || outLow == '-($rStr)')) {
            thetaLow = '0';
            thetaUpp = 'pi';
          }
          regionDesc = 'disco circular $ov² + $iv² ≤ $rSqStr';
        }
      }
    }

    if (rUpperExpr == null || thetaLow == null || thetaUpp == null) return null;

    // Transform integrand f(x,y) -> f(r cosθ, r sinθ)
    final fAst = SymbolicCalculusEngine.parse(integral.integrand);
    if (fAst == null) return null;
    var fPolar = SymbolicCalculusEngine.substitute(
      fAst,
      'x',
      SymMul([SymVar('r'), SymFunc('cos', SymVar('theta'))]),
    );
    fPolar = SymbolicCalculusEngine.substitute(
      fPolar,
      'y',
      SymMul([SymVar('r'), SymFunc('sin', SymVar('theta'))]),
    );
    // Simplify Pythagorean x^2+y^2 = r^2 in polar AST using text replacement on normalized integrand when clean
    final cleanedF = IntegralExpressionTransformer.normalizeExpression(integral.integrand).replaceAll(' ', '');
    final fPolarStr = _simplifyPolarExprString(cleanedF) ?? _astToInput(fPolar);

    final polarIntegral = MultivariableIntegral(
      integrand: fPolarStr,
      bounds: [
        IntegrationBound(variable: 'r', lower: '0', upper: rUpperExpr),
        IntegrationBound(variable: 'theta', lower: thetaLow, upper: thetaUpp),
      ],
      coordinateSystem: CoordinateSystemType.polar,
    );

    final sol = solveCoordinateSystem(polarIntegral, startTime);
    if (sol == null || !sol.isSuccess) return null;

    // Prepend Cartesian -> Polar conversion step
    final convStep = SolverStep(
      stepNumber: 1,
      variable: 'r',
      lowerBoundLatex: '0',
      upperBoundLatex: IntegralExpressionTransformer.toDisplayLatex(rUpperExpr),
      currentIntegrandLatex: IntegralExpressionTransformer.toDisplayLatex(integral.integrand),
      stepTitle: 'Paso 1: Reconocimiento de Recinto Circular ($regionDesc)',
      stepIntegralLatex: sol.originalIntegralLatex,
      constantTreatmentText: 'La región es una $regionDesc. Aplicamos el cambio a coordenadas polares x = r cosθ, y = r sinθ, dA = r dr dθ:',
      antiderivativeLatex: sol.originalIntegralLatex,
      antiderivativeWorkLatex: '0 \\le r \\le ${IntegralExpressionTransformer.toDisplayLatex(rUpperExpr)}, \\quad ${IntegralExpressionTransformer.toDisplayLatex(thetaLow)} \\le \\theta \\le ${IntegralExpressionTransformer.toDisplayLatex(thetaUpp)}',
      evaluatedLatex: sol.originalIntegralLatex,
      simplifiedResultLatex: sol.originalIntegralLatex,
      explanation: 'Al convertir las cotas con radicales a polares, eliminamos las raíces cuadradas y el Jacobiano r permite integración elemental directa.',
      appliedMethod: 'Conversión Automática a Coordenadas Polares',
    );

    final adjustedSteps = <SolverStep>[
      convStep,
      ...sol.steps.skip(1).map((s) => _copyStepWithNumber(s, s.stepNumber)),
    ];

    return sol.copyWith(
      originalIntegralLatex: LocalMathEngine.toLatexPublic(integral),
      steps: adjustedSteps,
    );
  }

  static String? _simplifyPolarExprString(String expr) {
    var s = IntegralExpressionTransformer.normalizeExpression(expr).replaceAll(' ', '');
    s = s.replaceAll('x^2+y^2', '(r^2)').replaceAll('y^2+x^2', '(r^2)');
    s = s.replaceAll('-x^2-y^2', '-(r^2)').replaceAll('-y^2-x^2', '-(r^2)');
    s = s.replaceAllMapped(RegExp(r'\bx\b'), (_) => '(r*cos(theta))');
    s = s.replaceAllMapped(RegExp(r'\by\b'), (_) => '(r*sin(theta))');
    return s;
  }

  // =========================================================================
  // 3D CARTESIAN -> CYLINDRICAL / SPHERICAL / ELLIPSOID TRANSFORM
  // =========================================================================

  static IntegralSolution? trySolve3DCartesianTransform(
    MultivariableIntegral integral,
    DateTime startTime,
  ) {
    if (integral.dimension != 3 || integral.bounds.length != 3) return null;
    final bIn = integral.bounds[0];
    final bMid = integral.bounds[1];
    final bOut = integral.bounds[2];

    final vIn = bIn.variable.toLowerCase();
    final vMid = bMid.variable.toLowerCase();
    final vOut = bOut.variable.toLowerCase();

    final inUpp = IntegralExpressionTransformer.normalizeExpression(bIn.upper).replaceAll(' ', '');
    final inLow = IntegralExpressionTransformer.normalizeExpression(bIn.lower).replaceAll(' ', '');
    final midUpp = IntegralExpressionTransformer.normalizeExpression(bMid.upper).replaceAll(' ', '');
    final midLow = IntegralExpressionTransformer.normalizeExpression(bMid.lower).replaceAll(' ', '');
    final outLow = IntegralExpressionTransformer.normalizeExpression(bOut.lower).replaceAll(' ', '');
    final outUpp = IntegralExpressionTransformer.normalizeExpression(bOut.upper).replaceAll(' ', '');

    // 1. Axis-permuted cylinder: e.g. x in [0, H], y in [-sqrt(R^2-z^2), sqrt(R^2-z^2)], z in [-R, R]
    //    or z in [-sqrt(R^2-y^2), sqrt(R^2-y^2)], y in [-R, R], x in [0, H]
    final bool isMidRad = midUpp.startsWith('sqrt(') && midLow == '-$midUpp';
    final bool isInConst = !SymbolicCalculusEngine.containsVariable(inLow) && !SymbolicCalculusEngine.containsVariable(inUpp) && !inLow.contains(vMid) && !inLow.contains(vOut);
    if (isMidRad && !inLow.contains(vMid) && !inLow.contains(vOut) && !inUpp.contains(vMid) && !inUpp.contains(vOut)) {
      final matchC = RegExp('^sqrt\\((.+?)-$vOut\\^2\\)\$').firstMatch(midUpp);
      if (matchC != null) {
        final rStr = _extractSqrtConst(matchC.group(1)!);
        if (outLow == '-$rStr' || outLow == '-($rStr)') {
          final cylIntegral = MultivariableIntegral(
            integrand: integral.integrand,
            bounds: [
              IntegrationBound(variable: vIn, lower: bIn.lower, upper: bIn.upper),
              IntegrationBound(variable: 'r', lower: '0', upper: rStr),
              const IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi'),
            ],
            coordinateSystem: CoordinateSystemType.cylindrical,
          );
          final sol = solveCoordinateSystem(cylIntegral, startTime);
          if (sol != null && sol.isSuccess) return sol;
        }
      }
    }

    // 2. Centered sphere in Cartesian: z in [±sqrt(R^2 - x^2 - y^2)], y in [±sqrt(R^2 - x^2)], x in [-R, R]
    if (vIn == 'z' && vMid == 'y' && vOut == 'x' && inUpp.startsWith('sqrt(') && isMidRad) {
      final sphereM = RegExp(r'^sqrt\((.+?)-x\^2-y\^2\)$').firstMatch(inUpp);
      if (sphereM != null) {
        final rStr = _extractSqrtConst(sphereM.group(1)!);
        final isFullZ = inLow == '-$inUpp';
        final isUpperZ = inLow == '0';
        if (isFullZ || isUpperZ) {
          final phiUpp = isFullZ ? 'pi' : 'pi/2';
          final fSph = integral.integrand
              .replaceAll('x^2 + y^2 + z^2', 'rho^2')
              .replaceAll('x^2+y^2+z^2', 'rho^2');
          final sphIntegral = MultivariableIntegral(
            integrand: fSph,
            bounds: [
              IntegrationBound(variable: 'rho', lower: '0', upper: rStr),
              IntegrationBound(variable: 'phi', lower: '0', upper: phiUpp),
              const IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi'),
            ],
            coordinateSystem: CoordinateSystemType.spherical,
          );
          final sol = solveCoordinateSystem(sphIntegral, startTime);
          if (sol != null && sol.isSuccess) return sol;
        }
      }
    }

    if (isInConst && outUpp.isEmpty) return null;
    return null;
  }

  // =========================================================================
  // GENERALIZED FUBINI ORDER REVERSAL (MAT 212 NON-ELEMENTARY INTEGRANDS)
  // =========================================================================

  static (MultivariableIntegral, SymbolicIntegrationOutcome, String)? tryGeneralFubiniReversal(
    MultivariableIntegral integral,
    SymExpr parsedIntegrand,
  ) {
    if (integral.dimension != 2) return null;
    final inner = integral.bounds[0];
    final outer = integral.bounds[1];
    final iv = inner.variable;
    final ov = outer.variable;

    final inLowAst = SymbolicCalculusEngine.parse(inner.lower);
    final inUppAst = SymbolicCalculusEngine.parse(inner.upper);
    final outLowAst = SymbolicCalculusEngine.parse(outer.lower);
    final outUppAst = SymbolicCalculusEngine.parse(outer.upper);
    if (inLowAst == null || inUppAst == null || outLowAst == null || outUppAst == null) {
      return null;
    }

    final altOutcome = SymbolicCalculusEngine.integrate(parsedIntegrand, ov);
    if (!altOutcome.isSymbolic) return null;

    final inLowZero = inLowAst is SymNum && inLowAst.rat.isZero;
    final outLowZero = outLowAst is SymNum && outLowAst.rat.isZero;
    final inLowDependsOv = inLowAst.dependsOn(ov);
    final inUppDependsOv = inUppAst.dependsOn(ov);

    // 1. Rectangular constant domain [a, b] x [c, d] (including symbolic constants!)
    if (!inLowDependsOv && !inUppDependsOv) {
      return (
        MultivariableIntegral(
          integrand: integral.integrand,
          bounds: [outer, inner],
          coordinateSystem: integral.coordinateSystem,
        ),
        altOutcome,
        'Dado que el recinto es rectangular, el Teorema de Fubini permite intercambiar directamente el orden a d$ov d$iv.',
      );
    }

    // 2. Lower curve: 0 <= iv <= g(ov), a <= ov <= b (monotonically increasing g)
    //    e.g. 0 <= y <= x^3, 0 <= x <= 1  <->  y^(1/3) <= x <= 1, 0 <= y <= 1
    //    or   0 <= y <= k*x, 0 <= x <= b  <->  y/k <= x <= b, 0 <= y <= k*b
    if (inLowZero && inUppDependsOv && outLowZero) {
      final inv = _invertMonotonicExpr(inUppAst, ov, iv);
      if (inv != null) {
        final newOutUpp = SymbolicCalculusEngine.substitute(inUppAst, ov, outUppAst);
        return (
          MultivariableIntegral(
            integrand: integral.integrand,
            bounds: [
              IntegrationBound(variable: ov, lower: _astToInput(inv), upper: outer.upper),
              IntegrationBound(variable: iv, lower: '0', upper: _astToInput(newOutUpp)),
            ],
            coordinateSystem: integral.coordinateSystem,
          ),
          altOutcome,
          'Invertimos las desigualdades de la región 0 ≤ $iv ≤ ${SymbolicCalculusEngine.toLatex(inUppAst)} sobre 0 ≤ $ov ≤ ${SymbolicCalculusEngine.toLatex(outUppAst)} a ${SymbolicCalculusEngine.toLatex(inv)} ≤ $ov ≤ ${SymbolicCalculusEngine.toLatex(outUppAst)} para $iv ∈ [0, ${SymbolicCalculusEngine.toLatex(newOutUpp)}].',
        );
      }
    }

    // 3. Upper curve: g(ov) <= iv <= C, 0 <= ov <= B where g(B) = C (and g(0) = 0)
    //    e.g. y <= x <= 1, 0 <= y <= 1  <->  0 <= y <= x, 0 <= x <= 1
    //    or   y/2 <= x <= 1, 0 <= y <= 2 <-> 0 <= y <= 2x, 0 <= x <= 1
    //    or   x^2 <= y <= 1, 0 <= x <= 1 <-> 0 <= x <= sqrt(y), 0 <= y <= 1
    //    or   y^(1/3) <= x <= 1, 0 <= y <= 1 <-> 0 <= y <= x^3, 0 <= x <= 1
    if (inLowDependsOv && !inUppDependsOv && outLowZero) {
      final inv = _invertMonotonicExpr(inLowAst, ov, iv);
      if (inv != null) {
        final valAtOutUpp = SymbolicCalculusEngine.substitute(inLowAst, ov, outUppAst);
        final diffAtCorner = SymbolicCalculusEngine.simplify(
          SymAdd([valAtOutUpp, SymMul([SymNum.intVal(-1), inUppAst])]),
        );
        final env = SymbolicCalculusEngine.defaultParamEnv(diffAtCorner.variables());
        if (diffAtCorner.eval(env).abs() < 1e-6) {
          return (
            MultivariableIntegral(
              integrand: integral.integrand,
              bounds: [
                IntegrationBound(variable: ov, lower: '0', upper: _astToInput(inv)),
                IntegrationBound(variable: iv, lower: '0', upper: inner.upper),
              ],
              coordinateSystem: integral.coordinateSystem,
            ),
            altOutcome,
            'Despejando $ov de la curva frontera $iv = ${SymbolicCalculusEngine.toLatex(inLowAst)}, la región equivale a 0 ≤ $ov ≤ ${SymbolicCalculusEngine.toLatex(inv)} con $iv ∈ [0, ${SymbolicCalculusEngine.toLatex(inUppAst)}].',
          );
        }
      }
    }

    // 4. Lower-to-upper pair with non-zero starting constant: a <= ov <= b, ov <= iv <= b
    if (inLowDependsOv && !inUppDependsOv && !outLowZero) {
      final inv = _invertMonotonicExpr(inLowAst, ov, iv);
      if (inv != null) {
        final valAtOutLow = SymbolicCalculusEngine.substitute(inLowAst, ov, outLowAst);
        final valAtOutUpp = SymbolicCalculusEngine.substitute(inLowAst, ov, outUppAst);
        final diffAtCorner = SymbolicCalculusEngine.simplify(
          SymAdd([valAtOutUpp, SymMul([SymNum.intVal(-1), inUppAst])]),
        );
        final env = SymbolicCalculusEngine.defaultParamEnv(diffAtCorner.variables());
        if (diffAtCorner.eval(env).abs() < 1e-6) {
          return (
            MultivariableIntegral(
              integrand: integral.integrand,
              bounds: [
                IntegrationBound(variable: ov, lower: outer.lower, upper: _astToInput(inv)),
                IntegrationBound(variable: iv, lower: _astToInput(valAtOutLow), upper: inner.upper),
              ],
              coordinateSystem: integral.coordinateSystem,
            ),
            altOutcome,
            'Invertimos las desigualdades sobre el triángulo desplazado a ${SymbolicCalculusEngine.toLatex(outLowAst)} ≤ $ov ≤ ${SymbolicCalculusEngine.toLatex(inv)} y ${SymbolicCalculusEngine.toLatex(valAtOutLow)} ≤ $iv ≤ ${SymbolicCalculusEngine.toLatex(inUppAst)}.',
          );
        }
      }
    }

    return null;
  }

  /// Inverts `iv = expr(ov)` to express `ov` in terms of `iv` for standard monotonic forms:
  /// k * ov, ov / k, k * ov^p, ov^p, sqrt(ov), exp(ov), ln(ov)
  static SymExpr? _invertMonotonicExpr(SymExpr expr, String ov, String iv) {
    final s = SymbolicCalculusEngine.simplify(expr);
    if (s is SymVar && s.name == SymVar.canonicalName(ov)) {
      return SymVar(SymVar.canonicalName(iv));
    }
    // Linear k * ov + b
    final lin = SymbolicCalculusEngine.matchLinear(s, ov);
    if (lin != null) {
      final (k, b) = lin;
      return SymbolicCalculusEngine.simplify(
        SymDiv(SymAdd([SymVar(SymVar.canonicalName(iv)), SymMul([SymNum.intVal(-1), b])]), k),
      );
    }
    // Power ov^p
    if (s is SymPow && s.base is SymVar && (s.base as SymVar).name == SymVar.canonicalName(ov) && s.exp is SymNum) {
      final p = (s.exp as SymNum).rat;
      if (!p.isZero) {
        final invP = SymRat(p.q, p.p);
        return SymbolicCalculusEngine.simplify(
          SymPow(SymVar(SymVar.canonicalName(iv)), SymNum(invP)),
        );
      }
    }
    // sqrt(ov) -> iv^2
    if (s is SymFunc && s.name == 'sqrt' && s.arg is SymVar && (s.arg as SymVar).name == SymVar.canonicalName(ov)) {
      return SymPow(SymVar(SymVar.canonicalName(iv)), SymNum.intVal(2));
    }
    // k * ov^p
    if (s is SymMul && s.factors.length == 2 && !s.factors[0].dependsOn(ov)) {
      final k = s.factors[0];
      final rest = s.factors[1];
      if (rest is SymPow && rest.base is SymVar && (rest.base as SymVar).name == SymVar.canonicalName(ov) && rest.exp is SymNum) {
        final p = (rest.exp as SymNum).rat;
        if (!p.isZero) {
          final invP = SymRat(p.q, p.p);
          return SymbolicCalculusEngine.simplify(
            SymPow(SymDiv(SymVar(SymVar.canonicalName(iv)), k), SymNum(invP)),
          );
        }
      }
    }
    return null;
  }

  // =========================================================================
  // ENHANCED 3D MESH GENERATOR (DUAL SURFACES + DOMAIN PROJECTION ON Z=0)
  // =========================================================================

  static Map<String, dynamic> generateEnhancedMesh(
    MultivariableIntegral integral, {
    int resolution = 24,
  }) {
    final sys = integral.coordinateSystem;

    // 1. Volume between two explicit surfaces OR 3D Cartesian solid
    if (integral.problemMode == ProblemMode.volumeBetweenSurfaces ||
        (integral.dimension == 3 && sys == CoordinateSystemType.cartesian)) {
      return _generateDualSurfaceMesh(integral, resolution: resolution);
    }

    // 2. Cylindrical / Polar mesh
    if (sys == CoordinateSystemType.polar || sys == CoordinateSystemType.cylindrical) {
      return _generatePolarOrCylindricalMesh(integral, resolution: resolution);
    }

    // 3. Spherical mesh
    if (sys == CoordinateSystemType.spherical) {
      return _generateSphericalMesh(integral, resolution: resolution);
    }

    // 4. Standard 2D surface z = f(x, y) over domain R + projection on z = 0
    return _generateStandard2DSurfaceMesh(integral, resolution: resolution);
  }

  static Map<String, dynamic> _generateDualSurfaceMesh(
    MultivariableIntegral integral, {
    int resolution = 22,
  }) {
    final bInner = integral.bounds.isNotEmpty ? integral.bounds[0] : const IntegrationBound(variable: 'z', lower: '0', upper: '1');
    final bMid = integral.bounds.length >= 2 ? integral.bounds[1] : const IntegrationBound(variable: 'y', lower: '-1', upper: '1');
    final bOuter = integral.bounds.length >= 3 ? integral.bounds[2] : (integral.bounds.length == 2 ? integral.bounds[1] : const IntegrationBound(variable: 'x', lower: '-1', upper: '1'));

    final xBound = integral.dimension >= 3 ? bOuter : (integral.bounds[1].variable == 'x' ? integral.bounds[1] : integral.bounds[0]);
    final yBound = integral.dimension >= 3 ? bMid : (integral.bounds[0].variable == 'y' ? integral.bounds[0] : integral.bounds[1]);

    final zLowExpr = integral.zLowerExpr ?? (integral.dimension >= 3 ? bInner.lower : '0');
    final zUppExpr = integral.zUpperExpr ?? (integral.dimension >= 3 ? bInner.upper : integral.integrand);

    double xMin = MathExpressionEvaluator.evaluate(xBound.lower, params: previewParams);
    double xMax = MathExpressionEvaluator.evaluate(xBound.upper, params: previewParams);
    if (!xMin.isFinite || !xMax.isFinite || (xMax - xMin).abs() < 1e-6) {
      xMin = -2.0;
      xMax = 2.0;
    }

    final topVerts = <double>[];
    final botVerts = <double>[];
    final topInds = <int>[];
    final botInds = <int>[];
    final topGrid = <String, int>{};
    final botGrid = <String, int>{};
    int tCount = 0;
    int bCount = 0;

    final topBoundaryPts = <List<double>>[];
    final botBoundaryPts = <List<double>>[];

    for (int i = 0; i <= resolution; i++) {
      final x = xMin + (xMax - xMin) * (i / resolution);
      double yMin = MathExpressionEvaluator.evaluate(yBound.lower, x: x, params: previewParams);
      double yMax = MathExpressionEvaluator.evaluate(yBound.upper, x: x, params: previewParams);
      if (!yMin.isFinite || !yMax.isFinite) {
        yMin = -2.0;
        yMax = 2.0;
      }
      if (yMin > yMax) {
        final tmp = yMin;
        yMin = yMax;
        yMax = tmp;
      }

      botBoundaryPts.add([x, yMin]);
      topBoundaryPts.add([x, yMax]);

      for (int j = 0; j <= resolution; j++) {
        final y = yMin + (yMax - yMin) * (j / resolution);
        var zl = MathExpressionEvaluator.evaluate(zLowExpr, x: x, y: y, params: previewParams);
        var zu = MathExpressionEvaluator.evaluate(zUppExpr, x: x, y: y, params: previewParams);
        if (!zl.isFinite) zl = 0.0;
        if (!zu.isFinite) zu = 0.0;
        zl = zl.clamp(-10.0, 10.0);
        zu = zu.clamp(-10.0, 10.0);

        topVerts.addAll([x, y, zu]);
        topGrid['$i,$j'] = tCount++;
        botVerts.addAll([x, y, zl]);
        botGrid['$i,$j'] = bCount++;
      }
    }

    for (int i = 0; i < resolution; i++) {
      for (int j = 0; j < resolution; j++) {
        final p0 = topGrid['$i,$j'];
        final p1 = topGrid['${i + 1},$j'];
        final p2 = topGrid['$i,${j + 1}'];
        final p3 = topGrid['${i + 1},${j + 1}'];
        if (p0 != null && p1 != null && p2 != null && p3 != null) {
          topInds.addAll([p0, p1, p2, p1, p3, p2]);
        }
        final b0 = botGrid['$i,$j'];
        final b1 = botGrid['${i + 1},$j'];
        final b2 = botGrid['$i,${j + 1}'];
        final b3 = botGrid['${i + 1},${j + 1}'];
        if (b0 != null && b1 != null && b2 != null && b3 != null) {
          botInds.addAll([b0, b2, b1, b1, b2, b3]);
        }
      }
    }

    final projPoly = [...topBoundaryPts, ...botBoundaryPts.reversed];

    return {
      'type': 'volume',
      'dimension': integral.dimension,
      'title': 'Sólido V: z ∈ [$zLowExpr, $zUppExpr]',
      'top_surface': {'vertices': topVerts, 'indices': topInds},
      'bottom_surface': {'vertices': botVerts, 'indices': botInds},
      'vertices': topVerts,
      'indices': topInds,
      'domain_projection': [projPoly],
    };
  }

  static Map<String, dynamic> _generatePolarOrCylindricalMesh(
    MultivariableIntegral integral, {
    int resolution = 24,
  }) {
    IntegrationBound rB = const IntegrationBound(variable: 'r', lower: '0', upper: '2');
    IntegrationBound thB = const IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi');
    IntegrationBound? zB;

    for (final b in integral.bounds) {
      final v = b.variable.toLowerCase();
      if (v == 'r') rB = b;
      if (v == 'theta') thB = b;
      if (v == 'z') zB = b;
    }

    final thMin = MathExpressionEvaluator.evaluate(thB.lower, params: previewParams);
    final thMax = MathExpressionEvaluator.evaluate(thB.upper, params: previewParams);
    final tA = thMin.isFinite ? thMin : 0.0;
    final tB = thMax.isFinite ? thMax : 2 * math.pi;

    final topVerts = <double>[];
    final botVerts = <double>[];
    final topInds = <int>[];
    final botInds = <int>[];
    final grid = <String, int>{};
    final projOuter = <List<double>>[];
    int cnt = 0;

    for (int i = 0; i <= resolution; i++) {
      final th = tA + (tB - tA) * (i / resolution);
      final rL = MathExpressionEvaluator.evaluate(rB.lower, params: {...previewParams, 'theta': th});
      final rU = MathExpressionEvaluator.evaluate(rB.upper, params: {...previewParams, 'theta': th});
      final rMin = rL.isFinite ? math.max(0.0, rL) : 0.0;
      final rMax = rU.isFinite ? math.max(rMin, rU) : 2.0;

      projOuter.add([rMax * math.cos(th), rMax * math.sin(th)]);

      for (int j = 0; j <= resolution; j++) {
        final r = rMin + (rMax - rMin) * (j / resolution);
        final x = r * math.cos(th);
        final y = r * math.sin(th);

        double zTop, zBot;
        if (zB != null) {
          zBot = MathExpressionEvaluator.evaluate(zB.lower, x: x, y: y, params: {...previewParams, 'r': r, 'theta': th});
          zTop = MathExpressionEvaluator.evaluate(zB.upper, x: x, y: y, params: {...previewParams, 'r': r, 'theta': th});
        } else {
          zBot = 0.0;
          zTop = MathExpressionEvaluator.evaluate(integral.integrand, x: x, y: y, params: {...previewParams, 'r': r, 'theta': th});
        }
        if (!zBot.isFinite) zBot = 0.0;
        if (!zTop.isFinite) zTop = 0.0;

        topVerts.addAll([x, y, zTop.clamp(-10.0, 10.0)]);
        botVerts.addAll([x, y, zBot.clamp(-10.0, 10.0)]);
        grid['$i,$j'] = cnt++;
      }
    }

    for (int i = 0; i < resolution; i++) {
      for (int j = 0; j < resolution; j++) {
        final p0 = grid['$i,$j'];
        final p1 = grid['${i + 1},$j'];
        final p2 = grid['$i,${j + 1}'];
        final p3 = grid['${i + 1},${j + 1}'];
        if (p0 != null && p1 != null && p2 != null && p3 != null) {
          topInds.addAll([p0, p1, p2, p1, p3, p2]);
          botInds.addAll([p0, p2, p1, p1, p2, p3]);
        }
      }
    }

    return {
      'type': zB != null ? 'volume' : 'surface',
      'dimension': integral.dimension,
      'title': '${integral.coordinateSystem.label}: ${integral.integrand}',
      'top_surface': {'vertices': topVerts, 'indices': topInds},
      if (zB != null) 'bottom_surface': {'vertices': botVerts, 'indices': botInds},
      'vertices': topVerts,
      'indices': topInds,
      'domain_projection': [projOuter],
    };
  }

  static Map<String, dynamic> _generateSphericalMesh(
    MultivariableIntegral integral, {
    int resolution = 22,
  }) {
    IntegrationBound rhoB = const IntegrationBound(variable: 'rho', lower: '0', upper: '2');
    IntegrationBound phiB = const IntegrationBound(variable: 'phi', lower: '0', upper: 'pi');
    IntegrationBound thB = const IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi');
    for (final b in integral.bounds) {
      final v = b.variable.toLowerCase();
      if (v == 'rho') rhoB = b;
      if (v == 'phi') phiB = b;
      if (v == 'theta') thB = b;
    }

    final pMin = MathExpressionEvaluator.evaluate(phiB.lower, params: previewParams);
    final pMax = MathExpressionEvaluator.evaluate(phiB.upper, params: previewParams);
    final tMin = MathExpressionEvaluator.evaluate(thB.lower, params: previewParams);
    final tMax = MathExpressionEvaluator.evaluate(thB.upper, params: previewParams);
    final phiA = pMin.isFinite ? pMin : 0.0;
    final phiBVal = pMax.isFinite ? pMax : math.pi;
    final thA = tMin.isFinite ? tMin : 0.0;
    final thBVal = tMax.isFinite ? tMax : 2 * math.pi;

    final verts = <double>[];
    final inds = <int>[];
    final grid = <String, int>{};
    final proj = <List<double>>[];
    int cnt = 0;

    for (int i = 0; i <= resolution; i++) {
      final phi = phiA + (phiBVal - phiA) * (i / resolution);
      for (int j = 0; j <= resolution; j++) {
        final th = thA + (thBVal - thA) * (j / resolution);
        var rho = MathExpressionEvaluator.evaluate(
          rhoB.upper,
          params: {...previewParams, 'phi': phi, 'theta': th},
        );
        if (!rho.isFinite || rho < 0) rho = 0.0;
        final x = rho * math.sin(phi) * math.cos(th);
        final y = rho * math.sin(phi) * math.sin(th);
        final z = rho * math.cos(phi);
        verts.addAll([x, y, z]);
        grid['$i,$j'] = cnt++;
        if (i == resolution ~/ 2) {
          proj.add([x, y]);
        }
      }
    }

    for (int i = 0; i < resolution; i++) {
      for (int j = 0; j < resolution; j++) {
        final p0 = grid['$i,$j'];
        final p1 = grid['${i + 1},$j'];
        final p2 = grid['$i,${j + 1}'];
        final p3 = grid['${i + 1},${j + 1}'];
        if (p0 != null && p1 != null && p2 != null && p3 != null) {
          inds.addAll([p0, p1, p2, p1, p3, p2]);
        }
      }
    }

    return {
      'type': 'surface',
      'dimension': 3,
      'title': 'Sólido Esférico (ρ, φ, θ)',
      'vertices': verts,
      'indices': inds,
      if (proj.length >= 3) 'domain_projection': [proj],
    };
  }

  static Map<String, dynamic> _generateStandard2DSurfaceMesh(
    MultivariableIntegral integral, {
    int resolution = 24,
  }) {
    double xMin = -2.5, xMax = 2.5;
    IntegrationBound? xB;
    IntegrationBound? yB;
    if (integral.bounds.length >= 2) {
      if (integral.bounds[1].variable.toLowerCase() == 'x') {
        xB = integral.bounds[1];
        yB = integral.bounds[0];
      } else {
        xB = integral.bounds[0];
        yB = integral.bounds[1];
      }
      final rawX0 = MathExpressionEvaluator.evaluate(xB.lower, params: previewParams);
      final rawX1 = MathExpressionEvaluator.evaluate(xB.upper, params: previewParams);
      if (rawX0.isFinite && rawX1.isFinite && (rawX1 - rawX0).abs() > 1e-4 && !SymbolicCalculusEngine.containsVariable(xB.lower) && !SymbolicCalculusEngine.containsVariable(xB.upper)) {
        xMin = math.min(rawX0, rawX1);
        xMax = math.max(rawX0, rawX1);
      }
    }

    final verts = <double>[];
    final inds = <int>[];
    final grid = <String, int>{};
    final topProj = <List<double>>[];
    final botProj = <List<double>>[];
    int count = 0;

    for (int i = 0; i <= resolution; i++) {
      final x = xMin + (xMax - xMin) * (i / resolution);
      double yMin = -2.5, yMax = 2.5;
      if (yB != null && xB != null && integral.bounds[1].variable.toLowerCase() == 'x') {
        final yl = MathExpressionEvaluator.evaluate(yB.lower, x: x, params: previewParams);
        final yu = MathExpressionEvaluator.evaluate(yB.upper, x: x, params: previewParams);
        if (yl.isFinite && yu.isFinite) {
          yMin = math.min(yl, yu);
          yMax = math.max(yl, yu);
        }
      }
      botProj.add([x, yMin]);
      topProj.add([x, yMax]);

      for (int j = 0; j <= resolution; j++) {
        final y = yMin + (yMax - yMin) * (j / resolution);
        var z = MathExpressionEvaluator.evaluate(integral.integrand, x: x, y: y, params: previewParams);
        if (!z.isFinite) z = 0.0;
        verts.addAll([x, y, z.clamp(-12.0, 12.0)]);
        grid['$i,$j'] = count++;
      }
    }

    for (int i = 0; i < resolution; i++) {
      for (int j = 0; j < resolution; j++) {
        final p0 = grid['$i,$j'];
        final p1 = grid['${i + 1},$j'];
        final p2 = grid['$i,${j + 1}'];
        final p3 = grid['${i + 1},${j + 1}'];
        if (p0 != null && p1 != null && p2 != null && p3 != null) {
          inds.addAll([p0, p1, p2, p1, p3, p2]);
        }
      }
    }

    final projPoly = [...topProj, ...botProj.reversed];

    return {
      'type': 'surface',
      'dimension': integral.dimension,
      'title': 'Superficie z = ${integral.integrand}',
      'vertices': verts,
      'indices': inds,
      'domain_projection': [projPoly],
      'bounds': {
        'x_min': xMin,
        'x_max': xMax,
        'y_min': -2.5,
        'y_max': 2.5,
        'z_min': -3.0,
        'z_max': 4.0,
      },
    };
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  static SolverStep _copyStepWithNumber(SolverStep s, int num) {
    return SolverStep(
      stepNumber: num,
      variable: s.variable,
      lowerBoundLatex: s.lowerBoundLatex,
      upperBoundLatex: s.upperBoundLatex,
      currentIntegrandLatex: s.currentIntegrandLatex,
      antiderivativeLatex: s.antiderivativeLatex,
      evaluatedLatex: s.evaluatedLatex,
      simplifiedResultLatex: s.simplifiedResultLatex,
      explanation: s.explanation,
      appliedMethod: s.appliedMethod,
      isLimitInverted: s.isLimitInverted,
      stepTitle: s.stepTitle,
      stepIntegralLatex: s.stepIntegralLatex,
      constantTreatmentText: s.constantTreatmentText,
      antiderivativeWorkLatex: s.antiderivativeWorkLatex,
      limitsEvaluationText: s.limitsEvaluationText,
    );
  }

  static String _varLatex(String v) {
    return switch (v.toLowerCase()) {
      'theta' => r'\theta',
      'phi' => r'\phi',
      'rho' => r'\rho',
      _ => v,
    };
  }

  static String _formatCoordinateIntegralLatex(
    MultivariableIntegral integral,
    SymExpr jacobianAst,
  ) {
    final buf = StringBuffer();
    for (final b in integral.bounds.reversed) {
      final low = IntegralExpressionTransformer.toDisplayLatex(b.lower);
      final upp = IntegralExpressionTransformer.toDisplayLatex(b.upper);
      buf.write('\\int_{$low}^{$upp} ');
    }
    final fDisp = IntegralExpressionTransformer.toDisplayLatex(integral.integrand);
    final jLatex = SymbolicCalculusEngine.toLatex(jacobianAst);
    if (fDisp == '1') {
      buf.write(jLatex);
    } else {
      buf.write('\\left($fDisp\\right) \\cdot $jLatex');
    }
    for (final b in integral.bounds) {
      buf.write('\\, d${_varLatex(b.variable)}');
    }
    return buf.toString();
  }

  static String _extractSqrtConst(String expr) {
    final s = expr.replaceAll(' ', '');
    if (s.endsWith('^2')) return s.substring(0, s.length - 2);
    final numVal = MathExpressionEvaluator.evaluate(s);
    if (!SymbolicCalculusEngine.containsVariable(s) && numVal.isFinite && numVal > 0) {
      final r = math.sqrt(numVal);
      if ((r - r.roundToDouble()).abs() < 1e-6) return '${r.round()}';
    }
    return 'sqrt($s)';
  }

  static String _astToInput(SymExpr e) {
    return switch (e) {
      SymNum(:final rat) => rat.isInt ? '${rat.p}' : '(${rat.p}/${rat.q})',
      SymFloat(:final value) => '$value',
      SymConst(:final name) => name,
      SymVar(:final name) => name,
      SymAdd(:final terms) => terms.map(_astToInput).join(' + '),
      SymMul(:final factors) => factors
          .map((f) => f is SymAdd ? '(${_astToInput(f)})' : _astToInput(f))
          .join('*'),
      SymDiv(:final num, :final den) => '(${_astToInput(num)})/(${_astToInput(den)})',
      SymPow(:final base, :final exp) => '(${_astToInput(base)})^(${_astToInput(exp)})',
      SymFunc(:final name, :final arg) => '$name(${_astToInput(arg)})',
    };
  }
}
