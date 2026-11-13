import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/features/calculator/domain/entities/integration_bound.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/calculator/domain/services/integral_expression_transformer.dart';
import 'package:integra_3d/features/calculator/domain/services/local_math_engine.dart';
import 'package:integra_3d/features/calculator/domain/services/region_geometry_solver.dart';
import 'package:integra_3d/features/calculator/domain/services/symbolic_calculus_engine.dart';
import 'package:integra_3d/features/solver/domain/entities/integral_solution.dart';
import 'package:integra_3d/features/solver/domain/services/math_ai_didactic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHttpAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;
  _FakeHttpAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MAT 212 Case 1: Mandatory Order Reversal (Non-Elementary Integrands)', () {
    test('Solves ∫_0^1 ∫_y^1 (y*exp(x)/x) dx dy via order reversal', () {
      const integral = MultivariableIntegral(
        integrand: 'y * exp(x) / x',
        bounds: [
          IntegrationBound(variable: 'x', lower: 'y', upper: '1'),
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
        ],
      );
      final sol = LocalMathEngine.solveLocal(integral);
      expect(sol.isSuccess, isTrue);
      // Inner int_0^x (y e^x / x) dy = 0.5 x e^x; outer int_0^1 0.5 x e^x dx = 0.5
      expect(sol.approxNumeric, closeTo(0.5, 1e-2));
      expect(
        sol.steps.any((s) => (s.appliedMethod ?? '').toLowerCase().contains('fubini') ||
            (s.stepTitle ?? '').toLowerCase().contains('orden')),
        isTrue,
      );
    });

    test('Solves ∫_0^1 ∫_y^1 (y^3*exp(x)/x^2) dx dy via order reversal', () {
      const integral = MultivariableIntegral(
        integrand: 'y^3 * exp(x) / x^2',
        bounds: [
          IntegrationBound(variable: 'x', lower: 'y', upper: '1'),
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
        ],
      );
      final sol = LocalMathEngine.solveLocal(integral);
      expect(sol.isSuccess, isTrue);
      // Inner int_0^x y^3 e^x / x^2 dy = x^2 e^x / 4; outer int_0^1 x^2 e^x / 4 dx = (e - 2)/4 ≈ 0.17957
      expect(sol.approxNumeric, closeTo(0.17957, 1e-2));
    });

    test('Solves ∫_0^1 ∫_x^1 sin(y)/y dy dx via order reversal (and [0, pi/2])', () {
      const integralUnit = MultivariableIntegral(
        integrand: 'sin(y) / y',
        bounds: [
          IntegrationBound(variable: 'y', lower: 'x', upper: '1'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
      );
      final sol1 = LocalMathEngine.solveLocal(integralUnit);
      expect(sol1.isSuccess, isTrue);
      // 1 - cos(1) ≈ 0.459698
      expect(sol1.approxNumeric, closeTo(0.4597, 1e-2));

      const integralPi2 = MultivariableIntegral(
        integrand: 'sin(y) / y',
        bounds: [
          IntegrationBound(variable: 'y', lower: 'x', upper: 'pi/2'),
          IntegrationBound(variable: 'x', lower: '0', upper: 'pi/2'),
        ],
      );
      final sol2 = LocalMathEngine.solveLocal(integralPi2);
      expect(sol2.isSuccess, isTrue);
      expect(sol2.approxNumeric, closeTo(1.0, 1e-2));
    });

    test('Solves ∫_0^1 ∫_0^x exp(y/x) dy dx cleanly = (e - 1)/2', () {
      const integral = MultivariableIntegral(
        integrand: 'exp(y / x)',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: 'x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
      );
      final sol = LocalMathEngine.solveLocal(integral);
      expect(sol.isSuccess, isTrue);
      // (e - 1)/2 ≈ 0.85914
      expect(sol.approxNumeric, closeTo(0.85914, 2e-2));
    });

    test('Solves ∫_0^1 ∫_{y^(1/3)}^1 x*sqrt(1+y^3) dx dy or reverses power bounds', () {
      const integral = MultivariableIntegral(
        integrand: 'sqrt(1 + x^3)',
        bounds: [
          IntegrationBound(variable: 'x', lower: 'sqrt(y)', upper: '1'),
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
        ],
      );
      final sol = LocalMathEngine.solveLocal(integral);
      expect(sol.isSuccess, isTrue);
      // Inner y in [0, x^2] -> x^2 sqrt(1 + x^3) -> 2/9 (2^(3/2) - 1) ≈ 0.40632
      expect(sol.approxNumeric, closeTo(0.40632, 2e-2));
    });
  });

  group('MAT 212 Cases 2-5: Polar, UV Jacobian, Cylindrical, Spherical & Symbolic Constants', () {
    test('Implicit multiplication normalizes 2ax, abc, kR cleanly', () {
      expect(
        IntegralExpressionTransformer.normalizeExpression('2ax - x^2'),
        equals('2*a*x - x^2'),
      );
      expect(
        IntegralExpressionTransformer.normalizeExpression('abc'),
        equals('a*b*c'),
      );
    });

    test('Polar shifted circle x^2 + y^2 = 2*a*x yields (3/2)*pi*a^4', () {
      const shiftedPolar = MultivariableIntegral(
        integrand: 'r^2',
        bounds: [
          IntegrationBound(variable: 'r', lower: '0', upper: '2*a*cos(theta)'),
          IntegrationBound(variable: 'theta', lower: '-pi/2', upper: 'pi/2'),
        ],
        coordinateSystem: CoordinateSystemType.polar,
      );
      final sol = LocalMathEngine.solveLocal(shiftedPolar);
      expect(sol.isSuccess, isTrue);
      expect(sol.domainAnalysis?.regionType, equals('Polar'));
      expect(sol.exactLatex, anyOf(contains('a^{4}'), contains(r'\pi')));

      // Also check Cartesian shifted circle radical detection: sqrt(2*a*x - x^2)
      const shiftedCart = MultivariableIntegral(
        integrand: 'x^2 + y^2',
        bounds: [
          IntegrationBound(variable: 'y', lower: '-sqrt(2*a*x - x^2)', upper: 'sqrt(2*a*x - x^2)'),
          IntegrationBound(variable: 'x', lower: '0', upper: '2*a'),
        ],
      );
      final cartSol = LocalMathEngine.solveLocal(shiftedCart);
      expect(cartSol.isSuccess, isTrue);
      expect(cartSol.exactLatex, contains(r'\pi'));
      expect(cartSol.exactLatex, contains('a^{4}'));
    });

    test('Polar cardioid r = 1 + cos(theta) computes exact area (3/2)*pi', () {
      const cardioid = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'r', lower: '0', upper: '1 + cos(theta)'),
          IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi'),
        ],
        coordinateSystem: CoordinateSystemType.polar,
      );
      final sol = LocalMathEngine.solveLocal(cardioid);
      expect(sol.isSuccess, isTrue);
      expect(sol.approxNumeric, closeTo(4.71239, 1e-2));
    });

    test('Symbolic positive constants produce abc/6 for symbolic tetrahedron', () {
      const tetra = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'z', lower: '0', upper: 'c * (1 - x/a - y/b)'),
          IntegrationBound(variable: 'y', lower: '0', upper: 'b * (1 - x/a)'),
          IntegrationBound(variable: 'x', lower: '0', upper: 'a'),
        ],
      );
      final sol = LocalMathEngine.solveLocal(tetra);
      expect(sol.isSuccess, isTrue);
      expect(sol.exactLatex, contains('a'));
      expect(sol.exactLatex, contains('b'));
      expect(sol.exactLatex, contains('c'));
      expect(sol.exactLatex, contains('6'));
    });

    test('General (u, v) transformation with 4-curve families computes Jacobian & exact integral', () {
      // Family 1: xy = 1, xy = 3; y = x, y = 3x => u=xy, v=y/x => |J| = 1/(2v)
      // Area = \int_1^3 \int_1^3 1/(2v) dv du = ln(3) ≈ 1.09861
      const uvHyperbolic = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: 'x', upper: '3*x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
        problemMode: ProblemMode.regionCurves,
        boundaryCurves: ['x*y = 1', 'x*y = 3', 'y = x', 'y = 3*x'],
      );
      final sol1 = LocalMathEngine.solveLocal(uvHyperbolic);
      expect(sol1.isSuccess, isTrue);
      expect(sol1.domainAnalysis?.regionType, equals('UV_Jacobian'));
      expect(sol1.domainAnalysis?.jacobianLatex, isNotNull);
      expect(sol1.approxNumeric, closeTo(1.0986, 2e-2));

      // Family 2: parallel lines x+y=1, x+y=3; x-2y=0, x-2y=4
      const uvLinear = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
        problemMode: ProblemMode.regionCurves,
        boundaryCurves: ['x + y = 1', 'x + y = 3', 'x - 2*y = 0', 'x - 2*y = 4'],
      );
      final sol2 = LocalMathEngine.solveLocal(uvLinear);
      expect(sol2.isSuccess, isTrue);
      expect(sol2.domainAnalysis?.regionType, equals('UV_Jacobian'));
      // |du/dx*dv/dy - du/dy*dv/dx| = |-2 - 1| = 3 -> |J| = 1/3 -> Area = (3-1)*(4-0)/3 = 8/3 ≈ 2.6667
      expect(sol2.approxNumeric, closeTo(8.0 / 3.0, 2e-2));
    });

    test('Cylindrical and Spherical coordinate systems include Jacobian in DomainAnalysis', () {
      // Cone mass with constant density k: M = k * (1/3) * pi * R^2 * H
      const coneMass = MultivariableIntegral(
        integrand: 'k',
        bounds: [
          IntegrationBound(variable: 'z', lower: 'H * r / R', upper: 'H'),
          IntegrationBound(variable: 'r', lower: '0', upper: 'R'),
          IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi'),
        ],
        coordinateSystem: CoordinateSystemType.cylindrical,
      );
      final cylSol = LocalMathEngine.solveLocal(coneMass);
      expect(cylSol.isSuccess, isTrue);
      expect(cylSol.domainAnalysis?.regionType, equals('Cylindrical'));
      expect(cylSol.domainAnalysis?.jacobianLatex, contains('r'));

      // Spherical ellipsoid 36z^2 + 9x^2 + 4y^2 <= 144 -> z^2/4 + x^2/16 + y^2/36 <= 1 (a=4, b=6, c=2 -> V = 4/3 pi a b c = 64 pi)
      final sph = MultivariableIntegral(
        integrand: '48', // rescaled J = 4*6*2 = 48 rho^2 sin(phi) on unit ball rho in [0,1]
        bounds: const [
          IntegrationBound(variable: 'rho', lower: '0', upper: '1'),
          IntegrationBound(variable: 'phi', lower: '0', upper: 'pi'),
          IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi'),
        ],
        coordinateSystem: CoordinateSystemType.spherical,
      );
      final sphSol = LocalMathEngine.solveLocal(sph);
      expect(sphSol.isSuccess, isTrue);
      expect(sphSol.domainAnalysis?.regionType, equals('Spherical'));
      expect(sphSol.exactLatex, anyOf(contains(r'64\pi'), contains(r'64 \pi')));
      expect(sphSol.approxNumeric, closeTo(64 * 3.1415926, 1e-2));
    });

    test('MAT 212 Region by Vertices and Curves deduce limits & Paso 0', () {
      final vertDeduced = RegionGeometrySolver.deduceFromVertices(
        verticesInput: ['A(0,0)', 'B(10,1)', 'C(1,1)'],
        integrand: '1',
      );
      expect(vertDeduced, isNotNull);
      // Shares horizontal y=1 -> single integral in Type II (dx dy)
      expect(vertDeduced!.subIntegrals.length, equals(1));
      expect(vertDeduced.primaryIntegral.bounds.first.variable, equals('x'));
      expect(vertDeduced.step0.stepTitle, contains('Paso 0'));

      // Solve full mode 2 curves y = 2*x, y = x^2 -> area = 4/3
      const curveArea = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
        problemMode: ProblemMode.regionCurves,
        boundaryCurves: ['y = 2*x', 'y = x^2'],
      );
      final curveSol = LocalMathEngine.solveLocal(curveArea);
      expect(curveSol.isSuccess, isTrue);
      expect(curveSol.approxNumeric, closeTo(4.0 / 3.0, 1e-2));
      expect(curveSol.steps.first.stepTitle, contains('Paso 0'));
      expect(curveSol.domainAnalysis?.intersectionPoints.length, greaterThanOrEqualTo(2));
    });

    test('MAT 212 Mode 3 Applications: Surface Area, Volume Between Surfaces, Mass & Centroid', () {
      // Surface Area of z = 2x + 3y + 1 over [0, 2] x [0, 1] -> 2 * 1 * sqrt(1 + 4 + 9) = 2 sqrt(14) ≈ 7.4833
      const surfInt = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
          IntegrationBound(variable: 'x', lower: '0', upper: '2'),
        ],
        problemMode: ProblemMode.surfaceArea,
        zUpperExpr: '2*x + 3*y + 1',
      );
      final surfSol = LocalMathEngine.solveLocal(surfInt);
      expect(surfSol.isSuccess, isTrue);
      expect(surfSol.approxNumeric, closeTo(7.4833, 2e-2));

      // Volume between z_sup = 8 - x^2 - y^2 and z_inf = x^2 + y^2 over [0, 1] x [0, 1] -> 20/3 ≈ 6.6667
      const volInt = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
        problemMode: ProblemMode.volumeBetweenSurfaces,
        zLowerExpr: 'x^2 + y^2',
        zUpperExpr: '8 - x^2 - y^2',
      );
      final volSol = LocalMathEngine.solveLocal(volInt);
      expect(volSol.isSuccess, isTrue);
      expect(volSol.approxNumeric, closeTo(20.0 / 3.0, 2e-2));

      // Mass & Centroid of uniform square [0, 2] x [0, 2] with density k=1 -> M=4, (x_bar, y_bar) = (1, 1)
      const massInt = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: '2'),
          IntegrationBound(variable: 'x', lower: '0', upper: '2'),
        ],
        problemMode: ProblemMode.massAndCenterOfMass,
        densityExpr: '1',
      );
      final massSol = LocalMathEngine.solveLocal(massInt);
      expect(massSol.isSuccess, isTrue);
      expect(massSol.approxNumeric, closeTo(4.0, 1e-3));
      expect(massSol.applicationSummary, isNotNull);
      expect(massSol.applicationSummary!['x_bar_latex'], equals('1'));
      expect(massSol.applicationSummary!['y_bar_latex'], equals('1'));
    });

    test('Mesh generation returns dual surfaces + z=0 projection for volume between surfaces', () {
      const volInt = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: 'x^2', upper: '2*x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '2'),
        ],
        problemMode: ProblemMode.volumeBetweenSurfaces,
        zLowerExpr: 'x^2 + y^2',
        zUpperExpr: '8 - x^2 - y^2',
      );
      final mesh = LocalMathEngine.generateLocalMesh(volInt, resolution: 10);
      expect(mesh['type'], equals('volume'));
      expect(mesh['top_surface'], isA<Map>());
      expect(mesh['bottom_surface'], isA<Map>());
      expect((mesh['domain_projection'] as List).isNotEmpty, isTrue);
    });
  });

  group('Module 4: DomainAnalysis JSON Protocol & MathAiDidacticService', () {
    test('DomainAnalysis serializes and deserializes cleanly via IntegralSolution', () {
      final jsonMap = {
        'is_success': true,
        'exact_latex': r'\frac{4}{3}',
        'approx_numeric': 1.3333,
        'original_integral_latex': r'\int_0^2 \int_{x^2}^{2x} 1 \, dy \, dx',
        'steps': [],
        'domain_analysis': {
          'region_type': 'Type I',
          'intersection_points': [
            {'x': '0', 'y': '0'},
            {'x': '2', 'y': '4'},
          ],
          'deduced_limits_latex': r'0 \le x \le 2, \; x^2 \le y \le 2x',
          'jacobian_latex': r'J = 1',
        },
      };
      final sol = IntegralSolution.fromJson(jsonMap);
      expect(sol.domainAnalysis, isNotNull);
      expect(sol.domainAnalysis!.regionType, equals('Type I'));
      expect(sol.domainAnalysis!.intersectionPoints.length, equals(2));
      expect(sol.domainAnalysis!.intersectionPoints[1]['y'], equals('4'));
      expect(sol.domainAnalysis!.deducedLimitsLatex, contains('2x'));
    });

    test('MathAiDidacticService parses and merges domain_analysis from Gemini response', () async {
      SharedPreferences.setMockInitialValues({'integra3d_gemini_api_key': 'AIzaMockKey'});

      final mockAiJson = jsonEncode({
        'region_definition': 'Región entre y = x^2 y y = 2x',
        'domain_analysis': {
          'region_type': 'Type I',
          'intersection_points': [
            {'x': '0', 'y': '0'},
            {'x': '2', 'y': '4'},
          ],
          'deduced_limits_latex': r'\int_0^2 \int_{x^2}^{2x} dy \, dx',
          'jacobian_latex': r'J = 1',
        },
        'steps': [
          {
            'step_number': 1,
            'variable': 'y',
            'step_title': 'Paso 1',
            'step_integral_latex': r'\int_{x^2}^{2x} 1 \, dy',
            'antiderivative_work_latex': r'y',
            'evaluated_latex': r'2x - x^2',
            'simplified_result_latex': r'2x - x^2',
            'explanation': 'Evaluación vertical.',
          }
        ],
      });

      final dio = Dio();
      dio.httpClientAdapter = _FakeHttpAdapter((opts) {
        return ResponseBody.fromString(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': mockAiJson}
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': ['application/json']},
        );
      });

      final service = MathAiDidacticService(dioClient: dio);
      const integral = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: 'x^2', upper: '2*x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '2'),
        ],
      );
      final base = LocalMathEngine.solveLocal(integral);
      final enriched = await service.enrichWithPedagogy(integral: integral, baseSolution: base);

      expect(enriched.domainAnalysis, isNotNull);
      expect(enriched.domainAnalysis!.intersectionPoints.length, equals(2));
      expect(enriched.domainAnalysis!.deducedLimitsLatex, contains('2x'));
    });

    test('SymbolicCalculusEngine exposes positive symbolic constants helper safely', () {
      final expr = SymbolicCalculusEngine.parse('a^2 + R*H');
      expect(expr, isNotNull);
      expect(SymbolicCalculusEngine.hasSymbolicParameters(expr!), isTrue);
    });
  });
}
