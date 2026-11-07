import 'dart:math' as math;

/// Evaluador de expresiones matemáticas autónomo mediante Descenso Recursivo.
/// Permite evaluar funciones algebraicas f(x, y, z) de cálculo multivariable
/// sin depender de bibliotecas externas ni APIs externas.
class MathExpressionEvaluator {
  final String _input;
  int _pos = 0;
  int _ch = -1;

  MathExpressionEvaluator(String expression)
      : _input = expression
            .replaceAll(' ', '')
            .replaceAll('**', '^')
            .replaceAll('×', '*')
            .replaceAll('÷', '/')
            .replaceAll('−', '-');

  /// Evalúa la expresión para los valores dados de x, y, z.
  static double evaluate(String expression, {double x = 0.0, double y = 0.0, double z = 0.0}) {
    if (expression.trim().isEmpty) return 0.0;
    try {
      final evaluator = MathExpressionEvaluator(expression);
      return evaluator._parse(x: x, y: y, z: z);
    } catch (_) {
      return 0.0;
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

  double _parse({required double x, required double y, required double z}) {
    _pos = -1;
    _nextChar();
    final result = _parseExpression(x: x, y: y, z: z);
    return result;
  }

  // expression = term (('+' | '-') term)*
  double _parseExpression({required double x, required double y, required double z}) {
    double v = _parseTerm(x: x, y: y, z: z);
    while (true) {
      if (_eat(43)) {
        // '+'
        v += _parseTerm(x: x, y: y, z: z);
      } else if (_eat(45)) {
        // '-'
        v -= _parseTerm(x: x, y: y, z: z);
      } else {
        return v;
      }
    }
  }

  // term = factor (('*' | '/') factor)*
  double _parseTerm({required double x, required double y, required double z}) {
    double v = _parseFactor(x: x, y: y, z: z);
    while (true) {
      if (_eat(42)) {
        // '*'
        v *= _parseFactor(x: x, y: y, z: z);
      } else if (_eat(47)) {
        // '/'
        final divisor = _parseFactor(x: x, y: y, z: z);
        v = (divisor != 0.0) ? v / divisor : 0.0;
      } else {
        return v;
      }
    }
  }

  // factor = power
  // power = unary ('^' factor)?
  double _parseFactor({required double x, required double y, required double z}) {
    double v = _parseUnary(x: x, y: y, z: z);
    if (_eat(94)) {
      // '^'
      final exponent = _parseFactor(x: x, y: y, z: z);
      if (v < 0 && exponent != exponent.roundToDouble()) {
        v = 0.0; // Evitar NaN en raíces pares de negativos
      } else {
        v = math.pow(v, exponent).toDouble();
      }
    }
    return v;
  }

  // unary = ('+' | '-') unary | primary
  double _parseUnary({required double x, required double y, required double z}) {
    if (_eat(43)) return _parseUnary(x: x, y: y, z: z); // '+'
    if (_eat(45)) return -_parseUnary(x: x, y: y, z: z); // '-'
    return _parsePrimary(x: x, y: y, z: z);
  }

  // primary = number | variable | function '(' expression ')' | '(' expression ')'
  double _parsePrimary({required double x, required double y, required double z}) {
    final startPos = _pos;

    if (_eat(40)) {
      // '('
      final v = _parseExpression(x: x, y: y, z: z);
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
      final name = _input.substring(startPos, _pos).toLowerCase();

      // Variables
      if (name == 'x') return x;
      if (name == 'y') return y;
      if (name == 'z') return z;
      if (name == 'pi') return math.pi;
      if (name == 'e') return math.e;

      // Funciones
      if (_eat(40)) {
        // '('
        final arg = _parseExpression(x: x, y: y, z: z);
        _eat(41); // ')'

        switch (name) {
          case 'sqrt':
            return arg >= 0 ? math.sqrt(arg) : 0.0;
          case 'sin':
            return math.sin(arg);
          case 'cos':
            return math.cos(arg);
          case 'tan':
            return math.tan(arg);
          case 'exp':
            return math.exp(arg);
          case 'ln':
          case 'log':
            return arg > 0 ? math.log(arg) : 0.0;
          case 'abs':
            return arg.abs();
          default:
            return arg;
        }
      }
    }

    return 0.0;
  }
}
