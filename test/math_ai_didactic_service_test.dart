import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/features/calculator/domain/entities/integration_bound.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/calculator/domain/services/local_math_engine.dart';
import 'package:integra_3d/features/solver/domain/entities/integral_solution.dart';
import 'package:integra_3d/features/solver/domain/services/math_ai_didactic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;
  _FakeHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MathAiDidacticService & Textbook Hybrid Resolution', () {
    test('LocalMathEngine provides verified checkpoints for 4xy triangle integral', () {
      const integral = MultivariableIntegral(
        integrand: '4 * x * y',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: 'x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '2'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      );

      final sol = LocalMathEngine.solveLocal(integral);

      expect(sol.isSuccess, isTrue);
      expect(sol.exactLatex, equals('8'));
      expect(sol.approxNumeric, equals(8.0));
      expect(sol.regionDefinition, contains(r'0 \le x \le 2'));
      expect(sol.regionDefinition, contains(r'0 \le y \le x'));

      expect(sol.steps.length, equals(5));

      // Step 1: triangular region setup
      final s1 = sol.steps[0];
      expect(s1.variable, equals('y'));
      expect(s1.stepIntegralLatex, contains(r'\int_{0}^{x} 4xy'));

      // Step 2: inner antiderivative wrt y
      final s2 = sol.steps[1];
      expect(s2.variable, equals('y'));
      expect(s2.constantTreatmentText, contains('constante'));
      expect(s2.antiderivativeWorkLatex, contains(r'2xy^2'));

      // Step 3: inner bounds evaluation
      final s3 = sol.steps[2];
      expect(s3.variable, equals('y'));
      expect(s3.limitsEvaluationText, contains('y = 0 y y = x'));
      expect(s3.simplifiedResultLatex, equals(r'2x^3'));

      // Step 4: outer integral antiderivative wrt x
      final s4 = sol.steps[3];
      expect(s4.variable, equals('x'));
      expect(s4.antiderivativeWorkLatex, contains(r'\frac{x^4}{2}'));

      // Step 5: outer bounds evaluation & exact result
      final s5 = sol.steps[4];
      expect(s5.variable, equals('x'));
      expect(s5.limitsEvaluationText, contains('x = 0 y x = 2'));
      expect(s5.simplifiedResultLatex, equals('8'));
    });

    test('IntegralSolution JSON deserialization parses full AI JSON schema without data loss', () {
      final userJson = {
        'integral_latex': r'\int_{0}^{2} \int_{0}^{x} 4xy \, dy \, dx',
        'region_definition': r'Esta integral está definida sobre la región donde 0 \le x \le 2 y 0 \le y \le x.',
        'steps': [
          {
            'step_number': 1,
            'variable': 'y',
            'step_title': 'Paso 1: Resolver la integral interna (con respecto a y)',
            'step_integral_latex': r'\int_{0}^{x} 4xy \, dy',
            'constant_treatment_text': 'Tratamos a x como una constante e integramos respecto a y:',
            'antiderivative_work_latex': r'\int 4xy \, dy = 4x \left(\frac{y^2}{2}\right) = 2xy^2',
            'limits_evaluation_text': 'Ahora evaluamos en los límites y = 0 y y = x:',
            'evaluated_latex': r'\left[2xy^2\right]_0^x = 2x(x)^2 - 2x(0)^2 = 2x^3',
            'simplified_result_latex': r'2x^3',
            'explanation': 'Se integra respecto a y considerando x constante.',
            'applied_method': 'Regla de la Potencia & Fubini',
          },
          {
            'step_number': 2,
            'variable': 'x',
            'step_title': 'Paso 2: Resolver la integral externa (con respecto a x)',
            'step_integral_latex': r'\int_{0}^{2} 2x^3 \, dx',
            'constant_treatment_text': 'Integramos respecto a x:',
            'antiderivative_work_latex': r'\int 2x^3 \, dx = \frac{x^4}{2}',
            'limits_evaluation_text': 'Ahora evaluamos en los límites x = 0 y x = 2:',
            'evaluated_latex': r'\left[\frac{x^4}{2}\right]_0^2 = 8',
            'simplified_result_latex': '8',
            'explanation': 'Evaluación en el intervalo exterior [0, 2].',
            'applied_method': 'Teorema Fundamental del Cálculo',
          }
        ],
        'sections': [
          {
            'title': '1. Interpretación Geométrica y Planteamiento',
            'content': 'Volumen bajo la superficie z = 4xy sobre el triángulo.',
          }
        ],
        'exact_result_latex': '8',
        'decimal_result': 8.0,
        'is_success': true,
      };

      final parsed = IntegralSolution.fromJson(userJson);

      expect(parsed.isSuccess, isTrue);
      expect(parsed.exactLatex, equals('8'));
      expect(parsed.approxNumeric, equals(8.0));
      expect(parsed.regionDefinition, contains(r'0 \le x \le 2'));
      expect(parsed.steps.length, equals(2));
      expect(parsed.steps[0].stepTitle, equals('Paso 1: Resolver la integral interna (con respecto a y)'));
      expect(parsed.steps[0].appliedMethod, equals('Regla de la Potencia & Fubini'));
      expect(parsed.didacticSections?.length, equals(1));
    });

    test('MathAiDidacticService falls back gracefully without breaking when offline or no API key', () async {
      const integral = MultivariableIntegral(
        integrand: '4 * x * y',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: 'x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '2'),
        ],
      );
      final baseSol = LocalMathEngine.solveLocal(integral);

      final service = MathAiDidacticService();
      final enriched = await service.enrichWithPedagogy(
        integral: integral,
        baseSolution: baseSol,
      );

      // Must preserve truthfulness and accuracy
      expect(enriched.isSuccess, isTrue);
      expect(enriched.exactLatex, equals(baseSol.exactLatex));
      expect(enriched.approxNumeric, equals(baseSol.approxNumeric));
      expect(enriched.steps.length, equals(baseSol.steps.length));
      expect(enriched.aiStatus, contains('Motor Simbólico'));
    });

    test('LocalMathEngine solves circular integral with radicals (4 - x^2 - y^4) into 5 steps and 4pi', () {
      const integral = MultivariableIntegral(
        integrand: '4 - x^2 - y^4',
        bounds: [
          IntegrationBound(variable: 'y', lower: '-sqrt(4 - x^2)', upper: 'sqrt(4 - x^2)'),
          IntegrationBound(variable: 'x', lower: '-2', upper: '2'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
      );

      final sol = LocalMathEngine.solveLocal(integral);
      expect(sol.isSuccess, isTrue);
      expect(sol.exactLatex, equals(r'4\pi'));
      expect(sol.approxNumeric, closeTo(12.5663, 0.001));
      expect(sol.steps.length, equals(5));
      expect(sol.steps.any((s) => s.simplifiedResultLatex.contains('A(')), isFalse);
      expect(sol.steps[0].appliedMethod, contains('Simetría Par'));
      expect(sol.steps[3].appliedMethod, contains('Coordenadas Polares'));
    });

    test('IntegralSolution parses arbitrary number of step packages (6 packages) cleanly', () {
      final multiStepJson = {
        'is_success': true,
        'exact_latex': r'\frac{2}{3}\sin(1)',
        'approx_numeric': 0.56098,
        'ai_provider': 'Gemini 2.0 Flash',
        'ai_status': '✨ Procedimiento didáctico por Gemini 2.0 Flash (6 pasos)',
        'steps': [
          {
            'step_number': 1,
            'step_title': 'Paso 1: Análisis de región y necesidad de cambio en el orden',
            'applied_method': 'Teorema de Fubini (Cambio de Orden)',
            'variable': 'x',
            'step_integral_latex': r'\int_0^2 \int_{y/2}^1 y \cos(x^3) \, dx \, dy = \int_0^1 \int_0^{2x} y \cos(x^3) \, dy \, dx',
            'constant_treatment_text': 'La integral de cos(x^3) respecto a x no tiene antiderivada elemental.',
            'simplified_result_latex': r'\int_0^1 \int_0^{2x} y \cos(x^3) \, dy \, dx',
          },
          {
            'step_number': 2,
            'step_title': 'Paso 2: Resolución de la integral interna en y',
            'applied_method': 'Regla de la Potencia',
            'variable': 'y',
            'constant_treatment_text': 'Tratamos a cos(x^3) como constante e integramos y:',
            'antiderivative_work_latex': r'\int_0^{2x} y \, dy = \left[\frac{y^2}{2}\right]_0^{2x} = 2x^2',
            'simplified_result_latex': r'2x^2 \cos(x^3)',
          },
          {
            'step_number': 3,
            'step_title': 'Paso 3: Planteamiento de la integral exterior y cambio de variable',
            'applied_method': 'Método de Sustitución (u-sustitución)',
            'variable': 'x',
            'constant_treatment_text': 'Definimos u = x^3, du = 3x^2 dx => x^2 dx = du/3.',
            'simplified_result_latex': r'\frac{2}{3} \int_0^1 \cos(u) \, du',
          },
          {
            'step_number': 4,
            'step_title': 'Paso 4: Transformación de límites de integración',
            'applied_method': 'Cambio de Límites',
            'variable': 'u',
            'constant_treatment_text': 'Si x = 0 => u = 0; si x = 1 => u = 1.',
            'simplified_result_latex': 'u \\in [0, 1]',
          },
          {
            'step_number': 5,
            'step_title': 'Paso 5: Cálculo de la antiderivada en u y evaluación',
            'applied_method': 'Teorema Fundamental del Cálculo',
            'variable': 'u',
            'antiderivative_work_latex': r'\int \cos(u) \, du = \sin(u)',
            'evaluated_latex': r'\frac{2}{3}\left[\sin(u)\right]_0^1 = \frac{2}{3}\sin(1)',
            'simplified_result_latex': r'\frac{2}{3}\sin(1)',
          },
          {
            'step_number': 6,
            'step_title': 'Paso 6: Conclusión y valor numérico final',
            'applied_method': 'Aritmética Exacta',
            'variable': 'x',
            'antiderivative_work_latex': r'I = \frac{2}{3}\sin(1) \approx 0.56098',
            'simplified_result_latex': '0.56098',
          },
        ],
      };

      final sol = IntegralSolution.fromJson(multiStepJson);
      expect(sol.isSuccess, isTrue);
      expect(sol.steps.length, equals(6));
      expect(sol.aiProvider, equals('Gemini 2.0 Flash'));
      expect(sol.aiStatus, contains('✨'));
      expect(sol.steps[0].appliedMethod, equals('Teorema de Fubini (Cambio de Orden)'));
      expect(sol.steps[2].appliedMethod, equals('Método de Sustitución (u-sustitución)'));
      expect(sol.steps[4].evaluatedLatex, contains(r'\frac{2}{3}\sin(1)'));
    });

    test('MathAiDidacticService fixes unescaped LaTeX backslashes emitted by LLMs into valid JSON', () {
      // LLMs frequently output \int and \frac directly without double-escaping
      const rawAiJsonWithUnescapedBackslashes = '{"integral_latex": "\\int_{0}^{1} x dx", "steps": [{"step_number": 1, "step_title": "Paso 1", "step_integral_latex": "\\int x dx = \\frac{x^2}{2}"}]}';
      final parsed = IntegralSolution.fromJson(const {
        'is_success': true,
        'exact_latex': r'\frac{1}{2}',
        'steps': [
          {
            'step_number': 1,
            'step_title': 'Paso 1',
            'step_integral_latex': rawAiJsonWithUnescapedBackslashes,
          }
        ]
      });
      expect(parsed.isSuccess, isTrue);
      expect(parsed.steps.length, equals(1));
    });

    test('IntegralSolution parses formulas_and_methods cards cleanly', () {
      final json = {
        'is_success': true,
        'exact_latex': r'4\pi',
        'steps': [
          {'step_number': 1, 'step_title': 'Paso 1', 'step_integral_latex': r'\int y dy'}
        ],
        'formulas_and_methods': [
          {
            'name': 'Teorema de Fubini',
            'formula_latex': r'\iint_R f(x, y) dA = \int_a^b \int_c^d f(x, y) dy dx',
            'description': 'Permite descomponer integrales dobles en iteradas.',
            'application': 'Descomposición en capas ortogonales.',
          },
          {
            'name': 'Regla de la Potencia',
            'formula_latex': r'\int u^n du = \frac{u^{n+1}}{n+1} + C',
            'description': 'Antiderivada para polinomios.',
            'application': 'Integración término a término.',
          }
        ],
      };

      final parsed = IntegralSolution.fromJson(json);
      expect(parsed.isSuccess, isTrue);
      expect(parsed.formulasAndMethods, isNotNull);
      expect(parsed.formulasAndMethods!.length, equals(2));
      expect(parsed.formulasAndMethods![0].name, equals('Teorema de Fubini'));
      expect(parsed.formulasAndMethods![1].formulaLatex, contains(r'\frac{u^{n+1}}{n+1}'));
    });

    test('Every built-in preset and arbitrary 1D/2D/3D expression yields >= 4 detailed steps', () {
      for (final preset in LocalMathEngine.builtInPresets) {
        final coordName = preset['coordinate_system'] as String? ?? 'cartesian';
        final coord = CoordinateSystemType.values.firstWhere(
          (e) => e.name == coordName,
          orElse: () => CoordinateSystemType.cartesian,
        );
        final rawBounds = (preset['bounds'] as List).cast<Map<String, dynamic>>();
        final integral = MultivariableIntegral(
          integrand: preset['integrand'] as String,
          bounds: rawBounds
              .map(
                (b) => IntegrationBound(
                  variable: b['variable'] as String,
                  lower: b['lower'] as String,
                  upper: b['upper'] as String,
                ),
              )
              .toList(),
          coordinateSystem: coord,
        );
        final sol = LocalMathEngine.solveLocal(integral);
        expect(sol.isSuccess, isTrue, reason: 'Preset ${preset['id']} must succeed');
        expect(
          sol.steps.length,
          greaterThanOrEqualTo(5),
          reason: 'Preset ${preset['id']} collapsed to ${sol.steps.length} steps',
        );
      }

      const customCases = [
        // 1D trigonometric
        MultivariableIntegral(
          integrand: 'sin(x) + cos(2*x)',
          bounds: [IntegrationBound(variable: 'x', lower: '0', upper: 'pi/2')],
        ),
        // 2D polynomial with fractional linear bound y/2 and coefficient denominator
        MultivariableIntegral(
          integrand: 'x^2/2 + y',
          bounds: [
            IntegrationBound(variable: 'x', lower: 'y/2', upper: '2'),
            IntegrationBound(variable: 'y', lower: '0', upper: '2'),
          ],
        ),
        // 2D transcendental general fallback
        MultivariableIntegral(
          integrand: 'sin(x) * exp(y)',
          bounds: [
            IntegrationBound(variable: 'y', lower: '0', upper: '1'),
            IntegrationBound(variable: 'x', lower: '0', upper: '1'),
          ],
        ),
        // 2D monomial dynamically parameterized
        MultivariableIntegral(
          integrand: '6 * x * y^2',
          bounds: [
            IntegrationBound(variable: 'y', lower: '0', upper: 'x'),
            IntegrationBound(variable: 'x', lower: '0', upper: '2'),
          ],
        ),
      ];

      for (final integral in customCases) {
        final sol = LocalMathEngine.solveLocal(integral);
        expect(sol.isSuccess, isTrue, reason: 'Integral ${integral.integrand} must succeed');
        expect(
          sol.steps.length,
          greaterThanOrEqualTo(4),
          reason: 'Integral ${integral.integrand} only produced ${sol.steps.length} steps',
        );
      }
    });

    test('MathAiDidacticService unwraps Pollinations OpenAI envelope and repairs unescaped LaTeX control chars', () async {
      SharedPreferences.setMockInitialValues({});
      // Simulates raw LLM content containing single-backslash \frac (\f), \theta (\t), \beta (\b), \right (\r)
      const llmJsonWithControlChars =
          r'{"region_definition":"0 \\le r \\le 2","steps":['
          r'{"step_number":1,"variable":"y","step_title":"Paso 1","step_integral_latex":"\\int \frac{x}{2} dy","antiderivative_work_latex":"\\left(\frac{y^2}{2}\\right) \beta \theta"},'
          r'{"step_number":2,"variable":"y","step_title":"Paso 2","step_integral_latex":"\\left[\frac{y^2}{2}\\right]_0^1","antiderivative_work_latex":"\frac{1}{2}"},'
          r'{"step_number":3,"variable":"x","step_title":"Paso 3","step_integral_latex":"\\int x dx","antiderivative_work_latex":"\frac{x^2}{2}"},'
          r'{"step_number":4,"variable":"x","step_title":"Paso 4","step_integral_latex":"\right|_{0}^{2}","antiderivative_work_latex":"\frac{4}{2} = 2"}'
          r'],"exact_result_latex":"8"}';

      final openAiEnvelope = jsonEncode({
        'choices': [
          {
            'message': {
              'content': llmJsonWithControlChars,
            }
          }
        ]
      });

      final dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) {
        expect(options.path, contains('/openai'));
        expect((options.data as Map)['reasoning_effort'], equals('low'));
        return ResponseBody.fromString(
          openAiEnvelope,
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      const integral = MultivariableIntegral(
        integrand: '4 * x * y',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: 'x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '2'),
        ],
      );
      final baseSol = LocalMathEngine.solveLocal(integral);
      final service = MathAiDidacticService(dioClient: dio);

      final enriched = await service.enrichWithPedagogy(
        integral: integral,
        baseSolution: baseSol,
      );

      expect(enriched.aiProvider, equals('IA Gratuita'));
      expect(enriched.steps.length, equals(4));
      expect(enriched.steps[0].stepIntegralLatex, contains(r'\frac{x}{2}'));
      expect(enriched.steps[0].antiderivativeWorkLatex, contains(r'\beta'));
      expect(enriched.steps[0].antiderivativeWorkLatex, contains(r'\theta'));
      expect(enriched.steps[3].stepIntegralLatex, contains(r'\right'));
      expect(enriched.exactLatex, equals(baseSol.exactLatex));
    });

    test('MathAiDidacticService rejects overly summarized <= 2-step AI response for 2D/3D integrals', () async {
      SharedPreferences.setMockInitialValues({});
      final lazyAiEnvelope = jsonEncode({
        'choices': [
          {
            'message': {
              'content': jsonEncode({
                'region_definition': 'Region R',
                'steps': [
                  {'step_number': 1, 'step_title': 'Paso 1', 'step_integral_latex': r'\int 4xy dy'},
                  {'step_number': 2, 'step_title': 'Paso 2', 'step_integral_latex': '8'},
                ],
                'exact_result_latex': '8',
              }),
            }
          }
        ]
      });

      final dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((_) {
        return ResponseBody.fromString(
          lazyAiEnvelope,
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      const integral = MultivariableIntegral(
        integrand: '4 * x * y',
        bounds: [
          IntegrationBound(variable: 'y', lower: '0', upper: 'x'),
          IntegrationBound(variable: 'x', lower: '0', upper: '2'),
        ],
      );
      final baseSol = LocalMathEngine.solveLocal(integral);
      expect(baseSol.steps.length, equals(5));

      final service = MathAiDidacticService(dioClient: dio);
      final enriched = await service.enrichWithPedagogy(
        integral: integral,
        baseSolution: baseSol,
      );

      // Must keep all 5 detailed steps rather than downgrading to 2 summarized steps
      expect(enriched.steps.length, equals(5));
      expect(enriched.exactLatex, equals(baseSol.exactLatex));
      expect(enriched.aiProvider, equals('Motor Simbólico Autónomo'));
      expect(enriched.aiStatus, contains('Procedimiento Didáctico Completo'));
    });
  });
}
