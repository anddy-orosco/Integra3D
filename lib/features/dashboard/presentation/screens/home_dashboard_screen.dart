import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/math_colors.dart';
import '../../../calculator/presentation/widgets/mat212_problem_builder.dart';
import '../../../ocr/presentation/widgets/ocr_scanner_sheet.dart';
import '../../../solver/domain/entities/integral_solution.dart';
import '../../../solver/presentation/providers/solver_provider.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../../core/utils/latex_sanitizer.dart';
import '../../../../core/utils/platform_responsive.dart';
import '../../../solver/presentation/widgets/latex_card.dart';
import '../../../visualization_3d/presentation/widgets/dual_visualization_viewport.dart';
import '../widgets/calculus_formulary_tab.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _desktopRightTabIndex = 0; // 0: 3D View, 1: Solución, 2: Formulario
  bool _desktopSplitView = false;

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
        _tabController.animateTo(1); // Saltar a la solución en móvil
        setState(() => _desktopRightTabIndex = 1); // Solución en escritorio
      },
    );
  }

  Future<void> _openAiConfigDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentKey = prefs.getString('integra3d_gemini_api_key') ??
        prefs.getString('integra3d_byok_gemini_key') ??
        prefs.getString('integra3d_openrouter_key') ??
        prefs.getString('integra3d_groq_key') ??
        '';

    if (!mounted) return;

    final controller = TextEditingController(text: currentKey);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.slateDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.auto_awesome, color: AppColors.cyberEmerald, size: 22),
              SizedBox(width: 8),
              Text(
                'Motor de IA Didáctica',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.pureWhite),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Integra3D funciona al 100% de forma autónoma y GRATUITA sin necesidad de ingresar ninguna clave. Si deseas conectar opcionalmente tu propia clave de Google Gemini, OpenRouter o Groq para enriquecer las explicaciones con modelos en la nube, puedes ingresarla a continuación.',
                  style: TextStyle(fontSize: 12, color: AppColors.pureWhite, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.deepVoid,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Proveedores recomendados 100% GRATIS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.electricCyan)),
                      SizedBox(height: 4),
                      Text('• Google AI Studio (Gemini 2.0/1.5 Flash): aistudio.google.com', style: TextStyle(fontSize: 10, color: AppColors.mutedGray)),
                      Text('• OpenRouter (Gemini, LLaMA, DeepSeek gratis): openrouter.ai', style: TextStyle(fontSize: 10, color: AppColors.mutedGray)),
                      Text('• Groq Cloud (LLaMA 3.3 70B ultra-rápido): console.groq.com', style: TextStyle(fontSize: 10, color: AppColors.mutedGray)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 12, color: AppColors.pureWhite, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'Clave de API (Gemini, OpenRouter o Groq)',
                    labelStyle: const TextStyle(color: AppColors.mutedGray, fontSize: 11),
                    hintText: 'AIzaSy... o sk-or-... o gsk_...',
                    hintStyle: const TextStyle(color: AppColors.mutedGray, fontSize: 11),
                    filled: true,
                    fillColor: AppColors.slateElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AppColors.mutedGray),
                      onPressed: () => controller.clear(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (currentKey.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await prefs.remove('integra3d_gemini_api_key');
                  await prefs.remove('integra3d_byok_gemini_key');
                  await prefs.remove('integra3d_openrouter_key');
                  await prefs.remove('integra3d_groq_key');
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clave eliminada. Modo autónomo local activo.')),
                    );
                  }
                },
                child: const Text('Eliminar', style: TextStyle(color: AppColors.coralFlame)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.mutedGray)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyberEmerald,
                foregroundColor: AppColors.deepVoid,
              ),
              onPressed: () async {
                final key = controller.text.trim();
                if (key.isNotEmpty) {
                  await prefs.setString('integra3d_gemini_api_key', key);
                  await prefs.setString('integra3d_byok_gemini_key', key);
                  if (key.startsWith('sk-or-')) {
                    await prefs.setString('integra3d_openrouter_key', key);
                  } else if (key.startsWith('gsk_')) {
                    await prefs.setString('integra3d_groq_key', key);
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Motor de IA configurado exitosamente.')),
                    );
                    ref.read(solverProvider.notifier).solve();
                  }
                } else {
                  await prefs.remove('integra3d_gemini_api_key');
                  await prefs.remove('integra3d_byok_gemini_key');
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
              child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
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
        titleSpacing: 12,
        title: Row(
          children: [
            // Logo Icono de la App
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.slateDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: mathColors.primaryAction.withAlpha(120), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: mathColors.primaryAction.withAlpha(35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(Icons.hub_rounded, color: mathColors.primaryAction, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Integra3D',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: mathColors.formulaText,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Cálculo Multivariable y Graficadora',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: mathColors.metadataText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Insignia Académica Elegante en el Costado Derecho: UPEA • Ingeniería de Sistemas
          Container(
            margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.slateElevated,
                  AppColors.slateDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cyberEmerald.withAlpha(140), width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.cyberEmerald.withAlpha(45),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.cyberEmerald, width: 0.8),
                  ),
                  child: const Text(
                    'UPEA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cyberEmerald,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.terminal_rounded, size: 11, color: AppColors.electricCyan),
                        SizedBox(width: 3),
                        Text(
                          'Ing. de Sistemas',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.pureWhite,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Univ. Pública de El Alto',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botón de Configuración de IA Didáctica
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.auto_awesome, size: 18, color: AppColors.cyberEmerald),
            tooltip: 'Configurar Motor de IA Didáctica',
            onPressed: _openAiConfigDialog,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isExpanded = constraints.maxWidth >= ResponsiveLayout.mediumBreakpoint;

            if (isExpanded) {
              return _buildDesktopWorkstation(context, state, notifier, mathColors, constraints);
            }

            return Column(
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
                      Tab(icon: Icon(Icons.menu_book_rounded, size: 16), text: 'Formulario'),
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
                      const CalculusFormularyTab(),
                      _build3DViewportTab(state),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopWorkstation(
    BuildContext context,
    SolverState state,
    SolverNotifier notifier,
    MathColors mathColors,
    BoxConstraints constraints,
  ) {
    final leftWidth = (constraints.maxWidth * 0.40).clamp(410.0, 480.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Panel Izquierdo: Editor Matemático & Problemas Modelo
        SizedBox(
          width: leftWidth,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.deepVoid,
              border: Border(
                right: BorderSide(color: AppColors.borderSubtle, width: 1.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header del Panel Izquierdo: Editor
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.slateDark,
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.edit_outlined, size: 15, color: AppColors.cyberEmerald),
                      SizedBox(width: 8),
                      Text(
                        'Editor',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.pureWhite,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Cálculo Multivariable',
                        style: TextStyle(fontSize: 10, color: AppColors.mutedGray),
                      ),
                    ],
                  ),
                ),
                _buildPresetBar(state, notifier, mathColors),
                Expanded(
                  child: _buildEditorTab(state, notifier, mathColors),
                ),
              ],
            ),
          ),
        ),

        // Panel Derecho: Workstation con Tabs de 3D/2D Viewport, Solución Paso a Paso y Formulario
        Expanded(
          child: Container(
            color: AppColors.deepVoid,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDesktopRightToolbar(mathColors, constraints.maxWidth),
                Expanded(
                  child: _desktopSplitView && constraints.maxWidth >= 1100
                      ? _buildDesktopSplitPanel(state, mathColors)
                      : switch (_desktopRightTabIndex) {
                          0 => _build3DViewportTab(state),
                          1 => _buildSolutionTab(state, mathColors),
                          2 => const CalculusFormularyTab(),
                          _ => _build3DViewportTab(state),
                        },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopRightToolbar(MathColors mathColors, double totalWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.slateDark,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildWorkstationTabButton(
              index: 0,
              icon: Icons.view_in_ar_rounded,
              label: '3D View',
              mathColors: mathColors,
            ),
            const SizedBox(width: 8),
            _buildWorkstationTabButton(
              index: 1,
              icon: Icons.functions_rounded,
              label: 'Solución',
              mathColors: mathColors,
            ),
            const SizedBox(width: 8),
            _buildWorkstationTabButton(
              index: 2,
              icon: Icons.menu_book_rounded,
              label: 'Formulario',
              mathColors: mathColors,
            ),
            if (totalWidth >= 1100) ...[
              const SizedBox(width: 16),
              Tooltip(
                message: _desktopSplitView
                    ? 'Desactivar vista dividida (Mostrar una sola pestaña)'
                    : 'Ver Sólido 3D y Solución simultáneamente',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _desktopSplitView = !_desktopSplitView),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _desktopSplitView
                          ? AppColors.cyberEmerald.withAlpha(40)
                          : AppColors.slateElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _desktopSplitView
                            ? AppColors.cyberEmerald
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.vertical_split_rounded,
                          size: 15,
                          color: _desktopSplitView
                              ? AppColors.cyberEmerald
                              : AppColors.mutedGray,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Doble Panel (3D + Solución)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _desktopSplitView
                                ? AppColors.cyberEmerald
                                : AppColors.pureWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkstationTabButton({
    required int index,
    required IconData icon,
    required String label,
    required MathColors mathColors,
  }) {
    final isSelected = _desktopRightTabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          _desktopRightTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.slateElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: mathColors.secondaryAccent.withAlpha(160), width: 1.2)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.pureWhite : mathColors.metadataText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.pureWhite : mathColors.metadataText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSplitPanel(SolverState state, MathColors mathColors) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _build3DViewportTab(state),
        ),
        Container(
          height: 1.5,
          color: AppColors.borderSubtle,
        ),
        Expanded(
          flex: 6,
          child: _buildSolutionTab(state, mathColors),
        ),
      ],
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
                setState(() => _desktopRightTabIndex = 1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditorTab(SolverState state, SolverNotifier notifier, MathColors mathColors) {
    return Mat212ProblemBuilder(
      initialIntegral: state.currentIntegral,
      onCameraOcr: _openOcrScanner,
      onSolve: (integral) {
        notifier.solveIntegralModel(integral);
        _tabController.animateTo(1);
        setState(() => _desktopRightTabIndex = 1);
      },
    );
  }

  String _formatFinalLatexResult(IntegralSolution solution) {
    if (!solution.isSuccess) {
      return r'\text{Integral Divergente / Sin Solución Real}';
    }
    final raw = solution.exactLatex.trim();
    if (raw.startsWith(r'\approx') || raw.startsWith('~')) {
      return 'I $raw';
    }
    if (raw.startsWith('=')) {
      return 'I $raw';
    }
    if (raw.startsWith(r'\text') || raw.startsWith('M =') || raw.startsWith('(')) {
      return raw;
    }
    return 'I = $raw';
  }

  Widget _buildSolutionTab(SolverState state, MathColors mathColors) {
    return state.solutionState.when(
      data: (solution) {
        if (solution == null) {
          return const Center(child: Text('Presiona Calcular en el Editor.'));
        }

        final bottomInset = MediaQuery.of(context).padding.bottom;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Original Integral
              LatexCard(
                title: 'Integral Planteada',
                latex: solution.originalIntegralLatex,
              ),

              // Definición Didáctica del Dominio / Región R
              if (solution.regionDefinition != null && solution.regionDefinition!.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.deepVoid.withAlpha(160),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    _formatInlineMath(solution.regionDefinition!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.pureWhite,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

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
                latex: _formatFinalLatexResult(solution),
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
              const SizedBox(height: 12),

              // Banner de Estado IA / Motor
              _buildAiStatusBanner(solution, mathColors),
              const SizedBox(height: 8),

              // Análisis del Dominio (domain_analysis)
              if (solution.domainAnalysis != null) ...[
                _buildDomainAnalysisCard(solution.domainAnalysis!, mathColors),
                const SizedBox(height: 12),
              ],

              // Conmutador Interactivo Visor Dual 2D / UV / 3D integrado en la pantalla de resolución
              if (state.currentIntegral.bounds.length >= 2 ||
                  state.currentIntegral.boundaryCurves.isNotEmpty ||
                  state.currentIntegral.verticesInput.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.slateDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: DualVisualizationViewport(
                    integral: state.currentIntegral,
                    solution: solution,
                    meshData: state.meshData,
                    fixedHeight: 330,
                  ),
                ),
              ],

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
                      icon: const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.mutedGray),
                      label: const Text('Ver Formulario', style: TextStyle(fontSize: 11, color: AppColors.mutedGray)),
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

              // Formulario y Métodos Empleados en este ejercicio
              if (solution.formulasAndMethods != null && solution.formulasAndMethods!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildFormulasAndMethodsSection(solution.formulasAndMethods!, mathColors),
              ],
            ],
          ),
        ),
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

  Widget _buildAiStatusBanner(IntegralSolution solution, MathColors mathColors) {
    final status = solution.aiStatus;
    if (status == null || status.isEmpty) return const SizedBox.shrink();

    final isAi = status.contains('✨');
    final isWarning = status.contains('⚠️');
    final color = isAi
        ? mathColors.secondaryAccent
        : (isWarning ? AppColors.amberGlow : mathColors.primaryAction);

    final icon = isAi
        ? Icons.auto_awesome_rounded
        : (isWarning ? Icons.warning_amber_rounded : Icons.bolt_rounded);

    return InkWell(
      onTap: _openAiConfigDialog,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(120), width: 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isWarning ? AppColors.amberGlow : AppColors.pureWhite,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.tune_rounded, size: 14, color: color.withAlpha(180)),
          ],
        ),
      ),
    );
  }

  String _getStepIntegralLabel(SolverStep step, int totalSteps) {
    if (step.stepTitle != null && step.stepTitle!.isNotEmpty) {
      final t = step.stepTitle!.toLowerCase();
      if (t.contains('orden')) return 'Integral planteada y transformación de región:';
      if (t.contains('sustitución') || t.contains('sustitucion')) return 'Integral a transformar:';
      if (t.contains('algebraica') || t.contains('expansión') || t.contains('reducción')) return 'Expresión algebraica:';
      if (t.contains('externa')) return 'La integral externa es:';
      if (t.contains('intermedia')) return 'La integral intermedia es:';
      if (t.contains('interna')) return 'La integral interna es:';
    }
    if (step.stepNumber == 1) return 'La integral interna es:';
    if (step.stepNumber == totalSteps) return 'La integral externa es:';
    return 'Integral del paso:';
  }

  Widget _buildFormulasAndMethodsSection(List<FormulaMethodCard> formulas, MathColors mathColors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slateDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mathColors.primaryAction.withAlpha(100), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mathColors.primaryAction.withAlpha(35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.menu_book_rounded, color: mathColors.primaryAction, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Formulario y Métodos Utilizados (${formulas.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: mathColors.formulaText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...formulas.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.deepVoid.withAlpha(160),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.functions_rounded, size: 14, color: mathColors.secondaryAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: mathColors.secondaryAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.formulaLatex.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    LatexCard(latex: item.formulaLatex),
                  ],
                  if (item.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: TextStyle(fontSize: 11, color: mathColors.metadataText, height: 1.4),
                    ),
                  ],
                  if (item.application != null && item.application!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cyberEmerald.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.cyberEmerald.withAlpha(60)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 12, color: AppColors.cyberEmerald),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Aplicación: ${item.application!}',
                              style: const TextStyle(fontSize: 10, color: AppColors.cyberEmerald, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _buildStepCards(IntegralSolution solution, MathColors mathColors) {
    return solution.steps.map((step) {
      final isZ = step.variable.toLowerCase() == 'z';
      final isY = step.variable.toLowerCase() == 'y';
      final isX = step.variable.toLowerCase() == 'x';
      final isU = step.variable.toLowerCase() == 'u';

      Color axisColor = mathColors.secondaryAccent;
      if (isZ) {
        axisColor = mathColors.axisZ;
      } else if (isY) {
        axisColor = mathColors.axisY;
      } else if (isX) {
        axisColor = mathColors.axisX;
      } else if (isU) {
        axisColor = AppColors.amberGlow;
      }

      final title = step.stepTitle ?? 'Paso ${step.stepNumber}';

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
            // Encabezado del Paso: Número + Título + Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: step.isLimitInverted ? AppColors.amberGlow : mathColors.primaryAction,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${step.stepNumber}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepVoid),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.pureWhite, height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (step.appliedMethod != null && step.appliedMethod!.isNotEmpty)
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
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: step.isLimitInverted ? AppColors.amberGlow : mathColors.secondaryAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (step.variable.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: axisColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: axisColor.withAlpha(120)),
                              ),
                              child: Text(
                                isU ? 'Variable u' : 'Eje ${step.variable.toUpperCase()}',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: axisColor),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Alerta de inversión en este paso si aplica
            if (step.isLimitInverted) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                        'Cotas invertidas: ${_formatInlineMath(step.lowerBoundLatex)} > ${_formatInlineMath(step.upperBoundLatex)}. Se aplicó la inversión canónica con factor (-1) preservando signos en F(b) - F(a).',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.amberGlow),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Planteamiento / Integral Inicial del Paso
            if (step.stepIntegralLatex != null && step.stepIntegralLatex!.trim().isNotEmpty) ...[
              Text(
                _getStepIntegralLabel(step, solution.steps.length),
                style: TextStyle(fontSize: 12, color: mathColors.metadataText, height: 1.4),
              ),
              const SizedBox(height: 6),
              LatexCard(latex: step.stepIntegralLatex!),
              const SizedBox(height: 10),
            ],

            // 2. Desarrollo del método / Antiderivada / Sustitución
            if (step.constantTreatmentText != null && step.constantTreatmentText!.trim().isNotEmpty) ...[
              Text(
                _formatInlineMath(step.constantTreatmentText!),
                style: TextStyle(fontSize: 12, color: mathColors.metadataText, height: 1.4),
              ),
              const SizedBox(height: 6),
            ],
            if (step.antiderivativeWorkLatex != null &&
                step.antiderivativeWorkLatex!.trim().isNotEmpty &&
                step.antiderivativeWorkLatex != step.stepIntegralLatex) ...[
              LatexCard(latex: step.antiderivativeWorkLatex!),
              const SizedBox(height: 10),
            ],

            // 3. Evaluación de Límites o aritmética de sustitución
            if (step.limitsEvaluationText != null && step.limitsEvaluationText!.trim().isNotEmpty) ...[
              Text(
                _formatInlineMath(step.limitsEvaluationText!),
                style: TextStyle(fontSize: 12, color: mathColors.metadataText, height: 1.4),
              ),
              const SizedBox(height: 6),
            ],
            if (step.evaluatedLatex.trim().isNotEmpty &&
                step.evaluatedLatex != step.antiderivativeWorkLatex &&
                step.evaluatedLatex != step.stepIntegralLatex) ...[
              LatexCard(latex: step.evaluatedLatex),
              const SizedBox(height: 10),
            ],

            // 4. Explicación didáctica
            if (step.explanation.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 2, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.deepVoid.withAlpha(110),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatInlineMath(step.explanation),
                  style: TextStyle(fontSize: 11, color: mathColors.metadataText.withAlpha(220), height: 1.45),
                ),
              ),
            ],

            // 5. Milestone / Expresión resultante del paso (Renderizado Matemático KaTeX)
            if (step.simplifiedResultLatex.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.deepVoid.withAlpha(160),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: mathColors.primaryAction.withAlpha(90)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 14, color: mathColors.primaryAction),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        step.stepNumber == solution.steps.length
                            ? 'Resultado final del cálculo:'
                            : 'Expresión para el Paso ${step.stepNumber + 1}:',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: mathColors.primaryAction),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Math.tex(
                            LatexSanitizer.sanitize(step.simplifiedResultLatex),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.pureWhite,
                            ),
                            onErrorFallback: (_) => Text(
                              _formatInlineMath(step.simplifiedResultLatex),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.pureWhite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  /// Limpia y formatea expresiones matemáticas que aparecen dentro de textos explicativos
  String _formatInlineMath(String text) {
    if (text.isEmpty) return text;
    var result = text;
    // Raíces cuadradas
    result = result.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'), (m) => '√(${m[1]})');
    result = result.replaceAllMapped(RegExp(r'\\sqrt\s*([a-zA-Z0-9])'), (m) => '√${m[1]}');
    // Fracciones simples \frac{a}{b} -> (a/b)
    result = result.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '(${m[1]}/${m[2]})');
    // Símbolos matemáticos
    result = result
        .replaceAll(r'\le', '≤')
        .replaceAll(r'\ge', '≥')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\mp', '∓')
        .replaceAll(r'\ne', '≠')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\sim', '~')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\rho', 'ρ')
        .replaceAll(r'\phi', 'φ')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\int', '∫')
        .replaceAll(r'\iint', '∬')
        .replaceAll(r'\iiint', '∭')
        .replaceAll(r'\oint', '∮');
    // Superíndices
    result = result
        .replaceAll('^{2}', '²')
        .replaceAll('^2', '²')
        .replaceAll('^{3}', '³')
        .replaceAll('^3', '³')
        .replaceAll('^{4}', '⁴')
        .replaceAll('^4', '⁴')
        .replaceAll('^{0}', '⁰')
        .replaceAll('^0', '⁰')
        .replaceAll('^{1}', '¹')
        .replaceAll('^1', '¹');
    // Funciones
    result = result
        .replaceAll(r'\sin', 'sin')
        .replaceAll(r'\cos', 'cos')
        .replaceAll(r'\tan', 'tan')
        .replaceAll(r'\sec', 'sec')
        .replaceAll(r'\csc', 'csc')
        .replaceAll(r'\cot', 'cot')
        .replaceAll(r'\ln', 'ln')
        .replaceAll(r'\log', 'log')
        .replaceAll(r'\exp', 'exp');
    return result;
  }

  Widget _buildDomainAnalysisCard(DomainAnalysis da, MathColors mathColors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slateDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mathColors.secondaryAccent.withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 16, color: mathColors.secondaryAccent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Análisis Geométrico del Dominio',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.pureWhite,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cyberEmerald.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.cyberEmerald.withAlpha(120)),
                ),
                child: Text(
                  da.regionType,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyberEmerald,
                  ),
                ),
              ),
            ],
          ),
          if (da.intersectionPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                const Text(
                  'Cortes:',
                  style: TextStyle(fontSize: 11, color: AppColors.mutedGray),
                ),
                ...da.intersectionPoints.map(
                  (pt) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.deepVoid,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.amberGlow.withAlpha(130)),
                    ),
                    child: Text(
                      '(${pt['x'] ?? '0'}, ${pt['y'] ?? '0'})',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.amberGlow,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (da.deducedLimitsLatex.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            LatexCard(latex: da.deducedLimitsLatex),
          ],
          if (da.jacobianLatex != null && da.jacobianLatex!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            LatexCard(title: 'Determinante Jacobiano', latex: da.jacobianLatex!),
          ],
        ],
      ),
    );
  }

  Widget _build3DViewportTab(SolverState state) {
    final solution = state.solutionState.asData?.value;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DualVisualizationViewport(
        integral: state.currentIntegral,
        solution: solution,
        meshData: state.meshData,
        initialMode: DualViewportMode.solid3D,
      ),
    );
  }
}
