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

class FormulaMethodCard {
  final String name;
  final String formulaLatex;
  final String description;
  final String? application;

  const FormulaMethodCard({
    required this.name,
    required this.formulaLatex,
    required this.description,
    this.application,
  });

  factory FormulaMethodCard.fromJson(Map<String, dynamic> json) {
    return FormulaMethodCard(
      name: json['name'] as String? ??
          json['nombre'] as String? ??
          json['method_name'] as String? ??
          json['titulo'] as String? ??
          'Método Matemático',
      formulaLatex: json['formula_latex'] as String? ??
          json['formula'] as String? ??
          json['latex'] as String? ??
          json['ecuacion'] as String? ??
          '',
      description: json['description'] as String? ??
          json['descripcion'] as String? ??
          json['desc'] as String? ??
          json['teoria'] as String? ??
          '',
      application: json['application'] as String? ??
          json['aplicacion'] as String? ??
          json['usage'] as String? ??
          json['uso'] as String? ??
          json['exercise_application'] as String?,
    );
  }
}

class DomainAnalysis {
  final String regionType; // "Type I", "Type II", "Polar", "UV_Jacobian", "Cylindrical", "Spherical"
  final List<Map<String, String>> intersectionPoints;
  final String deducedLimitsLatex;
  final String? jacobianLatex;
  final List<String> boundaryCurves;
  final String? alternateOrderLatex;
  final String? uvTransformSummary;
  final Map<String, dynamic>? uvData;

  const DomainAnalysis({
    required this.regionType,
    this.intersectionPoints = const [],
    this.deducedLimitsLatex = '',
    this.jacobianLatex,
    this.boundaryCurves = const [],
    this.alternateOrderLatex,
    this.uvTransformSummary,
    this.uvData,
  });

  factory DomainAnalysis.fromJson(Map<String, dynamic> json) {
    final rawPts = json['intersection_points'] as List<dynamic>? ?? [];
    final pts = rawPts
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
        .toList();

    final rawCurves = json['boundary_curves'] as List<dynamic>? ?? [];
    final curves = rawCurves.map((c) => c.toString()).toList();

    return DomainAnalysis(
      regionType: json['region_type'] as String? ?? 'Type I',
      intersectionPoints: pts,
      deducedLimitsLatex: json['deduced_limits_latex'] as String? ?? '',
      jacobianLatex: json['jacobian_latex'] as String?,
      boundaryCurves: curves,
      alternateOrderLatex: json['alternate_order_latex'] as String?,
      uvTransformSummary: json['uv_transform_summary'] as String?,
      uvData: json['uv_data'] is Map<String, dynamic>
          ? json['uv_data'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'region_type': regionType,
      'intersection_points': intersectionPoints,
      'deduced_limits_latex': deducedLimitsLatex,
      if (jacobianLatex != null) 'jacobian_latex': jacobianLatex,
      if (boundaryCurves.isNotEmpty) 'boundary_curves': boundaryCurves,
      if (alternateOrderLatex != null) 'alternate_order_latex': alternateOrderLatex,
      if (uvTransformSummary != null) 'uv_transform_summary': uvTransformSummary,
      if (uvData != null) 'uv_data': uvData,
    };
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
  final String? aiProvider;
  final String? aiStatus;
  final List<FormulaMethodCard>? formulasAndMethods;
  final DomainAnalysis? domainAnalysis;
  final Map<String, dynamic>? applicationSummary;

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
    this.aiProvider,
    this.aiStatus,
    this.formulasAndMethods,
    this.domainAnalysis,
    this.applicationSummary,
  });

  factory IntegralSolution.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'] as List<dynamic>? ?? [];
    final sectionsJson = (json['didactic_sections'] ?? json['sections']) as List<dynamic>? ?? [];
    final sections = sectionsJson
        .map((e) => PedagogicalSection.fromJson(e as Map<String, dynamic>))
        .toList();

    final formulasJson = (json['formulas_and_methods'] ?? json['methods_and_formulas'] ?? json['formulas']) as List<dynamic>? ?? [];
    final formulas = formulasJson
        .map((e) => FormulaMethodCard.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawDomain = json['domain_analysis'];
    final domainAnalysis = rawDomain is Map<String, dynamic>
        ? DomainAnalysis.fromJson(rawDomain)
        : null;

    final rawAppSummary = json['application_summary'];
    final appSummary = rawAppSummary is Map<String, dynamic> ? rawAppSummary : null;

    return IntegralSolution(
      isSuccess: json['is_success'] as bool? ?? false,
      exactLatex: json['exact_latex'] as String? ?? json['exact_result_latex'] as String? ?? '',
      approxNumeric: (json['approx_numeric'] as num?)?.toDouble() ??
          (json['decimal_result'] as num?)?.toDouble(),
      steps: stepsJson.map((e) => SolverStep.fromJson(e as Map<String, dynamic>)).toList(),
      originalIntegralLatex: json['original_integral_latex'] as String? ?? json['integral_latex'] as String? ?? '',
      errorMessage: json['error_message'] as String?,
      executionTimeMs: (json['execution_time_ms'] as num?)?.toDouble() ?? 0.0,
      didacticSections: sections.isNotEmpty ? sections : null,
      regionDefinition: json['region_definition'] as String?,
      aiProvider: json['ai_provider'] as String?,
      aiStatus: json['ai_status'] as String?,
      formulasAndMethods: formulas.isNotEmpty ? formulas : null,
      domainAnalysis: domainAnalysis,
      applicationSummary: appSummary,
    );
  }

  IntegralSolution copyWith({
    bool? isSuccess,
    String? exactLatex,
    double? approxNumeric,
    List<SolverStep>? steps,
    String? originalIntegralLatex,
    String? errorMessage,
    double? executionTimeMs,
    List<PedagogicalSection>? didacticSections,
    String? regionDefinition,
    String? aiProvider,
    String? aiStatus,
    List<FormulaMethodCard>? formulasAndMethods,
    DomainAnalysis? domainAnalysis,
    Map<String, dynamic>? applicationSummary,
  }) {
    return IntegralSolution(
      isSuccess: isSuccess ?? this.isSuccess,
      exactLatex: exactLatex ?? this.exactLatex,
      approxNumeric: approxNumeric ?? this.approxNumeric,
      steps: steps ?? this.steps,
      originalIntegralLatex: originalIntegralLatex ?? this.originalIntegralLatex,
      errorMessage: errorMessage ?? this.errorMessage,
      executionTimeMs: executionTimeMs ?? this.executionTimeMs,
      didacticSections: didacticSections ?? this.didacticSections,
      regionDefinition: regionDefinition ?? this.regionDefinition,
      aiProvider: aiProvider ?? this.aiProvider,
      aiStatus: aiStatus ?? this.aiStatus,
      formulasAndMethods: formulasAndMethods ?? this.formulasAndMethods,
      domainAnalysis: domainAnalysis ?? this.domainAnalysis,
      applicationSummary: applicationSummary ?? this.applicationSummary,
    );
  }

  IntegralSolution copyWithDidactic(List<PedagogicalSection> sections) {
    return copyWith(didacticSections: sections);
  }
}
