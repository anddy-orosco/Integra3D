import 'dart:math' as math;
import 'integral_expression_transformer.dart';

/// Evaluador de expresiones matemáticas autónomo mediante Descenso Recursivo.
/// Permite evaluar funciones algebraicas f(x, y, z) de cálculo multivariable
/// sin depender de bibliotecas externas ni APIs externas.
class MathExpressionEvaluator {
  final String _input;
  int _pos = 0;
  int _ch = -1;

  MathExpressionEvaluator(String expression)
      : _input = IntegralExpressionTransformer.normalizeExpression(expression)
            .replaceAll(' ', '')
            .replaceAll('**', '^')
            .replaceAll('×', '*')
            .replaceAll('÷', '/')
            .replaceAll('−', '-');

  /// Evalúa la expresión para los valores dados de x, y, z y parámetros opcionales.
  static double evaluate(
    String expression, {
    double x = 0.0,
    double y = 0.0,
    double z = 0.0,
    Map<String, double> params = const {},
  }) {
    if (expression.trim().isEmpty) return 0.0;
    try {
      final evaluator = MathExpressionEvaluator(expression);
      final result = evaluator._parse(x: x, y: y, z: z, params: params);
      if (result.isNaN || result.isInfinite) return result;
      return result.abs() < 1e-12 ? 0.0 : result;
    } catch (_) {
      return double.nan;
    }
  }

  void _nextChar() {
    _pos++;
    if (_pos < _input.length) {
      _ch = _input.codeUnitAt(_pos);
    } else {
      _ch = -1;
    }
  }

  bool _eat(int charToEat) {
    while (_ch == 32) {
      _nextChar(); // Ignorar espacios
    }
    if (_ch == charToEat) {
      _nextChar();
      return true;
    }
    return false;
  }

  double _parse({
    required double x,
    required double y,
    required double z,
    required Map<String, double> params,
  }) {
    _pos = -1;
    _nextChar();
    final result = _parseExpression(x: x, y: y, z: z, params: params);
    return result;
  }

  // expression = term (('+' | '-') term)*
  double _parseExpression({
    required double x,
    required double y,
    required double z,
    required Map<String, double> params,
  }) {
    double v = _parseTerm(x: x, y: y, z: z, params: params);
    while (true) {
      if (_eat(43)) {
        // '+'
        v += _parseTerm(x: x, y: y, z: z, params: params);
      } else if (_eat(45)) {
        // '-'
        v -= _parseTerm(x: x, y: y, z: z, params: params);
      } else {
        return v;
      }
    }
  }

  // term = unary (('*' | '/') unary)*
  double _parseTerm({
    required double x,
    required double y,
    required double z,
    required Map<String, double> params,
  }) {
    double v = _parseUnary(x: x, y: y, z: z, params: params);
    while (true) {
      if (_eat(42)) {
        // '*'
        v *= _parseUnary(x: x, y: y, z: z, params: params);
      } else if (_eat(47)) {
        // '/'
        final divisor = _parseUnary(x: x, y: y, z: z, params: params);
        v = (divisor != 0.0) ? v / divisor : (v == 0.0 ? double.nan : (v > 0 ? double.infinity : -double.infinity));
      } else {
        return v;
      }
    }
  }

  // unary = ('+' | '-') unary | power
  double _parseUnary({
    required double x,
    required double y,
    required double z,
    required Map<String, double> params,
  }) {
    if (_eat(43)) return _parseUnary(x: x, y: y, z: z, params: params); // '+'
    if (_eat(45)) return -_parseUnary(x: x, y: y, z: z, params: params); // '-'
    return _parseFactor(x: x, y: y, z: z, params: params);
  }

  // power = primary ('^' unary)?
  double _parseFactor({
    required double x,
    required double y,
    required double z,
    required Map<String, double> params,
  }) {
    double v = _parsePrimary(x: x, y: y, z: z, params: params);
    if (_eat(94)) {
      // '^'
      final exponent = _parseUnary(x: x, y: y, z: z, params: params);
      if (v < 0 && exponent != exponent.roundToDouble()) {
        // Allow odd integer roots like (-8)^(1/3) = -2
        final inv = 1.0 / exponent;
        if ((inv - inv.roundToDouble()).abs() < 1e-9 && inv.round().isOdd) {
          v = -math.pow(-v, exponent).toDouble();
        } else {
          v = double.nan; // Indefinido en reales para potencias fraccionarias pares de negativos
        }
      } else {
        v = math.pow(v, exponent).toDouble();
      }
    }
    return v;
  }

