import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/latex_sanitizer.dart';
import '../../domain/entities/integration_bound.dart';
import '../../domain/entities/multivariable_integral.dart';
import '../../domain/services/integral_expression_transformer.dart';
import '../../domain/services/region_geometry_solver.dart';
import 'mathway_formula_editor.dart';

enum Mat212EntryMode {
  directIterated,
  regionBuilder,
  applications,
}

enum Mat212ApplicationKind {
  planarArea,
  surfaceArea,
  volumeBetweenSurfaces,
  massAndCenterOfMass,
}

class Mat212ProblemBuilder extends StatefulWidget {
  final MultivariableIntegral initialIntegral;
  final Function(MultivariableIntegral) onSolve;
  final VoidCallback? onCameraOcr;

  const Mat212ProblemBuilder({
    super.key,
    required this.initialIntegral,
    required this.onSolve,
    this.onCameraOcr,
  });

  @override
  State<Mat212ProblemBuilder> createState() => _Mat212ProblemBuilderState();
}

class _Mat212ProblemBuilderState extends State<Mat212ProblemBuilder> {
  Mat212EntryMode _entryMode = Mat212EntryMode.directIterated;

  // Mode 2: Region by Curves or Vertices
  bool _isVerticesMode = false;
  late final TextEditingController _curvesCtrl;
  late final TextEditingController _verticesCtrl;
  late final TextEditingController _regionIntegrandCtrl;
  late final TextEditingController _uvTransformCtrl;
  String _preferredOrder = 'auto'; // 'auto', 'type1', 'type2', 'polar', 'uv'

  // Mode 3: Applications
  Mat212ApplicationKind _appKind = Mat212ApplicationKind.planarArea;
  late final TextEditingController _appRegionCtrl;
  late final TextEditingController _appSurfaceZCtrl;
  late final TextEditingController _appZSupCtrl;
  late final TextEditingController _appZInfCtrl;
  late final TextEditingController _appDensityCtrl;
  String _appCoordHint = 'auto';
  bool _massIs3D = true;

  @override
  void initState() {
    super.initState();
    _curvesCtrl = TextEditingController(text: 'y = 2*x, y = x^2');
    _verticesCtrl = TextEditingController(text: 'A(0,0), B(10,1), C(1,1)');
    _regionIntegrandCtrl = TextEditingController(text: 'x + y');
    _uvTransformCtrl = TextEditingController();

    _appRegionCtrl = TextEditingController(text: 'x^2 + y^2 = R^2');
    _appSurfaceZCtrl = TextEditingController(text: '4 - x^2 - y^2');
    _appZSupCtrl = TextEditingController(text: '8 - x^2 - y^2');
    _appZInfCtrl = TextEditingController(text: 'x^2 + y^2');
    _appDensityCtrl = TextEditingController(text: 'k');
  }

  @override
  void dispose() {
    _curvesCtrl.dispose();
    _verticesCtrl.dispose();
    _regionIntegrandCtrl.dispose();
    _uvTransformCtrl.dispose();
    _appRegionCtrl.dispose();
    _appSurfaceZCtrl.dispose();
    _appZSupCtrl.dispose();
    _appZInfCtrl.dispose();
    _appDensityCtrl.dispose();
    super.dispose();
  }

