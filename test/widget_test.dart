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
}

void main() {
  testWidgets('Integra3D smoke test', (WidgetTester tester) async {
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
    expect(find.text('CALCULAR CON SYMPY'), findsOneWidget);
  });
}
