import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/features/dashboard/presentation/widgets/calculus_formulary_tab.dart';

void main() {
  testWidgets('CalculusFormularyTab displays categories and filters items', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CalculusFormularyTab(),
        ),
      ),
    );

    // Initial render: search bar and chips are present
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Integrales Dobles'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Coordenadas & Jacobiano'), findsOneWidget);
    expect(find.text('Teorema de Fubini para Integrales Dobles'), findsOneWidget);

    // Filter by searching 'Fubini'
    await tester.enterText(find.byType(TextField), 'Fubini');
    await tester.pumpAndSettle();

    expect(find.text('Teorema de Fubini para Integrales Dobles'), findsOneWidget);

    // Filter by category chip 'Integrales Triples'
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Integrales Triples'));
    await tester.pumpAndSettle();

    expect(find.text('Integrales Triples en Coordenadas Cartesianas'), findsOneWidget);
  });
}
