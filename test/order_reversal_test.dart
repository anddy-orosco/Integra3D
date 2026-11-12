import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/features/calculator/domain/entities/integration_bound.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/calculator/domain/services/local_math_engine.dart';

void main() {
  test('Order reversal for y * cos(x^3) with x in [y/2, 1] and y in [0, 2]', () {
    const integral = MultivariableIntegral(
      integrand: 'y * cos(x^3)',
      bounds: [
        IntegrationBound(variable: 'x', lower: 'y/2', upper: '1'),
        IntegrationBound(variable: 'y', lower: '0', upper: '2'),
      ],
      coordinateSystem: CoordinateSystemType.cartesian,
    );

    final sol = LocalMathEngine.solveLocal(integral);
    expect(sol.isSuccess, isTrue);
    expect(sol.exactLatex, contains(r'\sin(1)'));
    expect(sol.approxNumeric, closeTo(0.56098, 0.001));

    // Steps must be at least 5 and describe order reversal and u-substitution
    expect(sol.steps.length, greaterThanOrEqualTo(5));
    expect(sol.steps[0].stepTitle!.toLowerCase(), contains('orden de integración'));
    expect(sol.steps[0].explanation.toLowerCase(), contains('fijando primero'));
    expect(sol.steps[1].stepTitle!.toLowerCase(), contains('integral interna'));
    expect(sol.steps[2].stepTitle!.toLowerCase(), contains('externa'));
    expect(sol.steps[2].explanation.toLowerCase(), contains('sustitución'));
    expect(sol.steps[3].stepTitle!.toLowerCase(), contains('antiderivada'));
    expect(sol.steps[4].stepTitle!.toLowerCase(), contains('resultado final'));

    // Check no tautology
    for (final s in sol.steps) {
      expect(s.antiderivativeWorkLatex, isNot(contains(r'\int (y \cos(x^3)) dx = \int (y \cos(x^3)) dx')));
    }
  });

  test('Order reversal with LaTeX backslashes: y \\cos(x^3) with \\frac{y}{2}', () {
    const integral = MultivariableIntegral(
      integrand: r'y \cos(x^3)',
      bounds: [
        IntegrationBound(variable: 'x', lower: r'\frac{y}{2}', upper: '1'),
        IntegrationBound(variable: 'y', lower: '0', upper: '2'),
      ],
      coordinateSystem: CoordinateSystemType.cartesian,
    );

    final sol = LocalMathEngine.solveLocal(integral);
    expect(sol.isSuccess, isTrue);
    expect(sol.exactLatex, contains(r'\sin(1)'));
    expect(sol.approxNumeric, closeTo(0.56098, 0.001));
    expect(sol.steps.length, greaterThanOrEqualTo(5));
    expect(sol.formulasAndMethods, isNotNull);
    expect(sol.formulasAndMethods!.length, greaterThanOrEqualTo(3));
  });

  test('Circular radical solver handles \\sqrt{4-x^2} LaTeX format and circular disk', () {
    const integral = MultivariableIntegral(
      integrand: '4 - x^2 - y^4',
      bounds: [
        IntegrationBound(variable: 'y', lower: r'-\sqrt{4-x^2}', upper: r'\sqrt{4-x^2}'),
        IntegrationBound(variable: 'x', lower: '-2', upper: '2'),
      ],
      coordinateSystem: CoordinateSystemType.cartesian,
    );

    final sol = LocalMathEngine.solveLocal(integral);
    expect(sol.isSuccess, isTrue);
    expect(sol.exactLatex, contains(r'\pi'));
    expect(sol.steps.length, greaterThanOrEqualTo(5));
    // Verify no A(x) dummy placeholders in steps
    for (final s in sol.steps) {
      expect(s.antiderivativeLatex, isNot(contains('A(')));
      expect(s.evaluatedLatex, isNot(contains('A(')));
      expect(s.simplifiedResultLatex, isNot(contains('A(')));
    }
  });
}
