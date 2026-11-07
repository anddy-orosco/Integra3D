import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/math_colors.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../calculator/presentation/widgets/keyboard/math_keyboard.dart';
import '../../../ocr/presentation/widgets/ocr_scanner_modal.dart';
import '../../../solver/presentation/providers/solver_provider.dart';
import '../../../solver/presentation/widgets/latex_card.dart';
import '../../../visualization_3d/presentation/widgets/native_3d_viewport.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _integrandController = TextEditingController();

  // Control de teclado virtual matemático
  bool _showMathKeyboard = false;
  late TextEditingController _activeController;
  String _activeFieldLabel = 'Integrando f(x, y, z)';

  // Controladores para los límites de integración
  final Map<String, TextEditingController> _boundControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final initialIntegral = ref.read(solverProvider).currentIntegral;
    _integrandController.text = initialIntegral.integrand;
    _activeController = _integrandController;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _integrandController.dispose();
    for (final c in _boundControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getBoundController(int index, bool isLower, String initialVal) {
    final key = '${index}_${isLower ? "lower" : "upper"}';
    if (!_boundControllers.containsKey(key)) {
      final ctrl = TextEditingController(text: initialVal);
      _boundControllers[key] = ctrl;
      return ctrl;
    }
    final existing = _boundControllers[key]!;
    if (!_showMathKeyboard && existing.text != initialVal) {
      existing.text = initialVal;
    }
    return existing;
  }

  void _openOcrScanner() {
    OcrScannerModal.show(
      context,
      onIntegralAccepted: (integral) {
        final notifier = ref.read(solverProvider.notifier);
        notifier.loadPreset({
          'name': 'Ejercicio Escaneado',
          'dimension': integral.dimension,
          'integrand': integral.integrand,
          'coordinate_system': integral.coordinateSystem.apiValue,
          'bounds': integral.bounds.map((b) => b.toJson()).toList(),
        });
        setState(() {
          _integrandController.text = integral.integrand;
          _showMathKeyboard = false;
        });
        _tabController.animateTo(1); // Saltar a la solución
      },
    );
  }

  void _focusField(TextEditingController ctrl, String label) {
    setState(() {
      _activeController = ctrl;
      _activeFieldLabel = label;
      _showMathKeyboard = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(solverProvider);
    final notifier = ref.read(solverProvider.notifier);
    final mathColors = context.mathColors;

    if (_integrandController.text != state.currentIntegral.integrand && !_showMathKeyboard) {
      _integrandController.text = state.currentIntegral.integrand;
    }

    return Scaffold(
      backgroundColor: AppColors.deepVoid,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: mathColors.primaryAction.withAlpha(35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: mathColors.primaryAction.withAlpha(90)),
              ),
              child: Icon(Icons.hub_rounded, color: mathColors.primaryAction, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Integra3D',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: mathColors.formulaText,
                  ),
                ),
                Text(
                  'Cálculo Multivariable & Math OCR',
                  style: TextStyle(
                    fontSize: 10,
                    color: mathColors.metadataText,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Botón directo para Escanear con Cámara o Foto
          IconButton(
            icon: const Icon(Icons.camera_alt_rounded, size: 20, color: AppColors.amberGlow),
            tooltip: 'Escanear ejercicio con foto (OCR)',
            onPressed: _openOcrScanner,
          ),

          // Engine Status Indicator Pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: state.isBackendConnected
                  ? mathColors.primaryAction.withAlpha(25)
                  : mathColors.mathWarning.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: state.isBackendConnected
                    ? mathColors.primaryAction.withAlpha(120)
                    : mathColors.mathWarning.withAlpha(120),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 7,
                  color: state.isBackendConnected
                      ? mathColors.primaryAction
                      : mathColors.mathWarning,
                ),
                const SizedBox(width: 5),
                Text(
                  state.isBackendConnected ? 'SymPy' : 'Local',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: state.isBackendConnected
                        ? mathColors.primaryAction
                        : mathColors.mathWarning,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.sync_rounded, size: 20, color: mathColors.metadataText),
            tooltip: 'Sincronizar conexión',
            onPressed: () => notifier.checkConnectionAndSync(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preset problems bar
            _buildPresetBar(state, notifier, mathColors),

            // Refined Segmented Tab Bar (Dark Matrix)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.slateDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.slateElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: mathColors.secondaryAccent.withAlpha(140), width: 1),
                ),
                labelColor: AppColors.pureWhite,
                unselectedLabelColor: mathColors.metadataText,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(icon: Icon(Icons.edit_outlined, size: 16), text: 'Editor'),
                  Tab(icon: Icon(Icons.functions_rounded, size: 16), text: 'Solución'),
                  Tab(icon: Icon(Icons.timeline_rounded, size: 16), text: 'Pasos'),
                  Tab(icon: Icon(Icons.view_in_ar_rounded, size: 16), text: '3D View'),
                ],
              ),
            ),

            // Main Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEditorTab(state, notifier, mathColors),
                  _buildSolutionTab(state, mathColors),
                  _buildStepsTab(state, mathColors),
                  _build3DViewportTab(state),
                ],
              ),
            ),

            // 3. Teclado Matemático Desplegable (Mathway Style)
            if (_showMathKeyboard && _tabController.index == 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                color: AppColors.deepVoid,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.keyboard_alt_outlined, size: 14, color: AppColors.electricCyan),
                        const SizedBox(width: 6),
                        Text(
                          'Teclado Activo: $_activeFieldLabel',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.electricCyan),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => setState(() => _showMathKeyboard = false),
                      child: const Text('Ocultar', style: TextStyle(fontSize: 11, color: AppColors.mutedGray)),
                    ),
                  ],
                ),
              ),
              MathKeyboard(
                controller: _activeController,
                onClose: () => setState(() => _showMathKeyboard = false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetBar(SolverState state, SolverNotifier notifier, MathColors mathColors) {
    if (state.presets.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.presets.length,
        itemBuilder: (context, index) {
          final preset = state.presets[index];
          final name = preset['name'] as String? ?? '';
          final dim = preset['dimension'] as int? ?? 2;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ActionChip(
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.slateDark,
              side: const BorderSide(color: AppColors.borderSubtle),
              avatar: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: mathColors.secondaryAccent.withAlpha(35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${dim}D',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: mathColors.secondaryAccent,
                  ),
                ),
              ),
              label: Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.pureWhite,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () {
                notifier.loadPreset(preset);
                setState(() {
                  _integrandController.text = preset['integrand'] as String? ?? '';
                  _showMathKeyboard = false;
                });
                _tabController.animateTo(1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditorTab(SolverState state, SolverNotifier notifier, MathColors mathColors) {
    final integral = state.currentIntegral;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dimension Switcher
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.slateDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      notifier.setDimension(2);
                      setState(() => _showMathKeyboard = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: integral.dimension == 2 ? AppColors.slateElevated : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: integral.dimension == 2
                            ? Border.all(color: mathColors.secondaryAccent.withAlpha(140))
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '∬ Integral Doble (2D)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: integral.dimension == 2
                              ? mathColors.secondaryAccent
                              : mathColors.metadataText,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      notifier.setDimension(3);
                      setState(() => _showMathKeyboard = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: integral.dimension == 3 ? AppColors.slateElevated : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: integral.dimension == 3
                            ? Border.all(color: mathColors.secondaryAccent.withAlpha(140))
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '∭ Integral Triple (3D)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: integral.dimension == 3
                              ? mathColors.secondaryAccent
                              : mathColors.metadataText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Coordinate system dropdown
          DropdownButtonFormField<CoordinateSystemType>(
            initialValue: integral.coordinateSystem,
            decoration: InputDecoration(
              labelText: 'Sistema de Coordenadas & Elemento de Volumen',
              prefixIcon: Icon(Icons.scatter_plot_rounded, size: 18, color: mathColors.secondaryAccent),
            ),
            items: CoordinateSystemType.values.map((sys) {
              return DropdownMenuItem(
                value: sys,
                child: Text(sys.label, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) notifier.setCoordinateSystem(val);
            },
          ),
          const SizedBox(height: 12),

          // Integrand input (Con accesos directos estilo Mathway: Teclado y Cámara)
          TextField(
            controller: _integrandController,
            onTap: () => _focusField(_integrandController, 'Integrando f(x, y, z)'),
            decoration: InputDecoration(
              labelText: 'Función Integrando f(x, y, z)',
              hintText: 'Ej: 4 - x^2 - y^2 o exp(-x^2 - y^2)',
              prefixIcon: Icon(Icons.functions_rounded, size: 18, color: mathColors.secondaryAccent),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.keyboard_alt_outlined,
                      size: 20,
                      color: (_showMathKeyboard && _activeController == _integrandController)
                          ? mathColors.secondaryAccent
                          : AppColors.mutedGray,
                    ),
                    tooltip: 'Abrir Teclado Matemático',
                    onPressed: () {
                      setState(() {
                        if (_showMathKeyboard && _activeController == _integrandController) {
                          _showMathKeyboard = false;
                        } else {
                          _activeController = _integrandController;
                          _activeFieldLabel = 'Integrando f(x, y, z)';
                          _showMathKeyboard = true;
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.amberGlow),
                    tooltip: 'Escanear con Foto (OCR)',
                    onPressed: _openOcrScanner,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            onChanged: (val) => notifier.updateIntegrand(val),
          ),
          const SizedBox(height: 14),

          // Limits section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Límites de Integración Iterada:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mathColors.metadataText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: mathColors.secondaryAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${integral.dimension} capas',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: mathColors.secondaryAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...List.generate(integral.bounds.length, (index) {
            final bound = integral.bounds[index];
            final orderLabel = index == 0
                ? 'Interior'
                : (index == integral.bounds.length - 1 ? 'Exterior' : 'Intermedio');

            final lowerCtrl = _getBoundController(index, true, bound.lower);
            final upperCtrl = _getBoundController(index, false, bound.upper);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slateDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'd${bound.variable} — $orderLabel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: mathColors.secondaryAccent,
                        ),
                      ),
                      Text('Nivel ${index + 1}', style: TextStyle(fontSize: 10, color: mathColors.metadataText)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lowerCtrl,
                          onTap: () => _focusField(lowerCtrl, 'Límite Inferior de d${bound.variable}'),
                          decoration: InputDecoration(
                            labelText: 'Inferior (a)',
                            suffixIcon: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: (_showMathKeyboard && _activeController == lowerCtrl)
                                  ? mathColors.secondaryAccent
                                  : AppColors.mutedGray,
                            ),
                          ),
                          onChanged: (val) => notifier.updateBound(index, lower: val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: upperCtrl,
                          onTap: () => _focusField(upperCtrl, 'Límite Superior de d${bound.variable}'),
                          decoration: InputDecoration(
                            labelText: 'Superior (b)',
                            suffixIcon: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: (_showMathKeyboard && _activeController == upperCtrl)
                                  ? mathColors.secondaryAccent
                                  : AppColors.mutedGray,
                            ),
                          ),
                          onChanged: (val) => notifier.updateBound(index, upper: val),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),

          // Primary Solve Button (Cyber Emerald)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: mathColors.primaryAction,
              foregroundColor: AppColors.deepVoid,
            ),
            icon: const Icon(Icons.bolt_rounded, size: 20),
            label: const Text('CALCULAR Y PROYECTAR EN 3D'),
            onPressed: () {
              setState(() => _showMathKeyboard = false);
              notifier.solve();
              _tabController.animateTo(1);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSolutionTab(SolverState state, MathColors mathColors) {
    return state.solutionState.when(
      data: (solution) {
        if (solution == null) {
          return const Center(child: Text('Presiona Calcular en el Editor.'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Original Integral
              LatexCard(
                title: 'Integral Planteada',
                latex: solution.originalIntegralLatex,
              ),

              // Exact result
              LatexCard(
                title: 'Resultado Simbólico Exacto',
                subtitle: solution.approxNumeric != null
                    ? 'Aproximación Numérica: ≈ ${solution.approxNumeric}'
                    : null,
                latex: solution.exactLatex,
                isHighlight: true,
              ),

              // Execution & Engine pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.slateDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      'Tiempo: ${solution.executionTimeMs.toStringAsFixed(1)} ms',
                      style: TextStyle(fontSize: 11, color: mathColors.primaryAction, fontWeight: FontWeight.bold),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    icon: Icon(Icons.view_in_ar_rounded, size: 14, color: mathColors.secondaryAccent),
                    label: const Text('Ver en 3D', style: TextStyle(fontSize: 11, color: AppColors.pureWhite)),
                    onPressed: () => _tabController.animateTo(3),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Conceptual Didactic sections
              if (solution.didacticSections != null && solution.didacticSections!.isNotEmpty) ...[
                Text(
                  'Fundamento Teórico y Conceptual:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: mathColors.secondaryAccent),
                ),
                const SizedBox(height: 8),
                ...solution.didacticSections!.map((sec) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.slateDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sec.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.pureWhite),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sec.content,
                        style: TextStyle(fontSize: 12, color: mathColors.metadataText, height: 1.45),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: mathColors.primaryAction),
            const SizedBox(height: 14),
            Text('Procesando cálculo iterado...', style: TextStyle(color: mathColors.metadataText, fontSize: 13)),
          ],
        ),
      ),
      error: (err, _) => Center(
        child: Text('Error: $err', style: TextStyle(color: mathColors.metadataText)),
      ),
    );
  }

  Widget _buildStepsTab(SolverState state, MathColors mathColors) {
    final solution = state.solutionState.asData?.value;
    if (solution == null || solution.steps.isEmpty) {
      return Center(
        child: Text('No hay pasos calculados aún.', style: TextStyle(color: mathColors.metadataText)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: solution.steps.length,
      itemBuilder: (context, index) {
        final step = solution.steps[index];
        final isZ = step.variable == 'z';
        final isY = step.variable == 'y';
        final axisColor = isZ
            ? mathColors.axisZ
            : (isY ? mathColors.axisY : mathColors.axisX);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.slateDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: mathColors.primaryAction,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${step.stepNumber}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepVoid),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Integración respecto a d${step.variable}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.pureWhite),
                      ),
                    ],
                  ),
                  // Axis canonical tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: axisColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: axisColor.withAlpha(120)),
                    ),
                    child: Text(
                      'Eje ${step.variable.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: axisColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(step.explanation, style: TextStyle(fontSize: 11, color: mathColors.metadataText)),
              const Divider(color: AppColors.borderSubtle, height: 20),

              Text('1. Antiderivada parcial:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mathColors.secondaryAccent)),
              const SizedBox(height: 4),
              LatexCard(latex: '\\int f \\, d${step.variable} = ${step.antiderivativeLatex}'),

              const SizedBox(height: 8),
              Text('2. Evaluación de límites [a, b]:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mathColors.secondaryAccent)),
              const SizedBox(height: 4),
              LatexCard(latex: step.evaluatedLatex),

              const SizedBox(height: 8),
              Text('3. Resultado simplificado:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mathColors.mathWarning)),
              const SizedBox(height: 4),
              LatexCard(latex: step.simplifiedResultLatex, isHighlight: true),
            ],
          ),
        );
      },
    );
  }

  Widget _build3DViewportTab(SolverState state) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Native3DViewport(meshData: state.meshData),
    );
  }
}
