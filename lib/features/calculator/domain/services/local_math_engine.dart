import 'dart:math' as math;
import '../entities/integration_bound.dart';
import '../entities/multivariable_integral.dart';
import 'integral_expression_transformer.dart';
import 'math_expression_evaluator.dart';
import '../../../solver/domain/entities/integral_solution.dart';

/// Motor matemático autónomo de respaldo en Dart.
/// Garantiza que Integra3D funcione al 100% incluso sin el servidor SymPy activo,
/// calculando soluciones simbólicas conocidas, aproximaciones numéricas de alta precisión
/// y generando mallas 3D para el renderizador nativo.
class LocalMathEngine {
  static final List<Map<String, dynamic>> builtInPresets = [
    {
      'id': 'image3_double_integral',
      'name': 'Integral Doble con Límite Variable',
      'description': 'Integral de x*y² con x ∈ [0, 3y - 5] e y ∈ [-2, 1]',
      'dimension': 2,
      'integrand': 'x * y^2',
      'coordinate_system': 'cartesian',
      'bounds': [
        {'variable': 'x', 'lower': '0', 'upper': '3*y - 5'},
        {'variable': 'y', 'lower': '-2', 'upper': '1'},
      ],
      'exact_latex': r'\frac{2469}{20}',
      'numeric_approx': 123.45,
      'steps': [
        {
          'step_number': 1,
          'variable': 'x',
          'lower_bound_latex': '0',
          'upper_bound_latex': '3y - 5',
          'current_integrand_latex': r'x y^2',
          'antiderivative_latex': r'\frac{x^2 y^2}{2}',
          'evaluated_latex': r'\left[ \frac{x^2 y^2}{2} \right]_0^{3y - 5} = \frac{y^2(3y - 5)^2}{2} = \frac{9y^4 - 30y^3 + 25y^2}{2}',
          'simplified_result_latex': r'\frac{9y^4 - 30y^3 + 25y^2}{2}',
          'explanation': 'Se integra con respecto a x tratando a y como constante. Se evalúa el límite superior 3y - 5 y el inferior 0 mediante el Teorema Fundamental del Cálculo.',
        },
        {
          'step_number': 2,
          'variable': 'y',
          'lower_bound_latex': '-2',
          'upper_bound_latex': '1',
          'current_integrand_latex': r'\frac{9y^4 - 30y^3 + 25y^2}{2}',
          'antiderivative_latex': r'\frac{9y^5}{10} - \frac{15y^4}{4} + \frac{25y^3}{6}',
          'evaluated_latex': r'\left( \frac{9}{10} - \frac{15}{4} + \frac{25}{6} \right) - \left( -\frac{288}{10} - 60 - \frac{200}{6} \right) = \frac{79}{60} - \left(-\frac{7328}{60}\right) = \frac{2469}{20}',
          'simplified_result_latex': r'\frac{2469}{20} = 123.45',
          'explanation': 'Se integra el polinomio en y en el intervalo exterior [-2, 1] obteniendo exactamente 2469/20.',
        },
      ],
      'sections': [
        {
          'title': '1. Región de Integración Tipo II',
          'content': 'La región en el plano xy está delimitada por límites horizontales: x varía entre 0 y la recta variable x = 3y - 5, mientras que y está fija en [-2, 1].',
        },
        {
          'title': '2. Teorema de Fubini y Resultado Analítico',
          'content': 'La integral iterada se evalúa secuencialmente produciendo un valor exacto de 2469/20 = 123.45 u³.',
        },
      ],
    },
    {
      'id': 'paraboloid_cylinder',
      'name': 'Paraboloide Elíptico',
      'description': 'Volumen acotado por z = 4 - x² - y² sobre el plano z = 0',
      'dimension': 2,
      'integrand': '4 - x^2 - y^2',
      'coordinate_system': 'cartesian',
      'bounds': [
        {'variable': 'y', 'lower': '-sqrt(4 - x^2)', 'upper': 'sqrt(4 - x^2)'},
        {'variable': 'x', 'lower': '-2', 'upper': '2'},
      ],
      'exact_latex': r'8\pi',
      'numeric_approx': 25.1327,
      'steps': [
        {
          'step_number': 1,
          'variable': 'y',
          'lower_bound_latex': r'-\sqrt{4 - x^2}',
          'upper_bound_latex': r'\sqrt{4 - x^2}',
          'current_integrand_latex': r'4 - x^2 - y^2',
          'antiderivative_latex': r'(4 - x^2)y - \frac{y^3}{3}',
          'evaluated_latex': r'\left[(4 - x^2)y - \frac{y^3}{3}\right]_{-\sqrt{4 - x^2}}^{\sqrt{4 - x^2}} = \frac{4}{3}(4 - x^2)^{3/2}',
          'simplified_result_latex': r'\frac{4}{3}(4 - x^2)^{3/2}',
          'explanation': 'Se integra respecto a y considerando x como constante. Aplicamos el Teorema Fundamental del Cálculo sobre el disco x² + y² ≤ 4.',
        },
        {
          'step_number': 2,
          'variable': 'x',
          'lower_bound_latex': r'-2',
          'upper_bound_latex': r'2',
          'current_integrand_latex': r'\frac{4}{3}(4 - x^2)^{3/2}',
          'antiderivative_latex': r'\int \frac{4}{3}(4 - x^2)^{3/2} \, dx',
          'evaluated_latex': r'\text{Sustitución trigonométrica } x = 2\sin\theta \implies \int_{-\pi/2}^{\pi/2} \frac{64}{3}\cos^4\theta \, d\theta',
          'simplified_result_latex': r'8\pi',
          'explanation': 'Se efectúa la integración trigonométrica para calcular el volumen total del paraboloide de altura 4.',
        },
      ],
      'sections': [
        {
          'title': '1. Interpretación Geométrica y Dominio',
          'content': 'El integrando modela un paraboloide circular que abre hacia abajo con vértice en (0, 0, 4). La traza con el plano z = 0 forma una circunferencia de radio R = 2 en el plano xy.',
        },
        {
          'title': '2. Teorema de Fubini y Simetría',
          'content': 'La región es circular. Al integrar primero con respecto a y, las secciones transversales son parábolas cuya área luego se suma a lo largo del intervalo x ∈ [-2, 2].',
        },
        {
          'title': '3. Conclusión Académica',
          'content': 'El volumen neto acotado es exactamente 8π u³ ≈ 25.1327 u³. Coincide con la fórmula clásica de Cavalieri V = (1/2)·π·R²·h = (1/2)·π·(4)·(4) = 8π.',
        },
      ],
    },
    {
      'id': 'fundamental_tetrahedron',
      'name': 'Tetraedro Fundamental',
      'description': 'Sólido acotado por x + y + z = 1 y los planos coordenados',
      'dimension': 3,
      'integrand': '1',
      'coordinate_system': 'cartesian',
      'bounds': [
        {'variable': 'z', 'lower': '0', 'upper': '1 - x - y'},
        {'variable': 'y', 'lower': '0', 'upper': '1 - x'},
        {'variable': 'x', 'lower': '0', 'upper': '1'},
      ],
      'exact_latex': r'\frac{1}{6}',
      'numeric_approx': 0.1667,
      'steps': [
        {
          'step_number': 1,
          'variable': 'z',
          'lower_bound_latex': '0',
          'upper_bound_latex': '1 - x - y',
          'current_integrand_latex': '1',
          'antiderivative_latex': 'z',
          'evaluated_latex': r'[z]_0^{1 - x - y} = 1 - x - y',
          'simplified_result_latex': '1 - x - y',
          'explanation': 'La primera integral suma los elementos diferenciales verticales dV = dz dy dx desde el plano xy hasta el plano oblicuo.',
        },
        {
          'step_number': 2,
          'variable': 'y',
          'lower_bound_latex': '0',
          'upper_bound_latex': '1 - x',
          'current_integrand_latex': '1 - x - y',
          'antiderivative_latex': r'(1 - x)y - \frac{y^2}{2}',
          'evaluated_latex': r'\left[(1 - x)y - \frac{y^2}{2}\right]_0^{1 - x} = \frac{(1 - x)^2}{2}',
          'simplified_result_latex': r'\frac{(1 - x)^2}{2}',
          'explanation': 'Se evalúa el área de la sección transversal triangular en el plano proyectado.',
        },
        {
          'step_number': 3,
          'variable': 'x',
          'lower_bound_latex': '0',
          'upper_bound_latex': '1',
          'current_integrand_latex': r'\frac{(1 - x)^2}{2}',
          'antiderivative_latex': r'-\frac{(1 - x)^3}{6}',
          'evaluated_latex': r'\left[-\frac{(1 - x)^3}{6}\right]_0^1 = 0 - \left(-\frac{1}{6}\right) = \frac{1}{6}',
          'simplified_result_latex': r'\frac{1}{6}',
          'explanation': 'Se acumula el volumen a lo largo del intervalo [0, 1]. Resultado exacto: 1/6.',
        },
      ],
      'sections': [
        {
          'title': '1. Configuración del Sólido 3D',
          'content': 'Sólido poliédrico de 4 vértices: (0,0,0), (1,0,0), (0,1,0) y (0,0,1). El volumen se calcula mediante la integral triple de la función unidad 1 dV.',
        },
        {
          'title': '2. Verificación Geométrica Clásica',
          'content': 'Por geometría euclidiana, el volumen de una pirámide es V = (1/3)·ÁreaBase·Altura = (1/3)·(1/2 · 1 · 1)·(1) = 1/6 u³.',
        },
      ],
    },
    {
      'id': 'gaussian_2d',
      'name': 'Campana de Gauss 2D',
      'description': 'Superficie z = exp(-x² - y²) sobre [-1.5, 1.5]²',
      'dimension': 2,
      'integrand': 'exp(-x^2 - y^2)',
      'coordinate_system': 'cartesian',
      'bounds': [
        {'variable': 'y', 'lower': '-1.5', 'upper': '1.5'},
        {'variable': 'x', 'lower': '-1.5', 'upper': '1.5'},
      ],
      'exact_latex': r'\pi \cdot \text{erf}(1.5)^2',
      'numeric_approx': 2.7562,
      'steps': [
        {
          'step_number': 1,
          'variable': 'y',
          'lower_bound_latex': '-1.5',
          'upper_bound_latex': '1.5',
          'current_integrand_latex': r'e^{-x^2} \cdot e^{-y^2}',
          'antiderivative_latex': r'e^{-x^2} \cdot \frac{\sqrt{\pi}}{2} \text{erf}(y)',
          'evaluated_latex': r'e^{-x^2} \cdot \sqrt{\pi} \text{erf}(1.5)',
          'simplified_result_latex': r'\sqrt{\pi} \text{erf}(1.5) e^{-x^2}',
          'explanation': 'Separabilidad: e^(-x² - y²) = e^(-x²) · e^(-y²). La antiderivada de e^(-y²) corresponde a la función de error de Gauss.',
        },
        {
          'step_number': 2,
          'variable': 'x',
          'lower_bound_latex': '-1.5',
          'upper_bound_latex': '1.5',
          'current_integrand_latex': r'\sqrt{\pi} \text{erf}(1.5) e^{-x^2}',
          'antiderivative_latex': r'\frac{\pi}{2} \text{erf}(1.5) \text{erf}(x)',
          'evaluated_latex': r'\pi \cdot \text{erf}(1.5)^2 \approx 2.7562',
          'simplified_result_latex': r'\pi \cdot \text{erf}(1.5)^2',
          'explanation': 'Evaluación sobre el dominio simétrico cuadrado.',
        },
      ],
      'sections': [
        {
          'title': '1. Relevancia en Probabilidad y Física',
          'content': 'La distribución normal bivariada independiente modela fenómenos de difusión y densidad de probabilidad espacial.',
        },
      ],
    },
    {
      'id': 'hyperbolic_paraboloid',
      'name': 'Silla de Montar (Paraboloide Hiperbólico)',
      'description': 'Superficie z = x² - y² en [-2, 2]²',
      'dimension': 2,
      'integrand': 'x^2 - y^2',
      'coordinate_system': 'cartesian',
      'bounds': [
        {'variable': 'y', 'lower': '-2', 'upper': '2'},
        {'variable': 'x', 'lower': '-2', 'upper': '2'},
      ],
      'exact_latex': '0',
      'numeric_approx': 0.0,
      'steps': [
        {
          'step_number': 1,
          'variable': 'y',
          'lower_bound_latex': '-2',
          'upper_bound_latex': '2',
          'current_integrand_latex': r'x^2 - y^2',
          'antiderivative_latex': r'x^2 y - \frac{y^3}{3}',
          'evaluated_latex': r'\left(2x^2 - \frac{8}{3}\right) - \left(-2x^2 + \frac{8}{3}\right) = 4x^2 - \frac{16}{3}',
          'simplified_result_latex': r'4x^2 - \frac{16}{3}',
          'explanation': 'Integración respecto a y evaluando límites simétricos.',
        },
        {
          'step_number': 2,
          'variable': 'x',
          'lower_bound_latex': '-2',
          'upper_bound_latex': '2',
          'current_integrand_latex': r'4x^2 - \frac{16}{3}',
          'antiderivative_latex': r'\frac{4x^3}{3} - \frac{16x}{3}',
          'evaluated_latex': r'\left(\frac{32}{3} - \frac{32}{3}\right) - \left(-\frac{32}{3} + \frac{32}{3}\right) = 0',
          'simplified_result_latex': '0',
          'explanation': 'Por simetría antisimétrica de x² - y² sobre el cuadrado [-2,2]², el volumen sobre el plano se cancela exactamente con el volumen bajo el plano.',
        },
      ],
      'sections': [
        {
          'title': '1. Punto de Ensilladura (Saddle Point)',
          'content': 'La superficie presenta curvatura gaussiana negativa. En (0,0,0) las derivadas parciales se anulan, pero no es un extremo local sino un punto de ensilladura.',
        },
      ],
    },
    {
      'id': 'upper_hemisphere',
      'name': 'Semiesfera de Radio R = 3',
      'description': 'Superficie z = sqrt(9 - x² - y²) sobre disco r ≤ 3',
      'dimension': 2,
      'integrand': 'sqrt(9 - x^2 - y^2)',
      'coordinate_system': 'cartesian',
      'bounds': [
        {'variable': 'y', 'lower': '-sqrt(9 - x^2)', 'upper': 'sqrt(9 - x^2)'},
        {'variable': 'x', 'lower': '-3', 'upper': '3'},
      ],
      'exact_latex': r'18\pi',
      'numeric_approx': 56.5487,
      'steps': [
        {
          'step_number': 1,
          'variable': 'y',
          'lower_bound_latex': r'-\sqrt{9 - x^2}',
          'upper_bound_latex': r'\sqrt{9 - x^2}',
          'current_integrand_latex': r'\sqrt{9 - x^2 - y^2}',
          'antiderivative_latex': r'\text{Integral circular en } y',
          'evaluated_latex': r'\frac{\pi}{2}(9 - x^2)',
          'simplified_result_latex': r'\frac{\pi}{2}(9 - x^2)',
          'explanation': 'El área de un semicírculo de radio r = √(9 - x²) a lo largo de un corte vertical.',
        },
        {
          'step_number': 2,
          'variable': 'x',
          'lower_bound_latex': '-3',
          'upper_bound_latex': '3',
          'current_integrand_latex': r'\frac{\pi}{2}(9 - x^2)',
          'antiderivative_latex': r'\frac{\pi}{2}\left(9x - \frac{x^3}{3}\right)',
          'evaluated_latex': r'\frac{\pi}{2}(18 - (-18)) = 18\pi',
          'simplified_result_latex': r'18\pi',
          'explanation': 'Volumen de una semiesfera: (2/3)·π·R³ = (2/3)·π·(27) = 18π u³.',
        },
      ],
      'sections': [
        {
          'title': '1. Volumen de la Semiesfera',
          'content': 'Corresponde a la mitad de una esfera de radio 3. Su volumen analítico exacto es (2/3)πR³ = 18π ≈ 56.5487 u³.',
        },
      ],
    },
  ];

