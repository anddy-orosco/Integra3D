import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/core/theme/app_theme.dart';
import 'package:integra_3d/features/calculator/domain/entities/integration_bound.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/calculator/domain/services/local_math_engine.dart';
import 'package:integra_3d/features/calculator/presentation/widgets/mat212_problem_builder.dart';
import 'package:integra_3d/features/visualization_2d/domain/entities/domain_2d_model.dart';
import 'package:integra_3d/features/visualization_2d/domain/services/domain_2d_extractor.dart';
import 'package:integra_3d/features/visualization_2d/presentation/widgets/native_2d_domain_viewport.dart';
import 'package:integra_3d/features/visualization_2d/presentation/widgets/uv_plane_viewport.dart';
import 'package:integra_3d/features/visualization_3d/presentation/widgets/dual_visualization_viewport.dart';
import 'package:integra_3d/features/visualization_3d/presentation/widgets/native_3d_viewport.dart';

void main() {
  group('Domain2DExtractor & Dual 2D / UV / 3D Visualization', () {
    test('Domain2DExtractor extracts parabolic/linear intersections and Type I/II formulas', () {
      const integral = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: 'x^2', upper: '2*x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '2'),
        ],
      );
      final model = Domain2DExtractor.extract(integral: integral);

      expect(model.preferredSweepOrder, equals(SweepOrderType.typeI));
      expect(model.intersectionPoints.length, greaterThanOrEqualTo(2));
      expect(model.shadedRegions, isNotEmpty);
      expect(model.typeIIntegralLatex, contains('dy'));
      expect(model.typeIIIntegralLatex, contains('dx'));
    });

    test('Domain2DExtractor generates UvMappingModel for polar and 4-curve UV integrals', () {
      const polarInt = MultivariableIntegral(
        integrand: 'r',
        bounds: [
          IntegrationBound(variable: 'r', lower: '0', upper: '2'),
          IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi'),
        ],
        coordinateSystem: CoordinateSystemType.polar,
      );
      final polarModel = Domain2DExtractor.extract(integral: polarInt);
      expect(polarModel.uvMapping, isNotNull);
      expect(polarModel.uvMapping!.uVarLabel, equals('r'));
      expect(polarModel.uvMapping!.vVarLabel, anyOf(contains('θ'), contains(r'\theta')));

      const uvInt = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
        problemMode: ProblemMode.regionCurves,
        boundaryCurves: ['x*y = 1', 'x*y = 3', 'y = x', 'y = 3*x'],
      );
      final uvModel = Domain2DExtractor.extract(integral: uvInt);
      expect(uvModel.uvMapping, isNotNull);
    });

    testWidgets('DualVisualizationViewport switches between 2D, UV, and 3D views', (tester) async {
      const integral = MultivariableIntegral(
        integrand: '4 - x^2 - y^2',
        bounds: [
          IntegrationBound(variable: 'r', lower: '0', upper: '2'),
          IntegrationBound(variable: 'theta', lower: '0', upper: '2*pi'),
        ],
        coordinateSystem: CoordinateSystemType.polar,
      );
      final mesh = LocalMathEngine.generateLocalMesh(integral, resolution: 10);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkMatrixTheme,
          home: Scaffold(
            body: SizedBox(
              width: 520,
              height: 620,
              child: DualVisualizationViewport(
                integral: integral,
                meshData: mesh,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default mode: 2D Domain
      expect(find.byType(Native2DDomainViewport), findsOneWidget);
      expect(find.text('Orden de Barrido:'), findsOneWidget);

      // Switch Orden de Barrido to Tipo II
      await tester.tap(find.text('Tipo II (dx dy)'));
      await tester.pumpAndSettle();
      expect(find.byType(Math), findsWidgets);

      // Switch to UV Plane
      await tester.tap(find.textContaining('Plano UV'));
      await tester.pumpAndSettle();
      expect(find.byType(UvPlaneViewport), findsOneWidget);

      // Switch to 3D Solid V
      await tester.tap(find.text('3D: Sólido V'));
      await tester.pumpAndSettle();
      expect(find.byType(Native3DViewport), findsOneWidget);
    });

    testWidgets('Native3DViewport renders dual surfaces and z=0 projection HUD controls', (tester) async {
      const volInt = MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'y', lower: '-sqrt(4 - x^2)', upper: 'sqrt(4 - x^2)'),
          IntegrationBound(variable: 'x', lower: '-2', upper: '2'),
        ],
        problemMode: ProblemMode.volumeBetweenSurfaces,
        zLowerExpr: 'x^2 + y^2',
        zUpperExpr: '8 - x^2 - y^2',
      );
      final mesh = LocalMathEngine.generateLocalMesh(volInt, resolution: 8);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkMatrixTheme,
          home: Scaffold(
            body: SizedBox(
              width: 480,
              height: 500,
              child: Native3DViewport(
                integral: volInt,
                meshData: mesh,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.layers_rounded), findsOneWidget);
      expect(find.byIcon(Icons.grid_on_rounded), findsOneWidget);
    });

    testWidgets('Mat212ProblemBuilder switches modes and submits Region & Application problems', (tester) async {
      MultivariableIntegral? solved;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkMatrixTheme,
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 800,
              child: Mat212ProblemBuilder(
                initialIntegral: const MultivariableIntegral(
                  integrand: 'x * y',
                  bounds: [
                    IntegrationBound(variable: 'y', lower: '0', upper: '1'),
                    IntegrationBound(variable: 'x', lower: '0', upper: '1'),
                  ],
                ),
                onSolve: (val) => solved = val,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modo Práctica MAT 212 (UPEA)'), findsOneWidget);
      expect(find.text('Iterada Directa'), findsOneWidget);
      expect(find.text('Región / Vértices'), findsOneWidget);
      expect(find.text('Aplicaciones'), findsOneWidget);

      // Switch to Región / Vértices mode and tap solve button
      await tester.tap(find.text('Región / Vértices'));
      await tester.pumpAndSettle();

      final solveRegionBtn = find.textContaining('Deducir Límites');
      expect(solveRegionBtn, findsOneWidget);
      await tester.ensureVisible(solveRegionBtn);
      await tester.tap(solveRegionBtn);
      await tester.pumpAndSettle();

      expect(solved, isNotNull);
      expect(solved!.problemMode, equals(ProblemMode.regionCurves));

      // Switch to Aplicaciones mode
      solved = null;
      await tester.tap(find.text('Aplicaciones'));
      await tester.pumpAndSettle();

      final solveAppBtn = find.textContaining('Calcular Aplicación');
      expect(solveAppBtn, findsOneWidget);
      await tester.ensureVisible(solveAppBtn);
      await tester.tap(solveAppBtn);
      await tester.pumpAndSettle();

      expect(solved, isNotNull);
      expect(
        [
          ProblemMode.planarArea,
          ProblemMode.surfaceArea,
          ProblemMode.volumeBetweenSurfaces,
          ProblemMode.massAndCenterOfMass,
        ].contains(solved!.problemMode),
        isTrue,
      );
    });
  });
}
