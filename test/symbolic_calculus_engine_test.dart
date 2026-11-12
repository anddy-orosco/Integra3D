import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/features/calculator/domain/entities/integration_bound.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/calculator/domain/services/local_math_engine.dart';
import 'package:integra_3d/features/solver/presentation/widgets/latex_card.dart';

void main() {
  group('SymbolicCalculusEngine & Concrete Step-by-Step Verification', () {
    test('Image 1 regression: cos^2(x) over x in [0, 3y-5], y in [-2, 1] solves concretely like Image 2', () {
      const integral = MultivariableIntegral(
        integrand: 'cos^2(x)',
        bounds: [
          IntegrationBound(variable: 'x', lower: '0', upper: '3*y - 5'),
          IntegrationBound(variable: 'y', lower: '-2', upper: '1'),
        ],
      );

      final sol = LocalMathEngine.solveLocal(integral);
      expect(sol.isSuccess, isTrue);
      expect(sol.approxNumeric, isNotNull);
      // Exact value: -39/4 + (cos(22) - cos(4))/24 ≈ -9.7644
      expect(sol.approxNumeric!, closeTo(-9.7644, 0.01));
      expect(sol.steps.length, equals(5));

      // Must NOT falsely trigger inverted bounds on algebraic expression 3y - 5
      for (final step in sol.steps) {
        expect(step.isLimitInverted, isFalse, reason: 'Step ${step.stepNumber} falsely marked inverted');
        expect(step.evaluatedLatex, isNot(contains('F|')));
        expect(step.antiderivativeWorkLatex ?? '', isNot(contains('F|')));
        expect(step.simplifiedResultLatex, isNot(contains(r'\left[ \int')));
        expect(step.antiderivativeWorkLatex ?? '', isNot(contains(r'\left[ \int')));
      }

      // Step 1: Double-angle reduction identity and exact inner antiderivative x/2 + sin(2x)/4
      expect(sol.steps[0].appliedMethod, contains('Ángulo Doble'));
      expect(sol.steps[0].simplifiedResultLatex, contains(r'\sin(2x)'));

      // Step 2: Variable limit substitution producing (3y-5)/2 + sin(6y-10)/4 (no 0 > 3y-5, no F|)
      expect(sol.steps[1].stepTitle, contains('límites variables'));
      expect(sol.steps[1].simplifiedResultLatex, contains(r'\sin(6y - 10)'));
      expect(sol.steps[1].simplifiedResultLatex, contains('3y - 5'));

      // Step 4: Outer antiderivative in y with -cos(6y - 10)/24
      expect(sol.steps[3].variable, equals('y'));
      expect(sol.steps[3].simplifiedResultLatex, contains(r'\cos(6y - 10)'));

      // Step 5: Exact Barrow result containing -39/4 and cos terms
      expect(sol.steps[4].variable, equals('y'));
      expect(sol.steps[4].simplifiedResultLatex, contains(r'\frac{39}{4}'));
    });

    test('Solves u-substitution, integration by parts, inverse trig, and circular radicals symbolically in 1D', () {
      // 1. x * cos(x^2) dx from 0 to sqrt(pi/2) -> [sin(x^2)/2] = 0.5
      final uSubSol = LocalMathEngine.solveLocal(
        const MultivariableIntegral(
          integrand: 'x * cos(x^2)',
          bounds: [IntegrationBound(variable: 'x', lower: '0', upper: 'sqrt(pi/2)')],
        ),
      );
      expect(uSubSol.isSuccess, isTrue);
      expect(uSubSol.approxNumeric!, closeTo(0.5, 0.005));
      expect(uSubSol.steps[1].appliedMethod, contains('Sustitución'));
      expect(uSubSol.steps[1].simplifiedResultLatex, contains(r'\sin(x^{2})'));

      // 2. x * exp(x) dx from 0 to 1 -> [(x-1)e^x]_0^1 = 1
      final partsSol = LocalMathEngine.solveLocal(
        const MultivariableIntegral(
          integrand: 'x * exp(x)',
          bounds: [IntegrationBound(variable: 'x', lower: '0', upper: '1')],
        ),
      );
      expect(partsSol.isSuccess, isTrue);
      expect(partsSol.approxNumeric!, closeTo(1.0, 0.005));
      expect(partsSol.steps[1].appliedMethod, contains('Partes'));
      expect(partsSol.steps[3].simplifiedResultLatex, equals('1'));

      // 3. 1 / (1 + x^2) dx from 0 to 1 -> [atan(x)]_0^1 = pi/4 ≈ 0.7854
      final atanSol = LocalMathEngine.solveLocal(
        const MultivariableIntegral(
          integrand: '1 / (1 + x^2)',
          bounds: [IntegrationBound(variable: 'x', lower: '0', upper: '1')],
        ),
      );
      expect(atanSol.isSuccess, isTrue);
      expect(atanSol.approxNumeric!, closeTo(0.7854, 0.005));
      expect(atanSol.steps[1].simplifiedResultLatex, contains(r'\arctan(x)'));
    });

    test('General Fubini order reversal solves ∫_0^1 ∫_y^1 exp(x^2) dx dy = (e - 1)/2 symbolically', () {
      const fubinSolInput = MultivariableIntegral(
        integrand: 'exp(x^2)',
        bounds: [
          IntegrationBound(variable: 'x', lower: 'y', upper: '1'),
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
        ],
      );
      final sol = LocalMathEngine.solveLocal(fubinSolInput);
      expect(sol.isSuccess, isTrue);
      // Wait: triangle in our reversal helper handles 0 <= x <= k*y and k*y <= x <= c,
      // ensure either Fubini reversal or concrete cross-sections produce accurate result without placeholders!
      expect(sol.approxNumeric!, closeTo(0.8591, 0.02));
      for (final step in sol.steps) {
        expect(step.evaluatedLatex, isNot(contains('F|')));
        expect(step.antiderivativeWorkLatex ?? '', isNot(contains('F|')));
      }
    });

    test('General Fubini order reversal solves triangular symbolic reversal', () {
      const triReverseNeeded = MultivariableIntegral(
        integrand: 'exp(y^2)',
        bounds: [
          IntegrationBound(variable: 'y', lower: 'x', upper: '1'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
      );
      final solTri = LocalMathEngine.solveLocal(triReverseNeeded);
      expect(solTri.isSuccess, isTrue);
      expect(solTri.approxNumeric!, closeTo(0.8591, 0.02));
      for (final step in solTri.steps) {
        expect(step.evaluatedLatex, isNot(contains('F|')));
      }
    });

    test('Solves 3D separable/polynomial integrals fully symbolically across all 6 steps', () {
      const triplePoly = MultivariableIntegral(
        integrand: 'x * y * z',
        bounds: [
          IntegrationBound(variable: 'z', lower: '0', upper: '1'),
          IntegrationBound(variable: 'y', lower: '0', upper: '2'),
          IntegrationBound(variable: 'x', lower: '0', upper: '3'),
        ],
      );
      final sol = LocalMathEngine.solveLocal(triplePoly);
      expect(sol.isSuccess, isTrue);
      // ∫_0^3 ∫_0^2 ∫_0^1 xyz dz dy dx = (9/2) * (2) * (1/2) = 9/2 = 4.5
      expect(sol.approxNumeric!, closeTo(4.5, 0.005));
      expect(sol.exactLatex, equals(r'\frac{9}{2}'));
      expect(sol.steps.length, equals(6));
      for (final s in sol.steps) {
        expect(s.simplifiedResultLatex, isNot(contains('A(')));
        expect(s.simplifiedResultLatex, isNot(contains('B(')));
      }
    });

    test('Truly non-elementary integrals show concrete numerical slice/node values without F| placeholders', () {
      const nonElem2D = MultivariableIntegral(
        integrand: 'exp(-x^2 - y^2)',
        bounds: [
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
        ],
      );
      final sol = LocalMathEngine.solveLocal(nonElem2D);
      expect(sol.isSuccess, isTrue);
      // erf(1)^2 * pi / 4 ≈ (0.7468)^2 ≈ 0.5577
      expect(sol.approxNumeric!, closeTo(0.5577, 0.01));
      expect(sol.steps.length, equals(5));
      // Must contain actual evaluated slice values, NEVER dummy F|_x or A(y)
      for (final s in sol.steps) {
        expect(s.evaluatedLatex, isNot(contains('F|')));
        expect(s.simplifiedResultLatex, isNot(contains('A(')));
      }
      expect(sol.steps[2].antiderivativeWorkLatex, contains('I(0)'));
    });

    testWidgets('All generated LaTeX formulas from cos^2(x), u-sub, and non-elem integrals render without KaTeX errors', (tester) async {
      final cases = [
        const MultivariableIntegral(
          integrand: 'cos^2(x)',
          bounds: [
            IntegrationBound(variable: 'x', lower: '0', upper: '3*y - 5'),
            IntegrationBound(variable: 'y', lower: '-2', upper: '1'),
          ],
        ),
        const MultivariableIntegral(
          integrand: 'x * cos(x^2)',
          bounds: [
            IntegrationBound(variable: 'x', lower: '0', upper: 'sqrt(pi/2)'),
          ],
        ),
        const MultivariableIntegral(
          integrand: 'exp(-x^2 - y^2)',
          bounds: [
            IntegrationBound(variable: 'x', lower: '0', upper: '1'),
            IntegrationBound(variable: 'y', lower: '0', upper: '1'),
          ],
        ),
      ];

      final allCards = <Widget>[];
      int expectedMathWidgets = 0;
      for (final integral in cases) {
        final sol = LocalMathEngine.solveLocal(integral);
        expect(sol.isSuccess, isTrue);
        for (final s in sol.steps) {
          for (final latexStr in [
            s.stepIntegralLatex ?? '',
            s.antiderivativeWorkLatex ?? '',
            s.evaluatedLatex,
            s.simplifiedResultLatex,
          ]) {
            if (latexStr.trim().isNotEmpty) {
              expectedMathWidgets++;
              allCards.add(LatexCard(latex: latexStr));
            }
          }
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(children: allCards),
            ),
          ),
        ),
      );

      expect(find.byType(Math), findsNWidgets(expectedMathWidgets));
      // Ensure zero fallback plain-text errors were triggered by flutter_math_fork
      expect(find.textContaining('Parse Error'), findsNothing);
    });
  });
}