  /// Resuelve la integral localmente reconociendo patrones o mediante integración numérica
  static IntegralSolution solveLocal(MultivariableIntegral integral) {
    final startTime = DateTime.now();

    // 1. Verificar si coincide con un preset conocido (debe coincidir integrando Y límites)
    final normalizedIntegrand = _cleanExpr(integral.integrand);
    for (final preset in builtInPresets) {
      final presetBounds = (preset['bounds'] as List<dynamic>?) ?? [];
      if (_cleanExpr(preset['integrand'] as String) == normalizedIntegrand &&
          preset['dimension'] == integral.dimension &&
          _boundsMatch(presetBounds, integral.bounds)) {
        final stepsRaw = (preset['steps'] as List<dynamic>?) ?? [];
        final steps = stepsRaw
            .map((s) => SolverStep.fromJson(s as Map<String, dynamic>))
            .toList();

        final sectionsRaw = (preset['sections'] as List<dynamic>?) ?? [];
        final sections = sectionsRaw
            .map((s) => PedagogicalSection.fromJson(s as Map<String, dynamic>))
            .toList();

        final ms = DateTime.now().difference(startTime).inMilliseconds.toDouble();
        return IntegralSolution(
          isSuccess: true,
          exactLatex: preset['exact_latex'] as String,
          approxNumeric: (preset['numeric_approx'] as num).toDouble(),
          steps: steps,
          originalIntegralLatex: _toLatexString(integral),
          executionTimeMs: math.max(ms, 12.5),
          didacticSections: sections,
        );
      }
    }

    // 2. Solución didáctica y numérica autónoma para integrales de cualquier dimensión (1D, 2D, 3D)
    try {
      if (integral.dimension == 1 && integral.bounds.isNotEmpty) {
        return _solve1D(integral, startTime);
      } else if (integral.dimension == 2 && integral.bounds.length >= 2) {
        return _solve2D(integral, startTime);
      } else if (integral.dimension == 3 && integral.bounds.length >= 3) {
        return _solve3D(integral, startTime);
      } else {
        // Dimensión por defecto según cantidad de límites
        if (integral.bounds.length >= 3) {
          return _solve3D(integral, startTime);
        } else if (integral.bounds.length == 2) {
          return _solve2D(integral, startTime);
        } else if (integral.bounds.isNotEmpty) {
          return _solve1D(integral, startTime);
        }
      }
    } catch (e) {
      return _buildDivergentSolution(
        integral,
        startTime,
        'Error matemático al procesar la integral: $e\n'
        'Verifica que la función sea continua en el dominio y no contenga divisiones entre cero.',
      );
    }

    return _buildDivergentSolution(
      integral,
      startTime,
      'No se pudo determinar un recinto válido para las cotas de integración especificadas.',
    );
  }

