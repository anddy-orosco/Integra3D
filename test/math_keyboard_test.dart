import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/core/theme/app_theme.dart';
import 'package:integra_3d/features/calculator/presentation/widgets/keyboard/math_keyboard.dart';

void main() {
  testWidgets('MathKeyboard inserts symbols and handles cursor correctly',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: 'x');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkMatrixTheme,
        home: Scaffold(
          body: MathKeyboard(controller: controller),
        ),
      ),
    );

    // Verify key categories are present
    expect(find.text('Álgebra'), findsOneWidget);
    expect(find.text('Integrales'), findsOneWidget);
    expect(find.text('Funciones'), findsOneWidget);

    // Tap on square root button '√x'
    await tester.tap(find.text('√x'));
    await tester.pumpAndSettle();

    // Controller should now contain 'xsqrt()' with cursor inside the parenthesis
    expect(controller.text, 'xsqrt()');
    expect(controller.selection.baseOffset, 6); // Position inside parentheses

    // Tap backspace (deletes '(' before cursor position 6)
    await tester.tap(find.text('⌫'));
    await tester.pumpAndSettle();
    expect(controller.text, 'xsqrt)');
  });
}
