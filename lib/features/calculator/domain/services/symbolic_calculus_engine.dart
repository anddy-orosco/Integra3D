import 'dart:math' as math;
import 'integral_expression_transformer.dart';

/// Resultado estructurado de una integración simbólica en una variable.
class SymbolicIntegrationOutcome {
  final bool isSymbolic;
  final SymExpr? antiderivative;
  final String antiderivativeLatex;
  final String method;
  final String explanation;
  final String? transformationLatex;

  const SymbolicIntegrationOutcome({
    required this.isSymbolic,
    this.antiderivative,
    required this.antiderivativeLatex,
    required this.method,
    required this.explanation,
    this.transformationLatex,
  });

  factory SymbolicIntegrationOutcome.failed({
    required String integrandLatex,
    required String variable,
    String? reason,
  }) {
    return SymbolicIntegrationOutcome(
      isSymbolic: false,
      antiderivative: null,
      antiderivativeLatex: '\\int ($integrandLatex) \\, d$variable',
      method: 'Integración Numérica Compuesta',
      explanation: reason ??
          'La expresión no admite una primitiva elemental cerrada respecto a $variable según el Criterio de Liouville.',
    );
  }
}

/// Racional exacto p/q (con q > 0) para preservar fracciones exactas sin pérdida decimal.
class SymRat {
  final int p;
  final int q;

  const SymRat._(this.p, this.q);

  factory SymRat(int num, [int den = 1]) {
    if (den == 0) {
      throw ArgumentError('División entre cero en SymRat');
    }
    if (num == 0) return const SymRat._(0, 1);
    int n = num;
    int d = den;
    if (d < 0) {
      n = -n;
      d = -d;
    }
    final g = _gcd(n.abs(), d);
    return SymRat._(n ~/ g, d ~/ g);
  }