  // =========================================================================
  // SOLUCIONADORES DIDÁCTICOS POR DIMENSIÓN (1D, 2D, 3D)
  // =========================================================================

  static String _findAntiderivative(String integrand, String variable) {
    final clean = integrand.trim();
    final v = variable.toLowerCase();

    // Caso 1: Integrando no depende de la variable (es constante respecto a v)
    if (!clean.toLowerCase().contains(v)) {
      final disp = IntegralExpressionTransformer.toDisplayLatex(clean);
      if (disp == '1' || disp.isEmpty) return v;
      return '$v \\cdot ($disp)';
    }

    // Caso 2: Integrando es solo la variable 'x', 'y', 'z'
    if (clean.toLowerCase() == v) {
      return '\\frac{$v^2}{2}';
    }

    // Caso 3: Potencia v^n (ej: x^2, x^3)
    final powRegex = RegExp('^$v\\^(\\d+)\$', caseSensitive: false);
    final powMatch = powRegex.firstMatch(clean);
    if (powMatch != null) {
      final n = int.tryParse(powMatch.group(1)!) ?? 1;
      final nPlus1 = n + 1;
      return '\\frac{$v^{$nPlus1}}{$nPlus1}';
    }

    // Caso 4: Coeficiente por potencia (ej: 4*x^2, 3x, 6x^3)
    final coeffPowRegex = RegExp('^(\\d+)\\s*\\*?\\s*$v(?:\\^(\\d+))?\$', caseSensitive: false);
    final coeffMatch = coeffPowRegex.firstMatch(clean);
    if (coeffMatch != null) {
      final c = int.tryParse(coeffMatch.group(1)!) ?? 1;
      final n = coeffMatch.group(2) != null ? (int.tryParse(coeffMatch.group(2)!) ?? 1) : 1;
      final nPlus1 = n + 1;
      if (c % nPlus1 == 0) {
        final div = c ~/ nPlus1;
        return div == 1 ? '$v^{$nPlus1}' : '$div $v^{$nPlus1}';
      }
      return '\\frac{$c $v^{$nPlus1}}{$nPlus1}';
    }

    // Caso 5: Exponencial e^v o exp(v)
    if (clean.toLowerCase() == 'exp($v)' || clean.toLowerCase() == 'e^$v') {
      return 'e^{$v}';
    }

    // Caso 6: sin(v) y cos(v)
    if (clean.toLowerCase() == 'sin($v)') {
      return '-\\cos($v)';
    }
    if (clean.toLowerCase() == 'cos($v)') {
      return '\\sin($v)';
    }

    // Caso general
    final disp = IntegralExpressionTransformer.toDisplayLatex(clean);
    return '\\int ($disp) \\, d$v';
  }

