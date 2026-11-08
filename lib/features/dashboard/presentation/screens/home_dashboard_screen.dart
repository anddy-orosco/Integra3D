import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/math_colors.dart';
import '../../../calculator/presentation/widgets/mathway_formula_editor.dart';
import '../../../ocr/presentation/widgets/ocr_scanner_sheet.dart';
import '../../../solver/domain/entities/integral_solution.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openOcrScanner() {
    OcrScannerSheet.show(
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
        _tabController.animateTo(1); // Saltar a la solución
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(solverProvider);
    final notifier = ref.read(solverProvider.notifier);
    final mathColors = context.mathColors;

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
                _tabController.animateTo(1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditorTab(SolverState state, SolverNotifier notifier, MathColors mathColors) {
    return MathwayFormulaEditor(
      initialIntegral: state.currentIntegral,
      onCameraOcr: _openOcrScanner,
      onSolve: (integral) {
        notifier.loadPreset({
          'name': 'Integral Personalizada',
          'dimension': integral.dimension,
          'integrand': integral.integrand,
          'coordinate_system': integral.coordinateSystem.apiValue,
          'bounds': integral.bounds.map((b) => b.toJson()).toList(),
        });
        _tabController.animateTo(1);
      },
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

              // Alerta didáctica si la integral no tiene solución real o es divergente
              if (!solution.isSuccess && solution.errorMessage != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.coralFlame.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.coralFlame.withAlpha(140), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppColors.coralFlame, size: 22),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Diagnóstico Didáctico: No Integrable o Divergente',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.coralFlame,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        solution.errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.pureWhite, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],

              // Exact result
              LatexCard(
                title: solution.isSuccess ? 'Resultado Simbólico / Numérico' : 'Estado de Convergencia',
                subtitle: solution.approxNumeric != null
                    ? 'Aproximación Numérica: ≈ ${solution.approxNumeric}'
                    : null,
                latex: solution.exactLatex,
                isHighlight: solution.isSuccess,
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
              const SizedBox(height: 18),

              // Desarrollo Paso a Paso Académico Integrado Directamente en Solución
              if (solution.steps.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Desarrollo Paso a Paso:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: mathColors.secondaryAccent,
                        letterSpacing: 0.3,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.fullscreen_rounded, size: 16, color: AppColors.mutedGray),
                      label: const Text('Ver Pantalla de Pasos', style: TextStyle(fontSize: 11, color: AppColors.mutedGray)),
                      onPressed: () => _tabController.animateTo(2),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._buildStepCards(solution, mathColors),
                const SizedBox(height: 16),
              ],

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

    final bool hasInversion = solution.steps.any((s) => s.isLimitInverted);

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Cabecera Didáctica: Planteamiento Integral I = ...
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.slateDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Planteamiento del Ejercicio:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mathColors.secondaryAccent,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              LatexCard(
                latex: 'I = ${solution.originalIntegralLatex.isEmpty ? "\\int f" : solution.originalIntegralLatex}',
                isHighlight: true,
              ),
              if (solution.regionDefinition != null && solution.regionDefinition!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.deepVoid.withAlpha(160),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    solution.regionDefinition!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.pureWhite,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. Banner de Orientación / Inversión si aplica
        if (hasInversion)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.amberGlow.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.amberGlow.withAlpha(100)),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_vert_circle_rounded, color: AppColors.amberGlow, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Propiedad de orientación activa: se detectaron límites invertidos (inferior > superior). Se aplica la identidad fundamental ∫_a^b f = -∫_b^a f con factor (-1) para garantizar rigor y conservar el signo.',
                    style: TextStyle(fontSize: 11, color: mathColors.formulaText, height: 1.35),
                  ),
                ),
              ],
            ),
          ),

        // 3. Pasos Secuenciales Didácticos (Estructura de Libro de Texto Académico)
        ..._buildStepCards(solution, mathColors),

        // 4. Conclusión Final y Botón de Navegación 3D
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.slateDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: mathColors.primaryAction.withAlpha(120), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Resultado Final de la Integral:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mathColors.primaryAction),
              ),
              const SizedBox(height: 8),
              LatexCard(
                latex: 'I = ${solution.exactLatex}',
                isHighlight: true,
              ),
              if (solution.approxNumeric != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Aproximación numérica: ≈ ${solution.approxNumeric}',
                  style: TextStyle(fontSize: 12, color: mathColors.metadataText),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mathColors.primaryAction,
                    foregroundColor: AppColors.deepVoid,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.view_in_ar_rounded, size: 18),
                  label: const Text(
                    'Explorar en el Espacio 3D',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _tabController.animateTo(3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStepCards(IntegralSolution solution, MathColors mathColors) {
    return solution.steps.map((step) {
      final isZ = step.variable == 'z';
      final isY = step.variable == 'y';
      final axisColor = isZ
          ? mathColors.axisZ
          : (isY ? mathColors.axisY : mathColors.axisX);

      final String defaultTitle = step.stepNumber == 1
          ? 'Paso 1: Resolver la integral interna (con respecto a ${step.variable})'
          : (step.stepNumber == solution.steps.length
              ? 'Paso ${step.stepNumber}: Resolver la integral externa (con respecto a ${step.variable})'
              : 'Paso ${step.stepNumber}: Resolver la integral intermedia (con respecto a ${step.variable})');

      final String defaultIntegralLabel = step.stepNumber == 1
          ? 'La integral interna es:'
          : (step.stepNumber == solution.steps.length
              ? 'La integral externa es:'
              : 'La integral intermedia es:');

      final String defaultConstantText = step.stepNumber == 1
          ? 'Tratamos las demás variables como constantes e integramos respecto a ${step.variable}:'
          : 'Integramos respecto a ${step.variable}:';

      final String defaultLimitsText =
          'Ahora evaluamos en los límites ${step.variable} = ${step.lowerBoundLatex} y ${step.variable} = ${step.upperBoundLatex}:';

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.slateDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: step.isLimitInverted
                ? AppColors.amberGlow.withAlpha(90)
                : AppColors.borderSubtle,
            width: step.isLimitInverted ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del Paso + Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: step.isLimitInverted ? AppColors.amberGlow : mathColors.primaryAction,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${step.stepNumber}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepVoid),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step.stepTitle ?? defaultTitle,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.pureWhite),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (step.appliedMethod != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: (step.isLimitInverted ? AppColors.amberGlow : mathColors.secondaryAccent).withAlpha(22),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: (step.isLimitInverted ? AppColors.amberGlow : mathColors.secondaryAccent).withAlpha(120)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              step.isLimitInverted ? Icons.swap_vert_rounded : Icons.functions_rounded,
                              size: 11,
                              color: step.isLimitInverted ? AppColors.amberGlow : mathColors.secondaryAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              step.appliedMethod!,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: step.isLimitInverted ? AppColors.amberGlow : mathColors.secondaryAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: axisColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: axisColor.withAlpha(120)),
                      ),
                      child: Text(
                        'Eje ${step.variable.toUpperCase()}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: axisColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Alerta de inversión en este paso si aplica
            if (step.isLimitInverted)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.amberGlow.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.amberGlow.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.amberGlow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cotas invertidas: ${step.lowerBoundLatex} > ${step.upperBoundLatex}. Se aplicó la inversión canónica con factor (-1) preservando signos en F(b) - F(a).',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.amberGlow),
                      ),
                    ),
                  ],
                ),
              ),

            // 1. "La integral interna es:"
            Text(
              defaultIntegralLabel,
              style: TextStyle(fontSize: 12, color: mathColors.metadataText, height: 1.4),
            ),
            const SizedBox(height: 6),
            LatexCard(
              latex: step.stepIntegralLatex ??
                  '\\int_{${step.lowerBoundLatex}}^{${step.upperBoundLatex}} ${step.currentIntegrandLatex} \\, d${step.variable}',
            ),

            const SizedBox(height: 10),

            // 2. "Tratamos a ... como una constante e integramos respecto a ...:"
            Text(
              step.constantTreatmentText ?? defaultConstantText,
              style: TextStyle(fontSize: 12, color: mathColors.metadataText, height: 1.4),
            ),
            const SizedBox(height: 6),
            LatexCard(
              latex: step.antiderivativeWorkLatex ??
                  '\\int ${step.currentIntegrandLatex} \\, d${step.variable} = ${step.antiderivativeLatex}',
            ),

            const SizedBox(height: 10),

            // 3. "Ahora evaluamos en los límites ...:"
            Text(
              step.limitsEvaluationText ?? defaultLimitsText,
              style: TextStyle(fontSize: 12, color: mathColors.metadataText, height: 1.4),
            ),
            const SizedBox(height: 6),
            LatexCard(latex: step.evaluatedLatex),

            const SizedBox(height: 10),

            // 4. Explicación didáctica y expresión resultante para el siguiente paso
            if (step.explanation.isNotEmpty)
              Text(
                step.explanation,
                style: TextStyle(fontSize: 11, color: mathColors.metadataText.withAlpha(200), height: 1.4),
              ),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.deepVoid.withAlpha(140),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: mathColors.primaryAction.withAlpha(70)),
              ),
              child: Row(
                children: [
                  Icon(Icons.arrow_forward_rounded, size: 14, color: mathColors.primaryAction),
                  const SizedBox(width: 8),
                  Text(
                    step.stepNumber == solution.steps.length
                        ? 'Resultado final del cálculo:'
                        : 'Expresión para el Paso ${step.stepNumber + 1}:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: mathColors.primaryAction),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.simplifiedResultLatex,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.pureWhite),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _build3DViewportTab(SolverState state) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Native3DViewport(meshData: state.meshData),
    );
  }
}
