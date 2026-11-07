import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/core/theme/app_theme.dart';
import 'package:integra_3d/features/calculator/domain/entities/integration_bound.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/calculator/presentation/widgets/mathway_formula_editor.dart';

void main() {
  testWidgets('MathwayFormulaEditor renders interactive cuadritos, allows differential swap and solves',
      (WidgetTester tester) async {
    MultivariableIntegral? solvedIntegral;

    final initialIntegral = MultivariableIntegral(
      integrand: 'x * y^2',
      bounds: const [
        IntegrationBound(variable: 'y', lower: '0', upper: '3*y - 5'),
        IntegrationBound(variable: 'x', lower: '-2', upper: '1'),
      ],
      coordinateSystem: CoordinateSystemType.cartesian,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkMatrixTheme,
        home: Scaffold(
          body: MathwayFormulaEditor(
            initialIntegral: initialIntegral,
            onSolve: (integral) {
              solvedIntegral = integral;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dimension pills
    expect(find.text('∬ Doble (2D)'), findsOneWidget);
    expect(find.text('∭ Triple (3D)'), findsOneWidget);
    expect(find.text('∫ Simple (1D)'), findsOneWidget);

    // Verify differential box is present with swap icon
    expect(find.text('dy dx'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);

    // Tap differential box to swap differential order to 'dx dy'
    await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('dx dy'), findsOneWidget);

    // Switch keyboard page to Multivariable & Dif
    expect(find.text('∬ Multivariable & Dif'), findsOneWidget);
    await tester.tap(find.text('∬ Multivariable & Dif'));
    await tester.pumpAndSettle();

    // Verify specialized multivariable keys are present
    expect(find.text('r dr dθ'), findsOneWidget);
    expect(find.text('x²+y²'), findsOneWidget);

    // Switch back to 123 Algebra
    await tester.tap(find.text('123 Álgebra'));
    await tester.pumpAndSettle();

    // Tap solve button (send icon)
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(solvedIntegral, isNotNull);
    expect(solvedIntegral!.integrand, contains('x'));
  });

  testWidgets('MathwayFormulaEditor detects active argument and allows one-tap exit',
      (WidgetTester tester) async {
    final initialIntegral = MultivariableIntegral(
      integrand: 'sqrt(4 - x^2)',
      bounds: const [
        IntegrationBound(variable: 'y', lower: '0', upper: '1'),
        IntegrationBound(variable: 'x', lower: '0', upper: '1'),
      ],
      coordinateSystem: CoordinateSystemType.cartesian,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkMatrixTheme,
        home: Scaffold(
          body: MathwayFormulaEditor(
            initialIntegral: initialIntegral,
            onSolve: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The integrand controller text is 'sqrt(4 - x^2)', by default cursor is at 0 or end.
    // Let's tap '◀' to move cursor inside the parenthesis:
    await tester.tap(find.text('◀'));
    await tester.pumpAndSettle();

    // The argument helper badge should be visible!
    expect(find.text('📍 En argumento: √( ... )'), findsOneWidget);
    expect(find.text('➔ Salir de función'), findsOneWidget);

    // Tap exit button
    await tester.tap(find.text('➔ Salir de función'));
    await tester.pumpAndSettle();

    // After exiting the function, the badge is gone
    expect(find.text('➔ Salir de función'), findsNothing);
  });
}
