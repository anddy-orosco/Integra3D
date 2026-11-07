import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../calculator/domain/entities/integration_bound.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../domain/entities/integral_solution.dart';
import '../../data/datasources/solver_remote_datasource.dart';

final solverDataSourceProvider = Provider<SolverRemoteDataSource>((ref) {
  return SolverRemoteDataSourceImpl();
});

class SolverState {
  final MultivariableIntegral currentIntegral;
  final AsyncValue<IntegralSolution?> solutionState;
  final Map<String, dynamic>? meshData;
  final List<Map<String, dynamic>> presets;
  final int activeTabIndex;

  const SolverState({
    required this.currentIntegral,
    required this.solutionState,
    this.meshData,
    this.presets = const [],
    this.activeTabIndex = 0,
  });

  SolverState copyWith({
    MultivariableIntegral? currentIntegral,
    AsyncValue<IntegralSolution?>? solutionState,
    Map<String, dynamic>? meshData,
    List<Map<String, dynamic>>? presets,
    int? activeTabIndex,
  }) {
    return SolverState(
      currentIntegral: currentIntegral ?? this.currentIntegral,
      solutionState: solutionState ?? this.solutionState,
      meshData: meshData ?? this.meshData,
      presets: presets ?? this.presets,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
    );
  }

  factory SolverState.initial() {
    return const SolverState(
      currentIntegral: MultivariableIntegral(
        integrand: '4 - x**2 - y**2',
        bounds: [
          IntegrationBound(variable: 'y', lower: '-sqrt(4 - x**2)', upper: 'sqrt(4 - x**2)'),
          IntegrationBound(variable: 'x', lower: '-2', upper: '2'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      ),
      solutionState: AsyncData(null),
      meshData: null,
      presets: [],
      activeTabIndex: 0,
    );
  }
}

class SolverNotifier extends Notifier<SolverState> {
  late final SolverRemoteDataSource _dataSource;

  @override
  SolverState build() {
    _dataSource = ref.watch(solverDataSourceProvider);
    // Asynchronously load presets after initial build
    Future.microtask(() => _loadPresets());
    return SolverState.initial();
  }

  Future<void> _loadPresets() async {
    try {
      final presets = await _dataSource.getPresets();
      if (presets.isNotEmpty) {
        state = state.copyWith(presets: presets);
      }
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
      state = state.copyWith(
        currentIntegral: MultivariableIntegral(
          integrand: state.currentIntegral.integrand,
          bounds: [
            const IntegrationBound(variable: 'y', lower: '0', upper: '1'),
            const IntegrationBound(variable: 'x', lower: '0', upper: '1'),
          ],
          coordinateSystem: state.currentIntegral.coordinateSystem,
        ),
      );
    } else if (dim == 3) {
      state = state.copyWith(
        currentIntegral: MultivariableIntegral(
          integrand: '1',
          bounds: [
            const IntegrationBound(variable: 'z', lower: '0', upper: '1 - x - y'),
            const IntegrationBound(variable: 'y', lower: '0', upper: '1 - x'),
            const IntegrationBound(variable: 'x', lower: '0', upper: '1'),
          ],
          coordinateSystem: state.currentIntegral.coordinateSystem,
        ),
      );
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
      solutionState: const AsyncData(null),
      meshData: null,
    );

    // Auto solve preset for quick demonstration
    solve();
  }

  Future<void> solve() async {
    state = state.copyWith(solutionState: const AsyncLoading());

    try {
      // Execute solution, mesh generation and didactic explanation concurrently
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

      state = state.copyWith(
        solutionState: AsyncData(solution),
        meshData: mesh.isNotEmpty ? mesh : null,
      );
    } catch (e, stack) {
      state = state.copyWith(
        solutionState: AsyncError(e, stack),
      );
    }
  }
}

final solverProvider = NotifierProvider<SolverNotifier, SolverState>(SolverNotifier.new);
