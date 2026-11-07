import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/features/calculator/domain/services/math_expression_evaluator.dart';

void main() {
  group('MathExpressionEvaluator Tests', () {
    test('evaluates polynomials and powers correctly', () {
      expect(MathExpressionEvaluator.evaluate('x * y^2', x: 2, y: 3), 18.0);
      expect(MathExpressionEvaluator.evaluate('3*y - 5', y: 4), 7.0);
      expect(MathExpressionEvaluator.evaluate('4 - x^2 - y^2', x: 1, y: 1), 2.0);
    });

    test('evaluates functions and unary operators', () {
      expect(MathExpressionEvaluator.evaluate('sqrt(16)'), 4.0);
      expect(MathExpressionEvaluator.evaluate('sqrt(4 - x^2)', x: 0), 2.0);
      expect(MathExpressionEvaluator.evaluate('-x + 5', x: 2), 3.0);
    });
  });
}
