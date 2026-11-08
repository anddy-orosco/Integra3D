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
  });
}
