import '../entities/integration_bound.dart';
import '../entities/multivariable_integral.dart';

/// Transformador y normalizador de expresiones matemáticas para Integra3D.
/// Convierte expresiones ingresadas por el usuario o capturadas por OCR en formato
/// compatible y normalizado para los motores de cálculo (SymPy en Python y LocalMathEngine en Dart).
class IntegralExpressionTransformer {
  /// Normaliza una expresión matemática agregando multiplicación implícita,
  /// convirtiendo operadores visuales a estándar y corrigiendo funciones comunes.
  static String normalizeExpression(String raw) {
    if (raw.trim().isEmpty) return '0';

    String expr = raw.trim();

    // 1. Reemplazos de caracteres especiales y Unicode a operadores estándar
    expr = expr
        .replaceAll('×', '*')
        .replaceAll('·', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('–', '-')
        .replaceAll('π', 'pi')
        .replaceAll('θ', 'theta')
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('⁴', '^4')
        .replaceAll('ⁿ', '^n');

    // 2. Normalizar sintaxis LaTeX como \sqrt{...} y \frac{...}{...}
    final sqrtRegex = RegExp(r'\\sqrt\{([^}]+)\}');
    expr = expr.replaceAllMapped(sqrtRegex, (m) => 'sqrt(${m.group(1)})');

    final fracRegex = RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}');
    expr = expr.replaceAllMapped(fracRegex, (m) => '(${m.group(1)})/(${m.group(2)})');

    // Limpiar barras invertidas sobrantes de LaTeX si las hubiera
    expr = expr.replaceAll(r'\sin', 'sin')
        .replaceAll(r'\cos', 'cos')
        .replaceAll(r'\tan', 'tan')
        .replaceAll(r'\exp', 'exp')
        .replaceAll(r'\ln', 'ln')
        .replaceAll(r'\log', 'log');

    // 3. Multiplicación implícita:
    // Número seguido de variable o función: ej. 3y -> 3*y, 2x -> 2*x, 4sin(x) -> 4*sin(x)
    expr = expr.replaceAllMapped(
      RegExp(r'(\d+)\s*([a-zA-Z\(])'),
      (m) => '${m.group(1)}*${m.group(2)}',
    );

    // Variable seguida de variable: ej. xy -> x*y, yx -> y*x
    // Asegurando no romper nombres de funciones como 'sin', 'cos', 'exp', 'log', 'ln', 'sqrt', 'pi'
    final reservedWords = ['sin', 'cos', 'tan', 'exp', 'log', 'ln', 'sqrt', 'pi', 'theta'];
    expr = _insertImplicitMultiplicationBetweenVariables(expr, reservedWords);

    // Paréntesis de cierre seguido de paréntesis de apertura: (x+1)(y-1) -> (x+1)*(y-1)
    expr = expr.replaceAllMapped(
      RegExp(r'\)\s*\('),
      (_) => ')*(',
    );

    // Variable seguida de paréntesis de apertura que no sea función: ej. x(y+1) -> x*(y+1)
    expr = expr.replaceAllMapped(
      RegExp(r'([xyzXYZ])\s*\('),
      (m) => '${m.group(1)}*(',
    );

    // Paréntesis de cierre seguido de variable: ej. (x+1)y -> (x+1)*y
    expr = expr.replaceAllMapped(
      RegExp(r'\)\s*([a-zA-Z])'),
      (m) => ')*${m.group(1)}',
    );

    // 4. Formatear operadores
    // Normalizar suma y resta binarias (sin alterar signo unario negativo como -2)
    expr = expr.replaceAllMapped(
      RegExp(r'([\w\)])\s*\+\s*'),
      (m) => '${m.group(1)} + ',
    );
    expr = expr.replaceAllMapped(
      RegExp(r'([\w\)])\s*-\s*'),
      (m) => '${m.group(1)} - ',
    );

    // Asegurar que signo unario al inicio o tras paréntesis quede pegado: -2, (-x)
    expr = expr.replaceAll(RegExp(r'^\s*-\s*'), '-');
    expr = expr.replaceAll(RegExp(r'\(\s*-\s*'), '(-');
    expr = expr.replaceAll(RegExp(r'\s*\*\s*'), '*');
    expr = expr.replaceAll(RegExp(r'\s*/\s*'), ' / ');

    return expr.trim();
  }

  /// Inserta multiplicación implícita entre variables algebraicas individuales (ej. x y^2 -> x * y^2, xy^2 -> x * y^2)
  static String _insertImplicitMultiplicationBetweenVariables(String expr, List<String> reserved) {
    // Casos comunes de cálculo multivariable:
    // x y -> x * y
    // xy^2 -> x * y^2
    // x y^2 -> x * y^2
    // y x -> y * x
    String result = expr;

    // x y^2 -> x * y^2
    result = result.replaceAllMapped(
      RegExp(r'\b([xyzXYZ])\s+([xyzXYZ])'),
      (m) => '${m.group(1)} * ${m.group(2)}',
    );

    // xy^2 -> x * y^2
    result = result.replaceAllMapped(
      RegExp(r'([xyzXYZ])([xyzXYZ])(\^|\*\*)'),
      (m) => '${m.group(1)} * ${m.group(2)}${m.group(3)}',
    );

    // xy -> x * y (donde x e y son variables aisladas)
    result = result.replaceAllMapped(
      RegExp(r'([xyzXYZ])([xyzXYZ])\b'),
      (m) => '${m.group(1)} * ${m.group(2)}',
    );

    return result;
  }

