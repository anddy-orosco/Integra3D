import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../calculator/domain/entities/integration_bound.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../calculator/domain/services/local_math_engine.dart';
import '../../domain/entities/integral_solution.dart';
import '../../domain/services/math_ai_didactic_service.dart';
import '../../data/datasources/solver_remote_datasource.dart';

final solverDataSourceProvider = Provider<SolverRemoteDataSource>((ref) {
  return SolverRemoteDataSourceImpl();
});

final mathAiDidacticServiceProvider = Provider<MathAiDidacticService>((ref) {
  return MathAiDidacticService();
});

class SolverState {
  final MultivariableIntegral currentIntegral;
  final AsyncValue<IntegralSolution?> solutionState;
  final Map<String, dynamic>? meshData;
  final List<Map<String, dynamic>> presets;
  final int activeTabIndex;
  final bool isBackendConnected;

  const SolverState({
    required this.currentIntegral,
    required this.solutionState,
    this.meshData,
    this.presets = const [],
    this.activeTabIndex = 0,
    this.isBackendConnected = false,
  });

  SolverState copyWith({
    MultivariableIntegral? currentIntegral,
    AsyncValue<IntegralSolution?>? solutionState,
    Map<String, dynamic>? meshData,
    List<Map<String, dynamic>>? presets,
    int? activeTabIndex,
    bool? isBackendConnected,
  }) {
    return SolverState(
      currentIntegral: currentIntegral ?? this.currentIntegral,
      solutionState: solutionState ?? this.solutionState,
      meshData: meshData ?? this.meshData,
      presets: presets ?? this.presets,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      isBackendConnected: isBackendConnected ?? this.isBackendConnected,
    );
  }

  factory SolverState.initial() {
    final initialIntegral = const MultivariableIntegral(
      integrand: '4 - x^2 - y^2',
      bounds: [
        IntegrationBound(variable: 'y', lower: '-sqrt(4 - x^2)', upper: 'sqrt(4 - x^2)'),
        IntegrationBound(variable: 'x', lower: '-2', upper: '2'),
      ],
      coordinateSystem: CoordinateSystemType.cartesian,
    );

    // Initial pre-calculated solution for instantaneous display
    final initialSol = LocalMathEngine.solveLocal(initialIntegral);
    final initialMesh = LocalMathEngine.generateLocalMesh(initialIntegral);

    return SolverState(
      currentIntegral: initialIntegral,
      solutionState: AsyncData(initialSol),
      meshData: initialMesh,
      presets: LocalMathEngine.builtInPresets,
      activeTabIndex: 0,
      isBackendConnected: false,
    );
  }
}

class SolverNotifier extends Notifier<SolverState> {
  late final SolverRemoteDataSource _dataSource;
  late final MathAiDidacticService _aiDidacticService;

  @override
  SolverState build() {
    _dataSource = ref.watch(solverDataSourceProvider);
    _aiDidacticService = ref.watch(mathAiDidacticServiceProvider);
    // Background health check & preset sync
    Future.microtask(() => checkConnectionAndSync());
    return SolverState.initial();
  }