  static const SymRat zero = SymRat._(0, 1);
  static const SymRat one = SymRat._(1, 1);
  static const SymRat minusOne = SymRat._(-1, 1);

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a == 0 ? 1 : a;
  }

  double toDouble() => p / q;
  bool get isZero => p == 0;
  bool get isOne => p == 1 && q == 1;
  bool get isMinusOne => p == -1 && q == 1;
  bool get isInt => q == 1;

  bool get _safe => p.abs() < 10000000 && q < 10000000;

  SymRat? tryAdd(SymRat o) {
    if (!_safe || !o._safe) return null;
    final np = p * o.q + o.p * q;
    final nq = q * o.q;
    if (np.abs() > 1000000000 || nq > 1000000000) return null;
    return SymRat(np, nq);
  }

  SymRat? tryMul(SymRat o) {
    if (!_safe || !o._safe) return null;
    final g1 = _gcd(p.abs(), o.q);
    final g2 = _gcd(o.p.abs(), q);
    final np = (p ~/ g1) * (o.p ~/ g2);
    final nq = (q ~/ g2) * (o.q ~/ g1);
    if (np.abs() > 1000000000 || nq > 1000000000) return null;
    return SymRat(np, nq);
  }

  SymRat? tryDiv(SymRat o) {
    if (o.isZero) return null;
    return tryMul(SymRat(o.q, o.p));
  }

  SymRat abs() => SymRat(p.abs(), q);
  SymRat neg() => SymRat(-p, q);

  static SymRat? tryFromDouble(double val, {int maxDenom = 1000}) {
    if (val.isNaN || val.isInfinite) return null;
    if (val.abs() < 1e-12) return SymRat.zero;
    final neg = val < 0;
    final av = val.abs();
    for (int d = 1; d <= maxDenom; d++) {
      final n = (av * d).round();
      if ((av - n / d).abs() < 1e-8) {
        return SymRat(neg ? -n : n, d);
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SymRat && p == other.p && q == other.q;

  @override
  int get hashCode => Object.hash(p, q);

  @override
  String toString() => q == 1 ? '$p' : '$p/$q';
}

/// Nodo base del AST simbólico.
sealed class SymExpr {
  const SymExpr();

  bool dependsOn(String variable);
  Set<String> variables();
  double eval(Map<String, double> env);
  String structuralKey();
}

class SymNum extends SymExpr {
  final SymRat rat;
  const SymNum(this.rat);
  factory SymNum.intVal(int v) => SymNum(SymRat(v, 1));

  @override
  bool dependsOn(String variable) => false;

  @override
  Set<String> variables() => const {};

  @override
  double eval(Map<String, double> env) => rat.toDouble();

  @override
  String structuralKey() => 'N(${rat.p}/${rat.q})';
}

class SymFloat extends SymExpr {
  final double value;
  const SymFloat(this.value);

  @override
  bool dependsOn(String variable) => false;

  @override
  Set<String> variables() => const {};

  @override
  double eval(Map<String, double> env) => value;

  @override
  String structuralKey() => 'F(${value.toStringAsPrecision(10)})';
}

class SymConst extends SymExpr {
  final String name; // 'pi' o 'e'
  const SymConst(this.name);

  @override
  bool dependsOn(String variable) => false;

  @override
  Set<String> variables() => const {};

  @override
  double eval(Map<String, double> env) => name == 'pi' ? math.pi : math.e;

  @override
  String structuralKey() => 'C($name)';
}

class SymVar extends SymExpr {
  final String name;
  const SymVar(this.name);

  static String canonicalName(String raw) {
    if (raw == 'R' || raw == 'H') return raw;
    return raw.toLowerCase();
  }

  @override
  bool dependsOn(String variable) => name == canonicalName(variable);

  @override
  Set<String> variables() => {name};

  @override
  double eval(Map<String, double> env) => env[name] ?? 0.0;

  @override
  String structuralKey() => 'V($name)';
}

class SymAdd extends SymExpr {
  final List<SymExpr> terms;
  const SymAdd(this.terms);

  @override
  bool dependsOn(String variable) => terms.any((t) => t.dependsOn(variable));

  @override
  Set<String> variables() => terms.expand((t) => t.variables()).toSet();

  @override
  double eval(Map<String, double> env) =>
      terms.fold(0.0, (acc, t) => acc + t.eval(env));

  @override
  String structuralKey() =>
      'A(${terms.map((t) => t.structuralKey()).join('+')})';
}

class SymMul extends SymExpr {
  final List<SymExpr> factors;
  const SymMul(this.factors);

  @override
  bool dependsOn(String variable) => factors.any((f) => f.dependsOn(variable));

  @override
  Set<String> variables() => factors.expand((f) => f.variables()).toSet();

  @override
  double eval(Map<String, double> env) =>
      factors.fold(1.0, (acc, f) => acc * f.eval(env));

  @override
  String structuralKey() =>
      'M(${factors.map((f) => f.structuralKey()).join('*')})';
}

class SymDiv extends SymExpr {
  final SymExpr num;
  final SymExpr den;
  const SymDiv(this.num, this.den);

  @override
  bool dependsOn(String variable) =>
      num.dependsOn(variable) || den.dependsOn(variable);

  @override
  Set<String> variables() => {...num.variables(), ...den.variables()};

  @override
  double eval(Map<String, double> env) {
    final d = den.eval(env);
    if (d == 0.0 || d.isNaN) return double.nan;
    return num.eval(env) / d;
  }

  @override
  String structuralKey() => 'D(${num.structuralKey()}/${den.structuralKey()})';
}

class SymPow extends SymExpr {
  final SymExpr base;
  final SymExpr exp;
  const SymPow(this.base, this.exp);

  @override
  bool dependsOn(String variable) =>
      base.dependsOn(variable) || exp.dependsOn(variable);

  @override
  Set<String> variables() => {...base.variables(), ...exp.variables()};

  @override
  double eval(Map<String, double> env) {
    final b = base.eval(env);
    final e = exp.eval(env);
    if (b.isNaN || e.isNaN) return double.nan;
    if (b < 0 && e != e.roundToDouble()) return double.nan;
    if (b == 0 && e < 0) return double.nan;
    return math.pow(b, e).toDouble();
  }

  @override
  String structuralKey() => 'P(${base.structuralKey()}^${exp.structuralKey()})';
}

class SymFunc extends SymExpr {
  final String name;
  final SymExpr arg;
  const SymFunc(this.name, this.arg);

  @override
  bool dependsOn(String variable) => arg.dependsOn(variable);

  @override
  Set<String> variables() => arg.variables();

  @override
  double eval(Map<String, double> env) {
    final v = arg.eval(env);
    if (v.isNaN || v.isInfinite) return double.nan;
    switch (name) {
      case 'sin':
        return math.sin(v);
      case 'cos':
        return math.cos(v);
      case 'tan':
        return math.tan(v);
      case 'sec':
        final c = math.cos(v);
        return c.abs() < 1e-12 ? double.nan : 1.0 / c;
      case 'csc':
        final s = math.sin(v);
        return s.abs() < 1e-12 ? double.nan : 1.0 / s;
      case 'cot':
        final t = math.tan(v);
        return t.abs() < 1e-12 ? double.nan : 1.0 / t;
      case 'sinh':
        return (math.exp(v) - math.exp(-v)) / 2.0;
      case 'cosh':
        return (math.exp(v) + math.exp(-v)) / 2.0;
      case 'tanh':
        final ep = math.exp(v);
        final em = math.exp(-v);
        return (ep - em) / (ep + em);
      case 'asin':
        return (v >= -1.0 && v <= 1.0) ? math.asin(v) : double.nan;
      case 'acos':
        return (v >= -1.0 && v <= 1.0) ? math.acos(v) : double.nan;
      case 'atan':
        return math.atan(v);
      case 'exp':
        return math.exp(v);
      case 'ln':
      case 'log':
        return v > 0 ? math.log(v) : double.nan;
      case 'sqrt':
        return v >= 0 ? math.sqrt(v) : double.nan;
      case 'abs':
        return v.abs();
      default:
        return double.nan;
    }
  }

  @override
  String structuralKey() => 'Fn($name(${arg.structuralKey()}))';
}

/// Motor simbólico completo basado en AST para simplificación, derivación,
/// expansión polinomial e integración paso a paso.
class SymbolicCalculusEngine {
  static final Set<String> _knownFunctions = {
    'sin',
    'cos',
    'tan',
    'sec',
    'csc',
    'cot',
    'sinh',
    'cosh',
    'tanh',
    'asin',
    'acos',
    'atan',
    'arcsin',
    'arccos',
    'arctan',
    'exp',
    'ln',
    'log',
    'sqrt',
    'abs',
  };

  /// Determina si una cadena contiene alguna variable algebraica real (excluyendo funciones/constantes).
  static bool containsVariable(String raw) {
    final norm = IntegralExpressionTransformer.normalizeExpression(raw).toLowerCase();
    final matches = RegExp(r'[a-z]+').allMatches(norm);
    for (final m in matches) {
      final token = m.group(0)!;
      if (token == 'pi' || token == 'e' || _knownFunctions.contains(token)) {
        continue;
      }
      return true;
    }
    return false;
  }

  /// Parsea una expresión matemática arbitraria a AST simbólico simplificado.
  static SymExpr? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      var normalized = IntegralExpressionTransformer.normalizeExpression(trimmed);
      normalized = rewriteTrigPowers(normalized)
          .replaceAll('**', '^')
          .replaceAll(' ', '');
      final p = _AstParser(normalized);
      final ast = p.parseAll();
      if (ast == null) return null;
      return simplify(ast);
    } catch (_) {
      return null;
    }
  }

  /// Convierte notación tipo `cos^2(x)` / `sin^3(2x)` en `cos(x)^2` / `sin(2x)^3`.
  static String rewriteTrigPowers(String input) {
    var s = input;
    final fnRegex = RegExp(
      r'\b(arcsin|arccos|arctan|asin|acos|atan|sinh|cosh|tanh|sin|cos|tan|sec|csc|cot|ln|log)\s*\^\s*(?:\{([^{}]+)\}|([0-9]+))\s*\(',
      caseSensitive: false,
    );

    int searchFrom = 0;
    while (true) {
      final m = fnRegex.firstMatch(s.substring(searchFrom));
      if (m == null) break;
      final absStart = searchFrom + m.start;
      final openParen = searchFrom + m.end - 1;
      int depth = 1;
      int pos = openParen + 1;
      while (pos < s.length && depth > 0) {
        if (s[pos] == '(') depth++;
        if (s[pos] == ')') depth--;
        pos++;
      }
      if (depth == 0) {
        final fn = m.group(1)!;
        final powStr = m.group(2) ?? m.group(3)!;
        final arg = s.substring(openParen + 1, pos - 1);
        final replacement = '$fn($arg)^$powStr';
        s = s.replaceRange(absStart, pos, replacement);
        searchFrom = absStart + replacement.length;
      } else {
        searchFrom = openParen + 1;
      }
    }
    return s;
  }

  // ==================== EVALUACIÓN & SUSTITUCIÓN ====================

  static const Set<String> positiveSymbolicConstants = {
    'a', 'b', 'c', 'm', 'n', 'R', 'H', 'k', 'r', 'rho',
  };

  static const Set<String> symbolicParameterNames = {
    'a', 'b', 'c', 'm', 'n', 'R', 'H', 'k',
  };

  static bool hasSymbolicParameters(SymExpr e) {
    return e.variables().any((v) => symbolicParameterNames.contains(v));
  }

  static Map<String, double> defaultParamEnv(Set<String> vars) {
    const fixed = {
      'a': 1.37,
      'b': 1.73,
      'c': 2.11,
      'm': 1.5,
      'n': 2.0,
      'R': 2.0,
      'H': 3.0,
      'k': 1.25,
    };
    const fallback = [1.23, 0.87, 0.59, 1.41, 0.93];
    final env = <String, double>{};
    int idx = 0;
    for (final v in vars) {
      env[v] = fixed[v] ?? fallback[idx++ % fallback.length];
    }
    return env;
  }

  static SymExpr substitute(SymExpr expr, String variable, SymExpr replacement) {
    final v = SymVar.canonicalName(variable);
    SymExpr walk(SymExpr node) {
      switch (node) {
        case SymVar(:final name):
          return name == v ? replacement : node;
        case SymNum():
        case SymFloat():
        case SymConst():
          return node;
        case SymAdd(:final terms):
          return SymAdd(terms.map(walk).toList());
        case SymMul(:final factors):
          return SymMul(factors.map(walk).toList());
        case SymDiv(:final num, :final den):
          return SymDiv(walk(num), walk(den));
        case SymPow(:final base, :final exp):
          return SymPow(walk(base), walk(exp));
        case SymFunc(:final name, :final arg):
          return SymFunc(name, walk(arg));
      }
    }

    return simplify(walk(expr));
  }

  // ==================== SIMPLIFICACIÓN ALGEBRAICA ====================

  static SymExpr simplify(SymExpr expr, {int depth = 0}) {
    if (depth > 25) return expr;

    switch (expr) {
      case SymNum(:final rat):
        return SymNum(rat);
      case SymFloat(:final value):
        if (value.abs() < 1e-12) return SymNum.intVal(0);
        final r = SymRat.tryFromDouble(value);
        return r != null ? SymNum(r) : expr;
      case SymConst():
      case SymVar():
        return expr;

      case SymFunc(:final name, :final arg):
        final sa = simplify(arg, depth: depth + 1);
        final canonicalName = switch (name) {
          'arcsin' => 'asin',
          'arccos' => 'acos',
          'arctan' => 'atan',
          'log' => 'ln',
          _ => name,
        };
        if (canonicalName == 'exp') {
          if (sa is SymNum && sa.rat.isZero) return SymNum.intVal(1);
          if (sa is SymFunc && sa.name == 'ln') return sa.arg;
        } else if (canonicalName == 'ln') {
          if (sa is SymNum && sa.rat.isOne) return SymNum.intVal(0);
          if (sa is SymConst && sa.name == 'e') return SymNum.intVal(1);
          if (sa is SymFunc && sa.name == 'exp') return sa.arg;
        } else if (canonicalName == 'sqrt') {
          if (sa is SymNum && sa.rat.p >= 0 && sa.rat.q >= 1) {
            final sp = math.sqrt(sa.rat.p.toDouble()).round();
            final sq = math.sqrt(sa.rat.q.toDouble()).round();
            if (sp * sp == sa.rat.p && sq * sq == sa.rat.q) {
              return SymNum(SymRat(sp, sq));
            }
          }
          // sqrt(a^2) -> a for positive symbolic parameters
          if (sa is SymPow && sa.exp is SymNum && (sa.exp as SymNum).rat.isInt && (sa.exp as SymNum).rat.p == 2) {
            if (_isDefinitelyPositive(sa.base)) {
              return sa.base;
            }
          }
          if (sa is SymMul) {
            final posFactors = <SymExpr>[];
            final remFactors = <SymExpr>[];
            for (final f in sa.factors) {
              if (f is SymNum && f.rat.p > 0) {
                final sp = math.sqrt(f.rat.p.toDouble()).round();
                final sq = math.sqrt(f.rat.q.toDouble()).round();
                if (sp * sp == f.rat.p && sq * sq == f.rat.q) {
                  posFactors.add(SymNum(SymRat(sp, sq)));
                  continue;
                }
              } else if (f is SymPow && f.exp is SymNum && (f.exp as SymNum).rat.isInt && (f.exp as SymNum).rat.p % 2 == 0 && _isDefinitelyPositive(f.base)) {
                final halfP = (f.exp as SymNum).rat.p ~/ 2;
                posFactors.add(halfP == 1 ? f.base : SymPow(f.base, SymNum.intVal(halfP)));
                continue;
              }
              remFactors.add(f);
            }
            if (posFactors.isNotEmpty) {
              final out = <SymExpr>[...posFactors];
              if (remFactors.isNotEmpty) {
                out.add(SymFunc('sqrt', remFactors.length == 1 ? remFactors.first : SymMul(remFactors)));
              }
              return simplify(SymMul(out), depth: depth + 1);
            }
          }
        } else if (canonicalName == 'sin') {
          if (sa is SymNum && sa.rat.isZero) return SymNum.intVal(0);
          final exactSin = _evalExactTrigPi('sin', sa);
          if (exactSin != null) return exactSin;
          if (sa is SymNum && sa.rat.p < 0) {
            return simplify(
              SymMul([SymNum.intVal(-1), SymFunc('sin', SymNum(sa.rat.abs()))]),
              depth: depth + 1,
            );
          }
        } else if (canonicalName == 'cos') {
          if (sa is SymNum && sa.rat.isZero) return SymNum.intVal(1);
          final exactCos = _evalExactTrigPi('cos', sa);
          if (exactCos != null) return exactCos;
          if (sa is SymNum && sa.rat.p < 0) {
            return SymFunc('cos', SymNum(sa.rat.abs()));
          }
        } else if (canonicalName == 'tan') {
          if (sa is SymNum && sa.rat.isZero) return SymNum.intVal(0);
          final exactTan = _evalExactTrigPi('tan', sa);
          if (exactTan != null) return exactTan;
        } else if (canonicalName == 'abs') {
          if (sa is SymNum) return SymNum(sa.rat.abs());
          if (sa is SymFloat) return SymFloat(sa.value.abs());
          if (_isDefinitelyPositive(sa)) return sa;
        }
        // Limpiar argumento puramente negativo dentro de cos(-u) = cos(u)
        if (canonicalName == 'cos' && _isStrictlyNegated(sa)) {
          final posArg = simplify(SymMul([SymNum.intVal(-1), sa]), depth: depth + 1);
          return SymFunc('cos', posArg);
        }
        return SymFunc(canonicalName, sa);

      case SymPow(:final base, :final exp):
        final sb = simplify(base, depth: depth + 1);
        final se = simplify(exp, depth: depth + 1);
        if (sb is SymConst && sb.name == 'e') {
          return simplify(SymFunc('exp', se), depth: depth + 1);
        }
        if (se is SymNum && se.rat.isZero) return SymNum.intVal(1);
        if (se is SymNum && se.rat.isOne) return sb;
        if (sb is SymNum && sb.rat.isZero) {
          if (se is SymNum && se.rat.p > 0) return SymNum.intVal(0);
        }
        if (sb is SymNum && sb.rat.isOne) return SymNum.intVal(1);
        if (sb is SymNum && se is SymNum && se.rat.isInt && se.rat.p.abs() <= 8) {
          final res = _powRat(sb.rat, se.rat.p);
          if (res != null) return SymNum(res);
        }
        if (sb is SymPow && sb.exp is SymNum && se is SymNum) {
          final prod = (sb.exp as SymNum).rat.tryMul(se.rat);
          if (prod != null) {
            if (_isDefinitelyPositive(sb.base) || (sb.exp as SymNum).rat.p.isOdd || se.rat.isInt) {
              return simplify(SymPow(sb.base, SymNum(prod)), depth: depth + 1);
            }
          }
        }
        if (sb is SymFunc && sb.name == 'sqrt' && se is SymNum && se.rat.isInt && se.rat.p % 2 == 0) {
          final halfP = se.rat.p ~/ 2;
          return simplify(SymPow(sb.arg, SymNum.intVal(halfP)), depth: depth + 1);
        }
        if (sb is SymMul && se is SymNum && se.rat.isInt && se.rat.p.abs() >= 1 && se.rat.p.abs() <= 6) {
          return simplify(
            SymMul(sb.factors.map((f) => SymPow(f, se)).toList()),
            depth: depth + 1,
          );
        }
        return SymPow(sb, se);

      case SymDiv(:final num, :final den):
        return _simplifyDiv(num, den, depth: depth + 1);

      case SymMul(:final factors):
        return _simplifyMul(factors, depth: depth + 1);

      case SymAdd(:final terms):
        return _simplifyAdd(terms, depth: depth + 1);
    }
  }

  static bool _isDefinitelyPositive(SymExpr e) {
    if (e is SymNum) return e.rat.p > 0;
    if (e is SymFloat) return e.value > 0;
    if (e is SymConst) return true;
    if (e is SymVar) return positiveSymbolicConstants.contains(e.name);
    if (e is SymPow && e.exp is SymNum && (e.exp as SymNum).rat.isInt && (e.exp as SymNum).rat.p.isEven) {
      return true;
    }
    if (e is SymMul) return e.factors.every(_isDefinitelyPositive);
    return false;
  }

  /// Evalúa sin/cos/tan exactamente para múltiplos racionales estándar de π (0, ±π/6, ±π/4, ±π/3, ±π/2, ±π, 2π...).
  static SymExpr? _evalExactTrigPi(String fn, SymExpr arg) {
    SymRat? piMultiple;
    if (arg is SymConst && arg.name == 'pi') {
      piMultiple = SymRat.one;
    } else if (arg is SymMul && arg.factors.length == 2) {
      final f0 = arg.factors[0];
      final f1 = arg.factors[1];
      if (f0 is SymNum && f1 is SymConst && f1.name == 'pi') {
        piMultiple = f0.rat;
      } else if (f1 is SymNum && f0 is SymConst && f0.name == 'pi') {
        piMultiple = f1.rat;
      }
    } else if (arg is SymDiv && arg.num is SymConst && (arg.num as SymConst).name == 'pi' && arg.den is SymNum) {
      piMultiple = SymRat(1, 1).tryDiv((arg.den as SymNum).rat);
    }
    if (piMultiple == null) return null;

    // Normalize k in k*pi to [0, 2)
    final p = piMultiple.p;
    final q = piMultiple.q;
    if (q > 12 || (12 % q != 0)) return null;
    final step = ((p * (12 ~/ q)) % 24 + 24) % 24; // 0..23 representing step * pi / 12

    if (fn == 'sin') {
      switch (step) {
        case 0:
        case 12:
          return SymNum.intVal(0);
        case 6:
          return SymNum.intVal(1);
        case 18:
          return SymNum.intVal(-1);
        case 2:
        case 10:
          return SymNum(SymRat(1, 2));
        case 14:
        case 22:
          return SymNum(SymRat(-1, 2));
        case 3:
        case 9:
          return SymDiv(SymFunc('sqrt', SymNum.intVal(2)), SymNum.intVal(2));
        case 15:
        case 21:
          return SymMul([SymNum.intVal(-1), SymDiv(SymFunc('sqrt', SymNum.intVal(2)), SymNum.intVal(2))]);
        case 4:
        case 8:
          return SymDiv(SymFunc('sqrt', SymNum.intVal(3)), SymNum.intVal(2));
        case 16:
        case 20:
          return SymMul([SymNum.intVal(-1), SymDiv(SymFunc('sqrt', SymNum.intVal(3)), SymNum.intVal(2))]);
      }
    } else if (fn == 'cos') {
      switch (step) {
        case 0:
          return SymNum.intVal(1);
        case 12:
          return SymNum.intVal(-1);
        case 6:
        case 18:
          return SymNum.intVal(0);
        case 4:
        case 20:
          return SymNum(SymRat(1, 2));
        case 8:
        case 16:
          return SymNum(SymRat(-1, 2));
        case 3:
        case 21:
          return SymDiv(SymFunc('sqrt', SymNum.intVal(2)), SymNum.intVal(2));
        case 9:
        case 15:
          return SymMul([SymNum.intVal(-1), SymDiv(SymFunc('sqrt', SymNum.intVal(2)), SymNum.intVal(2))]);
        case 2:
        case 22:
          return SymDiv(SymFunc('sqrt', SymNum.intVal(3)), SymNum.intVal(2));
        case 10:
        case 14:
          return SymMul([SymNum.intVal(-1), SymDiv(SymFunc('sqrt', SymNum.intVal(3)), SymNum.intVal(2))]);
      }
    } else if (fn == 'tan') {
      switch (step) {
        case 0:
        case 12:
          return SymNum.intVal(0);
        case 3:
        case 15:
          return SymNum.intVal(1);
        case 9:
        case 21:
          return SymNum.intVal(-1);
      }
    }
    return null;
  }

  static SymExpr _simplifyDiv(SymExpr rawNum, SymExpr rawDen, {int depth = 0}) {
    final sn = simplify(rawNum, depth: depth + 1);
    final sd = simplify(rawDen, depth: depth + 1);
    if (sn is SymNum && sn.rat.isZero) return SymNum.intVal(0);
    if (sd is SymNum && sd.rat.isOne) return sn;
    if (sd is SymNum && sd.rat.isMinusOne) {
      return simplify(SymMul([SymNum.intVal(-1), sn]), depth: depth + 1);
    }
    if (sn is SymNum && sd is SymNum) {
      final q = sn.rat.tryDiv(sd.rat);
      if (q != null) return SymNum(q);
      return SymFloat(sn.rat.toDouble() / sd.rat.toDouble());
    }
    if (sd is SymNum) {
      final inv = SymRat(sd.rat.q, sd.rat.p);
      return simplify(SymMul([SymNum(inv), sn]), depth: depth + 1);
    }

    // Flatten nested divisions (A / B) / (C / D) -> (A * D) / (B * C)
    if (sn is SymDiv || sd is SymDiv) {
      final numExpr = sn is SymDiv ? sn.num : sn;
      final numDen = sn is SymDiv ? sn.den : SymNum.intVal(1);
      final denNum = sd is SymDiv ? sd.num : sd;
      final denDen = sd is SymDiv ? sd.den : SymNum.intVal(1);
      return _simplifyDiv(
        simplify(SymMul([numExpr, denDen]), depth: depth + 1),
        simplify(SymMul([numDen, denNum]), depth: depth + 1),
        depth: depth + 1,
      );
    }

    // Cancel common multiplicative factors between numerator and denominator
    final nFacs = sn is SymMul ? List<SymExpr>.from(sn.factors) : <SymExpr>[sn];
    final dFacs = sd is SymMul ? List<SymExpr>.from(sd.factors) : <SymExpr>[sd];

    SymRat? numCoeff = SymRat.one;
    final nGroups = <String, (SymExpr base, SymExpr exp)>{};
    final nOrder = <String>[];
    final nExtra = <SymExpr>[];

    for (final f in nFacs) {
      if (f is SymNum) {
        final m = numCoeff?.tryMul(f.rat);
        if (m != null) {
          numCoeff = m;
        } else {
          nExtra.add(f);
        }
      } else if (f is SymPow) {
        final k = f.base.structuralKey();
        if (nGroups.containsKey(k)) {
          final ex = nGroups[k]!;
          nGroups[k] = (ex.$1, simplify(SymAdd([ex.$2, f.exp]), depth: depth + 1));
        } else {
          nGroups[k] = (f.base, f.exp);
          nOrder.add(k);
        }
      } else {
        final k = f.structuralKey();
        if (nGroups.containsKey(k)) {
          final ex = nGroups[k]!;
          nGroups[k] = (ex.$1, simplify(SymAdd([ex.$2, SymNum.intVal(1)]), depth: depth + 1));
        } else {
          nGroups[k] = (f, SymNum.intVal(1));
          nOrder.add(k);
        }
      }
    }

    SymRat? denCoeff = SymRat.one;
    final dGroups = <String, (SymExpr base, SymExpr exp)>{};
    final dOrder = <String>[];
    final dExtra = <SymExpr>[];

    for (final f in dFacs) {
      if (f is SymNum) {
        final m = denCoeff?.tryMul(f.rat);
        if (m != null) {
          denCoeff = m;
        } else {
          dExtra.add(f);
        }
      } else if (f is SymPow) {
        final k = f.base.structuralKey();
        if (dGroups.containsKey(k)) {
          final ex = dGroups[k]!;
          dGroups[k] = (ex.$1, simplify(SymAdd([ex.$2, f.exp]), depth: depth + 1));
        } else {
          dGroups[k] = (f.base, f.exp);
          dOrder.add(k);
        }
      } else {
        final k = f.structuralKey();
        if (dGroups.containsKey(k)) {
          final ex = dGroups[k]!;
          dGroups[k] = (ex.$1, simplify(SymAdd([ex.$2, SymNum.intVal(1)]), depth: depth + 1));
        } else {
          dGroups[k] = (f, SymNum.intVal(1));
          dOrder.add(k);
        }
      }
    }

    bool cancelledAny = false;
    final combinedRatio = (numCoeff != null && denCoeff != null && !denCoeff.isZero)
        ? numCoeff.tryDiv(denCoeff)
        : null;

    for (final k in List<String>.from(nOrder)) {
      if (!dGroups.containsKey(k)) continue;
      final (base, nExp) = nGroups[k]!;
      final (_, dExp) = dGroups[k]!;
      if (nExp is SymNum && dExp is SymNum) {
        final diffExp = nExp.rat.tryAdd(dExp.rat.neg());
        if (diffExp != null) {
          cancelledAny = true;
          if (diffExp.isZero) {
            nGroups.remove(k);
            nOrder.remove(k);
            dGroups.remove(k);
            dOrder.remove(k);
          } else if (diffExp.p > 0) {
            nGroups[k] = (base, SymNum(diffExp));
            dGroups.remove(k);
            dOrder.remove(k);
          } else {
            nGroups.remove(k);
            nOrder.remove(k);
            dGroups[k] = (base, SymNum(diffExp.neg()));
          }
        }
      } else if (nExp.structuralKey() == dExp.structuralKey()) {
        cancelledAny = true;
        nGroups.remove(k);
        nOrder.remove(k);
        dGroups.remove(k);
        dOrder.remove(k);
      }
    }

    if (cancelledAny || (combinedRatio != null && !denCoeff!.isOne)) {
      final finalNumList = <SymExpr>[
        if (combinedRatio != null && !combinedRatio.isOne) SymNum(combinedRatio),
        if (combinedRatio == null && numCoeff != null && !numCoeff.isOne) SymNum(numCoeff),
        ...nExtra,
        for (final k in nOrder)
          (nGroups[k]!.$2 is SymNum && (nGroups[k]!.$2 as SymNum).rat.isOne)
              ? nGroups[k]!.$1
              : SymPow(nGroups[k]!.$1, nGroups[k]!.$2),
      ];
      final finalDenList = <SymExpr>[
        if (combinedRatio == null && denCoeff != null && !denCoeff.isOne) SymNum(denCoeff),
        ...dExtra,
        for (final k in dOrder)
          (dGroups[k]!.$2 is SymNum && (dGroups[k]!.$2 as SymNum).rat.isOne)
              ? dGroups[k]!.$1
              : SymPow(dGroups[k]!.$1, dGroups[k]!.$2),
      ];

      final newNum = finalNumList.isEmpty
          ? SymNum.intVal(1)
          : (finalNumList.length == 1 ? finalNumList.first : SymMul(finalNumList));
      if (finalDenList.isEmpty) {
        return simplify(newNum, depth: depth + 1);
      }
      final newDen = finalDenList.length == 1 ? finalDenList.first : SymMul(finalDenList);
      return SymDiv(simplify(newNum, depth: depth + 1), simplify(newDen, depth: depth + 1));
    }

    return SymDiv(sn, sd);
  }

  static bool _isStrictlyNegated(SymExpr e) {
    if (e is SymNum && e.rat.p < 0) return true;
    if (e is SymFloat && e.value < 0) return true;
    if (e is SymMul && e.factors.isNotEmpty) {
      final f0 = e.factors.first;
      if (f0 is SymNum && f0.rat.p < 0) return true;
    }
    return false;
  }

  static SymRat? _powRat(SymRat b, int exp) {
    if (exp == 0) return SymRat.one;
    if (exp < 0) {
      if (b.isZero) return null;
      return _powRat(SymRat(b.q, b.p), -exp);
    }
    SymRat acc = SymRat.one;
    for (int i = 0; i < exp; i++) {
      final nxt = acc.tryMul(b);
      if (nxt == null) return null;
      acc = nxt;
    }
    return acc;
  }

  static SymExpr _simplifyMul(List<SymExpr> rawFactors, {int depth = 0}) {
    final flat = <SymExpr>[];
    final denomFactors = <SymExpr>[];
    for (final f in rawFactors) {
      final sf = simplify(f, depth: depth + 1);
      if (sf is SymMul) {
        flat.addAll(sf.factors);
      } else if (sf is SymDiv) {
        if (sf.num is SymMul) {
          flat.addAll((sf.num as SymMul).factors);
        } else {
          flat.add(sf.num);
        }
        if (sf.den is SymMul) {
          denomFactors.addAll((sf.den as SymMul).factors);
        } else {
          denomFactors.add(sf.den);
        }
      } else {
        flat.add(sf);
      }
    }

    if (denomFactors.isNotEmpty) {
      final numExpr = flat.isEmpty
          ? SymNum.intVal(1)
          : (flat.length == 1 ? flat.first : SymMul(flat));
      final denExpr = denomFactors.length == 1 ? denomFactors.first : SymMul(denomFactors);
      return _simplifyDiv(numExpr, denExpr, depth: depth + 1);
    }

    SymRat? ratCoeff = SymRat.one;
    double? floatCoeff;
    final otherFactors = <SymExpr>[];

    void multRat(SymRat r) {
      if (floatCoeff != null) {
        floatCoeff = floatCoeff! * r.toDouble();
      } else {
        final res = ratCoeff!.tryMul(r);
        if (res != null) {
          ratCoeff = res;
        } else {
          floatCoeff = ratCoeff!.toDouble() * r.toDouble();
          ratCoeff = null;
        }
      }
    }

    for (final f in flat) {
      if (f is SymNum) {
        if (f.rat.isZero) return SymNum.intVal(0);
        multRat(f.rat);
      } else if (f is SymFloat) {
        if (f.value.abs() < 1e-12) return SymNum.intVal(0);
        floatCoeff = (floatCoeff ?? ratCoeff!.toDouble()) * f.value;
        ratCoeff = null;
      } else {
        otherFactors.add(f);
      }
    }

    // Si hay exactamente un SymAdd y un factor entero puro (como 2*(3y-5) o -(a-b)),
    // distribuimos el entero para limpiar signos y ángulos (sin(2*(3y-5)) -> sin(6y-10)).
    if (floatCoeff == null &&
        ratCoeff != null &&
        ratCoeff!.isInt &&
        !ratCoeff!.isOne &&
        otherFactors.length == 1 &&
        otherFactors.first is SymAdd) {
      final add = otherFactors.first as SymAdd;
      final distributed = add.terms
          .map((t) => simplify(SymMul([SymNum(ratCoeff!), t]), depth: depth + 1))
          .toList();
      return simplify(SymAdd(distributed), depth: depth + 1);
    }

    // Combinar factores con misma base (x * x -> x^2, exp(a)*exp(b) -> exp(a+b))
    final combined = <SymExpr>[];
    final expArgs = <SymExpr>[];
    final powerGroups = <String, (SymExpr base, SymExpr exponent)>{};
    final powerOrder = <String>[];

    for (final f in otherFactors) {
      if (f is SymFunc && f.name == 'exp') {
        expArgs.add(f.arg);
        continue;
      }
      if (f is SymPow && !(f.base is SymConst && (f.base as SymConst).name == 'e')) {
        final key = f.base.structuralKey();
        if (powerGroups.containsKey(key)) {
          final existing = powerGroups[key]!;
          powerGroups[key] = (existing.$1, simplify(SymAdd([existing.$2, f.exp]), depth: depth + 1));
        } else {
          powerGroups[key] = (f.base, f.exp);
          powerOrder.add(key);
        }
      } else if (f is SymVar || f is SymFunc || f is SymConst) {
        final key = f.structuralKey();
        if (powerGroups.containsKey(key)) {
          final existing = powerGroups[key]!;
          powerGroups[key] = (existing.$1, simplify(SymAdd([existing.$2, SymNum.intVal(1)]), depth: depth + 1));
        } else {
          powerGroups[key] = (f, SymNum.intVal(1));
          powerOrder.add(key);
        }
      } else {
        combined.add(f);
      }
    }

    for (final key in powerOrder) {
      final (b, e) = powerGroups[key]!;
      final powNode = simplify(SymPow(b, e), depth: depth + 1);
      if (powNode is SymNum && powNode.rat.isOne) continue;
      if (powNode is SymNum) {
        multRat(powNode.rat);
      } else {
        combined.add(powNode);
      }
    }

    if (expArgs.isNotEmpty) {
      final sumExp = expArgs.length == 1
          ? expArgs.first
          : simplify(SymAdd(expArgs), depth: depth + 1);
      final expNode = simplify(SymFunc('exp', sumExp), depth: depth + 1);
      if (expNode is SymNum) {
        multRat(expNode.rat);
      } else {
        combined.add(expNode);
      }
    }

    // Orden canónico legible: variables primero (x, y, z, r...), luego funciones/compuestos
    combined.sort((a, b) => _factorSortRank(a).compareTo(_factorSortRank(b)));

    final coeffExpr = floatCoeff != null
        ? SymFloat(floatCoeff!)
        : (ratCoeff!.isOne ? null : SymNum(ratCoeff!));

    if (combined.isEmpty) {
      return coeffExpr ?? SymNum.intVal(1);
    }
    if (coeffExpr == null) {
      return combined.length == 1 ? combined.first : SymMul(combined);
    }
    return SymMul([coeffExpr, ...combined]);
  }

  static String _factorSortRank(SymExpr e) {
    if (e is SymVar) return '0_${e.name}';
    if (e is SymPow && e.base is SymVar) return '0_${(e.base as SymVar).name}^';
    if (e is SymConst) return '1_${e.name}';
    if (e is SymFunc) return '2_${e.name}';
    return '3_${e.structuralKey()}';
  }

  static SymExpr _simplifyAdd(List<SymExpr> rawTerms, {int depth = 0}) {
    final flat = <SymExpr>[];
    for (final t in rawTerms) {
      final st = simplify(t, depth: depth + 1);
      if (st is SymAdd) {
        flat.addAll(st.terms);
      } else {
        flat.add(st);
      }
    }

    SymRat? constRat = SymRat.zero;
    double? constFloat;
    final groups = <String, (SymExpr base, List<SymExpr> coeffs)>{};
    final order = <String>[];

    void addConstRat(SymRat r) {
      if (constFloat != null) {
        constFloat = constFloat! + r.toDouble();
      } else {
        final s = constRat!.tryAdd(r);
        if (s != null) {
          constRat = s;
        } else {
          constFloat = constRat!.toDouble() + r.toDouble();
          constRat = null;
        }
      }
    }

    for (final t in flat) {
      if (t is SymNum) {
        if (!t.rat.isZero) addConstRat(t.rat);
        continue;
      }
      if (t is SymFloat) {
        if (t.value.abs() >= 1e-12) {
          constFloat = (constFloat ?? constRat!.toDouble()) + t.value;
          constRat = null;
        }
        continue;
      }

      SymExpr coeff = SymNum.intVal(1);
      SymExpr base = t;
      if (t is SymMul && t.factors.isNotEmpty) {
        final f0 = t.factors.first;
        if (f0 is SymNum || f0 is SymFloat) {
          coeff = f0;
          final rest = t.factors.sublist(1);
          base = rest.length == 1 ? rest.first : SymMul(rest);
        }
      } else if (t is SymDiv) {
        SymRat numR = SymRat.one;
        SymExpr numRem = t.num;
        if (t.num is SymNum) {
          numR = (t.num as SymNum).rat;
          numRem = SymNum.intVal(1);
        } else if (t.num is SymMul && (t.num as SymMul).factors.isNotEmpty && (t.num as SymMul).factors.first is SymNum) {
          final mf = (t.num as SymMul).factors;
          numR = (mf.first as SymNum).rat;
          final rest = mf.sublist(1);
          numRem = rest.isEmpty ? SymNum.intVal(1) : (rest.length == 1 ? rest.first : SymMul(rest));
        }
        SymRat denR = SymRat.one;
        SymExpr denRem = t.den;
        if (t.den is SymMul && (t.den as SymMul).factors.isNotEmpty && (t.den as SymMul).factors.first is SymNum) {
          final df = (t.den as SymMul).factors;
          denR = (df.first as SymNum).rat;
          final rest = df.sublist(1);
          denRem = rest.isEmpty ? SymNum.intVal(1) : (rest.length == 1 ? rest.first : SymMul(rest));
        }
        final qR = numR.tryDiv(denR);
        if (qR != null && !qR.isOne) {
          coeff = SymNum(qR);
          base = SymDiv(numRem, denRem);
        }
      }

      final key = base.structuralKey();
      if (groups.containsKey(key)) {
        groups[key]!.$2.add(coeff);
      } else {
        groups[key] = (base, [coeff]);
        order.add(key);
      }
    }

    final out = <SymExpr>[];
    for (final key in order) {
      final (base, coeffs) = groups[key]!;
      SymRat? rSum = SymRat.zero;
      double? fSum;
      for (final c in coeffs) {
        if (c is SymNum) {
          if (fSum != null) {
            fSum += c.rat.toDouble();
          } else {
            final res = rSum!.tryAdd(c.rat);
            if (res != null) {
              rSum = res;
            } else {
              fSum = rSum.toDouble() + c.rat.toDouble();
              rSum = null;
            }
          }
        } else if (c is SymFloat) {
          fSum = (fSum ?? rSum!.toDouble()) + c.value;
          rSum = null;
        }
      }

      if (fSum != null) {
        if (fSum.abs() < 1e-12) continue;
        final term = simplify(SymMul([SymFloat(fSum), base]), depth: depth + 1);
        out.add(term);
      } else if (rSum != null && !rSum.isZero) {
        final term = rSum.isOne
            ? base
            : simplify(SymMul([SymNum(rSum), base]), depth: depth + 1);
        out.add(term);
      }
    }

    if (constFloat != null) {
      if (constFloat!.abs() >= 1e-12) out.add(SymFloat(constFloat!));
    } else if (constRat != null && !constRat!.isZero) {
      out.add(SymNum(constRat!));
    }

    if (out.isEmpty) return SymNum.intVal(0);
    if (out.length == 1) return out.first;
    return SymAdd(out);
  }

  /// Expande productos algebraicos `(A+B)*C`, divisiones `(A+B)/c` y potencias enteras `(A+B)^n`.
  static SymExpr expand(SymExpr expr, {int depth = 0}) {
    final s = simplify(expr, depth: depth);
    if (depth > 8) return s;

    switch (s) {
      case SymAdd(:final terms):
        return simplify(SymAdd(terms.map((t) => expand(t, depth: depth + 1)).toList()));

      case SymDiv(:final num, :final den):
        final en = expand(num, depth: depth + 1);
        final ed = expand(den, depth: depth + 1);
        if (en is SymAdd) {
          return simplify(
            SymAdd(en.terms.map((t) => SymDiv(t, ed)).toList()),
          );
        }
        return simplify(SymDiv(en, ed));

      case SymPow(:final base, :final exp):
        final eb = expand(base, depth: depth + 1);
        if (eb is SymAdd && exp is SymNum && exp.rat.isInt && exp.rat.p >= 2 && exp.rat.p <= 6) {
          SymExpr acc = SymNum.intVal(1);
          for (int i = 0; i < exp.rat.p; i++) {
            acc = _distributeMul(acc, eb);
          }
          return simplify(acc);
        }
        return simplify(SymPow(eb, exp));

      case SymMul(:final factors):
        SymExpr acc = SymNum.intVal(1);
        for (final f in factors) {
          final ef = expand(f, depth: depth + 1);
          acc = _distributeMul(acc, ef);
        }
        return simplify(acc);

      default:
        return s;
    }
  }

  static SymExpr _distributeMul(SymExpr a, SymExpr b) {
    final sa = simplify(a);
    final sb = simplify(b);
    if (sa is SymAdd) {
      return simplify(
        SymAdd(sa.terms.map((t) => _distributeMul(t, sb)).toList()),
      );
    }
    if (sb is SymAdd) {
      return simplify(
        SymAdd(sb.terms.map((t) => _distributeMul(sa, t)).toList()),
      );
    }
    return simplify(SymMul([sa, sb]));
  }

  // ==================== DERIVACIÓN SIMBÓLICA ====================

  static SymExpr diff(SymExpr expr, String variable) {
    final v = SymVar.canonicalName(variable);
    SymExpr d(SymExpr e) {
      if (!e.dependsOn(v)) return SymNum.intVal(0);
      switch (e) {
        case SymVar(:final name):
          return name == v ? SymNum.intVal(1) : SymNum.intVal(0);
        case SymNum():
        case SymFloat():
        case SymConst():
          return SymNum.intVal(0);
        case SymAdd(:final terms):
          return SymAdd(terms.map(d).toList());
        case SymMul(:final factors):
          final sum = <SymExpr>[];
          for (int i = 0; i < factors.length; i++) {
            if (!factors[i].dependsOn(v)) continue;
            final prod = <SymExpr>[];
            for (int j = 0; j < factors.length; j++) {
              prod.add(j == i ? d(factors[j]) : factors[j]);
            }
            sum.add(SymMul(prod));
          }
          return SymAdd(sum);
        case SymDiv(:final num, :final den):
          if (!den.dependsOn(v)) {
            return SymDiv(d(num), den);
          }
          final numer = SymAdd([
            SymMul([d(num), den]),
            SymMul([SymNum.intVal(-1), num, d(den)]),
          ]);
          return SymDiv(numer, SymPow(den, SymNum.intVal(2)));
        case SymPow(:final base, :final exp):
          if (!exp.dependsOn(v)) {
            return SymMul([
              exp,
              SymPow(base, SymAdd([exp, SymNum.intVal(-1)])),
              d(base),
            ]);
          }
          if (!base.dependsOn(v)) {
            return SymMul([e, SymFunc('ln', base), d(exp)]);
          }
          return SymMul([
            e,
            SymAdd([
              SymMul([d(exp), SymFunc('ln', base)]),
              SymDiv(SymMul([exp, d(base)]), base),
            ]),
          ]);
        case SymFunc(:final name, :final arg):
          final du = d(arg);
          SymExpr outer;
          switch (name) {
            case 'sin':
              outer = SymFunc('cos', arg);
            case 'cos':
              outer = SymMul([SymNum.intVal(-1), SymFunc('sin', arg)]);
            case 'tan':
              outer = SymPow(SymFunc('sec', arg), SymNum.intVal(2));
            case 'sec':
              outer = SymMul([SymFunc('sec', arg), SymFunc('tan', arg)]);
            case 'csc':
              outer = SymMul([SymNum.intVal(-1), SymFunc('csc', arg), SymFunc('cot', arg)]);
            case 'cot':
              outer = SymMul([SymNum.intVal(-1), SymPow(SymFunc('csc', arg), SymNum.intVal(2))]);
            case 'sinh':
              outer = SymFunc('cosh', arg);
            case 'cosh':
              outer = SymFunc('sinh', arg);
            case 'tanh':
              outer = SymPow(SymFunc('cosh', arg), SymNum.intVal(-2));
            case 'asin':
              outer = SymPow(
                SymAdd([SymNum.intVal(1), SymMul([SymNum.intVal(-1), SymPow(arg, SymNum.intVal(2))])]),
                SymNum(SymRat(-1, 2)),
              );
            case 'acos':
              outer = SymMul([
                SymNum.intVal(-1),
                SymPow(
                  SymAdd([SymNum.intVal(1), SymMul([SymNum.intVal(-1), SymPow(arg, SymNum.intVal(2))])]),
                  SymNum(SymRat(-1, 2)),
                ),
              ]);
            case 'atan':
              outer = SymDiv(
                SymNum.intVal(1),
                SymAdd([SymNum.intVal(1), SymPow(arg, SymNum.intVal(2))]),
              );
            case 'exp':
              outer = SymFunc('exp', arg);
            case 'ln':
              outer = SymDiv(SymNum.intVal(1), arg);
            case 'sqrt':
              outer = SymDiv(
                SymNum.intVal(1),
                SymMul([SymNum.intVal(2), SymFunc('sqrt', arg)]),
              );
            default:
              return SymNum.intVal(0);
          }
          return SymMul([outer, du]);
      }
    }

    return simplify(d(expr));
  }

  /// Verifica si `expr` es afín en `v`: `a * v + b` con `a != 0` independiente de `v`.
  static (SymExpr a, SymExpr b)? matchLinear(SymExpr expr, String v) {
    final s = simplify(expr);
    if (!s.dependsOn(v)) return null;
    if (_containsAbsOrNonSmooth(s)) return null;
    final a = diff(s, v);
    if (a.dependsOn(v)) return null;
    if (a is SymNum && a.rat.isZero) return null;
    final b = simplify(substitute(s, v, SymNum.intVal(0)));
    // Comprobar identidad numérica en dos valores distintos para evitar errores en ramas
    final testEnv1 = _safeOtherVarEnv(s.variables(), v)..[v] = 0.73;
    final testEnv2 = _safeOtherVarEnv(s.variables(), v)..[v] = -1.41;
    final lhs1 = s.eval(testEnv1);
    final rhs1 = SymAdd([SymMul([a, SymVar(v)]), b]).eval(testEnv1);
    final lhs2 = s.eval(testEnv2);
    final rhs2 = SymAdd([SymMul([a, SymVar(v)]), b]).eval(testEnv2);
    if (!lhs1.isFinite || !rhs1.isFinite || (lhs1 - rhs1).abs() > 1e-6) return null;
    if (!lhs2.isFinite || !rhs2.isFinite || (lhs2 - rhs2).abs() > 1e-6) return null;
    return (a, b);
  }

  static bool _containsAbsOrNonSmooth(SymExpr e) {
    if (e is SymFunc && e.name == 'abs') return true;
    return switch (e) {
      SymAdd(:final terms) => terms.any(_containsAbsOrNonSmooth),
      SymMul(:final factors) => factors.any(_containsAbsOrNonSmooth),
      SymDiv(:final num, :final den) => _containsAbsOrNonSmooth(num) || _containsAbsOrNonSmooth(den),
      SymPow(:final base, :final exp) => _containsAbsOrNonSmooth(base) || _containsAbsOrNonSmooth(exp),
      SymFunc(:final arg) => _containsAbsOrNonSmooth(arg),
      _ => false,
    };
  }

  static Map<String, double> _safeOtherVarEnv(Set<String> vars, String activeVar) {
    final canonActive = SymVar.canonicalName(activeVar);
    final env = defaultParamEnv(vars);
    env.remove(canonActive);
    return env;
  }

  // ==================== INTEGRACIÓN SIMBÓLICA COMPOSICIONAL ====================

  static SymbolicIntegrationOutcome integrate(SymExpr expr, String variable) {
    final v = SymVar.canonicalName(variable);
    final simp = simplify(expr);
    final outcome = _integrateRecursive(simp, v, depth: 0);

    if (outcome.isSymbolic && outcome.antiderivative != null) {
      final cleanAnti = simplify(outcome.antiderivative!);
      if (_verifyAntiderivativeNumerically(simp, cleanAnti, v)) {
        return SymbolicIntegrationOutcome(
          isSymbolic: true,
          antiderivative: cleanAnti,
          antiderivativeLatex: toLatex(cleanAnti),
          method: outcome.method,
          explanation: outcome.explanation,
          transformationLatex: outcome.transformationLatex,
        );
      }
    }

    return SymbolicIntegrationOutcome.failed(
      integrandLatex: toLatex(simp),
      variable: v,
    );
  }

  static SymbolicIntegrationOutcome _integrateRecursive(
    SymExpr expr,
    String v, {
    required int depth,
  }) {
    if (depth > 8) {
      return SymbolicIntegrationOutcome.failed(
        integrandLatex: toLatex(expr),
        variable: v,
      );
    }

    final e = simplify(expr);

    // 1. Constante respecto a v
    if (!e.dependsOn(v)) {
      final anti = simplify(SymMul([e, SymVar(v)]));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Linealidad / Factorización de Constantes',
        explanation: 'Al no depender de $v, el integrando actúa como constante: ∫ c d$v = c·$v.',
      );
    }

    // 2. Linealidad de sumas y diferencias
    if (e is SymAdd) {
      final antiTerms = <SymExpr>[];
      final methods = <String>{};
      final details = <String>[];
      String? firstTransform;
      for (final term in e.terms) {
        final sub = _integrateRecursive(term, v, depth: depth + 1);
        if (!sub.isSymbolic || sub.antiderivative == null) {
          return SymbolicIntegrationOutcome.failed(
            integrandLatex: toLatex(e),
            variable: v,
          );
        }
        antiTerms.add(sub.antiderivative!);
        methods.add(sub.method);
        firstTransform ??= sub.transformationLatex;
        if (sub.explanation.isNotEmpty) details.add(sub.explanation);
      }
      final combined = simplify(SymAdd(antiTerms));
      final joinedMethod = methods.length == 1
          ? methods.first
          : 'Integración Término a Término & Linealidad';
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: combined,
        antiderivativeLatex: toLatex(combined),
        method: joinedMethod,
        explanation: 'Se integra término a término aplicando linealidad de la integral respecto a $v.',
        transformationLatex: firstTransform,
      );
    }

    // 3. Separación de factores constantes en productos/cocientes
    if (e is SymMul || e is SymDiv) {
      final (constPart, varPart) = _splitConstAndVar(e, v);
      if (!(constPart is SymNum && constPart.rat.isOne)) {
        final sub = _integrateRecursive(varPart, v, depth: depth + 1);
        if (sub.isSymbolic && sub.antiderivative != null) {
          final scaled = simplify(SymMul([constPart, sub.antiderivative!]));
          return SymbolicIntegrationOutcome(
            isSymbolic: true,
            antiderivative: scaled,
            antiderivativeLatex: toLatex(scaled),
            method: sub.method,
            explanation: sub.explanation,
            transformationLatex: sub.transformationLatex,
          );
        }
      }
    }

    // 4. Reglas directas elementales (potencias, trigonométricas, exp, ln, radicales, inversas)
    final direct = _tryDirectRules(e, v);
    if (direct != null) return direct;

    // 5. Productos trigonométricos sin(mx)*cos(nx), cos(mx)*cos(nx), sin(mx)*sin(nx)
    final trigProd = _tryTrigProductToSum(e, v, depth: depth);
    if (trigProd != null) return trigProd;

    // 6. Sustitución u = g(v) general basada en derivada exacta u'(v)
    final uSub = _tryGeneralUSubstitution(e, v, depth: depth);
    if (uSub != null) return uSub;

    // 7. Integración por partes (P(v) * T(v), v^n * ln(av+b), e^(av)*sin/cos(bv))
    final byParts = _tryIntegrationByParts(e, v, depth: depth);
    if (byParts != null) return byParts;

    // 8. Expansión algebraica de productos de sumas y binomios (ej. (3y - 5)^2 * y^2)
    final expanded = expand(e);
    if (expanded.structuralKey() != e.structuralKey() && expanded is SymAdd) {
      final sub = _integrateRecursive(expanded, v, depth: depth + 1);
      if (sub.isSymbolic && sub.antiderivative != null) {
        return SymbolicIntegrationOutcome(
          isSymbolic: true,
          antiderivative: sub.antiderivative,
          antiderivativeLatex: sub.antiderivativeLatex,
          method: 'Expansión Algebraica & ${sub.method}',
          explanation: 'Expandimos primero el producto algebraico en suma de términos y luego integramos respecto a $v.',
          transformationLatex: '${toLatex(e)} = ${toLatex(expanded)}',
        );
      }
    }

    return SymbolicIntegrationOutcome.failed(
      integrandLatex: toLatex(e),
      variable: v,
    );
  }

  static (SymExpr constPart, SymExpr varPart) _splitConstAndVar(SymExpr e, String v) {
    final constFactors = <SymExpr>[];
    final varFactors = <SymExpr>[];

    void inspectFactor(SymExpr f, bool inDenom) {
      if (!f.dependsOn(v)) {
        constFactors.add(inDenom ? SymDiv(SymNum.intVal(1), f) : f);
      } else {
        varFactors.add(inDenom ? SymDiv(SymNum.intVal(1), f) : f);
      }
    }

    if (e is SymMul) {
      for (final f in e.factors) {
        inspectFactor(f, false);
      }
    } else if (e is SymDiv) {
      if (e.num is SymMul) {
        for (final f in (e.num as SymMul).factors) {
          inspectFactor(f, false);
        }
      } else {
        inspectFactor(e.num, false);
      }
      if (e.den is SymMul) {
        for (final f in (e.den as SymMul).factors) {
          inspectFactor(f, true);
        }
      } else {
        inspectFactor(e.den, true);
      }
    }

    final cExpr = constFactors.isEmpty
        ? SymNum.intVal(1)
        : simplify(SymMul(constFactors));
    final vExpr = varFactors.isEmpty
        ? SymNum.intVal(1)
        : simplify(SymMul(varFactors));
    return (cExpr, vExpr);
  }

  static SymbolicIntegrationOutcome? _tryDirectRules(SymExpr e, String v) {
    // a) Variable pura v -> v^2 / 2
    if (e is SymVar && e.name == v) {
      final anti = SymDiv(SymPow(SymVar(v), SymNum.intVal(2)), SymNum.intVal(2));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Regla de la Potencia',
        explanation: 'Aplicamos ∫ $v d$v = $v²/2.',
      );
    }

    // b) Potencia (base)^p donde p es constante respecto a v
    if (e is SymPow && !e.exp.dependsOn(v)) {
      final p = e.exp;
      final base = e.base;

      // Caso v^p
      if (base is SymVar && base.name == v) {
        if (p is SymNum && p.rat == SymRat.minusOne) {
          final anti = SymFunc('ln', SymFunc('abs', SymVar(v)));
          return SymbolicIntegrationOutcome(
            isSymbolic: true,
            antiderivative: anti,
            antiderivativeLatex: toLatex(anti),
            method: 'Integración Logarítmica',
            explanation: 'Aplicamos la regla ∫ $v⁻¹ d$v = ln|$v|.',
          );
        }
        final p1 = simplify(SymAdd([p, SymNum.intVal(1)]));
        final anti = simplify(SymDiv(SymPow(SymVar(v), p1), p1));
        return SymbolicIntegrationOutcome(
          isSymbolic: true,
          antiderivative: anti,
          antiderivativeLatex: toLatex(anti),
          method: 'Regla de la Potencia',
          explanation: 'Aplicamos ∫ $v^{${toLatex(p)}} d$v = \\frac{$v^{${toLatex(p1)}}}{${toLatex(p1)}}.',
        );
      }

      // Caso (a*v + b)^p
      final lin = matchLinear(base, v);
      if (lin != null) {
        final (a, b) = lin;
        if (p is SymNum && p.rat == SymRat.minusOne) {
          final anti = simplify(SymDiv(SymFunc('ln', SymFunc('abs', base)), a));
          return SymbolicIntegrationOutcome(
            isSymbolic: true,
            antiderivative: anti,
            antiderivativeLatex: toLatex(anti),
            method: 'Sustitución Lineal Logarítmica',
            explanation: 'Con sustitución u = ${toLatex(base)} (du = ${toLatex(a)} d$v), obtenemos ${toLatex(anti)}.',
            transformationLatex: 'u = ${toLatex(base)}, \\; du = ${toLatex(a)} \\, d$v',
          );
        }
        final p1 = simplify(SymAdd([p, SymNum.intVal(1)]));
        final denom = simplify(SymMul([a, p1]));
        final anti = simplify(SymDiv(SymPow(base, p1), denom));
        return SymbolicIntegrationOutcome(
          isSymbolic: true,
          antiderivative: anti,
          antiderivativeLatex: toLatex(anti),
          method: 'Sustitución Lineal (Regla de la Potencia)',
          explanation: 'Haciendo u = ${toLatex(base)} con du = ${toLatex(a)} d$v aplicamos la regla de la potencia.',
          transformationLatex: 'u = ${toLatex(base)}, \\; du = ${toLatex(a)} \\, d$v',
        );
      }

      // Caso trigonométrico: cos(u)^n, sin(u)^n, sec(u)^2, csc(u)^2, tan(u)^2
      if (base is SymFunc && p is SymNum && p.rat.isInt) {
        final trigRes = _tryTrigPower(base.name, base.arg, p.rat.p, v);
        if (trigRes != null) return trigRes;
      }

      // Potencias negativas de polinomios cuadráticos / radicales (ej. (1+x^2)^-1, (4-x^2)^(-1/2))
      if (p is SymNum && p.rat == SymRat.minusOne) {
        final rec = _tryReciprocalRules(base, v);
        if (rec != null) return rec;
      }
      if (p is SymNum && p.rat == SymRat(-1, 2)) {
        final rec = _tryReciprocalRules(SymFunc('sqrt', base), v);
        if (rec != null) return rec;
      }
    }

    // c) Cociente con variable en el denominador: 1/f(v)
    if (e is SymDiv && !e.num.dependsOn(v) && e.den.dependsOn(v)) {
      final invRes = _tryReciprocalRules(e.den, v);
      if (invRes != null) {
        final scaled = simplify(SymMul([e.num, invRes.antiderivative!]));
        return SymbolicIntegrationOutcome(
          isSymbolic: true,
          antiderivative: scaled,
          antiderivativeLatex: toLatex(scaled),
          method: invRes.method,
          explanation: invRes.explanation,
          transformationLatex: invRes.transformationLatex,
        );
      }
    }

    // d) Función elemental aplicada a argumento afín u = a*v + b
    if (e is SymFunc) {
      final lin = matchLinear(e.arg, v);
      if (lin != null) {
        final (a, b) = lin;
        final u = e.arg;
        final isUnitSlope = (a is SymNum && a.rat.isOne) && (b is SymNum && b.rat.isZero);
        final uHint = isUnitSlope ? null : 'u = ${toLatex(u)}, \\; du = ${toLatex(a)} \\, d$v';

        switch (e.name) {
          case 'exp':
            final anti = simplify(SymDiv(SymFunc('exp', u), a));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: isUnitSlope ? 'Integración Exponencial Directa' : 'Integración Exponencial & Sustitución Lineal',
              explanation: isUnitSlope
                  ? 'La antiderivada de e^{$v} es e^{$v}.'
                  : 'Con sustitución u = ${toLatex(u)} (du = ${toLatex(a)} d$v), ∫ e^{u} d$v = ${toLatex(anti)}.',
              transformationLatex: uHint,
            );
          case 'sin':
            final anti = simplify(SymMul([SymNum.intVal(-1), SymDiv(SymFunc('cos', u), a)]));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: isUnitSlope ? 'Integración Trigonométrica Directa' : 'Sustitución Lineal Trigonométrica',
              explanation: 'Aplicamos ∫ sin(u) du = -cos(u) con u = ${toLatex(u)}.',
              transformationLatex: uHint,
            );
          case 'cos':
            final anti = simplify(SymDiv(SymFunc('sin', u), a));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: isUnitSlope ? 'Integración Trigonométrica Directa' : 'Sustitución Lineal Trigonométrica',
              explanation: 'Aplicamos ∫ cos(u) du = sin(u) con u = ${toLatex(u)}.',
              transformationLatex: uHint,
            );
          case 'tan':
            final anti = simplify(SymMul([SymNum.intVal(-1), SymDiv(SymFunc('ln', SymFunc('abs', SymFunc('cos', u))), a)]));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: 'Integración Trigonométrica (Logarítmica)',
              explanation: 'Expresamos tan(u) = sin(u)/cos(u) y aplicamos u-sustitución.',
              transformationLatex: uHint ?? '\\int \\tan($v)\\,d$v = -\\ln|\\cos($v)|',
            );
          case 'sec':
            final anti = simplify(SymDiv(
              SymFunc('ln', SymFunc('abs', SymAdd([SymFunc('sec', u), SymFunc('tan', u)]))),
              a,
            ));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: 'Integración Trigonométrica',
              explanation: 'Aplicamos la fórmula estándar ∫ sec(u) du = ln|sec(u) + tan(u)|.',
              transformationLatex: uHint,
            );
          case 'sinh':
            final anti = simplify(SymDiv(SymFunc('cosh', u), a));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: 'Integración Hiperbólica',
              explanation: 'Aplicamos ∫ sinh(u) du = cosh(u).',
              transformationLatex: uHint,
            );
          case 'cosh':
            final anti = simplify(SymDiv(SymFunc('sinh', u), a));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: 'Integración Hiperbólica',
              explanation: 'Aplicamos ∫ cosh(u) du = sinh(u).',
              transformationLatex: uHint,
            );
          case 'sqrt':
            final anti = simplify(SymDiv(
              SymMul([SymNum.intVal(2), SymPow(u, SymNum(SymRat(3, 2)))]),
              SymMul([SymNum.intVal(3), a]),
            ));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: 'Sustitución Lineal Radical',
              explanation: 'Reescribimos √(${toLatex(u)}) como (${toLatex(u)})^{1/2} e integramos con regla de la potencia.',
              transformationLatex: uHint,
            );
          case 'ln':
            final anti = simplify(SymDiv(
              SymAdd([
                SymMul([u, SymFunc('ln', u)]),
                SymMul([SymNum.intVal(-1), u]),
              ]),
              a,
            ));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: 'Integración por Partes',
              explanation: 'Integramos ln(u) por partes tomando u = ln(u) y dv = d$v.',
              transformationLatex: '\\int \\ln(u)\\,du = u\\ln(u) - u',
            );
          case 'atan':
            final anti = simplify(SymDiv(
              SymAdd([
                SymMul([u, SymFunc('atan', u)]),
                SymMul([
                  SymNum(SymRat(-1, 2)),
                  SymFunc('ln', SymAdd([SymNum.intVal(1), SymPow(u, SymNum.intVal(2))])),
                ]),
              ]),
              a,
            ));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: 'Integración por Partes',
              explanation: 'Integramos arctan(u) por partes tomando u_p = arctan(u) y dv = d$v.',
              transformationLatex: '\\int \\arctan(u)\\,du = u\\arctan(u) - \\frac{1}{2}\\ln(1+u^2)',
            );
        }
      }

      // Radical circular clásico: sqrt(c^2 - (a*v)^2)
      if (e.name == 'sqrt') {
        final quad = _matchQuadratic(e.arg, v);
        if (quad != null) {
          final (cExpr, bExpr, aExpr) = quad; // aExpr*v^2 + bExpr*v + cExpr
          if ((bExpr is SymNum && bExpr.rat.isZero) && !cExpr.dependsOn(v) && !aExpr.dependsOn(v)) {
            final aVal = aExpr.eval(_safeOtherVarEnv(e.variables(), v));
            final cVal = cExpr.eval(_safeOtherVarEnv(e.variables(), v));
            if (aVal < 0 && cVal > 0) {
              // sqrt(R2 - K * v^2) where R2 = cExpr, K = -aExpr
              final r2 = cExpr;
              final k = simplify(SymMul([SymNum.intVal(-1), aExpr]));
              final sqrtK = simplify(SymFunc('sqrt', k));
              final sqrtR = simplify(SymFunc('sqrt', r2));
              final term1 = SymDiv(SymMul([SymVar(v), SymFunc('sqrt', e.arg)]), SymNum.intVal(2));
              final ratio = simplify(SymDiv(SymMul([sqrtK, SymVar(v)]), sqrtR));
              final term2 = SymDiv(
                SymMul([r2, SymFunc('asin', ratio)]),
                SymMul([SymNum.intVal(2), sqrtK]),
              );
              final anti = simplify(SymAdd([term1, term2]));
              return SymbolicIntegrationOutcome(
                isSymbolic: true,
                antiderivative: anti,
                antiderivativeLatex: toLatex(anti),
                method: 'Sustitución Trigonométrica',
                explanation: 'Aplicamos sustitución trigonométrica ${toLatex(sqrtK)}$v = ${toLatex(sqrtR)} sin(θ) para integrar el radical cuadrático.',
                transformationLatex: '\\int \\sqrt{a^2 - v^2}\\,dv = \\frac{v}{2}\\sqrt{a^2-v^2} + \\frac{a^2}{2}\\arcsin\\left(\\frac{v}{a}\\right)',
              );
            }
          }
        }
      }
    }

    return null;
  }

  static SymbolicIntegrationOutcome? _tryTrigPower(String fn, SymExpr arg, int n, String v) {
    final lin = matchLinear(arg, v);
    if (lin == null) return null;
    final (a, _) = lin;
    final two = SymNum.intVal(2);
    final twoU = simplify(SymMul([two, arg]));

    if (fn == 'sec' && n == 2) {
      final anti = simplify(SymDiv(SymFunc('tan', arg), a));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Integración Trigonométrica Directa',
        explanation: 'Aplicamos ∫ sec²(u) du = tan(u) con u = ${toLatex(arg)}.',
      );
    }
    if (fn == 'csc' && n == 2) {
      final anti = simplify(SymMul([SymNum.intVal(-1), SymDiv(SymFunc('cot', arg), a)]));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Integración Trigonométrica Directa',
        explanation: 'Aplicamos ∫ csc²(u) du = -cot(u) con u = ${toLatex(arg)}.',
      );
    }
    if (fn == 'tan' && n == 2) {
      final anti = simplify(SymAdd([
        SymDiv(SymFunc('tan', arg), a),
        SymMul([SymNum.intVal(-1), SymVar(v)]),
      ]));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Identidad Pitagórica (tan²u = sec²u - 1)',
        explanation: 'Sustituimos tan²(u) = sec²(u) - 1 e integramos directamente.',
        transformationLatex: '\\int \\tan^{2}(${toLatex(arg)})\\,d$v = \\int (\\sec^{2}(${toLatex(arg)}) - 1)\\,d$v',
      );
    }
    if (fn == 'cos' && n == 2) {
      final anti = simplify(SymAdd([
        SymDiv(SymVar(v), SymNum.intVal(2)),
        SymDiv(SymFunc('sin', twoU), simplify(SymMul([SymNum.intVal(4), a]))),
      ]));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Identidad de Ángulo Doble (Reducción de Potencia)',
        explanation: 'Aplicamos la identidad cos²(u) = (1 + cos(2u))/2 para transformar el cuadrado trigonométrico en una integral directa.',
        transformationLatex: '\\cos^{2}(${toLatex(arg)}) = \\frac{1 + \\cos(${toLatex(twoU)})}{2}',
      );
    }
    if (fn == 'sin' && n == 2) {
      final anti = simplify(SymAdd([
        SymDiv(SymVar(v), SymNum.intVal(2)),
        SymMul([
          SymNum.intVal(-1),
          SymDiv(SymFunc('sin', twoU), simplify(SymMul([SymNum.intVal(4), a]))),
        ]),
      ]));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Identidad de Ángulo Doble (Reducción de Potencia)',
        explanation: 'Aplicamos la identidad sin²(u) = (1 - cos(2u))/2 para integrar directamente.',
        transformationLatex: '\\sin^{2}(${toLatex(arg)}) = \\frac{1 - \\cos(${toLatex(twoU)})}{2}',
      );
    }
    if (fn == 'cos' && n == 3) {
      final anti = simplify(SymDiv(
        SymAdd([
          SymFunc('sin', arg),
          SymMul([SymNum(SymRat(-1, 3)), SymPow(SymFunc('sin', arg), SymNum.intVal(3))]),
        ]),
        a,
      ));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Identidad Pitagórica & Sustitución u = sin(${toLatex(arg)})',
        explanation: 'Separamos cos³(u) = (1 - sin²(u))cos(u) e integramos en u = sin(${toLatex(arg)}).',
        transformationLatex: '\\cos^{3}(${toLatex(arg)}) = (1 - \\sin^{2}(${toLatex(arg)}))\\cos(${toLatex(arg)})',
      );
    }
    if (fn == 'sin' && n == 3) {
      final anti = simplify(SymDiv(
        SymAdd([
          SymMul([SymNum.intVal(-1), SymFunc('cos', arg)]),
          SymMul([SymNum(SymRat(1, 3)), SymPow(SymFunc('cos', arg), SymNum.intVal(3))]),
        ]),
        a,
      ));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Identidad Pitagórica & Sustitución u = cos(${toLatex(arg)})',
        explanation: 'Separamos sin³(u) = (1 - cos²(u))sin(u) e integramos en u = cos(${toLatex(arg)}).',
        transformationLatex: '\\sin^{3}(${toLatex(arg)}) = (1 - \\cos^{2}(${toLatex(arg)}))\\sin(${toLatex(arg)})',
      );
    }
    if (fn == 'cos' && n == 4) {
      final fourU = simplify(SymMul([SymNum.intVal(4), arg]));
      final anti = simplify(SymAdd([
        SymMul([SymNum(SymRat(3, 8)), SymVar(v)]),
        SymDiv(SymFunc('sin', twoU), simplify(SymMul([SymNum.intVal(4), a]))),
        SymDiv(SymFunc('sin', fourU), simplify(SymMul([SymNum.intVal(32), a]))),
      ]));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Doble Reducción de Potencia (Ángulo Doble)',
        explanation: 'Aplicamos dos veces cos²(u) = (1 + cos(2u))/2 para expresar cos⁴(u) en términos lineales de coseno.',
        transformationLatex: '\\cos^{4}(${toLatex(arg)}) = \\frac{3}{8} + \\frac{1}{2}\\cos(${toLatex(twoU)}) + \\frac{1}{8}\\cos(${toLatex(fourU)})',
      );
    }
    if (fn == 'sin' && n == 4) {
      final fourU = simplify(SymMul([SymNum.intVal(4), arg]));
      final anti = simplify(SymAdd([
        SymMul([SymNum(SymRat(3, 8)), SymVar(v)]),
        SymMul([SymNum.intVal(-1), SymDiv(SymFunc('sin', twoU), simplify(SymMul([SymNum.intVal(4), a])))]),
        SymDiv(SymFunc('sin', fourU), simplify(SymMul([SymNum.intVal(32), a]))),
      ]));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Doble Reducción de Potencia (Ángulo Doble)',
        explanation: 'Aplicamos dos veces sin²(u) = (1 - cos(2u))/2 para reducir la cuarta potencia trigonométrica.',
        transformationLatex: '\\sin^{4}(${toLatex(arg)}) = \\frac{3}{8} - \\frac{1}{2}\\cos(${toLatex(twoU)}) + \\frac{1}{8}\\cos(${toLatex(fourU)})',
      );
    }
    if (fn == 'cos' && n == 1) {
      return _tryDirectRules(SymFunc('cos', arg), v);
    }
    if (fn == 'sin' && n == 1) {
      return _tryDirectRules(SymFunc('sin', arg), v);
    }
    return null;
  }

  static SymbolicIntegrationOutcome? _tryReciprocalRules(SymExpr den, String v) {
    // 1 / v
    if (den is SymVar && den.name == v) {
      final anti = SymFunc('ln', SymFunc('abs', SymVar(v)));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Integración Logarítmica Directa',
        explanation: 'Aplicamos ∫ (1/$v) d$v = ln|$v|.',
      );
    }
    // 1 / (a*v + b)
    final lin = matchLinear(den, v);
    if (lin != null) {
      final (a, _) = lin;
      final anti = simplify(SymDiv(SymFunc('ln', SymFunc('abs', den)), a));
      return SymbolicIntegrationOutcome(
        isSymbolic: true,
        antiderivative: anti,
        antiderivativeLatex: toLatex(anti),
        method: 'Sustitución Lineal Logarítmica',
        explanation: 'Haciendo u = ${toLatex(den)} (du = ${toLatex(a)} d$v), la integral equivale a ln|u|/${toLatex(a)}.',
        transformationLatex: 'u = ${toLatex(den)}, \\; du = ${toLatex(a)} \\, d$v',
      );
    }

    // 1 / (a*v + b)^n
    if (den is SymPow && den.exp is SymNum && den.exp.dependsOn(v) == false) {
      return _tryDirectRules(
        SymPow(den.base, simplify(SymMul([SymNum.intVal(-1), den.exp]))),
        v,
      );
    }

    // 1 / sqrt(c^2 - a*v^2) -> arcsin
    if (den is SymFunc && den.name == 'sqrt') {
      final linSub = matchLinear(den.arg, v);
      if (linSub != null) {
        final (a, _) = linSub;
        final anti = simplify(SymDiv(SymMul([SymNum.intVal(2), SymFunc('sqrt', den.arg)]), a));
        return SymbolicIntegrationOutcome(
          isSymbolic: true,
          antiderivative: anti,
          antiderivativeLatex: toLatex(anti),
          method: 'Sustitución Lineal Radical',
          explanation: 'Integramos (${toLatex(den.arg)})^{-1/2} con u = ${toLatex(den.arg)}.',
          transformationLatex: 'u = ${toLatex(den.arg)}, \\; du = ${toLatex(a)} \\, d$v',
        );
      }
      final quad = _matchQuadratic(den.arg, v);
      if (quad != null) {
        final (cExpr, bExpr, aExpr) = quad;
        if (bExpr is SymNum && bExpr.rat.isZero && !aExpr.dependsOn(v) && !cExpr.dependsOn(v)) {
          final env = _safeOtherVarEnv(den.variables(), v);
          final aVal = aExpr.eval(env);
          final cVal = cExpr.eval(env);
          if (aVal < 0 && cVal > 0) {
            final k = simplify(SymMul([SymNum.intVal(-1), aExpr]));
            final sqrtK = simplify(SymFunc('sqrt', k));
            final sqrtC = simplify(SymFunc('sqrt', cExpr));
            final anti = simplify(SymDiv(
              SymFunc('asin', SymDiv(SymMul([sqrtK, SymVar(v)]), sqrtC)),
              sqrtK,
            ));
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: anti,
              antiderivativeLatex: toLatex(anti),
              method: 'Sustitución Trigonométrica Inversa (arcsin)',
              explanation: 'Reconocemos la forma estándar ∫ d$v / √(a² - v²) = arcsin(v/a).',
            );
          }
        }
      }
    }

    // 1 / (cExpr + aExpr * v^2) -> arctan o fracciones parciales ln
    final quad = _matchQuadratic(den, v);
    if (quad != null) {
      final (cExpr, bExpr, aExpr) = quad;
      if (bExpr is SymNum && bExpr.rat.isZero && !aExpr.dependsOn(v) && !cExpr.dependsOn(v)) {
        final env = _safeOtherVarEnv(den.variables(), v);
        final aVal = aExpr.eval(env);
        final cVal = cExpr.eval(env);
        if (aVal > 0 && cVal > 0) {
          final sqrtA = simplify(SymFunc('sqrt', aExpr));
          final sqrtC = simplify(SymFunc('sqrt', cExpr));
          final anti = simplify(SymDiv(
            SymFunc('atan', SymDiv(SymMul([sqrtA, SymVar(v)]), sqrtC)),
            SymMul([sqrtA, sqrtC]),
          ));
          return SymbolicIntegrationOutcome(
            isSymbolic: true,
            antiderivative: anti,
            antiderivativeLatex: toLatex(anti),
            method: 'Integración Trigonométrica Inversa (arctan)',
            explanation: 'Aplicamos ∫ d$v / (a² + v²) = (1/a)·arctan(v/a).',
          );
        }
        if (aVal < 0 && cVal > 0) {
          final k = simplify(SymMul([SymNum.intVal(-1), aExpr]));
          final sqrtK = simplify(SymFunc('sqrt', k));
          final sqrtC = simplify(SymFunc('sqrt', cExpr));
          final anti = simplify(SymDiv(
            SymFunc(
              'ln',
              SymFunc(
                'abs',
                SymDiv(
                  SymAdd([sqrtC, SymMul([sqrtK, SymVar(v)])]),
                  SymAdd([sqrtC, SymMul([SymNum.intVal(-1), sqrtK, SymVar(v)])]),
                ),
              ),
            ),
            SymMul([SymNum.intVal(2), sqrtK, sqrtC]),
          ));
          return SymbolicIntegrationOutcome(
            isSymbolic: true,
            antiderivative: anti,
            antiderivativeLatex: toLatex(anti),
            method: 'Fracciones Parciales (Diferencia de Cuadrados)',
            explanation: 'Factorizamos el denominador como (${toLatex(sqrtC)} - ${toLatex(sqrtK)}$v)(${toLatex(sqrtC)} + ${toLatex(sqrtK)}$v) y descomponemos en fracciones simples.',
          );
        }
      }
    }

    // 1 / cos(u)^2 -> tan(u)/a ; 1 / sin(u)^2 -> -cot(u)/a
    if (den is SymPow && den.exp is SymNum && (den.exp as SymNum).rat.p == 2 && den.base is SymFunc) {
      final f = den.base as SymFunc;
      if (f.name == 'cos') return _tryTrigPower('sec', f.arg, 2, v);
      if (f.name == 'sin') return _tryTrigPower('csc', f.arg, 2, v);
    }

    return null;
  }

  static (SymExpr c0, SymExpr c1, SymExpr c2)? _matchQuadratic(SymExpr expr, String v) {
    final s = expand(expr);
    if (!s.dependsOn(v) || _containsAbsOrNonSmooth(s)) return null;
    final d1 = diff(s, v);
    final d2 = diff(d1, v);
    final d3 = diff(d2, v);
    if (d3.dependsOn(v)) return null;
    if (!(d3 is SymNum && d3.rat.isZero)) return null;
    if (d2 is SymNum && d2.rat.isZero) return null;

    final c0 = simplify(substitute(s, v, SymNum.intVal(0)));
    final c1 = simplify(substitute(d1, v, SymNum.intVal(0)));
    final c2 = simplify(SymDiv(d2, SymNum.intVal(2)));
    return (c0, c1, c2);
  }

  static SymbolicIntegrationOutcome? _tryTrigProductToSum(
    SymExpr e,
    String v, {
    required int depth,
  }) {
    if (e is! SymMul || e.factors.length != 2) return null;
    final f1 = e.factors[0];
    final f2 = e.factors[1];

    // Caso sin(u)^2 * cos(u)^2 = (1 - cos(4u))/8
    if (f1 is SymPow &&
        f2 is SymPow &&
        f1.exp is SymNum &&
        f2.exp is SymNum &&
        (f1.exp as SymNum).rat.isInt &&
        (f2.exp as SymNum).rat.isInt &&
        (f1.exp as SymNum).rat.p == 2 &&
        (f2.exp as SymNum).rat.p == 2 &&
        f1.base is SymFunc &&
        f2.base is SymFunc) {
      final b1 = f1.base as SymFunc;
      final b2 = f2.base as SymFunc;
      if (((b1.name == 'sin' && b2.name == 'cos') || (b1.name == 'cos' && b2.name == 'sin')) &&
          b1.arg.structuralKey() == b2.arg.structuralKey()) {
        final lin = matchLinear(b1.arg, v);
        if (lin != null) {
          final fourU = simplify(SymMul([SymNum.intVal(4), b1.arg]));
          final rewritten = simplify(SymMul([
            SymNum(SymRat(1, 8)),
            SymAdd([SymNum.intVal(1), SymMul([SymNum.intVal(-1), SymFunc('cos', fourU)])]),
          ]));
          final sub = _integrateRecursive(rewritten, v, depth: depth + 1);
          if (sub.isSymbolic && sub.antiderivative != null) {
            return SymbolicIntegrationOutcome(
              isSymbolic: true,
              antiderivative: sub.antiderivative,
              antiderivativeLatex: sub.antiderivativeLatex,
              method: 'Identidad de Ángulo Doble (sin²u cos²u)',
              explanation: 'Aplicamos sin²(u)cos²(u) = (1 - cos(4u))/8.',
              transformationLatex: '${toLatex(e)} = ${toLatex(rewritten)}',
            );
          }
        }
      }
    }

    if (f1 is! SymFunc || f2 is! SymFunc) return null;
    if (!((f1.name == 'sin' || f1.name == 'cos') && (f2.name == 'sin' || f2.name == 'cos'))) {
      return null;
    }

    final l1 = matchLinear(f1.arg, v);
    final l2 = matchLinear(f2.arg, v);
    if (l1 == null || l2 == null) return null;

    final A = f1.arg;
    final B = f2.arg;
    final half = SymNum(SymRat(1, 2));
    SymExpr rewritten;
    String identity;
    if (f1.name == 'sin' && f2.name == 'cos') {
      rewritten = simplify(SymMul([
        half,
        SymAdd([
          SymFunc('sin', SymAdd([A, B])),
          SymFunc('sin', SymAdd([A, SymMul([SymNum.intVal(-1), B])])),
        ]),
      ]));
      identity = '\\sin(A)\\cos(B) = \\frac{1}{2}[\\sin(A+B) + \\sin(A-B)]';
    } else if (f1.name == 'cos' && f2.name == 'sin') {
      rewritten = simplify(SymMul([
        half,
        SymAdd([
          SymFunc('sin', SymAdd([B, A])),
          SymFunc('sin', SymAdd([B, SymMul([SymNum.intVal(-1), A])])),
        ]),
      ]));
      identity = '\\cos(A)\\sin(B) = \\frac{1}{2}[\\sin(B+A) + \\sin(B-A)]';
    } else if (f1.name == 'cos' && f2.name == 'cos') {
      rewritten = simplify(SymMul([
        half,
        SymAdd([
          SymFunc('cos', SymAdd([A, B])),
          SymFunc('cos', SymAdd([A, SymMul([SymNum.intVal(-1), B])])),
        ]),
      ]));
      identity = '\\cos(A)\\cos(B) = \\frac{1}{2}[\\cos(A+B) + \\cos(A-B)]';
    } else {
      // sin * sin
      rewritten = simplify(SymMul([
        half,
        SymAdd([
          SymFunc('cos', SymAdd([A, SymMul([SymNum.intVal(-1), B])])),
          SymMul([SymNum.intVal(-1), SymFunc('cos', SymAdd([A, B]))]),
        ]),
      ]));
      identity = '\\sin(A)\\sin(B) = \\frac{1}{2}[\\cos(A-B) - \\cos(A+B)]';
    }

    final sub = _integrateRecursive(rewritten, v, depth: depth + 1);
    if (!sub.isSymbolic || sub.antiderivative == null) return null;
    return SymbolicIntegrationOutcome(
      isSymbolic: true,
      antiderivative: sub.antiderivative,
      antiderivativeLatex: sub.antiderivativeLatex,
      method: 'Identidad Producto a Suma Trigonométrica',
      explanation: 'Transformamos el producto trigonométrico en suma usando $identity.',
      transformationLatex: '${toLatex(e)} = ${toLatex(rewritten)}',
    );
  }

  static SymbolicIntegrationOutcome? _tryGeneralUSubstitution(
    SymExpr e,
    String v, {
    required int depth,
  }) {
    // Recoger candidatos de subexpresión interna u(v)
    final candidates = <SymExpr>[];
    final seen = <String>{};

    void collect(SymExpr node) {
      switch (node) {
        case SymFunc(:final name, :final arg):
          if (arg.dependsOn(v) && !(arg is SymVar && arg.name == v)) {
            final k = arg.structuralKey();
            if (seen.add(k)) candidates.add(arg);
          }
          // También la función completa como u = sin(x) o u = ln(x)
          if (node.dependsOn(v) && name != 'abs') {
            final k = node.structuralKey();
            if (seen.add(k)) candidates.add(node);
          }
          collect(arg);
        case SymPow(:final base, :final exp):
          if (base.dependsOn(v) && !(base is SymVar && base.name == v)) {
            final k = base.structuralKey();
            if (seen.add(k)) candidates.add(base);
          }
          collect(base);
          collect(exp);
        case SymDiv(:final num, :final den):
          if (den.dependsOn(v) && !(den is SymVar && den.name == v)) {
            final k = den.structuralKey();
            if (seen.add(k)) candidates.add(den);
          }
          collect(num);
          collect(den);
        case SymMul(:final factors):
          for (final f in factors) {
            collect(f);
          }
        case SymAdd(:final terms):
          for (final t in terms) {
            collect(t);
          }
        default:
          break;
      }
    }

    collect(e);

    const uSymName = '__usub__';
    for (final u in candidates) {
      final du = diff(u, v);
      if (du is SymNum && du.rat.isZero) continue;

      // Dividir e entre du: comprobar si al reemplazar u por uSymName la expresión resultante
      // iguala k(sin v) * g(uSymName) evaluando el cociente (e / du) respecto a u.
      // Construimos eReplaced sustituyendo ocurrencias exactas de u por uSymName
      final uKey = u.structuralKey();
      final eWithU = _replaceSubExpr(e, uKey, const SymVar(uSymName));
      if (!eWithU.dependsOn(uSymName)) continue;

      // Intentamos factorizar multiplicativamente g(u) en eWithU:
      // Separar factores que SOLO dependen de uSymName (y no de v) vs el resto
      SymExpr? gOfU;
      SymExpr? remainder;

      if (eWithU is SymMul) {
        final uFacs = <SymExpr>[];
        final vFacs = <SymExpr>[];
        for (final f in eWithU.factors) {
          if (f.dependsOn(uSymName) && !f.dependsOn(v)) {
            uFacs.add(f);
          } else {
            vFacs.add(f);
          }
        }
        if (uFacs.isNotEmpty) {
          gOfU = uFacs.length == 1 ? uFacs.first : SymMul(uFacs);
          remainder = vFacs.isEmpty ? SymNum.intVal(1) : SymMul(vFacs);
        }
      } else if (eWithU is SymDiv) {
        // Caso num(v) / g(u) o g(u) / den(v)
        final numHasU = eWithU.num.dependsOn(uSymName);
        final denHasU = eWithU.den.dependsOn(uSymName);
        if (denHasU && !eWithU.den.dependsOn(v) && !numHasU) {
          gOfU = SymDiv(SymNum.intVal(1), eWithU.den);
          remainder = eWithU.num;
        } else if (numHasU && !eWithU.num.dependsOn(v) && !denHasU) {
          gOfU = eWithU.num;
          remainder = SymDiv(SymNum.intVal(1), eWithU.den);
        } else if (eWithU.num is SymMul && !denHasU) {
          final uFacs = <SymExpr>[];
          final vFacs = <SymExpr>[];
          for (final f in (eWithU.num as SymMul).factors) {
            if (f.dependsOn(uSymName) && !f.dependsOn(v)) {
              uFacs.add(f);
            } else {
              vFacs.add(f);
            }
          }
          if (uFacs.isNotEmpty) {
            gOfU = uFacs.length == 1 ? uFacs.first : SymMul(uFacs);
            final remNum = vFacs.isEmpty ? SymNum.intVal(1) : SymMul(vFacs);
            remainder = SymDiv(remNum, eWithU.den);
          }
        }
      }

      if (gOfU == null || remainder == null) continue;

      // Verificamos si remainder / du es una constante respecto a v!
      final env = _safeOtherVarEnv(e.variables(), v);
      final ratio = _constantRatioInVar(remainder, du, v, env);
      if (ratio == null) continue;

      final gIntegrand = simplify(SymMul([ratio, gOfU]));
      final uRes = _integrateRecursive(gIntegrand, uSymName, depth: depth + 1);
      if (uRes.isSymbolic && uRes.antiderivative != null) {
        final substitutedBack = substitute(uRes.antiderivative!, uSymName, u);
        if (_verifyAntiderivativeNumerically(e, substitutedBack, v)) {
          return SymbolicIntegrationOutcome(
            isSymbolic: true,
            antiderivative: substitutedBack,
            antiderivativeLatex: toLatex(substitutedBack),
            method: 'Método de Sustitución (u-sustitución)',
            explanation: 'Hacemos el cambio u = ${toLatex(u)}, con diferencial du = ${toLatex(du)} d$v para reducir el integrando a forma elemental.',
            transformationLatex: 'u = ${toLatex(u)}, \\; du = ${toLatex(du)} \\, d$v',
          );
        }
      }
    }
    return null;
  }

  static SymExpr _replaceSubExpr(SymExpr node, String targetKey, SymExpr rep) {
    if (node.structuralKey() == targetKey) return rep;
    return switch (node) {
      SymAdd(:final terms) => SymAdd(terms.map((t) => _replaceSubExpr(t, targetKey, rep)).toList()),
      SymMul(:final factors) => SymMul(factors.map((f) => _replaceSubExpr(f, targetKey, rep)).toList()),
      SymDiv(:final num, :final den) => SymDiv(
          _replaceSubExpr(num, targetKey, rep),
          _replaceSubExpr(den, targetKey, rep),
        ),
      SymPow(:final base, :final exp) => SymPow(
          _replaceSubExpr(base, targetKey, rep),
          _replaceSubExpr(exp, targetKey, rep),
        ),
      SymFunc(:final name, :final arg) => SymFunc(name, _replaceSubExpr(arg, targetKey, rep)),
      _ => node,
    };
  }

  static SymExpr? _constantRatioInVar(
    SymExpr numer,
    SymExpr denom,
    String v,
    Map<String, double> baseEnv,
  ) {
    if (!numer.dependsOn(v) && !denom.dependsOn(v)) {
      return simplify(SymDiv(numer, denom));
    }
    const probes = [0.37, 0.71, 1.13, -0.49];
    final vals = <double>[];
    for (final p in probes) {
      final env = Map<String, double>.from(baseEnv)..[v] = p;
      final nVal = numer.eval(env);
      final dVal = denom.eval(env);
      if (nVal.isFinite && dVal.isFinite && dVal.abs() > 1e-10) {
        vals.add(nVal / dVal);
      }
    }
    if (vals.length < 3) return null;
    final v0 = vals.first;
    for (final x in vals.skip(1)) {
      if ((x - v0).abs() > 1e-6 * math.max(1.0, v0.abs())) return null;
    }
    final rat = SymRat.tryFromDouble(v0);
    return rat != null ? SymNum(rat) : null;
  }

  static SymbolicIntegrationOutcome? _tryIntegrationByParts(
    SymExpr e,
    String v, {
    required int depth,
  }) {
    if (e is! SymMul) return null;
    // Separar posibles factores P(v) y T(v) donde P(v) es polinomial o logarítmico simple
    final pFacs = <SymExpr>[];
    final tFacs = <SymExpr>[];
    for (final f in e.factors) {
      if (_isPurePolynomialIn(f, v)) {
        pFacs.add(f);
      } else {
        tFacs.add(f);
      }
    }

    // Caso 1: P(v) * T(v) donde T(v) es sin(av+b), cos(av+b) o exp(av+b)
    if (pFacs.isNotEmpty && tFacs.length == 1 && tFacs.first is SymFunc) {
      final tFn = tFacs.first as SymFunc;
      final lin = matchLinear(tFn.arg, v);
      if (lin != null && (tFn.name == 'sin' || tFn.name == 'cos' || tFn.name == 'exp')) {
        SymExpr pCur = simplify(SymMul(pFacs));
        final deg = _polynomialDegree(pCur, v);
        if (deg >= 1 && deg <= 4) {
          SymExpr tCur = tFn;
          final sumTerms = <SymExpr>[];
          int sign = 1;
          for (int k = 0; k <= deg; k++) {
            final integT = _integrateRecursive(tCur, v, depth: depth + 1);
            if (!integT.isSymbolic || integT.antiderivative == null) {
              return null;
            }
            tCur = integT.antiderivative!;
            final term = sign == 1
                ? SymMul([pCur, tCur])
                : SymMul([SymNum.intVal(-1), pCur, tCur]);
            sumTerms.add(term);
            pCur = diff(pCur, v);
            sign = -sign;
          }
          final anti = simplify(SymAdd(sumTerms));
          return SymbolicIntegrationOutcome(
            isSymbolic: true,
            antiderivative: anti,
            antiderivativeLatex: toLatex(anti),
            method: 'Integración por Partes (Método Tabular)',
            explanation: 'Aplicamos integración por partes repetida tomando u = ${toLatex(simplify(SymMul(pFacs)))} y dv = ${toLatex(tFn)} d$v.',
            transformationLatex: 'u = ${toLatex(simplify(SymMul(pFacs)))}, \\; dv = ${toLatex(tFn)}\\,d$v',
          );
        }
      }

      // Caso 2: P(v) * ln(a*v + b) para monomio v^n * ln(v)
      if (tFn.name == 'ln' && pFacs.length == 1 && pFacs.first is SymVar && tFn.arg is SymVar) {
        final anti = simplify(SymAdd([
          SymDiv(SymMul([SymPow(SymVar(v), SymNum.intVal(2)), SymFunc('ln', SymVar(v))]), SymNum.intVal(2)),
          SymMul([SymNum(SymRat(-1, 4)), SymPow(SymVar(v), SymNum.intVal(2))]),
        ]));
        return SymbolicIntegrationOutcome(
          isSymbolic: true,
          antiderivative: anti,
          antiderivativeLatex: toLatex(anti),
          method: 'Integración por Partes',
          explanation: 'Tomamos u = ln($v) y dv = $v d$v.',
          transformationLatex: 'u = \\ln($v), \\; dv = $v\\,d$v',
        );
      }
      if (tFn.name == 'ln' &&
          pFacs.length == 1 &&
          pFacs.first is SymPow &&
          (pFacs.first as SymPow).base is SymVar &&
          (pFacs.first as SymPow).exp is SymNum &&
          tFn.arg is SymVar) {
        final n = ((pFacs.first as SymPow).exp as SymNum).rat;
        if (n != SymRat.minusOne) {
          final n1 = n.tryAdd(SymRat.one);
          if (n1 != null) {
            final n1Sq = n1.tryMul(n1);
            if (n1Sq != null) {
              final anti = simplify(SymAdd([
                SymDiv(SymMul([SymPow(SymVar(v), SymNum(n1)), tFn]), SymNum(n1)),
                SymMul([SymNum(SymRat(-1, 1)), SymDiv(SymPow(SymVar(v), SymNum(n1)), SymNum(n1Sq))]),
              ]));
              return SymbolicIntegrationOutcome(
                isSymbolic: true,
                antiderivative: anti,
                antiderivativeLatex: toLatex(anti),
                method: 'Integración por Partes',
                explanation: 'Tomamos u = ln($v) y dv = $v^{${n.toString()}} d$v.',
                transformationLatex: 'u = \\ln($v), \\; dv = $v^{$n}\\,d$v',
              );
            }
          }
        }
      }
    }

    // Caso 3: Cíclica exp(a*v) * sin(b*v) o exp(a*v) * cos(b*v)
    if (e.factors.length == 2 && e.factors[0] is SymFunc && e.factors[1] is SymFunc) {
      final fA = e.factors[0] as SymFunc;
      final fB = e.factors[1] as SymFunc;
      final expFn = fA.name == 'exp' ? fA : (fB.name == 'exp' ? fB : null);
      final trigFn = (fA.name == 'sin' || fA.name == 'cos')
          ? fA
          : ((fB.name == 'sin' || fB.name == 'cos') ? fB : null);
      if (expFn != null && trigFn != null) {
        final la = matchLinear(expFn.arg, v);
        final lb = matchLinear(trigFn.arg, v);
        final laB = la?.$2;
        final lbB = lb?.$2;
        if (la != null && lb != null && laB is SymNum && laB.rat.isZero && lbB is SymNum && lbB.rat.isZero) {
          final a = la.$1;
          final b = lb.$1;
          final denom = simplify(SymAdd([SymPow(a, SymNum.intVal(2)), SymPow(b, SymNum.intVal(2))]));
          final bArg = trigFn.arg;
          final inner = trigFn.name == 'sin'
              ? SymAdd([
                  SymMul([a, SymFunc('sin', bArg)]),
                  SymMul([SymNum.intVal(-1), b, SymFunc('cos', bArg)]),
                ])
              : SymAdd([
                  SymMul([a, SymFunc('cos', bArg)]),
                  SymMul([b, SymFunc('sin', bArg)]),
                ]);
          final anti = simplify(SymDiv(SymMul([expFn, inner]), denom));
          return SymbolicIntegrationOutcome(
            isSymbolic: true,
            antiderivative: anti,
            antiderivativeLatex: toLatex(anti),
            method: 'Integración por Partes Cíclica',
            explanation: 'Aplicando dos veces integración por partes a la exponencial por trigonométrica se despeja la integral cíclica.',
            transformationLatex: '\\int e^{ax}\\${trigFn.name}(bx)\\,dx = \\frac{e^{ax}(... )}{a^2 + b^2}',
          );
        }
      }
    }

    return null;
  }

  static bool _isPurePolynomialIn(SymExpr e, String v) {
    if (!e.dependsOn(v)) return true;
    if (e is SymVar && e.name == v) return true;
    if (e is SymPow && e.base is SymVar && (e.base as SymVar).name == v && e.exp is SymNum) {
      final r = (e.exp as SymNum).rat;
      return r.isInt && r.p >= 1 && r.p <= 4;
    }
    if (e is SymAdd) return e.terms.every((t) => _isPurePolynomialIn(t, v));
    if (e is SymMul) return e.factors.every((f) => _isPurePolynomialIn(f, v));
    return false;
  }

  static int _polynomialDegree(SymExpr e, String v) {
    if (!e.dependsOn(v)) return 0;
    if (e is SymVar && e.name == v) return 1;
    if (e is SymPow && e.base is SymVar && (e.base as SymVar).name == v && e.exp is SymNum) {
      return (e.exp as SymNum).rat.p;
    }
    if (e is SymAdd) {
      int m = 0;
      for (final t in e.terms) {
        final d = _polynomialDegree(t, v);
        if (d > m) m = d;
      }
      return m;
    }
    if (e is SymMul) {
      int sum = 0;
      for (final f in e.factors) {
        sum += _polynomialDegree(f, v);
      }
      return sum;
    }
    return 0;
  }

  static bool _verifyAntiderivativeNumerically(SymExpr integrand, SymExpr antideriv, String v) {
    final env = _safeOtherVarEnv({...integrand.variables(), ...antideriv.variables()}, v);
    const probes = [0.43, 0.79, 1.37, 2.11, -0.37, -1.23, 5.2, 11.4, -2.5];
    const h = 1e-5;
    int verified = 0;

    for (final p in probes) {
      final env0 = Map<String, double>.from(env)..[v] = p;
      final envP = Map<String, double>.from(env)..[v] = p + h;
      final envM = Map<String, double>.from(env)..[v] = p - h;
      final fVal = integrand.eval(env0);
      final fPlus = antideriv.eval(envP);
      final fMinus = antideriv.eval(envM);
      if (fVal.isFinite && fPlus.isFinite && fMinus.isFinite) {
        final numDiff = (fPlus - fMinus) / (2.0 * h);
        final tol = 1e-3 * math.max(1.0, fVal.abs());
        if ((numDiff - fVal).abs() > tol) {
          return false;
        }
        verified++;
        if (verified >= 2) return true;
      }
    }
    return true;
  }

  // ==================== GENERADOR DE LATEX LIMPIO ====================

  static String toLatex(SymExpr expr) => _printLatex(expr, 0);

  static String _printLatex(SymExpr expr, int parentPrec) {
    switch (expr) {
      case SymNum(:final rat):
        if (rat.isInt) return '${rat.p}';
        if (rat.p < 0) return '-\\frac{${-rat.p}}{${rat.q}}';
        return '\\frac{${rat.p}}{${rat.q}}';

      case SymFloat(:final value):
        if ((value - value.roundToDouble()).abs() < 1e-9) {
          return '${value.round()}';
        }
        return value.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');

      case SymConst(:final name):
        return name == 'pi' ? r'\pi' : 'e';

      case SymVar(:final name):
        return switch (name) {
          'theta' => r'\theta',
          'phi' => r'\phi',
          'rho' => r'\rho',
          _ => name,
        };

      case SymAdd(:final terms):
        if (terms.isEmpty) return '0';
        final sb = StringBuffer();
        for (int i = 0; i < terms.length; i++) {
          final t = terms[i];
          final ts = _printLatex(t, 1);
          if (i == 0) {
            sb.write(ts);
          } else if (ts.startsWith('-')) {
            sb.write(' - ${ts.substring(1).trim()}');
          } else {
            sb.write(' + $ts');
          }
        }
        final out = sb.toString();
        return parentPrec > 1 ? '($out)' : out;

      case SymDiv(:final num, :final den):
        return '\\frac{${_printLatex(num, 0)}}{${_printLatex(den, 0)}}';

      case SymMul(:final factors):
        return _printMulLatex(factors, parentPrec);

      case SymPow(:final base, :final exp):
        // Formato clásico cos^2(x), sin^3(2x) cuando la potencia es entero >= 2
        if (base is SymFunc &&
            const {'sin', 'cos', 'tan', 'sec', 'csc', 'cot', 'sinh', 'cosh', 'tanh'}.contains(base.name) &&
            exp is SymNum &&
            exp.rat.isInt &&
            exp.rat.p >= 2) {
          return '\\${base.name}^{${exp.rat.p}}(${_printLatex(base.arg, 0)})';
        }
        final needsBaseParens =
            base is SymAdd ||
            base is SymMul ||
            base is SymDiv ||
            (base is SymNum && (base.rat.p < 0 || !base.rat.isInt)) ||
            (base is SymFloat && base.value < 0) ||
            base is SymPow;
        final bStr = _printLatex(base, 0);
        final eStr = _printLatex(exp, 0);
        final wrappedBase = needsBaseParens ? '($bStr)' : bStr;
        return '$wrappedBase^{$eStr}';

      case SymFunc(:final name, :final arg):
        final aStr = _printLatex(arg, 0);
        switch (name) {
          case 'exp':
            return 'e^{$aStr}';
          case 'sqrt':
            return '\\sqrt{$aStr}';
          case 'abs':
            return '\\left|$aStr\\right|';
          case 'ln':
            return '\\ln($aStr)';
          case 'asin':
            return '\\arcsin($aStr)';
          case 'acos':
            return '\\arccos($aStr)';
          case 'atan':
            return '\\arctan($aStr)';
          default:
            return '\\$name($aStr)';
        }
    }
  }

  static String _printMulLatex(List<SymExpr> factors, int parentPrec) {
    if (factors.isEmpty) return '1';

    bool negative = false;
    int denomInt = 1;
    int numInt = 1;
    SymFloat? floatPrefix;
    final symbolicNumer = <SymExpr>[];
    final symbolicDenom = <SymExpr>[];

    for (final f in factors) {
      if (f is SymNum) {
        if (f.rat.isZero) return '0';
        var p = f.rat.p;
        if (p < 0) {
          negative = !negative;
          p = -p;
        }
        numInt *= p;
        denomInt *= f.rat.q;
      } else if (f is SymFloat) {
        var v = f.value;
        if (v < 0) {
          negative = !negative;
          v = -v;
        }
        floatPrefix = SymFloat(v * (floatPrefix?.value ?? 1.0));
      } else if (f is SymDiv) {
        if (!(f.num is SymNum && (f.num as SymNum).rat.isOne)) {
          symbolicNumer.add(f.num);
        }
        symbolicDenom.add(f.den);
      } else {
        symbolicNumer.add(f);
      }
    }

    // Simplificar razón entera numInt / denomInt
    final g = SymRat._gcd(numInt, denomInt);
    numInt ~/= g;
    denomInt ~/= g;

    final numParts = <String>[];
    if (floatPrefix != null) {
      numParts.add(_printLatex(floatPrefix, 2));
    } else if (numInt != 1 || (symbolicNumer.isEmpty && denomInt == 1)) {
      numParts.add('$numInt');
    }

    for (int i = 0; i < symbolicNumer.length; i++) {
      final item = symbolicNumer[i];
      // Evitar paréntesis en fracción única tipo (1/2) * (3y - 5) -> \frac{3y - 5}{2}
      final dropAddParens = denomInt > 1 && symbolicNumer.length == 1 && numInt == 1 && item is SymAdd;
      final str = dropAddParens
          ? _printLatex(item, 0)
          : _printLatex(item, 2);
      numParts.add(str);
    }

    final joinedNum = numParts.isEmpty ? '1' : _joinProductTokens(numParts);
    final signStr = negative ? '-' : '';

    String result;
    if (denomInt > 1 || symbolicDenom.isNotEmpty) {
      final denParts = <String>[
        if (denomInt > 1) '$denomInt',
        for (final d in symbolicDenom) _printLatex(d, symbolicDenom.length == 1 && denomInt == 1 ? 0 : 2),
      ];
      final joinedDen = _joinProductTokens(denParts);
      result = '$signStr\\frac{$joinedNum}{$joinedDen}';
    } else {
      result = '$signStr$joinedNum';
    }

    if (parentPrec > 2 && negative) return '($result)';
    return result;
  }

  static String _joinProductTokens(List<String> parts) {
    if (parts.isEmpty) return '';
    final sb = StringBuffer(parts.first);
    for (int i = 1; i < parts.length; i++) {
      final prev = parts[i - 1];
      final cur = parts[i];
      // Insertar espacio cuando un token termina en letra o comando y el siguiente empieza con barra o letra de comando
      final prevIsDigit = RegExp(r'[0-9]$').hasMatch(prev);
      final curStartsWithSingleVar = RegExp(r'^[xyzrut](?:$|\^)').hasMatch(cur);
      final bothSingleVars = RegExp(r'^[xyzrut](?:\^\{[0-9]+\})?$').hasMatch(prev) && curStartsWithSingleVar;
      if ((prevIsDigit && curStartsWithSingleVar) || bothSingleVars || cur.startsWith('(')) {
        sb.write(cur);
      } else {
        sb.write(' $cur');
      }
    }
    return sb.toString();
  }
}

