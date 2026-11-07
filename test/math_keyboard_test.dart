import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/core/theme/app_theme.dart';
import 'package:integra_3d/features/calculator/presentation/widgets/keyboard/math_keyboard.dart';

void main() {
  testWidgets('MathwayKeyboard renders 5-row layout and inserts symbols correctly',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: 'x');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkMatrixTheme,
        home: Scaffold(
          body: MathwayKeyboard(controller: controller),
        ),
      ),
    );

    // Verify key symbols from Mathway layout are present
    expect(find.text('('), findsOneWidget);
    expect(find.text(')'), findsOneWidget);
    expect(find.text('√'), findsOneWidget);
    expect(find.text('∫'), findsOneWidget);
    expect(find.text('abc'), findsOneWidget);
    expect(find.text('⌫'), findsOneWidget);

    // Tap on square root button '√'
    await tester.tap(find.text('√'));
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
