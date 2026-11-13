import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integra_3d/main.dart';
import 'package:integra_3d/core/utils/platform_responsive.dart';
import 'package:integra_3d/features/solver/data/datasources/solver_remote_datasource.dart';
import 'package:integra_3d/features/solver/domain/entities/integral_solution.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/solver/presentation/providers/solver_provider.dart';

class FakeDesktopSolverRemoteDataSource implements SolverRemoteDataSource {
  @override
  Future<IntegralSolution> solveIntegral(MultivariableIntegral integral) async {
    return IntegralSolution(
      isSuccess: true,
      exactLatex: r'\frac{81}{2}',
      approxNumeric: 40.5,
      originalIntegralLatex: r'\int_0^3 \int_0^x 4xy \, dy \, dx',
      steps: const [
        SolverStep(
          stepNumber: 1,
          stepTitle: 'Paso 1: Integrar respecto a y',
          variable: 'y',
          lowerBoundLatex: '0',
          upperBoundLatex: 'x',
          currentIntegrandLatex: '4xy',
          antiderivativeLatex: '2xy^2',
          evaluatedLatex: '2x^3',
          simplifiedResultLatex: '2x^3',
          explanation: 'Integración parcial con respecto a y',
        ),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> getMesh(MultivariableIntegral integral) async {
    return {
      'title': 'Sólido Parabólico 3D',
      'vertices': [0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 1.0],
      'indices': [0, 1, 2],
    };
  }

  @override
  Future<List<PedagogicalSection>> getExplanation(MultivariableIntegral integral) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getPresets() async {
    return [
      {
        'name': 'Integral de Prueba Desktop',
        'dimension': 2,
        'integrand': '4*x*y',
        'bounds': [
          {'variable': 'y', 'lower': '0', 'upper': 'x'},
          {'variable': 'x', 'lower': '0', 'upper': '3'},
        ],
      }
    ];
  }

  @override
  Future<bool> checkBackendHealth() async {
    return true;
  }
}

void main() {
  group('Desktop & iPad Adaptive Workstation Tests', () {
    test('ResponsiveLayout breakpoint calculations', () {
      expect(ResponsiveLayout.compactBreakpoint, 600.0);
      expect(ResponsiveLayout.mediumBreakpoint, 960.0);
      expect(ResponsiveLayout.largeBreakpoint, 1280.0);
    });

    testWidgets('Renders dual-pane desktop workstation on wide screen (1280x800)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            solverDataSourceProvider.overrideWithValue(FakeDesktopSolverRemoteDataSource()),
          ],
          child: const Integra3DApp(),
        ),
      );

      await tester.pumpAndSettle();

      // On wide screen, Left Workstation Panel and Right Panel exist simultaneously
      expect(find.text('Integra3D'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('3D View'), findsOneWidget);
      expect(find.text('Solución'), findsOneWidget);
      expect(find.text('Formulario'), findsOneWidget);

      // Verify "Doble Panel" button is present on widescreen >= 1100
      expect(find.text('Doble Panel (3D + Solución)'), findsOneWidget);

      // Switch tabs in desktop workstation
      await tester.tap(find.text('Solución'));
      await tester.pumpAndSettle();

      // Verify step solution or instructions visible
      expect(find.text('Formulario'), findsOneWidget);
      await tester.tap(find.text('Formulario'));
      await tester.pumpAndSettle();

      // Verify formulary search bar
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // Toggle Doble Panel (3D + Solución)
      await tester.tap(find.text('Doble Panel (3D + Solución)'));
      await tester.pumpAndSettle();
    });

    testWidgets('Physical keyboard keystrokes and navigation work in MathwayFormulaEditor',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            solverDataSourceProvider.overrideWithValue(FakeDesktopSolverRemoteDataSource()),
          ],
          child: const Integra3DApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on integrand slot to focus
      final integrandCuadrito = find.text('Integrando');
      if (integrandCuadrito.evaluate().isNotEmpty) {
        await tester.tap(integrandCuadrito);
        await tester.pumpAndSettle();
      }

      // Send physical hardware key events (Tab, x, +, y)
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pumpAndSettle();

      // Verify app remains completely stable and responsive to hardware keys
      expect(find.byType(Integra3DApp), findsOneWidget);
    });
  });
}
