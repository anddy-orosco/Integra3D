import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integra_3d/main.dart';
import 'package:integra_3d/features/solver/data/datasources/solver_remote_datasource.dart';
import 'package:integra_3d/features/solver/domain/entities/integral_solution.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/solver/presentation/providers/solver_provider.dart';

class FakeSolverRemoteDataSource implements SolverRemoteDataSource {
  @override
  Future<IntegralSolution> solveIntegral(MultivariableIntegral integral) async {
    return const IntegralSolution(
      isSuccess: true,
      exactLatex: '8\\pi',
      approxNumeric: 25.1327,
    );
  }

  @override
  Future<Map<String, dynamic>> getMesh(MultivariableIntegral integral) async {
    return {};
  }

  @override
  Future<List<PedagogicalSection>> getExplanation(MultivariableIntegral integral) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getPresets() async {
    return [];
  }

  @override
  Future<bool> checkBackendHealth() async {
    return false;
  }
}

void main() {
  testWidgets('Integra3D smoke test', (WidgetTester tester) async {
    // Provide a larger surface size for testing widget layout
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          solverDataSourceProvider.overrideWithValue(FakeSolverRemoteDataSource()),
        ],
        child: const Integra3DApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Integra3D'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Solución'), findsOneWidget);
    expect(find.text('Formulario'), findsOneWidget);
    expect(find.text('3D View'), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}