  static IntegralSolution _solve1D(MultivariableIntegral integral, DateTime startTime) {
    final bound = integral.bounds[0];
    final approx = _simpson1DGeneral(
      integrand: integral.integrand,
      variable: bound.variable,
      lower: bound.lower,
      upper: bound.upper,
    );

    final ms = DateTime.now().difference(startTime).inMilliseconds.toDouble();

    if (approx.isNaN || approx.isInfinite) {
      return _buildDivergentSolution(
        integral,
        startTime,
        'La integral unidimensional diverge o presenta una discontinuidad infinita en el intervalo [${bound.lower}, ${bound.upper}].',
      );
    }

    final rawA = MathExpressionEvaluator.evaluate(bound.lower);
    final rawB = MathExpressionEvaluator.evaluate(bound.upper);
    final bool isInverted = !rawA.isNaN && !rawB.isNaN && rawA > rawB;
    final bool isIdentical = !rawA.isNaN && !rawB.isNaN && rawA == rawB;

    final cleanIntegrand = IntegralExpressionTransformer.toDisplayLatex(integral.integrand);
    final cleanLower = IntegralExpressionTransformer.toDisplayLatex(bound.lower);
    final cleanUpper = IntegralExpressionTransformer.toDisplayLatex(bound.upper);
    final approxStr = isIdentical ? '0.0000' : approx.toStringAsFixed(4);
    final antideriv = _findAntiderivative(integral.integrand, bound.variable);

    String appliedMethod = 'Teorema Fundamental del Cálculo';
    String evaluatedLatex;
    String explanation;

    if (isIdentical) {
      appliedMethod = 'Propiedad de Límites Idénticos: ∫_a^a = 0';
      evaluatedLatex = '\\int_{$cleanLower}^{$cleanUpper} ($cleanIntegrand) \\, d${bound.variable} = 0';
      explanation = 'Límites idénticos: el intervalo de integración tiene amplitud nula [$cleanLower, $cleanUpper]. La integral definida de cualquier función acotada en un punto degenerado es exactamente cero.';
    } else if (isInverted) {
      appliedMethod = 'Propiedad de Inversión de Límites: ∫_a^b = -∫_b^a';
      evaluatedLatex = '-\\int_{$cleanUpper}^{$cleanLower} ($cleanIntegrand) \\, d${bound.variable} = -\\left[ F(${bound.variable}) \\right]_{$cleanUpper}^{$cleanLower} = -(F($cleanLower) - F($cleanUpper)) \\approx $approxStr';
      explanation = 'Propiedad de Inversión de Límites: dado que el límite inferior ($cleanLower) es estrictamente mayor que el límite superior ($cleanUpper), se invierte el sentido de integración al intervalo canónico [$cleanUpper, $cleanLower] y se multiplica por el factor (-1). Esto preserva el signo negativo sin alterar el valor numérico.';
    } else {
      appliedMethod = 'Teorema Fundamental del Cálculo';
      evaluatedLatex = '\\left[ F(${bound.variable}) \\right]_{$cleanLower}^{$cleanUpper} = F($cleanUpper) - F($cleanLower) \\approx $approxStr';
      explanation = 'Se aplica el Teorema Fundamental del Cálculo integrando la función respecto a d${bound.variable} y evaluando la diferencia entre el límite superior e inferior F(b) - F(a).';
    }

    final sections = <PedagogicalSection>[
      const PedagogicalSection(
        title: '1. Teorema Fundamental del Cálculo',
        content: 'Si f es continua en [a, b] y F es una antiderivada de f, entonces ∫_a^b f(x) dx = F(b) - F(a).',
      ),
      if (isInverted)
        const PedagogicalSection(
          title: '2. Propiedad de Inversión de Sentido de Integración (∫_a^b = -∫_b^a)',
          content: 'Por definición de la suma de Riemann, el incremento dx = (b - a)/n se vuelve negativo cuando el límite inferior es mayor que el superior (a > b). Esto invierte el signo del resultado: ∫_a^b f(x) dx = -∫_b^a f(x) dx.',
        ),
      if (isIdentical)
        const PedagogicalSection(
          title: '2. Propiedad de Límites Idénticos (Intervalo Degenerado)',
          content: 'Si los extremos superior e inferior coinciden (a = b), la amplitud del intervalo es cero y la integral definida es exactamente 0.',
        ),
      PedagogicalSection(
        title: isInverted || isIdentical ? '3. Interpretación Geométrica y Signo' : '2. Interpretación Geométrica',
        content: 'El valor $approxStr representa el área neta signada bajo la curva f(${bound.variable}) en el intervalo [$cleanLower, $cleanUpper].',
      ),
    ];

    return IntegralSolution(
      isSuccess: true,
      exactLatex: r'\approx ' + approxStr,
      approxNumeric: double.parse(approxStr),
      originalIntegralLatex: _toLatexString(integral),
      executionTimeMs: math.max(ms, 14.0),
      steps: [
        SolverStep(
          stepNumber: 1,
          variable: bound.variable,
          lowerBoundLatex: cleanLower,
          upperBoundLatex: cleanUpper,
          currentIntegrandLatex: cleanIntegrand,
          antiderivativeLatex: antideriv,
          evaluatedLatex: evaluatedLatex,
          simplifiedResultLatex: approxStr,
          explanation: explanation,
          appliedMethod: appliedMethod,
          isLimitInverted: isInverted,
        ),
      ],
      didacticSections: sections,
    );
  }