  // primary = number | variable | function '(' expression ')' | '(' expression ')'
  double _parsePrimary({
    required double x,
    required double y,
    required double z,
    required Map<String, double> params,
  }) {
    final startPos = _pos;

    if (_eat(40)) {
      // '('
      final v = _parseExpression(x: x, y: y, z: z, params: params);
      _eat(41); // ')'
      return v;
    }

    // Números (enteros o decimales)
    if ((_ch >= 48 && _ch <= 57) || _ch == 46) {
      while ((_ch >= 48 && _ch <= 57) || _ch == 46) {
        _nextChar();
      }
      return double.tryParse(_input.substring(startPos, _pos)) ?? 0.0;
    }

    // Identificadores (variables o funciones)
    if ((_ch >= 97 && _ch <= 122) || (_ch >= 65 && _ch <= 90)) {
      while ((_ch >= 97 && _ch <= 122) || (_ch >= 65 && _ch <= 90) || (_ch >= 48 && _ch <= 57)) {
        _nextChar();
      }
      final rawName = _input.substring(startPos, _pos);
      final name = rawName.toLowerCase();

      const knownFns = {
        'sqrt', 'cbrt', 'sin', 'cos', 'tan', 'sec', 'csc', 'cot',
        'sinh', 'cosh', 'tanh', 'asin', 'arcsin', 'acos', 'arccos',
        'atan', 'arctan', 'exp', 'ln', 'log', 'abs',
      };

      // Si NO es una función conocida, retornar inmediatamente como variable / constante
      if (!knownFns.contains(name)) {
        if (params.containsKey(rawName)) return params[rawName]!;
        if (name == 'x') return x;
        if (name == 'y') return y;
        if (name == 'z') return z;
        if (params.containsKey(name)) return params[name]!;
        if (name == 'pi') return math.pi;
        if (name == 'e') return math.e;
        if (rawName == 'R') return 2.0;
        if (rawName == 'H') return 3.0;
        return 1.0;
      }

      // Potencia directa en notación función^k(arg), ej. cos^2(x)
      double? fnPower;
      if (_eat(94)) {
        fnPower = _parseUnary(x: x, y: y, z: z, params: params);
      }

      // Funciones
      if (_eat(40)) {
        // '('
        final arg = _parseExpression(x: x, y: y, z: z, params: params);
        _eat(41); // ')'

        double val;
        switch (name) {
          case 'sqrt':
            val = arg >= 0 ? math.sqrt(arg) : double.nan;
          case 'cbrt':
            val = arg < 0 ? -math.pow(-arg, 1.0 / 3.0).toDouble() : math.pow(arg, 1.0 / 3.0).toDouble();
          case 'sin':
            val = math.sin(arg);
          case 'cos':
            val = math.cos(arg);
          case 'tan':
            val = math.tan(arg);
          case 'sec':
            final c = math.cos(arg);
            val = c.abs() < 1e-12 ? double.nan : 1.0 / c;
          case 'csc':
            final s = math.sin(arg);
            val = s.abs() < 1e-12 ? double.nan : 1.0 / s;
          case 'cot':
            final t = math.tan(arg);
            val = t.abs() < 1e-12 ? double.nan : 1.0 / t;
          case 'sinh':
            val = (math.exp(arg) - math.exp(-arg)) / 2.0;
          case 'cosh':
            val = (math.exp(arg) + math.exp(-arg)) / 2.0;
          case 'tanh':
            final ep = math.exp(arg);
            final em = math.exp(-arg);
            val = (ep - em) / (ep + em);
          case 'asin':
          case 'arcsin':
            val = (arg >= -1.0 && arg <= 1.0) ? math.asin(arg) : double.nan;
          case 'acos':
          case 'arccos':
            val = (arg >= -1.0 && arg <= 1.0) ? math.acos(arg) : double.nan;
          case 'atan':
          case 'arctan':
            val = math.atan(arg);
          case 'exp':
            val = math.exp(arg);
          case 'ln':
          case 'log':
            val = arg > 0 ? math.log(arg) : double.nan;
          case 'abs':
            val = arg.abs();
          default:
            val = arg;
        }
        if (fnPower != null && val.isFinite) {
          if (val < 0 && fnPower != fnPower.roundToDouble()) return double.nan;
          return math.pow(val, fnPower).toDouble();
        }
        return val;
      }
      // Fallback variable if not a function call
      if (params.containsKey(rawName)) return params[rawName]!;
      if (params.containsKey(name)) return params[name]!;
      if (name == 'x') return x;
      if (name == 'y') return y;
      if (name == 'z') return z;
      if (name == 'pi') return math.pi;
      if (name == 'e') return math.e;
      return 1.0;
    }

    return 0.0;
  }
}
