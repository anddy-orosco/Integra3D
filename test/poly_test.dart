import 'package:flutter_test/flutter_test.dart';
import 'package:integra_3d/features/calculator/domain/entities/integration_bound.dart';
import 'package:integra_3d/features/calculator/domain/entities/multivariable_integral.dart';
import 'package:integra_3d/features/calculator/domain/services/local_math_engine.dart';

int gcd(int a, int b) {
  while (b != 0) {
    final t = b;
    b = a % b;
    a = t;
  }
  return a.abs();
}

String formatFraction(int num, int den) {
  if (den < 0) {
    num = -num;
    den = -den;
  }
  if (den == 0) return '$num';
  final g = gcd(num.abs(), den);
  num ~/= g;
  den ~/= g;
  if (den == 1) return '$num';
  return '\\frac{$num}{$den}';
}

class Term2D {
  final double coeff;
  final int pInner;
  final int pOuter;

  const Term2D(this.coeff, this.pInner, this.pOuter);
  @override
  String toString() => 'Term2D(c: $coeff, pIn: $pInner, pOut: $pOuter)';
}

class LinearBound {
  final double c0;
  final double c1;

  const LinearBound(this.c0, this.c1);
  @override
  String toString() => 'LinearBound(c0: $c0, c1: $c1)';
}

int binom(int n, int k) {
  if (k < 0 || k > n) return 0;
  if (k == 0 || k == n) return 1;
  int c = 1;
  for (int i = 0; i < k; i++) {
    c = c * (n - i) ~/ (i + 1);
  }
  return c;
}

Map<int, double> expandBinomial(double c0, double c1, int n) {
  final result = <int, double>{};
  for (int k = 0; k <= n; k++) {
    final b = binom(n, k).toDouble();
    double termCoeff = b;
    for (int j = 0; j < (n - k); j++) {
      termCoeff *= c0;
    }
    for (int j = 0; j < k; j++) {
      termCoeff *= c1;
    }
    result[k] = (result[k] ?? 0.0) + termCoeff;
  }
  return result;
}

LinearBound? parseLinearBound(String boundStr, String outerVar) {
  var s = boundStr.replaceAll(' ', '').toLowerCase();
  if (s.isEmpty) return null;
  final ov = outerVar.toLowerCase();

  // If complex operations like sqrt, ^, /, return null
  if (s.contains('sqrt') || s.contains('^') || s.contains('/') || s.contains('(')) {
    return null;
  }

  // Split into signed tokens
  final tokens = <String>[];
  int start = 0;
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s[i] == '+' || s[i] == '-')) {
      tokens.add(s.substring(start, i));
      start = i;
    }
  }
  tokens.add(s.substring(start));

  double c0 = 0.0;
  double c1 = 0.0;

  for (var tok in tokens) {
    if (tok.isEmpty) continue;
    if (tok.startsWith('+')) tok = tok.substring(1);
    if (tok.contains(ov)) {
      var coeffPart = tok.replaceAll('*', '').replaceAll(ov, '');
      if (coeffPart.isEmpty || coeffPart == '+') {
        c1 += 1.0;
      } else if (coeffPart == '-') {
        c1 -= 1.0;
      } else {
        final val = double.tryParse(coeffPart);
        if (val == null) return null;
        c1 += val;
      }
    } else {
      final val = double.tryParse(tok);
      if (val == null) return null;
      c0 += val;
    }
  }

  return LinearBound(c0, c1);
}

List<Term2D>? parsePolynomial2DTerms(String expr, String innerVar, String outerVar) {
  var s = expr.replaceAll(' ', '').toLowerCase();
  final iv = innerVar.toLowerCase();
  final ov = outerVar.toLowerCase();

  if (s.contains('sin') || s.contains('cos') || s.contains('exp') || s.contains('ln') || s.contains('sqrt') || s.contains('/')) {
    return null;
  }

  final tokens = <String>[];
  int start = 0;
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s[i] == '+' || s[i] == '-')) {
      tokens.add(s.substring(start, i));
      start = i;
    }
  }
  tokens.add(s.substring(start));

  final terms = <Term2D>[];

  for (var tok in tokens) {
    if (tok.isEmpty) continue;
    if (tok.startsWith('+')) tok = tok.substring(1);

    double sign = 1.0;
    if (tok.startsWith('-')) {
      sign = -1.0;
      tok = tok.substring(1);
    }

    final varRegex = RegExp('^([0-9.]*)?\\*?(?:([$iv$ov])(?:\\^([0-9]+))?)?\\*?(?:([$iv$ov])(?:\\^([0-9]+))?)?\$');
    final m = varRegex.firstMatch(tok);
    if (m == null) return null;

    final cStr = m.group(1);
    double c = 1.0;
    if (cStr != null && cStr.isNotEmpty) {
      final parsed = double.tryParse(cStr);
      if (parsed == null) return null;
      c = parsed;
    }

    int pIn = 0;
    int pOut = 0;

    void addVar(String? v, String? p) {
      if (v == null) return;
      final pow = p != null ? int.parse(p) : 1;
      if (v == iv) pIn += pow;
      if (v == ov) pOut += pow;
    }

    addVar(m.group(2), m.group(3));
    addVar(m.group(4), m.group(5));

    terms.add(Term2D(sign * c, pIn, pOut));
  }

  return terms;
}

