import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
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

    if (_integrandController.text != state.currentIntegral.integrand) {
      _integrandController.text = state.currentIntegral.integrand;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryBlue.withAlpha(80)),
              ),
              child: const Icon(Icons.architecture_rounded, color: AppTheme.primaryBlueLight, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Integra3D',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                ),
                Text(
                  'Cálculo Multivariable & Topología 3D',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted.withAlpha(200)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Engine Status Indicator Pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: state.isBackendConnected
                  ? AppTheme.accentEmerald.withAlpha(25)
                  : AppTheme.accentGold.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: state.isBackendConnected
                    ? AppTheme.accentEmerald.withAlpha(120)
                    : AppTheme.accentGold.withAlpha(120),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: state.isBackendConnected ? AppTheme.accentEmerald : AppTheme.accentGold,
                ),
                const SizedBox(width: 6),
                Text(
                  state.isBackendConnected ? 'SymPy CAS' : 'Motor Local',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: state.isBackendConnected ? AppTheme.accentEmerald : AppTheme.accentGold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded, size: 20, color: AppTheme.textMuted),
            tooltip: 'Sincronizar conexión',
            onPressed: () => notifier.checkConnectionAndSync(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preset problems bar
            _buildPresetBar(state, notifier),

            // Refined Segmented Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBlue.withAlpha(120), width: 1),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textMuted,
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

  Widget _buildPresetBar(SolverState state, SolverNotifier notifier) {
    if (state.presets.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
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
              backgroundColor: AppTheme.surfaceDark,
              side: const BorderSide(color: AppTheme.cardBorder),
              avatar: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${dim}D',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueLight),
                ),
              ),
              label: Text(
                name,
                style: const TextStyle(fontSize: 11, color: AppTheme.textLight, fontWeight: FontWeight.w500),
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

  Widget _buildEditorTab(SolverState state, SolverNotifier notifier) {
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
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => notifier.setDimension(2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: integral.dimension == 2 ? AppTheme.surfaceElevated : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: integral.dimension == 2 ? Border.all(color: AppTheme.primaryBlue.withAlpha(120)) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '∬ Integral Doble (2D)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: integral.dimension == 2 ? AppTheme.primaryBlueLight : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => notifier.setDimension(3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: integral.dimension == 3 ? AppTheme.surfaceElevated : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: integral.dimension == 3 ? Border.all(color: AppTheme.primaryBlue.withAlpha(120)) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '∭ Integral Triple (3D)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: integral.dimension == 3 ? AppTheme.primaryBlueLight : AppTheme.textMuted,
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
            decoration: const InputDecoration(
              labelText: 'Sistema de Coordenadas & Elemento de Volumen',
              prefixIcon: Icon(Icons.language_rounded, size: 18, color: AppTheme.primaryBlueLight),
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

          // Integrand input
          TextField(
            controller: _integrandController,
            decoration: const InputDecoration(
              labelText: 'Función Integrando f(x, y, z)',
              hintText: 'Ej: 4 - x^2 - y^2 o exp(-x^2 - y^2)',
              prefixIcon: Icon(Icons.calculate_outlined, size: 18, color: AppTheme.primaryBlueLight),
            ),
            onChanged: (val) => notifier.updateIntegrand(val),
          ),
          const SizedBox(height: 14),

          // Limits section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Límites de Integración Iterada:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
              Text(
                '${integral.dimension} variables',
                style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlueLight),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...List.generate(integral.bounds.length, (index) {
            final bound = integral.bounds[index];
            final orderLabel = index == 0
                ? 'Interior (Primero)'
                : (index == integral.bounds.length - 1 ? 'Exterior (Final)' : 'Intermedio');
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'd${bound.variable} — $orderLabel',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryBlueLight),
                      ),
                      Text('Capa ${index + 1}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
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
                      const SizedBox(width: 10),
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
            );
          }),
          const SizedBox(height: 12),

          // Primary Solve Button
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('RESOLVER Y GRAFICAR EN 3D'),
            onPressed: () {
              notifier.solve();
              _tabController.animateTo(1);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSolutionTab(SolverState state) {
    return state.solutionState.when(
      data: (solution) {
        if (solution == null) {
          return const Center(child: Text('Presiona Resolver en el Editor.'));
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
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(
                      'Tiempo: ${solution.executionTimeMs.toStringAsFixed(1)} ms',
                      style: const TextStyle(fontSize: 11, color: AppTheme.accentEmerald),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppTheme.cardBorder),
                    ),
                    icon: const Icon(Icons.view_in_ar_rounded, size: 14, color: AppTheme.primaryBlueLight),
                    label: const Text('Ver en 3D', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                    onPressed: () => _tabController.animateTo(3),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Conceptual Didactic sections
              if (solution.didacticSections != null && solution.didacticSections!.isNotEmpty) ...[
                const Text(
                  'Fundamento Teórico y Conceptual:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueLight),
                ),
                const SizedBox(height: 8),
                ...solution.didacticSections!.map((sec) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sec.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textLight),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sec.content,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                      ),
                    ],
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
            CircularProgressIndicator(color: AppTheme.primaryBlue),
            SizedBox(height: 14),
            Text('Procesando cálculo iterado...', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      ),
      error: (err, _) => Center(
        child: Text('Error: $err', style: const TextStyle(color: AppTheme.textMuted)),
      ),
    );
  }

  Widget _buildStepsTab(SolverState state) {
    final solution = state.solutionState.asData?.value;
    if (solution == null || solution.steps.isEmpty) {
      return const Center(
        child: Text('No hay pasos calculados aún.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: solution.steps.length,
      itemBuilder: (context, index) {
        final step = solution.steps[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${step.stepNumber}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Integración respecto a d${step.variable}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(step.explanation, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const Divider(color: AppTheme.cardBorder, height: 20),

              const Text('Antiderivada parcial:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryBlueLight)),
              const SizedBox(height: 4),
              LatexCard(latex: '\\int f \\, d${step.variable} = ${step.antiderivativeLatex}'),

              const SizedBox(height: 8),
              const Text('Evaluación en límites [a, b]:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryBlueLight)),
              const SizedBox(height: 4),
              LatexCard(latex: step.evaluatedLatex),

              const SizedBox(height: 8),
              const Text('Resultado simplificado:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentGold)),
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
