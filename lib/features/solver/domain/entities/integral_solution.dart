class SolverStep {
  final int stepNumber;
  final String variable;
  final String lowerBoundLatex;
  final String upperBoundLatex;
  final String currentIntegrandLatex;
  final String antiderivativeLatex;
  final String evaluatedLatex;
  final String simplifiedResultLatex;
  final String explanation;
  final String? appliedMethod;
  final bool isLimitInverted;

  const SolverStep({
    required this.stepNumber,
    required this.variable,
    required this.lowerBoundLatex,
    required this.upperBoundLatex,
    required this.currentIntegrandLatex,
    required this.antiderivativeLatex,
    required this.evaluatedLatex,
    required this.simplifiedResultLatex,
    required this.explanation,
    this.appliedMethod,
    this.isLimitInverted = false,
  });

  factory SolverStep.fromJson(Map<String, dynamic> json) {
    return SolverStep(
      stepNumber: json['step_number'] as int? ?? 1,
      variable: json['variable'] as String? ?? '',
      lowerBoundLatex: json['lower_bound_latex'] as String? ?? '',
      upperBoundLatex: json['upper_bound_latex'] as String? ?? '',
      currentIntegrandLatex: json['current_integrand_latex'] as String? ?? '',
      antiderivativeLatex: json['antiderivative_latex'] as String? ?? '',
      evaluatedLatex: json['evaluated_latex'] as String? ?? '',
      simplifiedResultLatex: json['simplified_result_latex'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      appliedMethod: json['applied_method'] as String?,
      isLimitInverted: json['is_limit_inverted'] as bool? ?? false,
    );
  }
}

class PedagogicalSection {
  final String title;
  final String content;

  const PedagogicalSection({
    required this.title,
    required this.content,
  });

  factory PedagogicalSection.fromJson(Map<String, dynamic> json) {
    return PedagogicalSection(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

class IntegralSolution {
  final bool isSuccess;
  final String exactLatex;
  final double? approxNumeric;
  final List<SolverStep> steps;
  final String originalIntegralLatex;
  final String? errorMessage;
  final double executionTimeMs;
  final List<PedagogicalSection>? didacticSections;

  const IntegralSolution({
    required this.isSuccess,
    required this.exactLatex,
    this.approxNumeric,
    this.steps = const [],
    this.originalIntegralLatex = '',
    this.errorMessage,
    this.executionTimeMs = 0.0,
    this.didacticSections,
  });

  factory IntegralSolution.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'] as List<dynamic>? ?? [];
    return IntegralSolution(
      isSuccess: json['is_success'] as bool? ?? false,
      exactLatex: json['exact_latex'] as String? ?? '',
      approxNumeric: (json['approx_numeric'] as num?)?.toDouble(),
      steps: stepsJson.map((e) => SolverStep.fromJson(e as Map<String, dynamic>)).toList(),
      originalIntegralLatex: json['original_integral_latex'] as String? ?? '',
      errorMessage: json['error_message'] as String?,
      executionTimeMs: (json['execution_time_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }

  IntegralSolution copyWithDidactic(List<PedagogicalSection> sections) {
    return IntegralSolution(
      isSuccess: isSuccess,
      exactLatex: exactLatex,
      approxNumeric: approxNumeric,
      steps: steps,
      originalIntegralLatex: originalIntegralLatex,
      errorMessage: errorMessage,
      executionTimeMs: executionTimeMs,
      didacticSections: sections,
    );
  }
}