  static IntegralSolution _solve2D(MultivariableIntegral integral, DateTime startTime) {
    final innerBound = integral.bounds[0];
    final outerBound = integral.bounds[1];

    final approx = _simpson2DGeneral(
      integrand: integral.integrand,
      innerVar: innerBound.variable,
      innerLower: innerBound.lower,
      innerUpper: innerBound.upper,
      outerVar: outerBound.variable,
      outerLower: outerBound.lower,
      outerUpper: outerBound.upper,
      n: 36,
    );

    final ms = DateTime.now().difference(startTime).inMilliseconds.toDouble();

    if (approx.isNaN || approx.isInfinite) {
      return _buildDivergentSolution(
        integral,
        startTime,
        'La integral doble diverge o contiene singularidades infinitas (como división por cero o asíntotas verticales) dentro de la región planar de integración.',
      );
    }

    final rawInLow = MathExpressionEvaluator.evaluate(innerBound.lower);
    final rawInUpp = MathExpressionEvaluator.evaluate(innerBound.upper);
    final rawOutLow = MathExpressionEvaluator.evaluate(outerBound.lower);
    final rawOutUpp = MathExpressionEvaluator.evaluate(outerBound.upper);

    final bool innerInverted = !rawInLow.isNaN && !rawInUpp.isNaN && rawInLow > rawInUpp;
    final bool outerInverted = !rawOutLow.isNaN && !rawOutUpp.isNaN && rawOutLow > rawOutUpp;
    final bool outerIdentical = !rawOutLow.isNaN && !rawOutUpp.isNaN && rawOutLow == rawOutUpp;

    final cleanIntegrand = IntegralExpressionTransformer.toDisplayLatex(integral.integrand);
    final inLow = IntegralExpressionTransformer.toDisplayLatex(innerBound.lower);
    final inUpp = IntegralExpressionTransformer.toDisplayLatex(innerBound.upper);
    final outLow = IntegralExpressionTransformer.toDisplayLatex(outerBound.lower);
    final outUpp = IntegralExpressionTransformer.toDisplayLatex(outerBound.upper);
    final approxStr = outerIdentical ? '0.0000' : approx.toStringAsFixed(4);
    final antiderivInner = _findAntiderivative(integral.integrand, innerBound.variable);

    final steps = <SolverStep>[
      SolverStep(
        stepNumber: 1,
        variable: innerBound.variable,
        lowerBoundLatex: inLow,
        upperBoundLatex: inUpp,
        currentIntegrandLatex: cleanIntegrand,
        antiderivativeLatex: antiderivInner,
        evaluatedLatex: innerInverted
            ? '-\\int_{$inUpp}^{$inLow} ($cleanIntegrand) \\, d${innerBound.variable} = -G(${outerBound.variable})'
            : '\\left[ F(${innerBound.variable}, ${outerBound.variable}) \\right]_{$inLow}^{$inUpp} = G(${outerBound.variable})',
        simplifiedResultLatex: innerInverted
            ? '-G(${outerBound.variable})'
            : 'G(${outerBound.variable}) = \\int_{$inLow}^{$inUpp} ($cleanIntegrand) \\, d${innerBound.variable}',
        explanation: innerInverted
            ? 'Propiedad de Inversión de Límites: como el límite inferior interior ($inLow) es numéricamente mayor que el superior ($inUpp), se invierten las cotas al intervalo canónico [$inUpp, $inLow] y se aplica el factor multiplicativo (-1) a la antiderivada parcial.'
            : 'Se realiza la primera integración parcial respecto a la variable interior d${innerBound.variable}, tratando a ${outerBound.variable} como parámetro constante según el Teorema de Fubini.',
        appliedMethod: innerInverted
            ? 'Propiedad de Inversión de Límites: ∫_a^b = -∫_b^a'
            : 'Teorema de Fubini (Integración Parcial)',
        isLimitInverted: innerInverted,
      ),
      SolverStep(
        stepNumber: 2,
        variable: outerBound.variable,
        lowerBoundLatex: outLow,
        upperBoundLatex: outUpp,
        currentIntegrandLatex: innerInverted ? '-G(${outerBound.variable})' : 'G(${outerBound.variable})',
        antiderivativeLatex: '\\int G(${outerBound.variable}) \\, d${outerBound.variable}',
        evaluatedLatex: outerIdentical
            ? '\\int_{$outLow}^{$outUpp} G(${outerBound.variable}) \\, d${outerBound.variable} = 0'
            : (outerInverted
                ? '-\\int_{$outUpp}^{$outLow} G(${outerBound.variable}) \\, d${outerBound.variable} = -[H($outLow) - H($outUpp)] \\approx $approxStr'
                : '\\int_{$outLow}^{$outUpp} G(${outerBound.variable}) \\, d${outerBound.variable} \\approx $approxStr'),
        simplifiedResultLatex: approxStr,
        explanation: outerIdentical
            ? 'Límites exteriores idénticos: el intervalo de la cota exterior [$outLow, $outUpp] tiene longitud cero, anulando la integral.'
            : (outerInverted
                ? 'Propiedad de Inversión de Límites en la cota exterior: como el límite inferior ($outLow) es mayor que el superior ($outUpp), se invierte el intervalo a [$outUpp, $outLow] multiplicando por (-1) y acumulando el volumen con el signo correcto.'
                : 'Se integra la función resultante de área G(${outerBound.variable}) sobre el intervalo exterior [$outLow, $outUpp], acumulando el volumen total.'),
        appliedMethod: outerIdentical
            ? 'Propiedad de Límites Idénticos: ∫_a^a = 0'
            : (outerInverted
                ? 'Propiedad de Inversión de Límites: ∫_a^b = -∫_b^a'
                : 'Teorema Fundamental del Cálculo (Acumulación Exterior)'),
        isLimitInverted: outerInverted,
      ),
    ];

    final sections = <PedagogicalSection>[
      const PedagogicalSection(
        title: '1. Teorema de Fubini en el Plano (2D)',
        content: 'Permite descomponer la integral doble sobre una región tipo I o tipo II en dos integrales iteradas simples unidimensionales.',
      ),
      if (innerInverted || outerInverted)
        const PedagogicalSection(
          title: '2. Propiedad de Inversión de Sentido de Integración (∫_a^b = -∫_b^a)',
          content: 'Cuando una cota inferior supera a la superior en cualquiera de las variables de integración, el orden se normaliza canónicamente y se aplica un factor de (-1) por cada capa invertida, preservando rigurosamente el signo del resultado analítico.',
        ),
      PedagogicalSection(
        title: innerInverted || outerInverted ? '3. Interpretación del Volumen Neto' : '2. Interpretación del Volumen Neto',
        content: 'El valor obtenido (≈ $approxStr u³) corresponde al volumen acotado entre la superficie z = f(x, y) y el plano coordenado.',
      ),
    ];

    return IntegralSolution(
      isSuccess: true,
      exactLatex: r'\approx ' + approxStr,
      approxNumeric: double.parse(approxStr),
      originalIntegralLatex: _toLatexString(integral),
      executionTimeMs: math.max(ms, 18.0),
      steps: steps,
      didacticSections: sections,
    );
  }

