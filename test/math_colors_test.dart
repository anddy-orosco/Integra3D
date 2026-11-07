import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/core/theme/app_theme.dart';
import 'package:integra_3d/core/theme/math_colors.dart';
import 'package:integra_3d/features/solver/presentation/widgets/math_step_demo_card.dart';

void main() {
  testWidgets('MathStepDemoCard renders canonical 3D axes and LaTeX formula',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkMatrixTheme,
        home: const Scaffold(
          body: MathStepDemoCard(
            stepNumber: 1,
            title: 'Paso de Prueba Multivariable',
            integrationVariable: 'z',
          ),
        ),
      ),
    );

    expect(find.text('Paso de Prueba Multivariable'), findsOneWidget);
    expect(find.text('dz'), findsOneWidget);
    expect(find.text('Eje X (î)'), findsOneWidget);
    expect(find.text('Eje Y (ĵ)'), findsOneWidget);
    expect(find.text('Eje Z (k̂)'), findsOneWidget);
  });
}