/// Parser recursivo descendente para construir `SymExpr`.
class _AstParser {
  final String _s;
  int _pos = 0;

  _AstParser(this._s);

  int get _ch => _pos < _s.length ? _s.codeUnitAt(_pos) : -1;

  bool _eat(int code) {
    if (_ch == code) {
      _pos++;
      return true;
    }
    return false;
  }

  SymExpr? parseAll() {
    final e = _parseExpr();
    if (_pos != _s.length) return null;
    return e;
  }

  SymExpr _parseExpr() {
    final terms = <SymExpr>[_parseTerm()];
    while (true) {
      if (_eat(43)) {
        // '+'
        terms.add(_parseTerm());
      } else if (_eat(45)) {
        // '-'
        terms.add(SymMul([SymNum.intVal(-1), _parseTerm()]));
      } else {
        break;
      }
    }
    return terms.length == 1 ? terms.first : SymAdd(terms);
  }

  SymExpr _parseTerm() {
    var v = _parseUnary();
    while (true) {
      if (_eat(42)) {
        // '*'
        v = SymMul([v, _parseUnary()]);
      } else if (_eat(47)) {
        // '/'
        v = SymDiv(v, _parseUnary());
      } else {
        break;
      }
    }
    return v;
  }

  SymExpr _parseUnary() {
    if (_eat(43)) return _parseUnary();
    if (_eat(45)) return SymMul([SymNum.intVal(-1), _parseUnary()]);
    return _parseFactor();
  }