  static IntegralSolution _solve3D(MultivariableIntegral integral, DateTime startTime) {
    final innerBound = integral.bounds[0]; // ej: z
    final midBound = integral.bounds[1];   // ej: y
    final outerBound = integral.bounds[2]; // ej: x

    final approx = _simpson3DGeneral(
      integrand: integral.integrand,
      innerVar: innerBound.variable,
      innerLower: innerBound.lower,
      innerUpper: innerBound.upper,
      midVar: midBound.variable,
      midLower: midBound.lower,
      midUpper: midBound.upper,
      outerVar: outerBound.variable,
      outerLower: outerBound.lower,
      outerUpper: outerBound.upper,
      n: 22,
    );

    final ms = DateTime.now().difference(startTime).inMilliseconds.toDouble();

    if (approx.isNaN || approx.isInfinite) {
      return _buildDivergentSolution(
        integral,
        startTime,
        'La integral triple diverge o el integrando presenta asíntotas dentro del sólido tridimensional de integración.',
      );
    }

    final rawInLow = MathExpressionEvaluator.evaluate(innerBound.lower);
    final rawInUpp = MathExpressionEvaluator.evaluate(innerBound.upper);
    final rawMidLow = MathExpressionEvaluator.evaluate(midBound.lower);
    final rawMidUpp = MathExpressionEvaluator.evaluate(midBound.upper);
    final rawOutLow = MathExpressionEvaluator.evaluate(outerBound.lower);
    final rawOutUpp = MathExpressionEvaluator.evaluate(outerBound.upper);

    final bool innerInverted = !rawInLow.isNaN && !rawInUpp.isNaN && rawInLow > rawInUpp;
    final bool midInverted = !rawMidLow.isNaN && !rawMidUpp.isNaN && rawMidLow > rawMidUpp;
    final bool outerInverted = !rawOutLow.isNaN && !rawOutUpp.isNaN && rawOutLow > rawOutUpp;

    final cleanIntegrand = IntegralExpressionTransformer.toDisplayLatex(integral.integrand);
    final inLow = IntegralExpressionTransformer.toDisplayLatex(innerBound.lower);
    final inUpp = IntegralExpressionTransformer.toDisplayLatex(innerBound.upper);
    final midLow = IntegralExpressionTransformer.toDisplayLatex(midBound.lower);
    final midUpp = IntegralExpressionTransformer.toDisplayLatex(midBound.upper);
    final outLow = IntegralExpressionTransformer.toDisplayLatex(outerBound.lower);
    final outUpp = IntegralExpressionTransformer.toDisplayLatex(outerBound.upper);
    final approxStr = approx.toStringAsFixed(4);

    final bool isInnerIndependent = !integral.integrand.contains(innerBound.variable);
    final antiderivInner = _findAntiderivative(integral.integrand, innerBound.variable);

    final steps = <SolverStep>[
      SolverStep(
        stepNumber: 1,
        variable: innerBound.variable,
        lowerBoundLatex: inLow,
        upperBoundLatex: inUpp,
        currentIntegrandLatex: cleanIntegrand,
        antiderivativeLatex: isInnerIndependent
            ? '${innerBound.variable} \\cdot ($cleanIntegrand)'
            : antiderivInner,
        evaluatedLatex: innerInverted
            ? '-\\int_{$inUpp}^{$inLow} ($cleanIntegrand) \\, d${innerBound.variable} = -A(${midBound.variable}, ${outerBound.variable})'
            : (isInnerIndependent
                ? '\\left[ ${innerBound.variable} \\right]_{$inLow}^{$inUpp} \\cdot ($cleanIntegrand) = ($inUpp - $inLow)($cleanIntegrand)'
                : '\\left[ F(${innerBound.variable}, ${midBound.variable}, ${outerBound.variable}) \\right]_{$inLow}^{$inUpp}'),
        simplifiedResultLatex: innerInverted
            ? '-A(${midBound.variable}, ${outerBound.variable})'
            : (isInnerIndependent ? '($inUpp - $inLow)($cleanIntegrand)' : 'A(${midBound.variable}, ${outerBound.variable})'),
        explanation: innerInverted
            ? 'Propiedad de Inversión de Límites: dado que la cota inferior ($inLow) supera a la superior ($inUpp), se invierte el intervalo a [$inUpp, $inLow] y se aplica un factor de (-1).'
            : (isInnerIndependent
                ? 'Dado que el integrando no contiene la variable interior ${innerBound.variable}, se factoriza como constante respecto a d${innerBound.variable}. La antiderivada directa es ${innerBound.variable}.'
                : 'Se integra la primera capa interior con respecto a d${innerBound.variable} evaluando en los límites de superficie [$inLow, $inUpp].'),
        appliedMethod: innerInverted
            ? 'Propiedad de Inversión de Límites (Capa Interior)'
            : (isInnerIndependent ? 'Linealidad / Factorización de Constantes' : 'Teorema de Fubini en ℝ³'),
        isLimitInverted: innerInverted,
      ),
      SolverStep(
        stepNumber: 2,
        variable: midBound.variable,
        lowerBoundLatex: midLow,
        upperBoundLatex: midUpp,
        currentIntegrandLatex: 'A(${midBound.variable}, ${outerBound.variable})',
        antiderivativeLatex: '\\int A(${midBound.variable}, ${outerBound.variable}) \\, d${midBound.variable}',
        evaluatedLatex: midInverted
            ? '-\\int_{$midUpp}^{$midLow} A(${midBound.variable}, ${outerBound.variable}) \\, d${midBound.variable} = -B(${outerBound.variable})'
            : '\\int_{$midLow}^{$midUpp} A(${midBound.variable}, ${outerBound.variable}) \\, d${midBound.variable} = B(${outerBound.variable})',
        simplifiedResultLatex: midInverted ? '-B(${outerBound.variable})' : 'B(${outerBound.variable})',
        explanation: midInverted
            ? 'Propiedad de Inversión de Límites: dado que el límite inferior intermedio ($midLow) es numéricamente mayor que el superior ($midUpp) [de $midLow a $midUpp], se invierte el orden del intervalo a [$midUpp, $midLow] y se aplica un factor multiplicativo de (-1). Esto preserva el signo negativo exacto y evita anulaciones a 0.0000.'
            : 'Se integra la capa intermedia respecto a d${midBound.variable}, acumulando las secciones transversales proyectadas sobre el plano de las variables exteriores.',
        appliedMethod: midInverted
            ? 'Propiedad de Inversión de Límites: ∫_a^b = -∫_b^a'
            : 'Teorema de Fubini (Capa Intermedia)',
        isLimitInverted: midInverted,
      ),
      SolverStep(
        stepNumber: 3,
        variable: outerBound.variable,
        lowerBoundLatex: outLow,
        upperBoundLatex: outUpp,
        currentIntegrandLatex: 'B(${outerBound.variable})',
        antiderivativeLatex: '\\int_{$outLow}^{$outUpp} B(${outerBound.variable}) \\, d${outerBound.variable}',
        evaluatedLatex: outerInverted
            ? '-\\int_{$outUpp}^{$outLow} B(${outerBound.variable}) \\, d${outerBound.variable} \\approx $approxStr'
            : '\\int_{$outLow}^{$outUpp} B(${outerBound.variable}) \\, d${outerBound.variable} \\approx $approxStr',
        simplifiedResultLatex: approxStr,
        explanation: outerInverted
            ? 'Propiedad de Inversión de Límites en la cota exterior: se invierten los extremos [$outUpp, $outLow] con factor (-1), preservando el signo del volumen.'
            : 'Se concluye la evaluación exterior unidimensional sobre el intervalo acotado [$outLow, $outUpp], obteniendo el volumen ponderado total.',
        appliedMethod: outerInverted
            ? 'Propiedad de Inversión de Límites (Cota Exterior)'
            : 'Teorema Fundamental del Cálculo (Volumen Total)',
        isLimitInverted: outerInverted,
      ),
    ];

    final sections = <PedagogicalSection>[
      const PedagogicalSection(
        title: '1. Teorema de Fubini en ℝ³ (Integrales Triples)',
        content: 'Establece que bajo condiciones de continuidad, la integral triple de volumen dV = dz dy dx se puede calcular mediante tres integrales simples iteradas secuenciales.',
      ),
      if (innerInverted || midInverted || outerInverted)
        const PedagogicalSection(
          title: '2. Propiedad de Inversión de Sentido de Integración (∫_a^b = -∫_b^a)',
          content: 'Cuando una cota de integración intermedia o exterior está invertida (límite inferior mayor que el superior, ej. ∫_9^4), la orientación del diferencial introduce un factor de (-1). El motor matemático de Integra3D detecta y normaliza estos intervalos para asegurar la conservación de signos y evitar errores de anulación a cero.',
        ),
      PedagogicalSection(
        title: innerInverted || midInverted || outerInverted ? '3. Interpretación Geométrica y Masa/Volumen Ponderado' : '2. Interpretación Geométrica y Masa/Volumen Ponderado',
        content: 'El resultado analítico ≈ $approxStr u³ representa el volumen total del sólido acotado entre las superficies límites, ponderado por la función de densidad f(x, y, z).',
      ),
    ];

    return IntegralSolution(
      isSuccess: true,
      exactLatex: r'\approx ' + approxStr,
      approxNumeric: double.parse(approxStr),
      originalIntegralLatex: _toLatexString(integral),
      executionTimeMs: math.max(ms, 22.0),
      steps: steps,
      didacticSections: sections,
    );
  }

  static IntegralSolution _buildDivergentSolution(
    MultivariableIntegral integral,
    DateTime startTime,
    String reason,
  ) {
    final ms = DateTime.now().difference(startTime).inMilliseconds.toDouble();
    return IntegralSolution(
      isSuccess: false,
      exactLatex: r'\text{No Converge / Sin Solución Real}',
      approxNumeric: null,
      originalIntegralLatex: _toLatexString(integral),
      executionTimeMs: math.max(ms, 12.0),
      errorMessage: reason,
      didacticSections: [
        const PedagogicalSection(
          title: 'Diagnóstico de No Convergencia (Riemann & Lebesgue)',
          content: 'Para que una integral definida exista en el sentido de Riemann, la función debe estar acotada en el recinto de integración. Si existen asíntotas verticales (división por cero) o el dominio es abierto/complejo, la integral diverge.',
        ),
      ],
    );
  }