  List<String> _splitCommaItems(String raw) {
    final items = <String>[];
    int depth = 0;
    int start = 0;
    for (int i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        final s = raw.substring(start, i).trim();
        if (s.isNotEmpty) items.add(s);
        start = i + 1;
      }
    }
    final tail = raw.substring(start).trim();
    if (tail.isNotEmpty) items.add(tail);
    return items;
  }

  void _solveRegionProblem() {
    final integrandText = _regionIntegrandCtrl.text.trim();
    final integrand = integrandText.isEmpty
        ? '1'
        : IntegralExpressionTransformer.normalizeExpression(integrandText);

    RegionDeductionResult? deduced;
    if (_isVerticesMode) {
      final verts = _splitCommaItems(_verticesCtrl.text);
      deduced = RegionGeometrySolver.deduceFromVertices(
        verticesInput: verts,
        integrand: integrand,
        preferredOrder: _preferredOrder,
      );
      if (deduced != null) {
        widget.onSolve(deduced.primaryIntegral.copyWith(
          problemMode: ProblemMode.regionVertices,
          verticesInput: verts,
          preferredOrder: _preferredOrder,
        ));
        return;
      }
    } else {
      final curves = _splitCommaItems(_curvesCtrl.text);
      deduced = RegionGeometrySolver.deduceFromCurves(
        curvesInput: curves,
        integrand: integrand,
        preferredOrder: _preferredOrder,
        customUvTransform: _uvTransformCtrl.text.trim().isEmpty
            ? null
            : _uvTransformCtrl.text.trim(),
      );
      if (deduced != null) {
        widget.onSolve(deduced.primaryIntegral.copyWith(
          problemMode: ProblemMode.regionCurves,
          boundaryCurves: curves,
          uvTransformInput: _uvTransformCtrl.text.trim().isEmpty
              ? null
              : _uvTransformCtrl.text.trim(),
          preferredOrder: _preferredOrder,
        ));
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.slateDark,
        content: Text(
          'No se pudo deducir una región cerrada. Verifica las ecuaciones o vértices.',
          style: TextStyle(color: AppColors.amberGlow),
        ),
      ),
    );
  }

  void _solveApplicationProblem() {
    final regionItems = _splitCommaItems(_appRegionCtrl.text);
    final isVertices = regionItems.isNotEmpty && regionItems.every((s) => s.contains('(') && !s.contains('='));

    RegionDeductionResult? baseRegion;
    if (isVertices) {
      baseRegion = RegionGeometrySolver.deduceFromVertices(
        verticesInput: regionItems,
        integrand: '1',
      );
    } else if (regionItems.isNotEmpty) {
      baseRegion = RegionGeometrySolver.deduceFromCurves(
        curvesInput: regionItems,
        integrand: '1',
        preferredOrder: _appCoordHint,
      );
    }

    final baseBounds = baseRegion?.primaryIntegral.bounds ??
        const [
          IntegrationBound(variable: 'y', lower: '0', upper: '1'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ];
    final baseCoord = baseRegion?.primaryIntegral.coordinateSystem ?? CoordinateSystemType.cartesian;

    switch (_appKind) {
      case Mat212ApplicationKind.planarArea:
        final compiled = MultivariableIntegral(
          integrand: '1',
          bounds: baseBounds,
          coordinateSystem: baseCoord,
          problemMode: ProblemMode.planarArea,
          boundaryCurves: isVertices ? const [] : regionItems,
          verticesInput: isVertices ? regionItems : const [],
          preferredOrder: _appCoordHint,
        );
        widget.onSolve(compiled);

      case Mat212ApplicationKind.surfaceArea:
        final zExpr = IntegralExpressionTransformer.normalizeExpression(_appSurfaceZCtrl.text);
        final compiled = MultivariableIntegral(
          integrand: zExpr, // LocalMathEngine computes sqrt(1 + zx^2 + zy^2) in Step 0!
          bounds: baseBounds,
          coordinateSystem: baseCoord,
          problemMode: ProblemMode.surfaceArea,
          boundaryCurves: isVertices ? const [] : regionItems,
          verticesInput: isVertices ? regionItems : const [],
          zUpperExpr: zExpr,
        );
        widget.onSolve(compiled);

      case Mat212ApplicationKind.volumeBetweenSurfaces:
        final zSup = IntegralExpressionTransformer.normalizeExpression(_appZSupCtrl.text);
        final zInf = IntegralExpressionTransformer.normalizeExpression(_appZInfCtrl.text);
        final compiled = MultivariableIntegral(
          integrand: '($zSup) - ($zInf)',
          bounds: baseBounds,
          coordinateSystem: baseCoord,
          problemMode: ProblemMode.volumeBetweenSurfaces,
          boundaryCurves: isVertices ? const [] : regionItems,
          verticesInput: isVertices ? regionItems : const [],
          zUpperExpr: zSup,
          zLowerExpr: zInf,
        );
        widget.onSolve(compiled);

      case Mat212ApplicationKind.massAndCenterOfMass:
        final rho = IntegralExpressionTransformer.normalizeExpression(_appDensityCtrl.text);
        final zSup = IntegralExpressionTransformer.normalizeExpression(_appZSupCtrl.text);
        final zInf = IntegralExpressionTransformer.normalizeExpression(_appZInfCtrl.text);
        final bounds = _massIs3D
            ? [
                IntegrationBound(variable: 'z', lower: zInf, upper: zSup),
                ...baseBounds,
              ]
            : baseBounds;
        final coord3D = _massIs3D && baseCoord == CoordinateSystemType.polar
            ? CoordinateSystemType.cylindrical
            : baseCoord;

        final compiled = MultivariableIntegral(
          integrand: rho,
          bounds: bounds,
          coordinateSystem: coord3D,
          problemMode: ProblemMode.massAndCenterOfMass,
          boundaryCurves: isVertices ? const [] : regionItems,
          verticesInput: isVertices ? regionItems : const [],
          zLowerExpr: _massIs3D ? zInf : null,
          zUpperExpr: _massIs3D ? zSup : null,
          densityExpr: rho,
        );
        widget.onSolve(compiled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Selector de Modo: "Modo Práctica MAT 212"
        Container(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.slateDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.school_rounded, size: 14, color: AppColors.cyberEmerald),
                  SizedBox(width: 6),
                  Text(
                    'Modo Práctica MAT 212 (UPEA)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cyberEmerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SegmentedButton<Mat212EntryMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppColors.deepVoid,
                  selectedBackgroundColor: AppColors.electricCyan.withAlpha(38),
                  selectedForegroundColor: AppColors.electricCyan,
                  foregroundColor: AppColors.mutedGray,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                segments: const [
                  ButtonSegment(
                    value: Mat212EntryMode.directIterated,
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text('Iterada Directa')),
                  ),
                  ButtonSegment(
                    value: Mat212EntryMode.regionBuilder,
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text('Región / Vértices')),
                  ),
                  ButtonSegment(
                    value: Mat212EntryMode.applications,
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text('Aplicaciones')),
                  ),
                ],
                selected: {_entryMode},
                onSelectionChanged: (sel) {
                  setState(() => _entryMode = sel.first);
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: switch (_entryMode) {
            Mat212EntryMode.directIterated => MathwayFormulaEditor(
                initialIntegral: widget.initialIntegral,
                onSolve: widget.onSolve,
                onCameraOcr: widget.onCameraOcr,
              ),
            Mat212EntryMode.regionBuilder => _buildRegionBuilder(),
            Mat212EntryMode.applications => _buildApplicationsBuilder(),
          },
        ),
      ],
    );
  }

  Widget _buildRegionBuilder() {
    final previewResult = _isVerticesMode
        ? RegionGeometrySolver.deduceFromVertices(
            verticesInput: _splitCommaItems(_verticesCtrl.text),
            integrand: _regionIntegrandCtrl.text.trim().isEmpty ? '1' : _regionIntegrandCtrl.text,
            preferredOrder: _preferredOrder,
          )
        : RegionGeometrySolver.deduceFromCurves(
            curvesInput: _splitCommaItems(_curvesCtrl.text),
            integrand: _regionIntegrandCtrl.text.trim().isEmpty ? '1' : _regionIntegrandCtrl.text,
            preferredOrder: _preferredOrder,
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggle Curvas vs Vértices
          Row(
            children: [
              Expanded(
                child: _pillButton(
                  label: 'Por Curvas Frontera',
                  active: !_isVerticesMode,
                  onTap: () => setState(() => _isVerticesMode = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pillButton(
                  label: 'Por Vértices de Polígono',
                  active: _isVerticesMode,
                  onTap: () => setState(() => _isVerticesMode = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Example Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (!_isVerticesMode) ...[
                  _exampleChip('y = 2x, y = x²', () {
                    setState(() {
                      _curvesCtrl.text = 'y = 2*x, y = x^2';
                      _regionIntegrandCtrl.text = 'x * y';
                      _preferredOrder = 'auto';
                    });
                  }),
                  _exampleChip('x² + y² = 2ax', () {
                    setState(() {
                      _curvesCtrl.text = 'x^2 + y^2 = 2*a*x';
                      _regionIntegrandCtrl.text = 'x^2 + y^2';
                      _preferredOrder = 'polar';
                    });
                  }),
                  _exampleChip('xy=1..3, y=x..3x', () {
                    setState(() {
                      _curvesCtrl.text = 'x*y = 1, x*y = 3, y = x, y = 3*x';
                      _regionIntegrandCtrl.text = '1';
                      _preferredOrder = 'uv';
                    });
                  }),
                  _exampleChip('x+y=1..3, x-2y=0..4', () {
                    setState(() {
                      _curvesCtrl.text = 'x + y = 1, x + y = 3, x - 2*y = 0, x - 2*y = 4';
                      _regionIntegrandCtrl.text = 'x + y';
                      _preferredOrder = 'uv';
                    });
                  }),
                ] else ...[
                  _exampleChip('A(0,0), B(10,1), C(1,1)', () {
                    setState(() {
                      _verticesCtrl.text = 'A(0,0), B(10,1), C(1,1)';
                      _regionIntegrandCtrl.text = 'x * y';
                      _preferredOrder = 'auto';
                    });
                  }),
                  _exampleChip('Triángulo (0,0), (2,0), (0,2)', () {
                    setState(() {
                      _verticesCtrl.text = 'A(0,0), B(2,0), C(0,2)';
                      _regionIntegrandCtrl.text = 'x + y';
                      _preferredOrder = 'auto';
                    });
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (!_isVerticesMode)
            _darkField(
              controller: _curvesCtrl,
              label: 'Ecuaciones Frontera (separadas por coma)',
              hint: 'ej. y = 2*x, y = x^2  o  x*y = 1, x*y = 3, y = x, y = 3*x',
              onChanged: (_) => setState(() {}),
            )
          else
            _darkField(
              controller: _verticesCtrl,
              label: 'Vértices del Polígono / Triángulo',
              hint: 'ej. A(0,0), B(10,1), C(1,1)',
              onChanged: (_) => setState(() {}),
            ),

          const SizedBox(height: 10),
          _darkField(
            controller: _regionIntegrandCtrl,
            label: 'Integrando f(x, y) (deja "1" para Área)',
            hint: 'ej. 1, x*y, x^2 + y^2',
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 10),
          // Sweep Order / Method Selector
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _orderChip('auto', 'Auto'),
              _orderChip('type1', 'Tipo I (dy dx)'),
              _orderChip('type2', 'Tipo II (dx dy)'),
              if (!_isVerticesMode) _orderChip('polar', 'Polares (r, θ)'),
              if (!_isVerticesMode) _orderChip('uv', 'Jacobiano (u, v)'),
            ],
          ),

          if (_preferredOrder == 'uv' && !_isVerticesMode) ...[
            const SizedBox(height: 10),
            _darkField(
              controller: _uvTransformCtrl,
              label: 'Transformación T(u,v) opcional (Auto si se deja vacío)',
              hint: 'ej. u = x*y, v = y/x',
            ),
          ],

          const SizedBox(height: 12),

          // Live Preview of Deduced Integral & Intersections
          if (previewResult != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slateDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cyberEmerald.withAlpha(110)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Vista Previa (${previewResult.domainAnalysis.regionType})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cyberEmerald,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${previewResult.domainAnalysis.intersectionPoints.length} vértices/cortes',
                        style: const TextStyle(fontSize: 10, color: AppColors.amberGlow),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Math.tex(
                      LatexSanitizer.sanitize(previewResult.domainAnalysis.deducedLimitsLatex),
                      textStyle: const TextStyle(fontSize: 14, color: AppColors.pureWhite),
                      onErrorFallback: (_) => Text(
                        previewResult.domainAnalysis.deducedLimitsLatex,
                        style: const TextStyle(fontSize: 12, color: AppColors.pureWhite),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyberEmerald,
              foregroundColor: AppColors.deepVoid,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text(
              'Deducir Límites, Resolver y Graficar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _solveRegionProblem,
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsBuilder() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector of the 4 MAT 212 Applications
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _appChip(Mat212ApplicationKind.planarArea, 'Área Plana ∬ dA'),
              _appChip(Mat212ApplicationKind.surfaceArea, 'Área Superficie 3D'),
              _appChip(Mat212ApplicationKind.volumeBetweenSurfaces, 'Volumen entre Superficies'),
              _appChip(Mat212ApplicationKind.massAndCenterOfMass, 'Masa y Centro de Masa'),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Preset examples per application
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_appKind == Mat212ApplicationKind.planarArea) ...[
                  _exampleChip('Cardioide r=1+cosθ', () {
                    setState(() {
                      _appRegionCtrl.text = 'r = 1 + cos(theta)';
                      _appCoordHint = 'polar';
                    });
                  }),
                  _exampleChip('Parábola y=2x, y=x²', () {
                    setState(() {
                      _appRegionCtrl.text = 'y = 2*x, y = x^2';
                      _appCoordHint = 'auto';
                    });
                  }),
                  _exampleChip('Hipérbolas xy=1..3, y=x..3x', () {
                    setState(() {
                      _appRegionCtrl.text = 'x*y = 1, x*y = 3, y = x, y = 3*x';
                      _appCoordHint = 'uv';
                    });
                  }),
                ],
                if (_appKind == Mat212ApplicationKind.surfaceArea) ...[
                  _exampleChip('Paraboloide z=4-x²-y²', () {
                    setState(() {
                      _appSurfaceZCtrl.text = '4 - x^2 - y^2';
                      _appRegionCtrl.text = 'x^2 + y^2 = 4';
                      _appCoordHint = 'polar';
                    });
                  }),
                  _exampleChip('Plano z=6-3x-2y (Q1)', () {
                    setState(() {
                      _appSurfaceZCtrl.text = '6 - 3*x - 2*y';
                      _appRegionCtrl.text = 'y = 0, y = 3 - 3*x/2, x = 0';
                      _appCoordHint = 'auto';
                    });
                  }),
                ],
                if (_appKind == Mat212ApplicationKind.volumeBetweenSurfaces) ...[
                  _exampleChip('Entre Paraboloides', () {
                    setState(() {
                      _appZSupCtrl.text = '8 - x^2 - y^2';
                      _appZInfCtrl.text = 'x^2 + y^2';
                      _appRegionCtrl.text = 'x^2 + y^2 = 4';
                      _appCoordHint = 'polar';
                    });
                  }),
                  _exampleChip('Tetraedro z=1-x-y', () {
                    setState(() {
                      _appZSupCtrl.text = '1 - x - y';
                      _appZInfCtrl.text = '0';
                      _appRegionCtrl.text = 'A(0,0), B(1,0), C(0,1)';
                      _appCoordHint = 'auto';
                    });
                  }),
                ],
                if (_appKind == Mat212ApplicationKind.massAndCenterOfMass) ...[
                  _exampleChip('Cono ρ=k (3D)', () {
                    setState(() {
                      _massIs3D = true;
                      _appDensityCtrl.text = 'k';
                      _appZInfCtrl.text = 'r';
                      _appZSupCtrl.text = 'H';
                      _appRegionCtrl.text = 'x^2 + y^2 = R^2';
                      _appCoordHint = 'polar';
                    });
                  }),
                  _exampleChip('Cubo ρ=x²+y²+z²', () {
                    setState(() {
                      _massIs3D = true;
                      _appDensityCtrl.text = 'x^2 + y^2 + z^2';
                      _appZInfCtrl.text = '0';
                      _appZSupCtrl.text = '1';
                      _appRegionCtrl.text = 'x = 0, x = 1, y = 0, y = 1';
                      _appCoordHint = 'auto';
                    });
                  }),
                  _exampleChip('Lámina 2D ρ=k*y', () {
                    setState(() {
                      _massIs3D = false;
                      _appDensityCtrl.text = 'k * y';
                      _appRegionCtrl.text = 'y = 0, y = 2 - x';
                      _appCoordHint = 'auto';
                    });
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Formula Card for active application
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.slateDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                switch (_appKind) {
                  Mat212ApplicationKind.planarArea => r'A = \iint_R 1 \, dA',
                  Mat212ApplicationKind.surfaceArea =>
                    r'A_S = \iint_R \sqrt{1 + \left(\frac{\partial z}{\partial x}\right)^2 + \left(\frac{\partial z}{\partial y}\right)^2} \, dA',
                  Mat212ApplicationKind.volumeBetweenSurfaces =>
                    r'V = \iint_R \left(z_{\text{sup}}(x,y) - z_{\text{inf}}(x,y)\right) dA',
                  Mat212ApplicationKind.massAndCenterOfMass => _massIs3D
                      ? r'M = \iiint_V \rho \, dV, \quad (\bar{x},\bar{y},\bar{z}) = \left(\frac{M_{yz}}{M}, \frac{M_{xz}}{M}, \frac{M_{xy}}{M}\right)'
                      : r'M = \iint_R \rho \, dA, \quad (\bar{x},\bar{y}) = \left(\frac{M_y}{M}, \frac{M_x}{M}\right)',
                },
                textStyle: const TextStyle(fontSize: 13, color: AppColors.electricCyan),
              ),
            ),
          ),
          const SizedBox(height: 10),

          if (_appKind == Mat212ApplicationKind.surfaceArea) ...[
            _darkField(
              controller: _appSurfaceZCtrl,
              label: 'Superficie z = f(x, y)',
              hint: 'ej. 4 - x^2 - y^2',
            ),
            const SizedBox(height: 10),
          ],

          if (_appKind == Mat212ApplicationKind.volumeBetweenSurfaces ||
              (_appKind == Mat212ApplicationKind.massAndCenterOfMass && _massIs3D)) ...[
            Row(
              children: [
                Expanded(
                  child: _darkField(
                    controller: _appZInfCtrl,
                    label: 'Superficie Inferior z_inf',
                    hint: 'ej. 0 o x^2 + y^2',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _darkField(
                    controller: _appZSupCtrl,
                    label: 'Superficie Superior z_sup',
                    hint: 'ej. 8 - x^2 - y^2',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          if (_appKind == Mat212ApplicationKind.massAndCenterOfMass) ...[
            Row(
              children: [
                Expanded(
                  child: _pillButton(
                    label: 'Lámina 2D',
                    active: !_massIs3D,
                    onTap: () => setState(() => _massIs3D = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pillButton(
                    label: 'Sólido 3D',
                    active: _massIs3D,
                    onTap: () => setState(() => _massIs3D = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _darkField(
              controller: _appDensityCtrl,
              label: _massIs3D ? 'Densidad ρ(x, y, z)' : 'Densidad ρ(x, y)',
              hint: 'ej. k, x^2 + y^2 + z^2',
            ),
            const SizedBox(height: 10),
          ],

          _darkField(
            controller: _appRegionCtrl,
            label: 'Región Dominio R (curvas o vértices)',
            hint: 'ej. x^2 + y^2 = R^2  o  y = 2*x, y = x^2',
          ),

          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyberEmerald,
              foregroundColor: AppColors.deepVoid,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.calculate_rounded),
            label: const Text(
              'Calcular Aplicación Paso a Paso',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _solveApplicationProblem,
          ),
        ],
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String label,
    required String hint,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: AppColors.pureWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11.5, color: AppColors.electricCyan),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.mutedGray),
        filled: true,
        fillColor: AppColors.slateDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cyberEmerald, width: 1.5),
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.cyberEmerald.withAlpha(35) : AppColors.slateDark,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? AppColors.cyberEmerald : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: active ? AppColors.cyberEmerald : AppColors.mutedGray,
          ),
        ),
      ),
    );
  }

  Widget _orderChip(String key, String label) {
    final active = _preferredOrder == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 10.5, color: active ? AppColors.deepVoid : AppColors.pureWhite)),
      selected: active,
      selectedColor: AppColors.electricCyan,
      backgroundColor: AppColors.slateDark,
      side: const BorderSide(color: AppColors.borderSubtle),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _preferredOrder = key),
    );
  }

  Widget _appChip(Mat212ApplicationKind kind, String label) {
    final active = _appKind == kind;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: active ? AppColors.deepVoid : AppColors.pureWhite)),
      selected: active,
      selectedColor: AppColors.cyberEmerald,
      backgroundColor: AppColors.slateDark,
      side: const BorderSide(color: AppColors.borderSubtle),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _appKind = kind),
    );
  }

  Widget _exampleChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.electricCyan)),
        backgroundColor: AppColors.slateElevated,
        side: const BorderSide(color: AppColors.borderSubtle),
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
      ),
    );
  }
}
