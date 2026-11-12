/// Sanitizador y corrector automático de sintaxis LaTeX para renderizado con flutter_math_fork.
/// Corrige dobles exponentes, delimitadores no balanceados, redundancias de coeficientes y
/// símbolos de programación crudos para garantizar que el usuario SIEMPRE vea tipografía matemática impecable.
class LatexSanitizer {
  /// Sanitiza y normaliza una cadena LaTeX antes de ser parseada por Math.tex.
  static String sanitize(String latex) {
    if (latex.trim().isEmpty) return '';
    var s = latex.trim();

    // 1. Corregir dobles operadores de igualdad / aproximación
    s = s.replaceAll(RegExp(r'=\s*\\approx'), r'\approx');
    s = s.replaceAll(RegExp(r'=\s*~'), r'\approx');
    s = s.replaceAll(RegExp(r'==+'), '=');

    // 2. Corregir exponentes exponenciales rotos: e^ x^{2} -> e^{x^2}, e^ y -> e^y
    s = s.replaceAllMapped(
      RegExp(r'e\^\s*([a-zA-Z0-9]+)\^\{?([0-9a-zA-Z]+)\}?'),
      (m) => 'e^{${m.group(1)}^{${m.group(2)}}}',
    );
    s = s.replaceAllMapped(
      RegExp(r'e\^\s*([a-zA-Z0-9]+)'),
      (m) => 'e^{${m.group(1)}}',
    );

    // 3. Corregir dobles superíndices consecutivos: x^2^3 -> x^{2^3}
    s = s.replaceAllMapped(
      RegExp(r'([a-zA-Z0-9\)\}])\^([a-zA-Z0-9]+)\^\{?([0-9a-zA-Z]+)\}?'),
      (m) => '${m.group(1)}^{${m.group(2)}^{${m.group(3)}}}',
    );

    // 4. Eliminar coeficiente '1 ' redundante en numeradores de fracciones (\frac{1 y^2 -> \frac{y^2)
    s = s.replaceAllMapped(
      RegExp(r'\\frac\{\s*1\s+([a-zA-Z])'),
      (m) => '\\frac{${m.group(1)}',
    );

    // 5. Corregir asteriscos de programación (* o **)
    s = s.replaceAll(r'**', '^');
    s = s.replaceAll(r'\*', ' ');
    s = s.replaceAll('*', ' ');

    // 6. Balancear delimitadores \left y \right
    s = _balanceDelimiters(s);

    // 7. Normalizar espacios múltiples
    s = s.replaceAll(RegExp(r'\s+'), ' ');

    return s.trim();
  }

  /// Asegura que cada \left tenga su correspondiente \right en LaTeX.
  static String _balanceDelimiters(String input) {
    final leftMatches = RegExp(r'\\left[\(\[\.\{\|\\]').allMatches(input).length;
    final rightMatches = RegExp(r'\\right[\)\]\.\}\|\\]').allMatches(input).length;

    if (leftMatches == rightMatches) return input;

    var balanced = input;
    if (leftMatches > rightMatches) {
      final diff = leftMatches - rightMatches;
      balanced += List.filled(diff, r'\right.').join(' ');
    } else if (rightMatches > leftMatches) {
      final diff = rightMatches - leftMatches;
      balanced = '${List.filled(diff, r"\left.").join(" ")} $balanced';
    }
    return balanced;
  }

  /// Convierte una expresión LaTeX a formato textual amigable con caracteres Unicode (∫, ², √, etc.)
  /// para casos de fallo extremo en el parser de KaTeX.
  static String toReadableUnicode(String latex) {
    var s = latex
        .replaceAll(r'\int', '∫')
        .replaceAll(r'\iint', '∬')
        .replaceAll(r'\iiint', '∭')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\le', '≤')
        .replaceAll(r'\ge', '≥')
        .replaceAll(r'\ne', '≠')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\mp', '∓')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\div', '÷')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\phi', 'φ')
        .replaceAll(r'\rho', 'ρ')
        .replaceAll(r'\sqrt', '√')
        .replaceAll(r'\,', ' ')
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '')
        .replaceAll(r'\text', '')
        .replaceAll(r'\frac', '');

    // Reemplazar superíndices comunes
    s = s
        .replaceAll('^2', '²')
        .replaceAll('^{2}', '²')
        .replaceAll('^3', '³')
        .replaceAll('^{3}', '³')
        .replaceAll('^4', '⁴')
        .replaceAll('^5', '⁵')
        .replaceAll('^6', '⁶');

    // Limpiar llaves sobrantes
    s = s.replaceAll('{', '(').replaceAll('}', ')');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}
