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

  testWidgets('MathwayKeyboard Page 1 and Page 2 display proper mathematical symbols',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: 'xy');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkMatrixTheme,
        home: Scaffold(
          body: MathwayKeyboard(controller: controller),
        ),
      ),
    );

    // Switch to Page 1: Multivariable
    await tester.tap(find.text('∬ Multivariable & Dif'));
    await tester.pumpAndSettle();

    // Verify mathematical labels are displayed, not programming text
    expect(find.text('√x'), findsOneWidget);
    expect(find.text('x²'), findsOneWidget);
    expect(find.text('e^{-(x²+y²)}'), findsOneWidget);

    // Switch to Page 2: Trigo
    await tester.tap(find.text('sin Trigo'));
    await tester.pumpAndSettle();

    expect(find.text('sin⁻¹'), findsOneWidget);
    expect(find.text('cos⁻¹'), findsOneWidget);
    expect(find.text('|x|'), findsOneWidget);
  });

  testWidgets('MathwayKeyboard arrows move cursor character by character without exiting slot',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: '4 - x^2');
    controller.selection = const TextSelection.collapsed(offset: 7); // end

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkMatrixTheme,
        home: Scaffold(
          body: MathwayKeyboard(controller: controller),
        ),
      ),
    );

    // Tap Left arrow 3 times
    await tester.tap(find.text('◀'));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 6);

    await tester.tap(find.text('◀'));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 5);

    // Tap Right arrow
    await tester.tap(find.text('▶'));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 6);
  });
}
