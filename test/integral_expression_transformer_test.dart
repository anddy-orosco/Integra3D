import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/features/calculator/domain/entities/integration_bound.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/calculator/domain/services/integral_expression_transformer.dart';
import 'package:integra_3d/features/calculator/domain/services/local_math_engine.dart';

void main() {
  group('IntegralExpressionTransformer Tests', () {
    test('normalizes expressions with implicit multiplication and powers', () {
      expect(IntegralExpressionTransformer.normalizeExpression('3y - 5'), '3*y - 5');
      expect(IntegralExpressionTransformer.normalizeExpression('xy^2'), 'x*y^2');
      expect(IntegralExpressionTransformer.normalizeExpression('x y^2'), 'x*y^2');
      expect(IntegralExpressionTransformer.normalizeExpression('2x + 4y'), '2*x + 4*y');
    });

    test('replaces unicode operators cleanly', () {
      expect(IntegralExpressionTransformer.normalizeExpression('x × y'), 'x*y');
      expect(IntegralExpressionTransformer.normalizeExpression('x ÷ y'), 'x / y');
      expect(IntegralExpressionTransformer.normalizeExpression('3 − 2'), '3 - 2');
      expect(IntegralExpressionTransformer.normalizeExpression('y²'), 'y^2');
    });

    test('parses full LaTeX double integral string accurately', () {
      const latex = r'\int_{-2}^{1} \int_{0}^{3y-5} x y^2 \, dx \, dy';
      final parsed = IntegralExpressionTransformer.parseFullIntegral(latex);

      expect(parsed, isNotNull);
      expect(parsed!.integrand, 'x*y^2');
      expect(parsed.bounds.length, 2);
      expect(parsed.bounds[0].variable, 'x');
      expect(parsed.bounds[0].lower, '0');
      expect(parsed.bounds[0].upper, '3*y - 5');
      expect(parsed.bounds[1].variable, 'y');
      expect(parsed.bounds[1].lower, '-2');
      expect(parsed.bounds[1].upper, '1');
    });

    test('toDisplayLatex transforms complex user expressions into clean math LaTeX', () {
      final input = 'xln(x)*exp(-(x^2 + y^2))sqrt(4 - x^2)';
      final display = IntegralExpressionTransformer.toDisplayLatex(input);

      expect(display, contains(r'\ln(x)'));
      expect(display, contains(r'e^{-(x^{2} + y^{2})}'));
      expect(display, contains(r'\sqrt{4 - x^{2}}'));
      expect(display, isNot(contains('*')));
    });

    test('toDisplayLatex transforms user uploaded integral without exp or asterisks', () {
      final input = '1 * e^y exp(x) * sin(tan(y))^2';
      final display = IntegralExpressionTransformer.toDisplayLatex(input);

      expect(display, isNot(contains('exp')));
      expect(display, isNot(contains('*')));
      expect(display, contains('e^{y}'));
      expect(display, contains('e^{x}'));
      expect(display, contains(r'\sin^{2}(\tan(y))'));
    });

    test('formatMathInline prepares math typography with unicode glyphs for interactive cursor', () {
      final input = 'xln(x)*exp(-(x^2 + y^2))sqrt(4 - x^2)';
      final inline = IntegralExpressionTransformer.formatMathInline(input);

      expect(inline, contains('√(4 - x²)'));
      expect(inline, contains('e^(-(x² + y²))'));
      expect(inline, isNot(contains('*')));
      expect(inline, isNot(contains('sqrt')));
      expect(inline, isNot(contains('exp')));
    });
  });

  group('LocalMathEngine Image 3 Rigorous Verification', () {
    test('solves Image 3 integral exactly: 2469/20 = 123.45', () {
      const integral = MultivariableIntegral(
        integrand: 'x * y^2',
        bounds: [
          IntegrationBound(variable: 'x', lower: '0', upper: '3*y - 5'),
          IntegrationBound(variable: 'y', lower: '-2', upper: '1'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      );

      final solution = LocalMathEngine.solveLocal(integral);

      expect(solution.isSuccess, isTrue);
      expect(solution.exactLatex, r'\frac{2469}{20}');
      expect(solution.approxNumeric, 123.45);
      expect(solution.steps.length, 2);
      expect(solution.steps[0].variable, 'x');
      expect(solution.steps[1].variable, 'y');
    });

    test('solves user custom 3D integral accurately instead of returning default 1/6', () {
      const integral = MultivariableIntegral(
        integrand: '1 * e^y exp(x) * sin(tan(y))^2',
        bounds: [
          IntegrationBound(variable: 'z', lower: '0', upper: '1 - x - y'),
          IntegrationBound(variable: 'y', lower: '0', upper: '1 - x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      );

      final solution = LocalMathEngine.solveLocal(integral);

      expect(solution.isSuccess, isTrue);
      // Value must be approximately 0.0358, NOT the hardcoded 0.1667 (1/6)
      expect(solution.approxNumeric, isNotNull);
      expect(solution.approxNumeric!, closeTo(0.0358, 0.005));
      expect(solution.approxNumeric!, isNot(closeTo(0.1667, 0.01)));

      // Step-by-step resolution must have 3 steps for z, y, x
      expect(solution.steps.length, 3);
      expect(solution.steps[0].variable, 'z');
      expect(solution.steps[1].variable, 'y');
      expect(solution.steps[2].variable, 'x');

      // Original integral LaTeX must not contain raw programming tokens
      expect(solution.originalIntegralLatex, isNot(contains('exp')));
      expect(solution.originalIntegralLatex, isNot(contains('*')));
      expect(solution.originalIntegralLatex, contains('e^{y}'));
    });

    test('detects singular or divergent integrals and provides didactic diagnosis', () {
      const divergentIntegral = MultivariableIntegral(
        integrand: '1 / x',
        bounds: [
          IntegrationBound(variable: 'x', lower: '-1', upper: '1'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      );

      final solution = LocalMathEngine.solveLocal(divergentIntegral);

      expect(solution.isSuccess, isFalse);
      expect(solution.errorMessage, contains('diverge'));
    });

    test('correctly evaluates 1D integral with inverted limits applying inversion property (∫_9^4 x dx = -32.5)', () {
      const inverted1D = MultivariableIntegral(
        integrand: 'x',
        bounds: [
          IntegrationBound(variable: 'x', lower: '9', upper: '4'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      );

      final solution = LocalMathEngine.solveLocal(inverted1D);

      expect(solution.isSuccess, isTrue);
      expect(solution.approxNumeric, isNotNull);
      // ∫_9^4 x dx = [x^2/2]_9^4 = (16 - 81)/2 = -32.5
      expect(solution.approxNumeric!, closeTo(-32.5, 0.01));
      expect(solution.steps.first.isLimitInverted, isTrue);
      expect(solution.steps.first.appliedMethod, contains('Inversión'));
      expect(solution.steps.first.evaluatedLatex, contains('-(F(9) - F(4))'));
    });

    test('correctly evaluates 1D integral with identical limits to zero (∫_5^5 x^2 dx = 0.0)', () {
      const zero1D = MultivariableIntegral(
        integrand: 'x^2',
        bounds: [
          IntegrationBound(variable: 'x', lower: '5', upper: '5'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      );

      final solution = LocalMathEngine.solveLocal(zero1D);

      expect(solution.isSuccess, isTrue);
      expect(solution.approxNumeric, 0.0);
      expect(solution.steps.first.appliedMethod, contains('Idénticos'));
    });

    test('correctly solves intermediate inverted limits in 3D (user screenshot case: mid from 9 to 4)', () {
      // Triple integral with middle bound inverted from 9 to 4:
      // ∫_0^1 dx ∫_9^4 dy ∫_0^2 1 dz = 1 * (4 - 9) * 2 = -10.0
      // Previously, 'mMax <= mMin continue;' caused this to return 0.0000!
      const userCase3D = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'z', lower: '0', upper: '2'),
          IntegrationBound(variable: 'y', lower: '9', upper: '4'), // Inverted intermediate bound!
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      );

      final solution = LocalMathEngine.solveLocal(userCase3D);

      expect(solution.isSuccess, isTrue);
      expect(solution.approxNumeric, isNotNull);
      expect(solution.approxNumeric!, closeTo(-10.0, 0.05));
      expect(solution.approxNumeric!, isNot(0.0)); // Must NOT be 0.0000!

      // Step 2 (middle variable y) must have isLimitInverted = true
      expect(solution.steps[1].variable, 'y');
      expect(solution.steps[1].isLimitInverted, isTrue);
      expect(solution.steps[1].appliedMethod, contains('Inversión'));
    });

    test('correctly solves 2D double integral with inverted outer and inner bounds', () {
      // ∫_2^0 dx ∫_9^4 1 dy = (-2) * (-5) = +10.0
      const doubleInverted2D = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: '9', upper: '4'),
          IntegrationBound(variable: 'x', lower: '2', upper: '0'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      );

      final solution = LocalMathEngine.solveLocal(doubleInverted2D);

      expect(solution.isSuccess, isTrue);
      expect(solution.approxNumeric, isNotNull);
      expect(solution.approxNumeric!, closeTo(10.0, 0.05));
      expect(solution.steps[0].isLimitInverted, isTrue);
      expect(solution.steps[1].isLimitInverted, isTrue);
    });
  });
}