  Future<void> checkConnectionAndSync() async {
    try {
      final isConnected = await _dataSource.checkBackendHealth();
      final presets = await _dataSource.getPresets();
      state = state.copyWith(
        isBackendConnected: isConnected,
        presets: presets.isNotEmpty ? presets : state.presets,
      );
    } catch (_) {}
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeTabIndex: index);
  }

  void updateIntegrand(String text) {
    state = state.copyWith(
      currentIntegral: state.currentIntegral.copyWith(integrand: text),
    );
  }

  void updateBound(int index, {String? variable, String? lower, String? upper}) {
    final updatedBounds = List<IntegrationBound>.from(state.currentIntegral.bounds);
    if (index >= 0 && index < updatedBounds.length) {
      updatedBounds[index] = updatedBounds[index].copyWith(
        variable: variable,
        lower: lower,
        upper: upper,
      );
      state = state.copyWith(
        currentIntegral: state.currentIntegral.copyWith(bounds: updatedBounds),
      );
    }
  }

  void setDimension(int dim) {
    if (dim == 2) {
      final newIntegral = MultivariableIntegral(
        integrand: '4 - x^2 - y^2',
        bounds: const [
          IntegrationBound(variable: 'y', lower: '-sqrt(4 - x^2)', upper: 'sqrt(4 - x^2)'),
          IntegrationBound(variable: 'x', lower: '-2', upper: '2'),
        ],
        coordinateSystem: state.currentIntegral.coordinateSystem,
      );
      state = state.copyWith(currentIntegral: newIntegral);
      solve();
    } else if (dim == 3) {
      final newIntegral = const MultivariableIntegral(
        integrand: '1',
        bounds: [
          IntegrationBound(variable: 'z', lower: '0', upper: '1 - x - y'),
          IntegrationBound(variable: 'y', lower: '0', upper: '1 - x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      );
      state = state.copyWith(currentIntegral: newIntegral);
      solve();
    }
  }

  void setCoordinateSystem(CoordinateSystemType system) {
    state = state.copyWith(
      currentIntegral: state.currentIntegral.copyWith(coordinateSystem: system),
    );
  }

  void loadPreset(Map<String, dynamic> preset) {
    final rawBounds = (preset['bounds'] as List<dynamic>?) ?? [];
    final bounds = rawBounds
        .map((b) => IntegrationBound.fromJson(b as Map<String, dynamic>))
        .toList();

    CoordinateSystemType coordType = CoordinateSystemType.cartesian;
    final coordStr = preset['coordinate_system'] as String? ?? 'cartesian';
    if (coordStr == 'cylindrical') {
      coordType = CoordinateSystemType.cylindrical;
    } else if (coordStr == 'spherical') {
      coordType = CoordinateSystemType.spherical;
    }

    state = state.copyWith(
      currentIntegral: MultivariableIntegral(
        integrand: preset['integrand'] as String? ?? '1',
        bounds: bounds,
        coordinateSystem: coordType,
      ),
    );

    solve();
  }

  Future<void> solve() async {
    state = state.copyWith(solutionState: const AsyncLoading());

    try {
      final results = await Future.wait([
        _dataSource.solveIntegral(state.currentIntegral),
        _dataSource.getMesh(state.currentIntegral),
        _dataSource.getExplanation(state.currentIntegral),
      ]);

      var solution = results[0] as IntegralSolution;
      final mesh = results[1] as Map<String, dynamic>;
      final explanation = results[2] as List<PedagogicalSection>;

      if (explanation.isNotEmpty) {
        solution = solution.copyWithDidactic(explanation);
      }

      // Hybrid Architecture: AI Didactic Enrichment guided by exact mathematical checkpoints
      solution = await _aiDidacticService.enrichWithPedagogy(
        integral: state.currentIntegral,
        baseSolution: solution,
      );

      state = state.copyWith(
        solutionState: AsyncData(solution),
        meshData: mesh.isNotEmpty ? mesh : LocalMathEngine.generateLocalMesh(state.currentIntegral),
      );
    } catch (e) {
      // In extreme cases, local fallback is 100% resilient
      var fallbackSol = LocalMathEngine.solveLocal(state.currentIntegral);
      try {
        fallbackSol = await _aiDidacticService.enrichWithPedagogy(
          integral: state.currentIntegral,
          baseSolution: fallbackSol,
        );
      } catch (_) {}

      final fallbackMesh = LocalMathEngine.generateLocalMesh(state.currentIntegral);
      state = state.copyWith(
        solutionState: AsyncData(fallbackSol),
        meshData: fallbackMesh,
      );
    }
  }
}

final solverProvider = NotifierProvider<SolverNotifier, SolverState>(SolverNotifier.new);