  static String _stripOuterParentheses(String s) {
    String t = s.trim();
    if (t.startsWith('(') && t.endsWith(')')) {
      int depth = 0;
      bool wrapsAll = true;
      for (int i = 0; i < t.length - 1; i++) {
        if (t[i] == '(') depth++;
        if (t[i] == ')') depth--;
        if (depth == 0) {
          wrapsAll = false;
          break;
        }
      }
      if (wrapsAll) {
        return t.substring(1, t.length - 1).trim();
      }
    }
    return t;
  }

  /// Intenta parsear una cadena completa de integral en LaTeX o texto plano.
  /// Ejemplos:
  /// - \int_{0}^{1}\int_{0}^{2-2x}(6-2x-y)\,dy\,dx
  /// - \int_{-2}^{1} \int_{0}^{3y-5} x y^2 \, dx \, dy
  /// - \int_0^1 \int_0^{1-x} \int_0^{1-x-y} 1 \, dz \, dy \, dx
  static MultivariableIntegral? parseFullIntegral(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    if (!clean.contains(r'\int') && !clean.contains('int')) {
      return null;
    }

    try {
      // 1. Regex para integral triple
      final tripleIntRegex = RegExp(
        r'\\int_\{?([^}^ ]+)\}?\^\{?([^}^ ]+)\}?\s*\\int_\{?([^}^ ]+)\}?\^\{?([^}^ ]+)\}?\s*\\int_\{?([^}^ ]+)\}?\^\{?([^}^ ]+)\}?\s*(.+?)\s*(?:\\,)?\s*d([xyzXYZ])\s*(?:\\,)?\s*d([xyzXYZ])\s*(?:\\,)?\s*d([xyzXYZ])',
      );
      final matchTriple = tripleIntRegex.firstMatch(clean);
      if (matchTriple != null) {
        final outLow = matchTriple.group(1) ?? '0';
        final outUpp = matchTriple.group(2) ?? '1';
        final midLow = matchTriple.group(3) ?? '0';
        final midUpp = matchTriple.group(4) ?? '1';
        final inLow = matchTriple.group(5) ?? '0';
        final inUpp = matchTriple.group(6) ?? '1';
        final rawIntegrand = _stripOuterParentheses(matchTriple.group(7) ?? '1');
        final inVar = matchTriple.group(8) ?? 'z';
        final midVar = matchTriple.group(9) ?? 'y';
        final outVar = matchTriple.group(10) ?? 'x';

        return MultivariableIntegral(
          integrand: normalizeExpression(rawIntegrand),
          bounds: [
            IntegrationBound(variable: inVar.toLowerCase(), lower: normalizeExpression(inLow), upper: normalizeExpression(inUpp)),
            IntegrationBound(variable: midVar.toLowerCase(), lower: normalizeExpression(midLow), upper: normalizeExpression(midUpp)),
            IntegrationBound(variable: outVar.toLowerCase(), lower: normalizeExpression(outLow), upper: normalizeExpression(outUpp)),
          ],
          coordinateSystem: CoordinateSystemType.cartesian,
        );
      }

      // 2. Regex para integral doble en LaTeX
      final doubleIntRegex = RegExp(
        r'\\int_\{?([^}^ ]+)\}?\^\{?([^}^ ]+)\}?\s*\\int_\{?([^}^ ]+)\}?\^\{?([^}^ ]+)\}?\s*(.+?)\s*(?:\\,)?\s*d([xyzXYZ])\s*(?:\\,)?\s*d([xyzXYZ])',
      );
      final match = doubleIntRegex.firstMatch(clean);
      if (match != null) {
        final outLow = match.group(1) ?? '0';
        final outUpp = match.group(2) ?? '1';
        final inLow = match.group(3) ?? '0';
        final inUpp = match.group(4) ?? '1';
        final rawIntegrand = _stripOuterParentheses(match.group(5) ?? '1');
        final inVar = match.group(6) ?? 'y';
        final outVar = match.group(7) ?? 'x';

        return MultivariableIntegral(
          integrand: normalizeExpression(rawIntegrand),
          bounds: [
            IntegrationBound(
              variable: inVar.toLowerCase(),
              lower: normalizeExpression(inLow),
              upper: normalizeExpression(inUpp),
            ),
            IntegrationBound(
              variable: outVar.toLowerCase(),
              lower: normalizeExpression(outLow),
              upper: normalizeExpression(outUpp),
            ),
          ],
          coordinateSystem: CoordinateSystemType.cartesian,
        );
      }
    } catch (_) {}

    return null;
  }

  /// Genera código LaTeX formal a partir de la entidad `MultivariableIntegral`.
  static String toLatex(MultivariableIntegral integral) {
    final buffer = StringBuffer();
    // En notación de cálculo estándar:
    // La integral exterior aparece primero: \int_{y_min}^{y_max} \int_{x_min(y)}^{x_max(y)} f(x,y) dx dy
    if (integral.bounds.length >= 2) {
      final outer = integral.bounds[1];
      final inner = integral.bounds[0];
      buffer.write(r'\int_{' + outer.lower + r'}^{' + outer.upper + r'} ');
      buffer.write(r'\int_{' + inner.lower + r'}^{' + inner.upper + r'} ');
      buffer.write(integral.integrand);
      buffer.write(r' \, d' + inner.variable + r' \, d' + outer.variable);
      return buffer.toString();
    } else if (integral.bounds.length == 1) {
      final b = integral.bounds[0];
      return r'\int_{' + b.lower + r'}^{' + b.upper + r'} ' + integral.integrand + r' \, d' + b.variable;
    }
    return integral.integrand;
  }
}