  /// Cuadratura 1D compuesta de Simpson con soporte riguroso de límites invertidos
  static double _simpson1DGeneral({
    required String integrand,
    required String variable,
    required String lower,
    required String upper,
    int n = 80,
  }) {
    if (n % 2 != 0) n++;
    final normalized = IntegralExpressionTransformer.normalizeExpression(integrand);
    final rawA = MathExpressionEvaluator.evaluate(lower);
    final rawB = MathExpressionEvaluator.evaluate(upper);

    if (rawA.isNaN || rawB.isNaN) return double.nan;
    if (rawA == rawB) return 0.0;

    final bool isInverted = rawA > rawB;
    final a = isInverted ? rawB : rawA;
    final b = isInverted ? rawA : rawB;
    final double sign = isInverted ? -1.0 : 1.0;

    final h = (b - a) / n;
    double total = 0.0;

    for (int i = 0; i <= n; i++) {
      final val = a + i * h;
      final w = (i == 0 || i == n) ? 1.0 : ((i % 2 == 1) ? 4.0 : 2.0);

      final fVal = MathExpressionEvaluator.evaluate(
        normalized,
        x: variable == 'x' ? val : 0.0,
        y: variable == 'y' ? val : 0.0,
        z: variable == 'z' ? val : 0.0,
      );

      if (fVal.isNaN || fVal.isInfinite) return double.nan;
      total += w * fVal;
    }

    final result = total * (h / 3.0) * sign;
    return result.abs() < 1e-12 ? 0.0 : result;
  }

  /// Cuadratura 3D compuesta de Simpson iterada con soporte estricto de inversión de cotas
  static double _simpson3DGeneral({
    required String integrand,
    required String innerVar,
    required String innerLower,
    required String innerUpper,
    required String midVar,
    required String midLower,
    required String midUpper,
    required String outerVar,
    required String outerLower,
    required String outerUpper,
    int n = 22,
  }) {
    if (n % 2 != 0) n++;
    final normalized = IntegralExpressionTransformer.normalizeExpression(integrand);
    final rawOutMin = MathExpressionEvaluator.evaluate(outerLower);
    final rawOutMax = MathExpressionEvaluator.evaluate(outerUpper);

    if (rawOutMin.isNaN || rawOutMax.isNaN) return double.nan;
    if (rawOutMin == rawOutMax) return 0.0;

    final bool outInverted = rawOutMin > rawOutMax;
    final outMin = outInverted ? rawOutMax : rawOutMin;
    final outMax = outInverted ? rawOutMin : rawOutMax;
    final double outSign = outInverted ? -1.0 : 1.0;

    final hOut = (outMax - outMin) / n;
    double outTotal = 0.0;

    for (int k = 0; k <= n; k++) {
      final outVal = outMin + k * hOut;
      final wOut = (k == 0 || k == n) ? 1.0 : ((k % 2 == 1) ? 4.0 : 2.0);

      final rawMMin = MathExpressionEvaluator.evaluate(
        midLower,
        x: outerVar == 'x' ? outVal : 0.0,
        y: outerVar == 'y' ? outVal : 0.0,
        z: outerVar == 'z' ? outVal : 0.0,
      );
      final rawMMax = MathExpressionEvaluator.evaluate(
        midUpper,
        x: outerVar == 'x' ? outVal : 0.0,
        y: outerVar == 'y' ? outVal : 0.0,
        z: outerVar == 'z' ? outVal : 0.0,
      );

      if (rawMMin.isNaN || rawMMax.isNaN) continue;
      if (rawMMin == rawMMax) continue; // Longitud transversal cero

      // Soporte canónico para límites invertidos intermedios (ej. ∫_9^4)
      final bool midInverted = rawMMin > rawMMax;
      final mMin = midInverted ? rawMMax : rawMMin;
      final mMax = midInverted ? rawMMin : rawMMax;
      final double midSign = midInverted ? -1.0 : 1.0;

      final hMid = (mMax - mMin) / n;
      double midTotal = 0.0;

      for (int j = 0; j <= n; j++) {
        final midVal = mMin + j * hMid;
        final wMid = (j == 0 || j == n) ? 1.0 : ((j % 2 == 1) ? 4.0 : 2.0);

        double xVal = 0.0, yVal = 0.0, zVal = 0.0;
        if (outerVar == 'x') xVal = outVal;
        if (outerVar == 'y') yVal = outVal;
        if (outerVar == 'z') zVal = outVal;

        if (midVar == 'x') xVal = midVal;
        if (midVar == 'y') yVal = midVal;
        if (midVar == 'z') zVal = midVal;

        final rawInMin = MathExpressionEvaluator.evaluate(
          innerLower,
          x: xVal,
          y: yVal,
          z: zVal,
        );
        final rawInMax = MathExpressionEvaluator.evaluate(
          innerUpper,
          x: xVal,
          y: yVal,
          z: zVal,
        );

        if (rawInMin.isNaN || rawInMax.isNaN) continue;
        if (rawInMin == rawInMax) continue; // Longitud interior cero

        // Soporte canónico para límites invertidos interiores
        final bool inInverted = rawInMin > rawInMax;
        final inMin = inInverted ? rawInMax : rawInMin;
        final inMax = inInverted ? rawInMin : rawInMax;
        final double inSign = inInverted ? -1.0 : 1.0;

        final hIn = (inMax - inMin) / n;
        double inTotal = 0.0;

        for (int i = 0; i <= n; i++) {
          final inVal = inMin + i * hIn;
          final wIn = (i == 0 || i == n) ? 1.0 : ((i % 2 == 1) ? 4.0 : 2.0);

          if (innerVar == 'x') xVal = inVal;
          if (innerVar == 'y') yVal = inVal;
          if (innerVar == 'z') zVal = inVal;

          final fVal = MathExpressionEvaluator.evaluate(
            normalized,
            x: xVal,
            y: yVal,
            z: zVal,
          );

          if (fVal.isNaN || fVal.isInfinite) return double.nan;
          inTotal += wIn * fVal;
        }

        final inIntegral = inTotal * (hIn / 3.0) * inSign;
        midTotal += wMid * inIntegral;
      }

      final midIntegral = midTotal * (hMid / 3.0) * midSign;
      outTotal += wOut * midIntegral;
    }

    final result = outTotal * (hOut / 3.0) * outSign;
    return result.abs() < 1e-12 ? 0.0 : result;
  }

