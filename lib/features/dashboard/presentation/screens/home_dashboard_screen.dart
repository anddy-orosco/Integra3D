import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../solver/presentation/providers/solver_provider.dart';
import '../../../solver/presentation/widgets/latex_card.dart';
import '../../../visualization_3d/presentation/widgets/three_js_viewport.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _integrandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final initialIntegral = ref.read(solverProvider).currentIntegral;
    _integrandController.text = initialIntegral.integrand;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _integrandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(solverProvider);
    final notifier = ref.read(solverProvider.notifier);

    // Keep controller in sync if preset loaded
    if (_integrandController.text != state.currentIntegral.integrand) {
      _integrandController.text = state.currentIntegral.integrand;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.view_in_ar_rounded, color: AppTheme.primaryCyan, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Integra3D',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                ),
                Text(
                  'Cálculo Multivariable & SymPy Engine',
                  style: TextStyle(fontSize: 11, color: AppTheme.primaryCyan, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted),
            tooltip: 'Recalcular',
            onPressed: () => notifier.solve(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Presets selector
            _buildPresetSelector(state, notifier),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppTheme.primaryCyan.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryCyan, width: 1.2),
                ),
                labelColor: AppTheme.primaryCyan,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note_rounded, size: 20), text: 'Editor'),
                  Tab(icon: Icon(Icons.functions_rounded, size: 20), text: 'Solución'),
                  Tab(icon: Icon(Icons.format_list_numbered_rounded, size: 20), text: 'Pasos'),
                  Tab(icon: Icon(Icons.view_in_ar_rounded, size: 20), text: '3D View'),
                ],
              ),
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEditorTab(state, notifier),
                  _buildSolutionTab(state),
                  _buildStepsTab(state),
                  _build3DViewportTab(state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSelector(SolverState state, SolverNotifier notifier) {
    if (state.presets.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.presets.length,
        itemBuilder: (context, index) {
          final preset = state.presets[index];
          final name = preset['name'] as String? ?? 'Ejemplo';
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: AppTheme.surfaceDark,
              side: const BorderSide(color: Color(0x22FFFFFF)),
              label: Text(
                name,
                style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
              ),
              avatar: const Icon(Icons.bookmark_border_rounded, size: 14, color: AppTheme.primaryCyan),
              onPressed: () {
                notifier.loadPreset(preset);
                _tabController.animateTo(1); // Jump to solution tab
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditorTab(SolverState state, SolverNotifier notifier) {
    final integral = state.currentIntegral;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dimension Selector
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Doble (2D)')),
                  selected: integral.dimension == 2,
                  selectedColor: AppTheme.primaryCyan.withAlpha(50),
                  onSelected: (val) {
                    if (val) notifier.setDimension(2);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Triple (3D)')),
                  selected: integral.dimension == 3,
                  selectedColor: AppTheme.primaryCyan.withAlpha(50),
                  onSelected: (val) {
                    if (val) notifier.setDimension(3);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Coordinate system selector
          DropdownButtonFormField<CoordinateSystemType>(
            initialValue: integral.coordinateSystem,
            decoration: const InputDecoration(
              labelText: 'Sistema de Coordenadas',
              prefixIcon: Icon(Icons.explore_outlined, color: AppTheme.primaryCyan),
            ),
            items: CoordinateSystemType.values.map((sys) {
              return DropdownMenuItem(
                value: sys,
                child: Text(sys.label, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) notifier.setCoordinateSystem(val);
            },
          ),
          const SizedBox(height: 16),

          // Integrand input
          TextField(
            controller: _integrandController,
            decoration: const InputDecoration(
              labelText: 'Función Integrando f(x, y, z)',
              hintText: 'Ej: 4 - x**2 - y**2 o exp(-x**2 - y**2)',
              prefixIcon: Icon(Icons.calculate_outlined, color: AppTheme.primaryCyan),
            ),
            onChanged: (val) => notifier.updateIntegrand(val),
          ),
          const SizedBox(height: 16),

          // Limits section header
          Text(
            'Límites de Integración (${integral.dimension} variables iteradas):',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),

          // Variable bounds cards
          ...List.generate(integral.bounds.length, (index) {
            final bound = integral.bounds[index];
            final orderLabel = index == 0 ? 'Interior' : (index == integral.bounds.length - 1 ? 'Exterior' : 'Intermedio');
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Variable: ${bound.variable} ($orderLabel)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
                        ),
                        Text('Capa ${index + 1}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: bound.lower,
                            decoration: const InputDecoration(labelText: 'Límite Inferior (a)'),
                            onChanged: (val) => notifier.updateBound(index, lower: val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: bound.upper,
                            decoration: const InputDecoration(labelText: 'Límite Superior (b)'),
                            onChanged: (val) => notifier.updateBound(index, upper: val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),

          // Action button
          ElevatedButton.icon(
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('CALCULAR CON SYMPY'),
            onPressed: () {
              notifier.solve();
              _tabController.animateTo(1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionTab(SolverState state) {
    return state.solutionState.when(
      data: (solution) {
        if (solution == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.touch_app_rounded, size: 48, color: AppTheme.textMuted),
                SizedBox(height: 12),
                Text('Presiona "CALCULAR CON SYMPY" en el Editor para resolver.'),
              ],
            ),
          );
        }

        if (!solution.isSuccess) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 54, color: Colors.orangeAccent),
                  const SizedBox(height: 16),
                  Text(
                    solution.errorMessage ?? 'Error desconocido',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: AppTheme.textLight),
                  ),
                ],
              ),
            ),
          );
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
              const SizedBox(height: 12),

              // Exact result
              LatexCard(
                title: 'Resultado Simbólico Exacto (SymPy)',
                subtitle: solution.approxNumeric != null
                    ? 'Aproximación Numérica: ≈ ${solution.approxNumeric}'
                    : null,
                latex: solution.exactLatex,
                isHighlight: true,
              ),
              const SizedBox(height: 12),

              // Execution stats chip
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x22FFFFFF)),
                    ),
                    child: Text(
                      'Tiempo de cálculo: ${solution.executionTimeMs.toStringAsFixed(1)} ms',
                      style: const TextStyle(fontSize: 11, color: AppTheme.accentGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Didactic explanation section
              if (solution.didacticSections != null && solution.didacticSections!.isNotEmpty) ...[
                const Text(
                  'Desglose Pedagógico y Conceptual:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
                ),
                const SizedBox(height: 8),
                ...solution.didacticSections!.map((sec) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sec.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sec.content,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryCyan),
            SizedBox(height: 16),
            Text('Calculando antiderivadas simbólicas...', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar Conexión'),
                onPressed: () => ref.read(solverProvider.notifier).solve(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepsTab(SolverState state) {
    final solution = state.solutionState.asData?.value;
    if (solution == null || solution.steps.isEmpty) {
      return const Center(
        child: Text('No hay pasos disponibles. Realiza un cálculo primero.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: solution.steps.length,
      itemBuilder: (context, index) {
        final step = solution.steps[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: AppTheme.primaryCyan,
                      child: Text(
                        '${step.stepNumber}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Integración con respecto a d${step.variable}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(step.explanation, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const Divider(color: Color(0x1FFFFFFF), height: 24),
                
                const Text('1. Antiderivada parcial:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryCyan)),
                const SizedBox(height: 4),
                LatexCard(latex: '\\int f \\, d${step.variable} = ${step.antiderivativeLatex}'),
                
                const SizedBox(height: 12),
                const Text('2. Evaluación de límites:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryCyan)),
                const SizedBox(height: 4),
                LatexCard(latex: step.evaluatedLatex),

                const SizedBox(height: 12),
                const Text('3. Resultado simplificado para la siguiente capa:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryCyan)),
                const SizedBox(height: 4),
                LatexCard(latex: step.simplifiedResultLatex, isHighlight: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _build3DViewportTab(SolverState state) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ThreeJsViewport(meshData: state.meshData),
    );
  }
}