String formatPoly1D(Map<int, double> poly, String v) {
  final sortedPowers = poly.keys.toList()..sort((a, b) => b.compareTo(a));
  final parts = <String>[];

  for (final p in sortedPowers) {
    final c = poly[p]!;
    if (c.abs() < 1e-9) continue;

    final isInt = (c - c.roundToDouble()).abs() < 1e-9;
    final absVal = c.abs();
    final cStr = isInt ? '${absVal.toInt()}' : absVal.toStringAsFixed(2);

    String termStr = '';
    if (p == 0) {
      termStr = cStr;
    } else if (p == 1) {
      termStr = (absVal == 1.0) ? v : '$cStr$v';
    } else {
      termStr = (absVal == 1.0) ? '$v^$p' : '$cStr$v^$p';
    }

    if (parts.isEmpty) {
      parts.add(c < 0 ? '-$termStr' : termStr);
    } else {
      parts.add(c < 0 ? '- $termStr' : '+ $termStr');
    }
  }

  return parts.isEmpty ? '0' : parts.join(' ');
}

void main() {
  test('Parser and bound expansion for 6 - 2x with y in [0, 2 - 2x] and x in [0, 1]', () {
    final boundUp = parseLinearBound('2 - 2x', 'x');
    expect(boundUp, isNotNull);
    expect(boundUp!.c0, equals(2.0));
    expect(boundUp.c1, equals(-2.0));

    final boundLow = parseLinearBound('0', 'x');
    expect(boundLow, isNotNull);
    expect(boundLow!.c0, equals(0.0));
    expect(boundLow.c1, equals(0.0));

    final terms = parsePolynomial2DTerms('6 - 2x', 'y', 'x');
    expect(terms, isNotNull);
    expect(terms!.length, equals(2));
    expect(terms[0].coeff, equals(6.0));
    expect(terms[0].pInner, equals(0));
    expect(terms[0].pOuter, equals(0));
    expect(terms[1].coeff, equals(-2.0));
    expect(terms[1].pInner, equals(0));
    expect(terms[1].pOuter, equals(1));

    final polyX = <int, double>{};
    for (final t in terms) {
      final n = t.pInner + 1;
      final cIn = t.coeff / n;
      final upExp = expandBinomial(boundUp.c0, boundUp.c1, n);
      final lowExp = expandBinomial(boundLow.c0, boundLow.c1, n);
      final allK = {...upExp.keys, ...lowExp.keys};
      for (final k in allK) {
        final diff = (upExp[k] ?? 0.0) - (lowExp[k] ?? 0.0);
        final netCoeff = cIn * diff;
        final totalPow = k + t.pOuter;
        polyX[totalPow] = (polyX[totalPow] ?? 0.0) + netCoeff;
      }
    }

    final polyStr = formatPoly1D(polyX, 'x');
    expect(polyStr, equals('4x^2 - 16x + 12'));
  });

  test('Parser for 6 - 2x - y', () {
    final terms = parsePolynomial2DTerms('6 - 2x - y', 'y', 'x');
    expect(terms, isNotNull);
    expect(terms!.length, equals(3));
    expect(terms[2].coeff, equals(-1.0));
    expect(terms[2].pInner, equals(1));
    expect(terms[2].pOuter, equals(0));
  });

  test('Parser for xy^3 with x in [0, 3y - 5] and y in [-2, 1]', () {
    final terms = parsePolynomial2DTerms('xy^3', 'x', 'y');
    expect(terms, isNotNull);
    expect(terms!.length, equals(1));
    expect(terms[0].coeff, equals(1.0));
    expect(terms[0].pInner, equals(1)); // x
    expect(terms[0].pOuter, equals(3)); // y

    final boundUp = parseLinearBound('3y - 5', 'y');
    expect(boundUp, isNotNull);
    expect(boundUp!.c0, equals(-5.0));
    expect(boundUp.c1, equals(3.0));

    final polyY = <int, double>{};
    for (final t in terms) {
      final n = t.pInner + 1; // 2
      final cIn = t.coeff / n; // 0.5
      final upExp = expandBinomial(boundUp.c0, boundUp.c1, n);
      // (3y - 5)^2 = 25 - 30y + 9y^2
      for (final entry in upExp.entries) {
        final k = entry.key;
        final netCoeff = cIn * entry.value;
        final totalPow = k + t.pOuter; // k + 3
        polyY[totalPow] = (polyY[totalPow] ?? 0.0) + netCoeff;
      }
    }

    expect(polyY[5], equals(4.5));
    expect(polyY[4], equals(-15.0));
    expect(polyY[3], equals(12.5));

    // Outer integral in y from -2 to 1
    // Antiderivative: (9/12) y^6 - 3 y^5 + (25/8) y^4 = (3/4) y^6 - 3 y^5 + (25/8) y^4
    double evalAt(double y) {
      double s = 0.0;
      for (final entry in polyY.entries) {
        final k = entry.key;
        final c = entry.value;
        final intPow = k + 1;
        s += (c / intPow) * (k + 1 == 6 ? (y * y * y * y * y * y) : (k + 1 == 5 ? (y * y * y * y * y) : (y * y * y * y)));
      }
      return s;
    }

    final val1 = evalAt(1.0);
    final valM2 = evalAt(-2.0);
    final diff = val1 - valM2;
    expect(diff, closeTo(-1545.0 / 8.0, 1e-9));
  });

  test('Fraction converter test', () {
    expect(doubleToFraction(4.5), equals((9, 2)));
    expect(doubleToFraction(-12.5), equals((-25, 2)));
    expect(doubleToFraction(16 / 3), equals((16, 3)));
    expect(doubleToFraction(-193.125), equals((-1545, 8)));
    expect(doubleToFraction(0.0), equals((0, 1)));
    expect(doubleToFraction(8.0), equals((8, 1)));
  });

  test('LocalMathEngine.solveLocal on 6 - 2x with y in [0, 2-2x] and x in [0, 1]', () {
    const integral = MultivariableIntegral(
      integrand: '6 - 2x',
      bounds: [
        IntegrationBound(variable: 'y', lower: '0', upper: '2 - 2x'),
        IntegrationBound(variable: 'x', lower: '0', upper: '1'),
      ],
      coordinateSystem: CoordinateSystemType.cartesian,
    );

    final sol = LocalMathEngine.solveLocal(integral);
    expect(sol.isSuccess, isTrue);
    expect(sol.exactLatex, equals(r'\frac{16}{3}'));
    expect(sol.approxNumeric, closeTo(5.3333, 0.001));
    expect(sol.steps.length, equals(5));

    expect(sol.steps[2].simplifiedResultLatex, equals('4x^2 - 16x + 12'));
    expect(sol.steps[3].antiderivativeLatex, contains(r'\frac{4}{3}x^3'));
    expect(sol.steps[4].evaluatedLatex, contains(r'\frac{16}{3}'));

    // Check that there is NO A(x) placeholder anywhere
    for (final s in sol.steps) {
      expect(s.currentIntegrandLatex, isNot(equals('A(x)')));
      expect(s.stepIntegralLatex, isNot(contains(r'A(x)')));
      expect(s.antiderivativeLatex, isNot(contains(r'A(x)')));
    }
  });
}

(int, int) doubleToFraction(double val, {int maxDenom = 360}) {
  if (val.isNaN || val.isInfinite) return (0, 1);
  final isNeg = val < 0;
  final absVal = val.abs();
  for (int d = 1; d <= maxDenom; d++) {
    final n = (absVal * d).round();
    final err = (absVal - n / d).abs();
    if (err < 1e-6) {
      final g = gcd(n, d);
      return (isNeg ? -(n ~/ g) : (n ~/ g), d ~/ g);
    }
  }
  final rounded = absVal.round();
  return (isNeg ? -rounded : rounded, 1);
}

