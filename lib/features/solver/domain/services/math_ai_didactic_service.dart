import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../entities/integral_solution.dart';

/// Servicio didáctico de IA para Integra3D.
/// Implementa la arquitectura híbrida: Motor Simbólico + IA Pedagógica.
/// Envía la integral en notación matemática rigurosa a un LLM (Gemini Flash, Groq Cloud u OpenRouter)
/// para empaquetar cada fase de la resolución en tarjetas ordenadas ("cuadros") estilo libro de texto.
class MathAiDidacticService {
  static const String _defaultEnvKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _communityGeminiPool = String.fromEnvironment(
    'COMMUNITY_GEMINI_KEY',
    defaultValue: '',
  );

  final Dio _dio;

  MathAiDidacticService({Dio? dioClient})
      : _dio = dioClient ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 35),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  static const String didacticSystemPrompt = r'''
Eres un profesor universitario titular de Cálculo Multivariable y Álgebra Simbólica.
Tu tarea es resolver y redactar el desarrollo paso a paso y la explicación pedagógica con máxima elegancia didáctica, rigor y claridad (estilo libro de texto de James Stewart / Larson / Thomas).

METODOLOGÍA OBLIGATORIA EN DOS FASES:
FASE 1 (Resolución Interna Previa y Conteo de Pasos):
- Primero resuelve todo el ejercicio internamente de principio a fin en tu proceso de pensamiento hasta obtener el resultado exacto.
- Analiza cuántos pasos matemáticos reales y necesarios te tomó resolverlo.
- ¡NO HAY UNA CANTIDAD DE PASOS DEFINIDA! La cantidad de paquetes de pasos en "steps" es 100% DINÁMICA y VARIABLE según la dificultad del ejercicio:
  * Si la integral es directa o inmediata: te tomará de 3 a 5 pasos.
  * Si requiere expansión de polinomios, binomios, productos distributivos o fracciones: te tomará de 5 a 7 pasos.
  * Si requiere cambio de orden de integración (Teorema de Fubini inverso), método de sustitución (u-sustitución), partes o identidades trigonométricas: te tomará 7, 8, 9, 10 o más pasos.
  * Si requiere cambio a coordenadas polares/cilíndricas/esféricas con factor Jacobiano r: te tomará de 6 a 9 pasos.
- NUNCA fuerces ni limites la solución a un número prefijado (como 3 o 6 pasos). Genera exactamente los paquetes necesarios para que un estudiante comprenda todo el procedimiento de principio a fin.

FASE 2 (Empaquetado de cada Paso para la Aplicación):
- Una vez resuelto el ejercicio, empaqueta CADA PASO individualmente en un objeto de paquete ordenado dentro del array "steps".
- La aplicación móvil contará estos pasos y creará exactamente UN CUADRO didáctico por cada paquete que envíes.
- Cada paquete de paso debe incluir:
  {
    "step_number": 1,
    "step_title": "Paso 1: [Título claro de la acción]",
    "constant_treatment_text": "Qué estás haciendo en este paso: tratamiento de variables como constantes, método aplicado o justificación geométrica.",
    "step_integral_latex": "Fórmula matemática o integral planteada en este paso en LaTeX puro.",
    "antiderivative_work_latex": "Fórmula del desarrollo matemático, antiderivada o sustitución calculada.",
    "limits_evaluation_text": "Texto explicativo de la evaluación en cotas o reemplazo de límites (si aplica).",
    "evaluated_latex": "Fórmula de la evaluación aritmética en los límites F(b) - F(a) o resultado de la sustitución.",
    "simplified_result_latex": "Expresión resultante tras este paso (la que alimenta al paso siguiente o el resultado final).",
    "explanation": "Explicación conceptual clara de por qué se realizó este paso.",
    "applied_method": "Nombre del teorema o regla aplicada (ej. Teorema de Fubini, u-Sustitución, Regla de la Potencia, etc.)",
    "variable": "Variable del paso (x, y, z o u)",
    "is_limit_inverted": false
  }

REGLAS MATEMÁTICAS INQUEBRANTABLES:
1. Responde ÚNICAMENTE con un objeto JSON válido (sin bloques ```json ni texto adicional fuera del JSON).
2. Usa notación LaTeX pura para todas las fórmulas matemáticas. Escapa siempre las barras invertidas dentro de cadenas JSON (ej. \\int, \\frac, \\left, \\right).
3. Si la integral no admite primitiva elemental en el orden dado (por ejemplo \int y \cos(x^3) dx dy, y e^x / x, y^3 e^x / x^2, x^3 \sin(y^3), e^{x^4}, \sin(y)/y, \tan(x^2), e^{y/x}, x\sqrt{1+y^3}), APLICA OBLIGATORIAMENTE el cambio de orden de integración (Fubini inverso) transformando la región R.
4. Para coordenadas polares (x^2+y^2=a^2, x^2+y^2=2ax, r=1+\cos\theta), cilíndricas (incluyendo permutaciones de ejes como y^2+z^2=r^2), esféricas (\rho^2\sin\phi, elipsoides reescalados, (x^2+y^2+z^2)^2=a^3x) o cambios de variable (u, v), muestra explícitamente el determinante Jacobiano y conserva las constantes simbólicas positivas (a, b, c, m, n, R, H, k).
5. NUNCA uses letras abstractas ni funciones ficticias vacías como A(x) o B(y). Escribe siempre las expresiones explícitas completas en LaTeX puro.
6. NUNCA inventes números ni signos; sé exacto con las fracciones irreducibles y constantes.

OBJETO OPCIONAL DE ANÁLISIS DE DOMINIO ("domain_analysis"):
Incluye cuando aplique el objeto estructurado "domain_analysis":
{
  "region_type": "Type I | Type II | Polar | UV_Jacobian | Cylindrical | Spherical",
  "intersection_points": [{"x": "0", "y": "0"}, {"x": "2", "y": "4"}],
  "deduced_limits_latex": "Explicación en KaTeX de cómo se despejaron las cotas inferiores y superiores a partir de las gráficas 2D/3D.",
  "jacobian_latex": "Desarrollo del determinante Jacobiano cuando aplique (null si es cartesiana directa)."
}

APARTADO OBLIGATORIO DE FORMULARIO Y MÉTODOS ("formulas_and_methods"):
Incluye OBLIGATORIAMENTE un array con los teoremas, fórmulas de cálculo e identidades matemáticas empleadas en el ejercicio:
[
  {
    "name": "Nombre canónico del teorema o regla (ej. Teorema de Fubini)",
    "formula_latex": "Fórmula teórica general en LaTeX puro (ej. \\iint_R f dA = \\int_a^b \\int_{g_1}^{g_2} f dy dx)",
    "description": "Explicación conceptual y teórica del método o teorema",
    "application": "Cómo y en qué paso específico se aplicó en este ejercicio"
  }
]

ESTRUCTURA GENERAL DE LA RESPUESTA JSON:
{
  "integral_latex": "string con la integral en LaTeX",
  "region_definition": "Esta integral está definida sobre la región donde...",
  "domain_analysis": { ... },
  "steps": [ ... ],
  "formulas_and_methods": [ ... ],
  "sections": [
    { "title": "1. Interpretación Geométrica y Planteamiento", "content": "..." },
    { "title": "2. Orden de Integración y Teorema de Fubini", "content": "..." },
    { "title": "3. Conclusión y Verificación del Resultado", "content": "..." }
  ],
  "exact_result_latex": "resultado exacto en LaTeX",
  "decimal_result": 0.0
}
''';

  Future<String?> _getEffectiveApiKey() async {
    if (_defaultEnvKey.isNotEmpty) return _defaultEnvKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final candidateKeys = [
        'integra3d_gemini_api_key',
        'integra3d_byok_gemini_key',
        'integra3d_openrouter_key',
        'integra3d_groq_key',
        'integra3d_ai_api_key',
      ];
      for (final k in candidateKeys) {
        final val = prefs.getString(k);
        if (val != null && val.trim().isNotEmpty) return val.trim();
      }
    } catch (_) {}
    if (_communityGeminiPool.isNotEmpty) {
      return _communityGeminiPool;
    }
    return null;
  }

  /// Enriquece la solución matemática con la redacción didáctica y paquetes de pasos de IA.
  /// Prioriza el uso de APIs gratuitas y el motor autónomo sin exigir clave al estudiante.
  Future<IntegralSolution> enrichWithPedagogy({
    required MultivariableIntegral integral,
    required IntegralSolution baseSolution,
  }) async {
    if (!baseSolution.isSuccess) {
      return baseSolution;
    }

    String? lastError;
    bool hasCustomKey = false;
    try {
      final apiKey = await _getEffectiveApiKey();
      hasCustomKey = apiKey != null && apiKey.isNotEmpty;

      // Preparar descripción rigurosa de la integral
      final boundsDesc = integral.bounds
          .map((b) => '${b.variable} desde ${b.lower} hasta ${b.upper}')
          .join(', ');

      final String referenceInfo;
      if (baseSolution.exactLatex.isNotEmpty &&
          !baseSolution.exactLatex.contains('A(') &&
          !baseSolution.exactLatex.contains('approx')) {
        referenceInfo = 'Resultado exacto de referencia verificado: ${baseSolution.exactLatex}';
      } else if (baseSolution.approxNumeric != null) {
        referenceInfo = 'Aproximación numérica de referencia: ≈ ${baseSolution.approxNumeric}';
      } else {
        referenceInfo = '';
      }

      final userPrompt = '''
METODOLOGÍA OBLIGATORIA EN DOS FASES:
FASE 1: Resuelve primero todo el ejercicio en tu interior de principio a fin hasta encontrar el resultado exacto.
        Determina cuántos pasos matemáticos lógicos y necesarios te tomó resolverlo (pueden ser 3, 5, 7, 8, 10 o más pasos según la dificultad; NO hay una cantidad fija de pasos).
FASE 2: Empaqueta cada paso individualmente en orden dentro del array "steps". La aplicación móvil contará estos pasos y creará exactamente un cuadro didáctico por cada paquete.
        En cada paquete incluye:
        - "step_number": número del paso (1, 2, 3...)
        - "step_title": título claro de la acción de este paso
        - "constant_treatment_text": qué estás haciendo en este paso (método, tratamiento de variables, etc.)
        - "step_integral_latex": la fórmula en LaTeX de la integral planteada o desarrollo del paso
        - "antiderivative_work_latex": la fórmula de la antiderivada calculada o sustitución
        - "limits_evaluation_text": texto de evaluación en límites o cambio de cotas
        - "evaluated_latex": fórmula del cálculo en límites F(b) - F(a)
        - "simplified_result_latex": expresión resultante tras este paso (que alimenta al siguiente paso)
        - "explanation": explicación pedagógica concisa de este paso
        - "applied_method": nombre del método o teorema matemático aplicado

DATOS DEL EJERCICIO A RESOLVER:
- Integral planteada: ${baseSolution.originalIntegralLatex.isNotEmpty ? baseSolution.originalIntegralLatex : integral.integrand}
- Integrando: ${integral.integrand}
- Cotas y límites: $boundsDesc
- Sistema de coordenadas: ${integral.coordinateSystem.name} (${integral.dimension}D)
$referenceInfo

REQUISITOS FUNDAMENTALES:
1. FORMULARIO Y MÉTODOS ("formulas_and_methods"): Incluye OBLIGATORIAMENTE el array con los teoremas, identidades y reglas teóricas generales empleadas (con name, formula_latex, description, application).
2. ANÁLISIS DE DOMINIO ("domain_analysis"): Incluye region_type ("Type I", "Type II", "Polar", "UV_Jacobian", "Cylindrical", "Spherical"), intersection_points, deduced_limits_latex y jacobian_latex si aplica.
3. SIN FUNCIONES VACÍAS: Prohibido usar funciones ficticias abstractas como A(x) o B(y). Escribe todas las fórmulas explícitas completas en LaTeX puro.
''';

      Map<String, dynamic>? aiJson;
      String providerName = 'IA Didáctica';

      if (hasCustomKey) {
        if (apiKey.startsWith('gsk_')) {
          providerName = 'Groq Cloud (Llama 3.3)';
          final res = await _callGroq(userPrompt, apiKey);
          aiJson = res.$1;
          lastError = res.$2;
        } else if (apiKey.startsWith('sk-or-')) {
          providerName = 'OpenRouter';
          final res = await _callOpenRouter(userPrompt, apiKey);
          aiJson = res.$1;
          lastError = res.$2;
        } else {
          providerName = 'Gemini 2.0 Flash';
          final res = await _callGemini(userPrompt, apiKey);
          aiJson = res.$1;
          lastError = res.$2;
        }
      } else {
        // Prioridad 1: Proveedor de IA Gratuito sin requerir clave de API al estudiante
        final freeRes = await _callFreeAI(userPrompt);
        if (freeRes.$1 != null) {
          providerName = 'IA Gratuita';
          aiJson = freeRes.$1;
        }
      }

      final stepsKeyCandidates = [
        'steps',
        'pasos',
        'solution_steps',
        'procedimiento',
        'pasos_solucion',
        'paso_a_paso',
      ];
      List<dynamic>? rawSteps;
      if (aiJson != null) {
        for (final k in stepsKeyCandidates) {
          if (aiJson[k] is List && (aiJson[k] as List).isNotEmpty) {
            rawSteps = aiJson[k] as List<dynamic>;
            break;
          }
        }
      }

      if (aiJson != null && rawSteps != null && rawSteps.isNotEmpty) {
        final aiSteps = <SolverStep>[];

        for (int i = 0; i < rawSteps.length; i++) {
          final rawItem = rawSteps[i];
          if (rawItem is! Map<String, dynamic>) continue;
          final s = rawItem;
          final baseStep = (i < baseSolution.steps.length) ? baseSolution.steps[i] : null;

          String getField(List<String> keys, String? fallback) {
            for (final k in keys) {
              final v = s[k];
              if (v is String && v.trim().isNotEmpty) return v.trim();
            }
            return fallback ?? '';
          }

          int parseStepNum() {
            for (final k in const ['step_number', 'paso', 'numero']) {
              final rawVal = s[k];
              if (rawVal is int) return rawVal;
              if (rawVal is num) return rawVal.toInt();
              if (rawVal is String) {
                final parsed = int.tryParse(rawVal.trim());
                if (parsed != null) return parsed;
              }
            }
            return baseStep?.stepNumber ?? (i + 1);
          }

          final stepNum = parseStepNum();
          final title = getField(['step_title', 'title', 'titulo', 'nombre', 'name'], baseStep?.stepTitle ?? 'Paso $stepNum');
          final method = getField(['applied_method', 'method', 'metodo', 'regla', 'rule', 'teorema'], baseStep?.appliedMethod);
          final variable = getField(['variable', 'var', 'eje', 'axis'], baseStep?.variable ?? '');
          final stepIntegral = getField(['step_integral_latex', 'integral_latex', 'formula', 'math_latex', 'integral', 'planteamiento'], baseStep?.stepIntegralLatex);
          final constantTreatment = getField(['constant_treatment_text', 'treatment', 'tratamiento', 'description', 'explicacion_pre', 'desarrollo'], baseStep?.constantTreatmentText);
          final antiderivativeWork = getField(['antiderivative_work_latex', 'antiderivative_latex', 'antiderivada', 'primitiva', 'work_latex', 'development_latex'], baseStep?.antiderivativeWorkLatex);
          final limitsEvaluation = getField(['limits_evaluation_text', 'evaluation_text', 'evaluacion', 'limites', 'limits_text'], baseStep?.limitsEvaluationText);
          final evaluated = getField(['evaluated_latex', 'evaluation_latex', 'evaluado', 'evaluated'], baseStep?.evaluatedLatex);
          final simplified = getField(['simplified_result_latex', 'result_latex', 'resultado', 'intermediate_result', 'result'], baseStep?.simplifiedResultLatex);
          final explanation = getField(['explanation', 'explicacion', 'detail', 'detalle', 'comentario'], baseStep?.explanation);
          final isInverted = (s['is_limit_inverted'] as bool?) ?? (s['invertido'] as bool?) ?? (baseStep?.isLimitInverted ?? false);

          aiSteps.add(
            SolverStep(
              stepNumber: i + 1,
              variable: variable,
              lowerBoundLatex: getField(['lower_bound_latex'], baseStep?.lowerBoundLatex),
              upperBoundLatex: getField(['upper_bound_latex'], baseStep?.upperBoundLatex),
              currentIntegrandLatex: getField(['current_integrand_latex'], baseStep?.currentIntegrandLatex),
              antiderivativeLatex: getField(['antiderivative_latex'], baseStep?.antiderivativeLatex),
              evaluatedLatex: evaluated,
              simplifiedResultLatex: simplified,
              explanation: explanation,
              appliedMethod: method.isNotEmpty ? method : null,
              isLimitInverted: isInverted,
              stepTitle: title,
              stepIntegralLatex: stepIntegral.isNotEmpty ? stepIntegral : null,
              constantTreatmentText: constantTreatment.isNotEmpty ? constantTreatment : null,
              antiderivativeWorkLatex: antiderivativeWork.isNotEmpty ? antiderivativeWork : null,
              limitsEvaluationText: limitsEvaluation.isNotEmpty ? limitsEvaluation : null,
            ),
          );
        }

        // Nunca degradar una resolución local detallada (5+ pasos) a un resumen de 2 pasos
        final bool aiWasTooSummarized = integral.dimension >= 2 &&
            aiSteps.length <= 2 &&
            baseSolution.steps.length > aiSteps.length;
        final finalSteps = aiWasTooSummarized ? baseSolution.steps : (aiSteps.isNotEmpty ? aiSteps : baseSolution.steps);

        final rawSections = (aiJson['sections'] as List<dynamic>?) ?? [];
        final sections = rawSections
            .whereType<Map<String, dynamic>>()
            .map(PedagogicalSection.fromJson)
            .toList();

        final formulaKeyCandidates = [
          'formulas_and_methods',
          'methods_and_formulas',
          'formulas',
          'metodos',
          'formulario',
          'theorems',
          'theoretical_formulas',
          'formulas_y_metodos',
          'metodos_usados',
          'formulas_utilizadas',
        ];
        List<dynamic>? rawFormulas;
        for (final k in formulaKeyCandidates) {
          if (aiJson[k] is List && (aiJson[k] as List).isNotEmpty) {
            rawFormulas = aiJson[k] as List<dynamic>;
            break;
          }
        }
        var formulas = (rawFormulas ?? [])
            .whereType<Map<String, dynamic>>()
            .map(FormulaMethodCard.fromJson)
            .where((f) => f.name.isNotEmpty && f.formulaLatex.isNotEmpty)
            .toList();

        // Si la IA no devolvió fórmulas, sintetizamos los teoremas correspondientes
        if (formulas.isEmpty) {
          formulas = _buildFallbackFormulas(integral, finalSteps);
        }

        final regionDef = (aiJson['region_definition'] as String?) ?? baseSolution.regionDefinition;
        final aiExactResult = (aiJson['exact_result_latex'] as String?)?.trim() ?? '';
        final baseHasExact = baseSolution.exactLatex.isNotEmpty &&
            !baseSolution.exactLatex.contains(r'\approx') &&
            !baseSolution.exactLatex.contains('A(');
        final exactResult = baseHasExact
            ? baseSolution.exactLatex
            : (aiExactResult.isNotEmpty ? aiExactResult : baseSolution.exactLatex);
        final decimalResult = baseSolution.approxNumeric ?? (aiJson['decimal_result'] as num?)?.toDouble();

        DomainAnalysis? mergedDomain = baseSolution.domainAnalysis;
        final rawDomainAnalysis = aiJson['domain_analysis'];
        if (rawDomainAnalysis is Map<String, dynamic>) {
          final aiDomain = DomainAnalysis.fromJson(rawDomainAnalysis);
          if (mergedDomain == null) {
            mergedDomain = aiDomain;
          } else {
            mergedDomain = DomainAnalysis(
              regionType: aiDomain.regionType.isNotEmpty ? aiDomain.regionType : mergedDomain.regionType,
              intersectionPoints: aiDomain.intersectionPoints.isNotEmpty
                  ? aiDomain.intersectionPoints
                  : mergedDomain.intersectionPoints,
              deducedLimitsLatex: aiDomain.deducedLimitsLatex.isNotEmpty
                  ? aiDomain.deducedLimitsLatex
                  : mergedDomain.deducedLimitsLatex,
              jacobianLatex: (aiDomain.jacobianLatex != null && aiDomain.jacobianLatex!.isNotEmpty)
                  ? aiDomain.jacobianLatex
                  : mergedDomain.jacobianLatex,
              boundaryCurves: mergedDomain.boundaryCurves,
              alternateOrderLatex: mergedDomain.alternateOrderLatex,
              uvTransformSummary: mergedDomain.uvTransformSummary,
              uvData: mergedDomain.uvData,
            );
          }
        }

        return baseSolution.copyWith(
          steps: finalSteps,
          didacticSections: sections.isNotEmpty ? sections : baseSolution.didacticSections,
          formulasAndMethods: formulas.isNotEmpty ? formulas : baseSolution.formulasAndMethods,
          regionDefinition: regionDef,
          exactLatex: exactResult,
          approxNumeric: decimalResult,
          domainAnalysis: mergedDomain,
          aiProvider: aiWasTooSummarized ? 'Motor Simbólico Autónomo' : providerName,
          aiStatus: aiWasTooSummarized
              ? '✨ Procedimiento Didáctico Completo (${finalSteps.length} pasos)'
              : '✨ Procedimiento didáctico por $providerName (${finalSteps.length} pasos)',
        );
      }
    } catch (e) {
      lastError = e.toString();
    }

    // Modo autónomo: siempre asegurar que existen fórmulas didácticas y pasos variables
    final fallbackFormulas = baseSolution.formulasAndMethods != null && baseSolution.formulasAndMethods!.isNotEmpty
        ? baseSolution.formulasAndMethods!
        : _buildFallbackFormulas(integral, baseSolution.steps);

    if (lastError != null && lastError.isNotEmpty && hasCustomKey) {
      final cleanError = lastError.contains('404')
          ? 'Modelo en la nube no disponible'
          : (lastError.contains('403') || lastError.contains('API_KEY_INVALID')
              ? 'Clave de API no válida'
              : (lastError.contains('429')
                  ? 'Límite de peticiones de API alcanzado'
                  : 'Modo autónomo local activo'));
      return baseSolution.copyWith(
        formulasAndMethods: fallbackFormulas,
        aiStatus: '✨ Procedimiento Didáctico por Motor Simbólico Autónomo (${baseSolution.steps.length} pasos) • ($cleanError)',
      );
    }

    return baseSolution.copyWith(
      formulasAndMethods: fallbackFormulas,
      aiStatus: '✨ Procedimiento Didáctico por Motor Simbólico Autónomo (${baseSolution.steps.length} pasos)',
    );
  }

  /// Construye tarjetas de fórmulas y teoremas teóricos utilizados en la resolución
  List<FormulaMethodCard> _buildFallbackFormulas(
    MultivariableIntegral integral,
    List<SolverStep> steps,
  ) {
    final list = <FormulaMethodCard>[];

    // 1. Teorema de Fubini
    if (integral.dimension == 3) {
      list.add(const FormulaMethodCard(
        name: 'Teorema de Fubini en ℝ³ (Integrales Triples)',
        formulaLatex: r'\iiint_E f(x, y, z) \, dV = \int_{a}^{b} \int_{u_1(x)}^{u_2(x)} \int_{w_1(x, y)}^{w_2(x, y)} f(x, y, z) \, dz \, dy \, dx',
        description: 'Permite descomponer la integral triple de volumen en tres integrales simples iteradas sucesivas sobre dominios proyectados.',
        application: 'Integración jerárquica en capas sucesivas a lo largo de los ejes coordenados.',
      ));
    } else {
      list.add(const FormulaMethodCard(
        name: 'Teorema de Fubini en el Plano (Integración Iterada)',
        formulaLatex: r'\iint_R f(x, y) \, dA = \int_{a}^{b} \int_{g_1(x)}^{g_2(x)} f(x, y) \, dy \, dx',
        description: 'Establece que una integral doble continua sobre un recinto acotado se calcula mediante integrales iteradas simples sucesivas.',
        application: 'Permite integrar primero respecto a la variable interior fijando la variable exterior como parámetro constante.',
      ));
    }

    // 2. Teorema Fundamental del Cálculo (Regla de Barrow)
    list.add(const FormulaMethodCard(
      name: 'Teorema Fundamental del Cálculo (Regla de Barrow)',
      formulaLatex: r'\int_{a}^{b} f(x) \, dx = F(b) - F(a) \quad [F^\prime(x) = f(x)]',
      description: 'Conecta la antiderivada de una función continua con la acumulación neta de área o volumen entre las cotas del intervalo.',
      application: 'Evaluación de las primitivas en los límites superior e inferior de cada capa de integración.',
    ));

    // 3. Método de Sustitución si aplica
    final bool hasSubstitution = steps.any((s) {
      final t = (s.stepTitle ?? '').toLowerCase();
      final m = (s.appliedMethod ?? '').toLowerCase();
      final e = s.explanation.toLowerCase();
      return t.contains('sustitución') ||
          t.contains('sustitucion') ||
          m.contains('sustitución') ||
          m.contains('sustitucion') ||
          e.contains('u-sustitución') ||
          e.contains('cambio de variable') ||
          s.variable == 'u';
    });
    if (hasSubstitution) {
      list.add(const FormulaMethodCard(
        name: 'Método de Integración por Sustitución (u-Sustitución)',
        formulaLatex: r'\int f(g(x)) g^\prime(x) \, dx = \int f(u) \, du \quad [u = g(x), \, du = g^\prime(x)dx]',
        description: 'Transforma una integral compuesta en una integral elemental mediante el cambio a una nueva variable diferenciable.',
        application: 'Permite integrar la función exterior aprovechando la diferencial generada por la integral previa.',
      ));
    }

    // 4. Regla de la Potencia
    list.add(const FormulaMethodCard(
      name: 'Regla de la Potencia para Antiderivadas',
      formulaLatex: r'\int u^n \, du = \frac{u^{n+1}}{n+1} + C \quad (n \ne -1)',
      description: 'Fórmula básica del cálculo integral para potencias y monomios de una variable.',
      application: 'Cálculo de primitivas parciales manteniendo fijas las variables exteriores.',
    ));

    // 5. Coordenadas polares / curvilíneas / Jacobianos si aplica
    final bool hasRadical = integral.bounds.any((b) => b.lower.contains('sqrt') || b.upper.contains('sqrt'));
    if (integral.coordinateSystem == CoordinateSystemType.polar || hasRadical) {
      list.add(const FormulaMethodCard(
        name: 'Transformación a Coordenadas Polares y Factor Jacobiano',
        formulaLatex: r'dA = dx \, dy = r \, dr \, d\theta, \quad x = r\cos\theta, \quad y = r\sin\theta',
        description: 'Facilita la integración sobre recintos circulares o cardioides incorporando el factor de escala diferencial Jacobiano r.',
        application: 'Conversión de fronteras curvilíneas en cotas radiales y angulares (como circunferencias centradas o desplazadas r = 2a cosθ).',
      ));
    }

    if (integral.coordinateSystem == CoordinateSystemType.cylindrical) {
      list.add(const FormulaMethodCard(
        name: 'Coordenadas Cilíndricas en ℝ³',
        formulaLatex: r'dV = r \, dz \, dr \, d\theta, \quad x = r\cos\theta, \quad y = r\sin\theta, \quad z = z',
        description: 'Extiende las coordenadas polares al espacio tridimensional aprovechando la simetría axial alrededor de un eje.',
        application: 'Sólidos limitados por cilindros y paraboloides (J = r).',
      ));
    }

    if (integral.coordinateSystem == CoordinateSystemType.spherical) {
      list.add(const FormulaMethodCard(
        name: 'Coordenadas Esféricas y Jacobiano Espacial',
        formulaLatex: r'dV = \rho^2 \sin\phi \, d\rho \, d\phi \, d\theta, \quad x = \rho\sin\phi\cos\theta, \quad y = \rho\sin\phi\sin\theta, \quad z = \rho\cos\phi',
        description: 'Parametriza regiones con simetría central mediante distancia radial ρ, colatitud φ y acimut θ.',
        application: 'Esferas, conos, lemniscatas espaciales y elipsoides reescalados.',
      ));
    }

    final bool hasUvTransform = integral.uvTransformInput?.trim().isNotEmpty == true ||
        steps.any((s) => (s.appliedMethod ?? '').toLowerCase().contains('jacobiano'));
    if (hasUvTransform) {
      list.add(const FormulaMethodCard(
        name: 'Teorema de Cambio de Variables y Determinante Jacobiano (u, v)',
        formulaLatex: r'\iint_R f(x,y)\,dx\,dy = \iint_S f(x(u,v), y(u,v)) \, \left|\frac{\partial(x,y)}{\partial(u,v)}\right| du\,dv, \quad J = \left(\frac{\partial(u,v)}{\partial(x,y)}\right)^{-1}',
        description: 'Transforma regiones delimitadas por familias de curvas en un rectángulo simple en el plano UV multiplicando por |J|.',
        application: 'Simplificación de dominios curvilíneos (xy=c, y=kx o rectas paralelas).',
      ));
    }

    if (integral.problemMode == ProblemMode.surfaceArea) {
      list.add(const FormulaMethodCard(
        name: 'Área de Superficie Paramétrica 3D',
        formulaLatex: r'A_S = \iint_R \sqrt{1 + \left(\frac{\partial z}{\partial x}\right)^2 + \left(\frac{\partial z}{\partial y}\right)^2} \, dA',
        description: 'Integra el elemento diferencial de área superficial dS sobre la proyección R en el plano base XY.',
        application: 'Cálculo exacto de áreas de paraboloides, conos, planos inclinados y esferas.',
      ));
    } else if (integral.problemMode == ProblemMode.massAndCenterOfMass) {
      list.add(const FormulaMethodCard(
        name: 'Masa Total, Momentos Estáticos y Centro de Masa',
        formulaLatex: r'M = \iiint_V \rho \, dV, \quad \bar{x} = \frac{M_{yz}}{M}, \quad \bar{y} = \frac{M_{xz}}{M}, \quad \bar{z} = \frac{M_{xy}}{M}',
        description: 'Obtiene la masa acumulada y las coordenadas centroidales ponderadas por la densidad variable o constante ρ.',
        application: 'Estática de láminas planas y sólidos 3D en ingeniería.',
      ));
    }

    // 6. Inversión de límites u orden de integración si aplica
    final bool hasInversion = steps.any((s) => s.isLimitInverted);
    if (hasInversion) {
      list.add(const FormulaMethodCard(
        name: 'Propiedad de Orientación e Inversión de Límites',
        formulaLatex: r'\int_{a}^{b} f(x) \, dx = -\int_{b}^{a} f(x) \, dx \quad (a > b)',
        description: 'Preserva rigurosamente el signo canónico del resultado cuando la cota inferior supera numéricamente a la superior.',
        application: 'Inversión al intervalo canónico aplicando factor (-1) a la antiderivada evaluada.',
      ));
    }

    return list;
  }

  /// Sanitiza y corrige escapes de barras invertidas de LaTeX en cadenas JSON.
  /// Los LLMs suelen emitir \int, \frac, \left en vez de \\int, \\frac, provocando FormatException en jsonDecode.
  static String _fixJsonLatex(String input) {
    final buffer = StringBuffer();
    bool inString = false;
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"') {
        int backslashCount = 0;
        int j = i - 1;
        while (j >= 0 && input[j] == r'\') {
          backslashCount++;
          j--;
        }
        if (backslashCount % 2 == 0) {
          inString = !inString;
        }
        buffer.write(char);
      } else if (inString && char == r'\') {
        if (i + 1 < input.length && input[i + 1] == r'\') {
          buffer.write(r'\\');
          i++;
        } else if (i + 1 < input.length && input[i + 1] == '"') {
          buffer.write(r'\"');
          i++;
        } else if (i + 1 < input.length && input[i + 1] == '/') {
          buffer.write(r'\/');
          i++;
        } else if (i + 5 < input.length &&
            input[i + 1] == 'u' &&
            RegExp(r'^[0-9a-fA-F]{4}$').hasMatch(input.substring(i + 2, i + 6))) {
          buffer.write(input.substring(i, i + 6));
          i += 5;
        } else {
          // Escapar la barra de LaTeX (\int, \frac, \left, \right, etc.) para que jsonDecode la acepte
          buffer.write(r'\\');
        }
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Restaura comandos LaTeX corrompidos cuando un LLM emite una sola barra invertida (\frac, \theta, \begin, \right)
  /// y jsonDecode los interpreta como caracteres de control (\f, \t, \b, \r).
  static dynamic _repairDecodedControlChars(dynamic node) {
    if (node is Map) {
      return node.map<String, dynamic>(
        (k, v) => MapEntry(k.toString(), _repairDecodedControlChars(v)),
      );
    } else if (node is List) {
      return node.map(_repairDecodedControlChars).toList();
    } else if (node is String) {
      var s = node;
      if (s.contains('\x0c')) s = s.replaceAll('\x0c', r'\f');
      if (s.contains('\x08')) s = s.replaceAll('\x08', r'\b');
      if (s.contains('\t')) {
        s = s.replaceAllMapped(
          RegExp(r'\t(frac|ext|heta|an|imes|o\b|au|ilde|riangle|op)'),
          (m) => '\\t${m[1]}',
        );
      }
      if (s.contains('\r')) {
        s = s.replaceAllMapped(
          RegExp(r'\r(ight|ho|angle)'),
          (m) => '\\r${m[1]}',
        );
      }
      return s;
    }
    return node;
  }

  static Map<String, dynamic>? _parseJsonSafely(String rawText) {
    var s = rawText.trim();
    if (s.startsWith('```json')) {
      s = s.substring(7);
    } else if (s.startsWith('```')) {
      s = s.substring(3);
    }
    if (s.endsWith('```')) {
      s = s.substring(0, s.length - 3);
    }
    s = s.trim();

    final firstBrace = s.indexOf('{');
    final lastBrace = s.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      s = s.substring(firstBrace, lastBrace + 1);
    }

    try {
      final decoded = jsonDecode(s) as Map<String, dynamic>;
      return _repairDecodedControlChars(decoded) as Map<String, dynamic>;
    } catch (_) {
      try {
        final fixed = _fixJsonLatex(s);
        final decoded = jsonDecode(fixed) as Map<String, dynamic>;
        return _repairDecodedControlChars(decoded) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
  }

  /// Llamada prioritaria al endpoint OpenAI-compatible gratuito de Pollinations
  /// sin exigir clave al estudiante, extrayendo adecuadamente el sobre `choices[0].message.content`.
  Future<(Map<String, dynamic>?, String?)> _callFreeAI(String prompt) async {
    final attempts = <Map<String, dynamic>>[
      {'model': 'openai-fast', 'reasoning_effort': 'low'},
      {'model': 'openai'},
    ];

    const stepKeys = [
      'steps',
      'pasos',
      'solution_steps',
      'procedimiento',
      'pasos_solucion',
      'paso_a_paso',
    ];

    for (final cfg in attempts) {
      try {
        final payload = <String, dynamic>{
          'model': cfg['model'],
          'messages': [
            {'role': 'system', 'content': didacticSystemPrompt},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.1,
        };
        if (cfg.containsKey('reasoning_effort')) {
          payload['reasoning_effort'] = cfg['reasoning_effort'];
        }

        final response = await _dio.post(
          'https://text.pollinations.ai/openai',
          data: payload,
          options: Options(
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 24),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (compatible; Integra3D/2.0)',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          Map<String, dynamic>? parsed;
          if (response.data is Map<String, dynamic>) {
            final dataMap = response.data as Map<String, dynamic>;
            final choices = dataMap['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final first = choices[0];
              if (first is Map<String, dynamic>) {
                final msg = first['message'] as Map<String, dynamic>?;
                final content = msg?['content'] as String?;
                if (content != null && content.trim().isNotEmpty) {
                  parsed = _parseJsonSafely(content);
                }
              }
            } else {
              parsed = _repairDecodedControlChars(dataMap) as Map<String, dynamic>;
            }
          } else if (response.data is String) {
            parsed = _parseJsonSafely(response.data as String);
          }

          if (parsed != null && stepKeys.any((k) => parsed![k] is List && (parsed[k] as List).isNotEmpty)) {
            return (parsed, null);
          }
        }
      } catch (_) {
        continue;
      }
    }
    return (null, null);
  }

  Future<(Map<String, dynamic>?, String?)> _callGemini(String prompt, String apiKey) async {
    final models = [
      'gemini-2.0-flash',
      'gemini-2.5-flash',
      'gemini-1.5-flash',
      'gemini-2.0-flash-lite',
      'gemini-1.5-flash-latest',
    ];
    String? errorDetail;
    for (final model in models) {
      try {
        final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
        final payload = {
          'system_instruction': {
            'parts': [
              {'text': didacticSystemPrompt}
            ]
          },
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'response_mime_type': 'application/json',
            'maxOutputTokens': 8192,
          }
        };

        final response = await _dio.post(url, data: payload);
        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map<String, dynamic>;
            final parts = content['parts'] as List<dynamic>;
            final text = parts[0]['text'] as String;
            final parsed = _parseJsonSafely(text);
            if (parsed != null) return (parsed, null);
          }
        }
      } on DioException catch (dioErr) {
        errorDetail = dioErr.message ?? dioErr.type.name;
        if (dioErr.response?.data != null) {
          errorDetail = '$errorDetail: ${dioErr.response?.data}';
        }
      } catch (e) {
        errorDetail = e.toString();
      }
    }
    return (null, errorDetail);
  }

  Future<(Map<String, dynamic>?, String?)> _callOpenRouter(String prompt, String apiKey) async {
    final models = [
      'google/gemini-2.0-flash-exp:free',
      'meta-llama/llama-3.3-70b-instruct:free',
      'deepseek/deepseek-r1:free',
      'qwen/qwen-2.5-coder-32b-instruct:free',
    ];
    String? errorDetail;
    for (final model in models) {
      try {
        final payload = {
          'model': model,
          'messages': [
            {'role': 'system', 'content': didacticSystemPrompt},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.1,
          'max_tokens': 8192,
          'response_format': {'type': 'json_object'},
        };

        final response = await _dio.post(
          'https://openrouter.ai/api/v1/chat/completions',
          data: payload,
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer': 'https://integra3d.app',
              'X-Title': 'Integra3D Mobile',
            },
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final msg = choices[0]['message'] as Map<String, dynamic>;
            final content = msg['content'] as String;
            final parsed = _parseJsonSafely(content);
            if (parsed != null) return (parsed, null);
          }
        }
      } on DioException catch (dioErr) {
        errorDetail = dioErr.message ?? dioErr.type.name;
      } catch (e) {
        errorDetail = e.toString();
      }
    }
    return (null, errorDetail);
  }

  Future<(Map<String, dynamic>?, String?)> _callGroq(String prompt, String apiKey) async {
    final models = ['llama-3.3-70b-versatile', 'mixtral-8x7b-32768'];
    String? errorDetail;
    for (final model in models) {
      try {
        final payload = {
          'model': model,
          'messages': [
            {'role': 'system', 'content': didacticSystemPrompt},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.1,
          'max_tokens': 8192,
          'response_format': {'type': 'json_object'},
        };

        final response = await _dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          data: payload,
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final msg = choices[0]['message'] as Map<String, dynamic>;
            final content = msg['content'] as String;
            final parsed = _parseJsonSafely(content);
            if (parsed != null) return (parsed, null);
          }
        }
      } on DioException catch (dioErr) {
        errorDetail = dioErr.message ?? dioErr.type.name;
      } catch (e) {
        errorDetail = e.toString();
      }
    }
    return (null, errorDetail);
  }
}
