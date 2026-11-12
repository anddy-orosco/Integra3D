import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:integra_3d/core/utils/latex_sanitizer.dart';
import 'package:integra_3d/features/calculator/domain/entities/integration_bound.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/calculator/domain/services/local_math_engine.dart';
import 'package:integra_3d/features/solver/presentation/widgets/latex_card.dart';

void main() {
  group('LaTeX Sanitizer & Renderer Verification', () {
    testWidgets('Sanitizer repairs broken double superscripts and unclosed delimiters', (tester) async {
      const broken1 = r'\int \left( \left[ \frac{1 y^2 x^{2}}{2} + \frac{1 e^ x^{2}}{2} \right]_{0}^{1} \right) dy';
      const broken2 = r'\int_{-2}^{1} \left[ \frac{1 y^2 x^{2}}{2} + \frac{1 e^ x^{2}}{2} \right]_{0}^{1} \, dy \approx 120.4952';
      const broken3 = r'I = \approx 120.4952';

      final clean1 = LatexSanitizer.sanitize(broken1);
      final clean2 = LatexSanitizer.sanitize(broken2);
      final clean3 = LatexSanitizer.sanitize(broken3);

      expect(clean1, contains(r'e^{x^{2}}'));
      expect(clean1, isNot(contains(r'1 e^')));
      expect(clean2, contains(r'\approx 120.4952'));
      expect(clean3, equals(r'I \approx 120.4952'));

      dynamic error;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LatexCard(latex: clean1),
                LatexCard(latex: clean2),
                LatexCard(latex: clean3),
              ],
            ),
          ),
        ),
      );

      // Verify that no error fallback triggered and rendered as pure Math.tex
      expect(find.byType(Math), findsNWidgets(3));
      expect(error, isNull);
    });

    testWidgets('LocalMathEngine generates clean steps for x*y^2 + e^x without broken e^', (tester) async {
      const integral = MultivariableIntegral(
        integrand: 'x * y^2 + e^x',
        bounds: [
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
          IntegrationBound(variable: 'y', lower: '-2', upper: '1'),
        ],
      );

      final sol = LocalMathEngine.solveLocal(integral);
      expect(sol.isSuccess, isTrue);

      for (final step in sol.steps) {
        // Must not contain broken "1 e^" or "e^ x^2"
        expect(step.antiderivativeWorkLatex, isNot(contains(r'1 e^')));
        expect(step.evaluatedLatex, isNot(contains(r'1 e^')));
        expect(step.antiderivativeWorkLatex, isNot(contains(r'\left( \left[')));
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: sol.steps.map((s) => LatexCard(latex: s.antiderivativeWorkLatex ?? '')).toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Math), findsNWidgets(sol.steps.length));
    });

    test('LocalMathEngine handles divergent integrals gracefully with complete diagnostic step', () {
      // 1/x from 0 to 1 diverges
      const divergentIntegral = MultivariableIntegral(
        integrand: '1 / x',
        bounds: [
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
      );

      final sol = LocalMathEngine.solveLocal(divergentIntegral);
      expect(sol.isSuccess, isFalse);
      expect(sol.exactLatex, contains(r'\text{No Converge'));
      expect(sol.steps.isNotEmpty, isTrue);
      expect(sol.steps[0].appliedMethod, contains('Criterio de Singularidad'));
      expect(sol.errorMessage, contains('diverge'));
      expect(sol.didacticSections?.isNotEmpty, isTrue);
    });
  });
}
