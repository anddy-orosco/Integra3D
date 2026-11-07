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
  });
}
