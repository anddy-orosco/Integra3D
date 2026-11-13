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
    expr = expr.replaceAll(r'\arcsin', 'asin')
        .replaceAll(r'\arccos', 'acos')
        .replaceAll(r'\arctan', 'atan')
        .replaceAll(r'\sinh', 'sinh')
        .replaceAll(r'\cosh', 'cosh')
        .replaceAll(r'\tanh', 'tanh')
        .replaceAll(r'\sin', 'sin')
        .replaceAll(r'\cos', 'cos')
        .replaceAll(r'\tan', 'tan')
        .replaceAll(r'\sec', 'sec')
        .replaceAll(r'\csc', 'csc')
        .replaceAll(r'\cot', 'cot')
        .replaceAll(r'\exp', 'exp')
        .replaceAll(r'\ln', 'ln')
        .replaceAll(r'\log', 'log');

    // 2b. Convertir cos^2(x) / \cos^{2}(x) a cos(x)^2 ANTES de multiplicar dígitos implícitos
    final trigPowRegex = RegExp(
      r'\b(arcsin|arccos|arctan|asin|acos|atan|sinh|cosh|tanh|sin|cos|tan|sec|csc|cot|ln|log)\s*\^\s*(?:\{([^{}]+)\}|([0-9]+))\s*\(',
      caseSensitive: false,
    );
    int trigFrom = 0;
    while (true) {
      final m = trigPowRegex.firstMatch(expr.substring(trigFrom));
      if (m == null) break;
      final absStart = trigFrom + m.start;
      final openParen = trigFrom + m.end - 1;
      int depth = 1;
      int pos = openParen + 1;
      while (pos < expr.length && depth > 0) {
        if (expr[pos] == '(') depth++;
        if (expr[pos] == ')') depth--;
        pos++;
      }
      if (depth == 0) {
        final fn = m.group(1)!;
        final powStr = m.group(2) ?? m.group(3)!;
        final arg = expr.substring(openParen + 1, pos - 1);
        final replacement = '$fn($arg)^$powStr';
        expr = expr.replaceRange(absStart, pos, replacement);
        trigFrom = absStart + replacement.length;
      } else {
        trigFrom = openParen + 1;
      }
    }

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

    // Exponente o variable seguido de función: ej. e^y exp(x) -> e^y * exp(x), x sin(y) -> x * sin(y)
    expr = expr.replaceAllMapped(
      RegExp(r'([0-9a-zA-Z\^\)])\s+(exp|sin|cos|tan|sec|csc|cot|ln|log|sqrt|cbrt|abs)'),
      (m) => '${m.group(1)} * ${m.group(2)}',
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

  /// Inserta multiplicación implícita entre variables algebraicas individuales (ej. x y^2 -> x * y^2, xy^2 -> x * y^2, 2ax -> 2*a*x)
  static String _insertImplicitMultiplicationBetweenVariables(String expr, List<String> reserved) {
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

    // Parámetros simbólicos y variables combinadas (ej: ax -> a*x, abc -> a*b*c, kR -> k*R)
    // sin dividir palabras reservadas ni tokens seguidos de '(' (como xln(...))
    const allReserved = {
      'sin', 'cos', 'tan', 'sec', 'csc', 'cot',
      'sinh', 'cosh', 'tanh', 'asin', 'acos', 'atan',
      'arcsin', 'arccos', 'arctan', 'exp', 'ln', 'log',
      'sqrt', 'cbrt', 'abs', 'pi', 'theta', 'phi', 'rho',
      'oo', 'inf',
    };
    const singleVars = {'x', 'y', 'z', 'X', 'Y', 'Z', 'a', 'b', 'c', 'm', 'n', 'k', 'r', 'R', 'H', 'u', 'v', 'w'};
    result = result.replaceAllMapped(
      RegExp(r'\b([A-Za-z]{2,5})\b(?!\s*\()'),
      (m) {
        final token = m.group(1)!;
        if (allReserved.contains(token.toLowerCase())) return token;
        if (token.startsWith('d') && token.length == 2) return token; // dx, dy, dz, dr
        final chars = token.split('');
        if (chars.every((ch) => singleVars.contains(ch))) {
          return chars.join('*');
        }
        return token;
      },
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

  /// Convierte una expresión matemática ingresada (como 'xln(x)*exp(-(x^2+y^2))sqrt(4-x^2)')
  /// a LaTeX visual limpio y académico para renderizado con flutter_math_fork.
  /// Elimina asteriscos informáticos y muestra funciones, raíces y exponentes como en libros de cálculo.
  static String toDisplayLatex(String raw) {
    if (raw.trim().isEmpty) return '';

    String expr = raw.trim();

    // Limpiar '1 *' si antecede a una variable o función (ej: 1 * e^y -> e^y), salvo si la expresión es solo '1'
    if (expr != '1') {
      expr = expr.replaceAll(RegExp(r'(^|[\+\-\(\s])1\s*\*\s*'), r'$1');
    }

    // 0. Separar si una variable o número está pegado a una función (ej: xln(x) -> x ln(x), 3sqrt -> 3 sqrt)
    expr = expr.replaceAllMapped(
      RegExp(r'([0-9a-zA-Z\)])(sin|cos|tan|sec|csc|cot|ln|log|exp|sqrt|cbrt|abs)'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // 1. Reemplazar funciones con argumentos balanceados:
    // exp(...) -> e^{...}
    expr = _replaceFunctionWithBalancedBrackets(expr, 'exp', (arg) => 'e^{${toDisplayLatex(arg)}}');

    // sqrt(...) -> \sqrt{...}
    expr = _replaceFunctionWithBalancedBrackets(expr, 'sqrt', (arg) => '\\sqrt{${toDisplayLatex(arg)}}');

    // cbrt(...) -> \sqrt[3]{...}
    expr = _replaceFunctionWithBalancedBrackets(expr, 'cbrt', (arg) => '\\sqrt[3]{${toDisplayLatex(arg)}}');

    // abs(...) -> |...|
    expr = _replaceFunctionWithBalancedBrackets(expr, 'abs', (arg) => '|${toDisplayLatex(arg)}|');

    // 2. Eliminar multiplicación explícita innecesaria (*)
    expr = expr.replaceAllMapped(
      RegExp(r'(\d+)\s*\*\s*([xyzXYZ](?:[\s\^\+\-\*/\)]|$))'),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    expr = expr.replaceAllMapped(
      RegExp(r'([xyzXYZ])\s*\*\s*([xyzXYZ])'),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    expr = expr.replaceAllMapped(
      RegExp(r'(\d+)\s*\*\s*([a-zA-Z\(\\])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    expr = expr.replaceAllMapped(
      RegExp(r'([a-zA-Z\)])\s*\*\s*([a-zA-Z\(\\])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    expr = expr.replaceAll('*', ' ');

    // 3. Potencias: x^2 -> x^{2}, ^(arg) -> ^{arg}, e^y -> e^{y}
    expr = expr.replaceAllMapped(
      RegExp(r'\^(\d+)'),
      (m) => '^{${m.group(1)}}',
    );
    expr = expr.replaceAllMapped(
      RegExp(r'\^([a-zA-Z])'),
      (m) => '^{${m.group(1)}}',
    );
    expr = expr.replaceAllMapped(
      RegExp(r'\^\(([^)]+)\)'),
      (m) => '^{${m.group(1)}}',
    );

    // 4. Funciones trigonométricas y trascendentes
    final funcs = [
      'arcsin', 'arccos', 'arctan', 'arcsec', 'asin', 'acos', 'atan',
      'sinh', 'cosh', 'tanh',
      'sin', 'cos', 'tan', 'sec', 'csc', 'cot',
      'ln', 'log'
    ];
    for (final f in funcs) {
      expr = expr.replaceAllMapped(
        RegExp('\\b$f\\b'),
        (m) => '\\$f',
      );
    }

    // 4b. Reordenar potencias trigonométricas a notación clásica: \sin(arg)^{2} -> \sin^{2}(arg)
    for (final f in ['arcsin', 'arccos', 'arctan', 'asin', 'acos', 'atan', 'sin', 'cos', 'tan', 'sec', 'csc', 'cot', 'ln', 'log']) {
      expr = _replaceTrigPowersWithLatex(expr, f);
    }

    // 5. Símbolos griegos y especiales
    expr = expr
        .replaceAll(RegExp(r'\bpi\b'), r'\pi ')
        .replaceAll(RegExp(r'\btheta\b'), r'\theta ')
        .replaceAll(RegExp(r'\bphi\b'), r'\phi ')
        .replaceAll(RegExp(r'\brho\b'), r'\rho ')
        .replaceAll(RegExp(r'\boo\b'), r'\infty ');

    // 6. Colapsar espacios múltiples
    expr = expr.replaceAll(RegExp(r'\s+'), ' ');

    return expr.trim();
  }

  /// Reemplaza llamadas a funciones considerando paréntesis balanceados anidados (ej. sqrt(4 - (x-1)^2))
  static String _replaceFunctionWithBalancedBrackets(
    String input,
    String funcName,
    String Function(String arg) replacer,
  ) {
    String str = input;
    int idx = str.indexOf('$funcName(');
    while (idx != -1) {
      int startArg = idx + funcName.length + 1;
      int depth = 1;
      int endArg = startArg;
      while (endArg < str.length && depth > 0) {
        if (str[endArg] == '(') depth++;
        if (str[endArg] == ')') depth--;
        if (depth > 0) endArg++;
      }
      if (depth == 0) {
        String arg = str.substring(startArg, endArg);
        String replacement = replacer(arg);
        str = str.replaceRange(idx, endArg + 1, replacement);
        idx = str.indexOf('$funcName(', idx + replacement.length);
      } else {
        // Paréntesis no cerrado aún mientras el usuario escribe
        String arg = str.substring(startArg);
        String replacement = replacer(arg);
        str = str.replaceRange(idx, str.length, replacement);
        break;
      }
    }
    return str;
  }

  /// Reemplaza potencias aplicadas a funciones trigonométricas (ej: \sin(tan(y))^{2} -> \sin^{2}(\tan(y)))
  static String _replaceTrigPowersWithLatex(String input, String funcName) {
    String str = input;
    final prefix = '\\$funcName(';
    int idx = str.indexOf(prefix);
    while (idx != -1) {
      int startArg = idx + prefix.length;
      int depth = 1;
      int endArg = startArg;
      while (endArg < str.length && depth > 0) {
        if (str[endArg] == '(') depth++;
        if (str[endArg] == ')') depth--;
        if (depth > 0) endArg++;
      }
      if (depth == 0) {
        final after = str.substring(endArg + 1);
        final powMatch = RegExp(r'^\s*\^(\{?\w+\}?)').firstMatch(after);
        if (powMatch != null) {
          final power = powMatch.group(1)!;
          final cleanPower = power.startsWith('{') && power.endsWith('}')
              ? power.substring(1, power.length - 1)
              : power;
          final arg = str.substring(startArg, endArg);
          final replacement = '\\$funcName^{$cleanPower}($arg)';
          str = str.replaceRange(idx, endArg + 1 + powMatch.end, replacement);
          idx = str.indexOf(prefix, idx + replacement.length);
          continue;
        }
      }
      idx = str.indexOf(prefix, idx + prefix.length);
    }
    return str;
  }

  /// Formatea una expresión para el cursor interactivo en tiempo real.
  /// Reemplaza texto informático crudo (*, sqrt, exp, ^2) por tipografía matemática limpia (√, ², e^, etc.)
  static String formatMathInline(String raw) {
    if (raw.isEmpty) return '';

    String res = raw;

    // Limpiar 1 * si antecede a una variable o función
    if (res != '1') {
      res = res.replaceAll(RegExp(r'(^|[\+\-\(\s])1\s*\*\s*'), r'$1');
    }

    // 0. Espaciar identificadores pegados a funciones (xln -> x ln)
    res = res.replaceAllMapped(
      RegExp(r'([0-9a-zA-Z\)])(sin|cos|tan|sec|csc|cot|ln|log|exp|sqrt|cbrt|abs)'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // 1. Reemplazos de funciones con glifos matemáticos
    res = res
        .replaceAll('sqrt(', '√(')
        .replaceAll('cbrt(', '∛(')
        .replaceAll('exp(', 'e^(')
        .replaceAll('asin(', 'sin⁻¹(')
        .replaceAll('acos(', 'cos⁻¹(')
        .replaceAll('atan(', 'tan⁻¹(')
        .replaceAll('asec(', 'sec⁻¹(');

    // 2. Potencias comunes
    res = res
        .replaceAll('^2', '²')
        .replaceAll('^3', '³')
        .replaceAll('^4', '⁴')
        .replaceAll('^5', '⁵')
        .replaceAll('^n', 'ⁿ');

    // 3. Multiplicaciones informáticas (*) eliminadas o espaciadas
    res = res.replaceAll('*', ' ');

    // 4. Símbolos griegos y constantes
    res = res
        .replaceAll(RegExp(r'\bpi\b'), 'π')
        .replaceAll(RegExp(r'\btheta\b'), 'θ')
        .replaceAll(RegExp(r'\bphi\b'), 'φ')
        .replaceAll(RegExp(r'\brho\b'), 'ρ')
        .replaceAll(RegExp(r'\boo\b'), '∞');

    return res;
  }
}