  SymExpr _parseFactor() {
    final base = _parsePrimary();
    if (_eat(94)) {
      // '^'
      final exp = _parseUnary();
      return SymPow(base, exp);
    }
    return base;
  }

  SymExpr _parsePrimary() {
    if (_eat(40)) {
      final inner = _parseExpr();
      if (!_eat(41)) throw FormatException('Paréntesis no cerrado');
      return inner;
    }

    // Número decimal o entero
    if ((_ch >= 48 && _ch <= 57) || _ch == 46) {
      final start = _pos;
      while ((_ch >= 48 && _ch <= 57) || _ch == 46) {
        _pos++;
      }
      final numStr = _s.substring(start, _pos);
      final intVal = int.tryParse(numStr);
      if (intVal != null) return SymNum.intVal(intVal);
      final dVal = double.parse(numStr);
      final r = SymRat.tryFromDouble(dVal);
      return r != null ? SymNum(r) : SymFloat(dVal);
    }

    // Identificador: función o variable/constante
    if ((_ch >= 97 && _ch <= 122) || (_ch >= 65 && _ch <= 90)) {
      final start = _pos;
      while ((_ch >= 97 && _ch <= 122) || (_ch >= 65 && _ch <= 90) || (_ch >= 48 && _ch <= 57)) {
        _pos++;
      }
      final rawIdent = _s.substring(start, _pos);
      final ident = (rawIdent == 'R' || rawIdent == 'H') ? rawIdent : rawIdent.toLowerCase();
      if (ident == 'pi' || ident == 'e') return SymConst(ident);
      if (_eat(40)) {
        final arg = _parseExpr();
        if (!_eat(41)) throw FormatException('Paréntesis no cerrado en $ident');
        return SymFunc(ident.toLowerCase(), arg);
      }
      return SymVar(ident);
    }

    throw FormatException('Carácter inesperado en posición $_pos: $_s');
  }
}