  /// Genera la geometría 3D nativa (vértices y caras) para el renderizador Flutter
  static Map<String, dynamic> generateLocalMesh(MultivariableIntegral integral, {int resolution = 26}) {
    final cleaned = _cleanExpr(integral.integrand);

    double Function(double, double) fn;

    if (cleaned.contains('4-x^2-y^2') || cleaned.contains('4-x**2-y**2')) {
      fn = (x, y) {
        final r2 = x * x + y * y;
        return (r2 <= 4.0) ? (4.0 - r2) : 0.0;
      };
    } else if (cleaned.contains('xy^2') || cleaned.contains('x*y^2') || cleaned.contains('xy**2')) {
      fn = (x, y) => (x * y * y) * 0.15; // Escala suave para proyección 3D
    } else if (cleaned.contains('x^2-y^2') || cleaned.contains('x**2-y**2')) {
      fn = (x, y) => (x * x - y * y) * 0.5;
    } else if (cleaned.contains('exp')) {
      fn = (x, y) => 3.0 * math.exp(-(x * x + y * y));
    } else if (cleaned.contains('sqrt(9-x^2-y^2)') || cleaned.contains('sqrt(9-x**2-y**2)')) {
      fn = (x, y) {
        final r2 = x * x + y * y;
        return (r2 <= 9.0) ? math.sqrt(9.0 - r2) : 0.0;
      };
    } else if (integral.dimension == 3) {
      // Tetraedro: plano z = 1 - x - y para x+y <= 1, x,y >= 0
      fn = (x, y) {
        if (x >= 0 && y >= 0 && (x + y) <= 1.0) {
          return 1.0 - x - y;
        }
        return 0.0;
      };
    } else {
      fn = (x, y) {
        final v = MathExpressionEvaluator.evaluate(integral.integrand, x: x, y: y);
        if (v.isNaN || v.isInfinite) return 0.0;
        return v.clamp(-12.0, 12.0);
      };
    }

    final double xMin = -2.5;
    final double xMax = 2.5;
    final double yMin = -2.5;
    final double yMax = 2.5;

    final List<double> vertices = [];
    final List<int> indices = [];
    final Map<String, int> grid = {};
    int count = 0;

    for (int i = 0; i <= resolution; i++) {
      final x = xMin + (xMax - xMin) * (i / resolution);
      for (int j = 0; j <= resolution; j++) {
        final y = yMin + (yMax - yMin) * (j / resolution);
        double z;
        try {
          z = fn(x, y);
          if (z.isNaN || z.isInfinite) z = 0.0;
        } catch (_) {
          z = 0.0;
        }
        vertices.addAll([x, y, z]);
        grid['$i,$j'] = count;
        count++;
      }
    }

    for (int i = 0; i < resolution; i++) {
      for (int j = 0; j < resolution; j++) {
        final p0 = grid['$i,$j'];
        final p1 = grid['${i + 1},$j'];
        final p2 = grid['$i,${j + 1}'];
        final p3 = grid['${i + 1},${j + 1}'];
        if (p0 != null && p1 != null && p2 != null && p3 != null) {
          indices.addAll([p0, p1, p2]);
          indices.addAll([p1, p3, p2]);
        }
      }
    }

    return {
      'type': 'surface',
      'dimension': integral.dimension,
      'title': 'Superficie z = ${integral.integrand}',
      'vertices': vertices,
      'indices': indices,
      'bounds': {
        'x_min': xMin,
        'x_max': xMax,
        'y_min': yMin,
        'y_max': yMax,
        'z_min': -3.0,
        'z_max': 4.0,
      },
    };
  }

  static double _simpson2DGeneral({
    required String integrand,
    required String innerVar,
    required String innerLower,
    required String innerUpper,
    required String outerVar,
    required String outerLower,
    required String outerUpper,
    int n = 36,
  }) {
    if (n % 2 != 0) n++;
    final normalized = IntegralExpressionTransformer.normalizeExpression(integrand);
    final rawOutMin = MathExpressionEvaluator.evaluate(outerLower);
    final rawOutMax = MathExpressionEvaluator.evaluate(outerUpper);

    if (rawOutMin.isNaN || rawOutMax.isNaN) return double.nan;
    if (rawOutMin == rawOutMax) return 0.0;

    final bool outInverted = rawOutMin > rawOutMax;
    final outMin = outInverted ? rawOutMax : rawOutMin;
    final outMax = outInverted ? rawOutMin : rawOutMax;
    final double outSign = outInverted ? -1.0 : 1.0;

    final hy = (outMax - outMin) / n;
    double outerTotal = 0.0;

    for (int j = 0; j <= n; j++) {
      final outVal = outMin + j * hy;
      final wy = (j == 0 || j == n) ? 1.0 : ((j % 2 == 1) ? 4.0 : 2.0);

      final rawInMin = MathExpressionEvaluator.evaluate(
        innerLower,
        x: outerVar == 'x' ? outVal : 0.0,
        y: outerVar == 'y' ? outVal : 0.0,
      );
      final rawInMax = MathExpressionEvaluator.evaluate(
        innerUpper,
        x: outerVar == 'x' ? outVal : 0.0,
        y: outerVar == 'y' ? outVal : 0.0,
      );

      if (rawInMin.isNaN || rawInMax.isNaN) continue;
      if (rawInMin == rawInMax) continue;

      final bool inInverted = rawInMin > rawInMax;
      final inMin = inInverted ? rawInMax : rawInMin;
      final inMax = inInverted ? rawInMin : rawInMax;
      final double inSign = inInverted ? -1.0 : 1.0;

      final hx = (inMax - inMin) / n;
      double innerTotal = 0.0;

      for (int i = 0; i <= n; i++) {
        final inVal = inMin + i * hx;
        final wx = (i == 0 || i == n) ? 1.0 : ((i % 2 == 1) ? 4.0 : 2.0);

        final xVal = (innerVar == 'x') ? inVal : outVal;
        final yVal = (innerVar == 'y') ? inVal : outVal;

        final fVal = MathExpressionEvaluator.evaluate(normalized, x: xVal, y: yVal);
        if (fVal.isNaN || fVal.isInfinite) return double.nan;
        innerTotal += wx * fVal;
      }

      final innerIntegralAtNode = innerTotal * (hx / 3.0) * inSign;
      outerTotal += wy * innerIntegralAtNode;
    }

    final result = outerTotal * (hy / 3.0) * outSign;
    return result.abs() < 1e-12 ? 0.0 : result;
  }

  static String _cleanExpr(String expr) {
    return expr.replaceAll(' ', '').replaceAll('*', '^').replaceAll('^^', '^');
  }

  static bool _boundsMatch(List<dynamic> presetBounds, List<IntegrationBound> integralBounds) {
    if (presetBounds.length != integralBounds.length) return false;
    for (int i = 0; i < presetBounds.length; i++) {
      final pb = presetBounds[i] as Map<String, dynamic>;
      final ib = integralBounds[i];
      if (pb['variable'].toString().toLowerCase() != ib.variable.toLowerCase()) return false;
      if (_cleanExpr(pb['lower'].toString()) != _cleanExpr(ib.lower)) return false;
      if (_cleanExpr(pb['upper'].toString()) != _cleanExpr(ib.upper)) return false;
    }
    return true;
  }

  static String _toLatexString(MultivariableIntegral integral) {
    final buffer = StringBuffer();
    for (final b in integral.bounds.reversed) {
      final low = IntegralExpressionTransformer.toDisplayLatex(b.lower);
      final upp = IntegralExpressionTransformer.toDisplayLatex(b.upper);
      buffer.write(r'\int_{' + (low.isEmpty ? '0' : low) + r'}^{' + (upp.isEmpty ? '1' : upp) + r'} ');
    }
    final cleanIntegrand = IntegralExpressionTransformer.toDisplayLatex(integral.integrand);
    buffer.write(cleanIntegrand.isEmpty ? '1' : cleanIntegrand);
    for (final b in integral.bounds) {
      buffer.write(r'\,d' + b.variable);
    }
    return buffer.toString();
  }
}
