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

  // Campos para la experiencia didáctica premium tipo libro de texto (Foto del usuario):
  final String? stepTitle;              // ej: "Paso 1: Resolver la integral interna (con respecto a y)"
  final String? stepIntegralLatex;      // ej: r'\int_{0}^{x} 4xy \, dy'
  final String? constantTreatmentText;  // ej: "Tratamos a x como una constante e integramos respecto a y:"
  final String? antiderivativeWorkLatex;// ej: r'\int 4xy \, dy = 4x \left(\frac{y^2}{2}\right) = 2xy^2'
  final String? limitsEvaluationText;   // ej: "Ahora evaluamos en los límites y = 0 y y = x:"

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
    this.stepTitle,
    this.stepIntegralLatex,
    this.constantTreatmentText,
    this.antiderivativeWorkLatex,
    this.limitsEvaluationText,
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
      stepTitle: json['step_title'] as String?,
      stepIntegralLatex: json['step_integral_latex'] as String?,
      constantTreatmentText: json['constant_treatment_text'] as String?,
      antiderivativeWorkLatex: json['antiderivative_work_latex'] as String?,
      limitsEvaluationText: json['limits_evaluation_text'] as String?,
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
  final String? regionDefinition;

  const IntegralSolution({
    required this.isSuccess,
    required this.exactLatex,
    this.approxNumeric,
    this.steps = const [],
    this.originalIntegralLatex = '',
    this.errorMessage,
    this.executionTimeMs = 0.0,
    this.didacticSections,
    this.regionDefinition,
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
      regionDefinition: json['region_definition'] as String?,
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
      regionDefinition: regionDefinition,
    );
  }
}
