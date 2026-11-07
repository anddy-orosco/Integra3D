import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modelo de tecla matemática individual.
class MathwayKey {
  final String label;          // Texto o glifo mostrado en la tecla
  final String insertText;     // Texto insertado en el controlador
  final int cursorOffset;      // Desplazamiento del cursor (-1 para meterse dentro de paréntesis)
  final bool isOrange;         // Teclas de acción naranja (abc, flechas, backspace, enter)
  final bool isSpecialGlyph;   // Si usa tipografía matemática serif
  final int flex;              // Proporción de ancho (1 por defecto, 2 para la barra espaciadora)
  final Color? customBgColor;
  final Color? customTextColor;

  const MathwayKey({
    required this.label,
    required this.insertText,
    this.cursorOffset = 0,
    this.isOrange = false,
    this.isSpecialGlyph = false,
    this.flex = 1,
    this.customBgColor,
    this.customTextColor,
  });
}

/// Teclado virtual idéntico a Mathway con soporte completo para cálculo multivariable:
/// - Páginas tabuladas: Álgebra & Cálculo (5x12), Multivariable & Diferenciales, Funciones & Trig, y Letras abc.
/// - Teclas dedicadas de diferenciales (dx, dy, dz, dy dx, dx dy, dz dy dx, r dr dθ).
/// - Navegación rápida entre ranuras (cuadritos) de límites e integrando.
class MathwayKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onEnter;
  final VoidCallback? onPrevSlot;
  final VoidCallback? onNextSlot;
  final VoidCallback? onClearSlot;
  final Function(String differential)? onDifferentialSelected;
  final Function(String template)? onSpecialTemplate;
  final VoidCallback? onSwitchToLetters;

  const MathwayKeyboard({
    super.key,
    required this.controller,
    this.onEnter,
    this.onPrevSlot,
    this.onNextSlot,
    this.onClearSlot,
    this.onDifferentialSelected,
    this.onSpecialTemplate,
    this.onSwitchToLetters,
  });

  @override
  State<MathwayKeyboard> createState() => _MathwayKeyboardState();
}

class _MathwayKeyboardState extends State<MathwayKeyboard> {
  // 0: Álgebra (Mathway 5x12), 1: Multivariable & Diferenciales, 2: Funciones & Trig, 3: Letras abc
  int _activePage = 0;
  bool _isShiftCaps = false;

  // =========================================================================
  // PÁGINA 0: ÁLGEBRA Y CÁLCULO PRINCIPAL (LAYOUT MATHWAY 5x12 EXACTO)
  // =========================================================================

  // Fila 1 (12 teclas): Delimitadores, Raíces, Desigualdad, Sumatoria, Integrales y Función
  static const List<MathwayKey> p0Row1 = [
    MathwayKey(label: '(', insertText: '(', isSpecialGlyph: true),
    MathwayKey(label: ')', insertText: ')', isSpecialGlyph: true),
    MathwayKey(label: '|', insertText: 'abs()', cursorOffset: -1, isSpecialGlyph: true),
    MathwayKey(label: '[', insertText: '[', isSpecialGlyph: true),
    MathwayKey(label: ']', insertText: ']', isSpecialGlyph: true),
    MathwayKey(label: '√', insertText: 'sqrt()', cursorOffset: -1, isSpecialGlyph: true),
    MathwayKey(label: 'ⁿ√', insertText: '()^(1/)', cursorOffset: -1, isSpecialGlyph: true),
    MathwayKey(label: '≥', insertText: '>=', isSpecialGlyph: true),
    MathwayKey(label: '∑', insertText: 'sum()', cursorOffset: -1, isSpecialGlyph: true),
    MathwayKey(label: '∫', insertText: 'int ', isSpecialGlyph: true),
    MathwayKey(label: '∫ₐᵇ', insertText: '__INTEGRAL_LAYER__', isSpecialGlyph: true),
    MathwayKey(label: 'f(x)', insertText: 'f(x)', isSpecialGlyph: true),
  ];

  // Fila 2 (12 teclas): Variable x, 7 8 9, Fracción, Potencia, Subíndice, Desigualdad, Trig, Grados, θ, e
  static const List<MathwayKey> p0Row2 = [
    MathwayKey(label: 'x', insertText: 'x', isSpecialGlyph: true),
    MathwayKey(label: '7', insertText: '7'),
    MathwayKey(label: '8', insertText: '8'),
    MathwayKey(label: '9', insertText: '9'),
    MathwayKey(label: '■/■', insertText: '/', isSpecialGlyph: true),
    MathwayKey(label: '■²', insertText: '^2', isSpecialGlyph: true),
    MathwayKey(label: '■_■', insertText: '_', isSpecialGlyph: true),
    MathwayKey(label: '≤', insertText: '<=', isSpecialGlyph: true),
    MathwayKey(label: 'sincos', insertText: '__SWITCH_TO_TRIG__', isSpecialGlyph: true),
    MathwayKey(label: '°', insertText: '°', isSpecialGlyph: true),
    MathwayKey(label: 'θ', insertText: 'theta', isSpecialGlyph: true),
    MathwayKey(label: 'e', insertText: 'e', isSpecialGlyph: true),
  ];

  // Fila 3 (12 teclas): Variable y, 4 5 6, División, Caret, Multiplicación, Mayor que, i, π, log, log_b
  static const List<MathwayKey> p0Row3 = [
    MathwayKey(label: 'y', insertText: 'y', isSpecialGlyph: true),
    MathwayKey(label: '4', insertText: '4'),
    MathwayKey(label: '5', insertText: '5'),
    MathwayKey(label: '6', insertText: '6'),
    MathwayKey(label: '/', insertText: '/'),
    MathwayKey(label: '^', insertText: '^'),
    MathwayKey(label: '×', insertText: '*'),
    MathwayKey(label: '>', insertText: '>'),
    MathwayKey(label: 'i', insertText: 'i', isSpecialGlyph: true),
    MathwayKey(label: 'π', insertText: 'pi', isSpecialGlyph: true),
    MathwayKey(label: 'log', insertText: 'log()', cursorOffset: -1, isSpecialGlyph: true),
    MathwayKey(label: 'log_■', insertText: 'log(, )', cursorOffset: -3, isSpecialGlyph: true),
  ];

  // Fila 4 (12 teclas): Variable z, 1 2 3, Menos, Más, División, Menor que, Límite, Infinito, ln, Factorial
  static const List<MathwayKey> p0Row4 = [
    MathwayKey(label: 'z', insertText: 'z', isSpecialGlyph: true),
    MathwayKey(label: '1', insertText: '1'),
    MathwayKey(label: '2', insertText: '2'),
    MathwayKey(label: '3', insertText: '3'),
    MathwayKey(label: '−', insertText: '-'),
    MathwayKey(label: '+', insertText: '+'),
    MathwayKey(label: '÷', insertText: '/'),
    MathwayKey(label: '<', insertText: '<'),
    MathwayKey(label: 'lim', insertText: 'lim()', cursorOffset: -1, isSpecialGlyph: true),
    MathwayKey(label: '∞', insertText: 'oo', isSpecialGlyph: true),
    MathwayKey(label: 'ln', insertText: 'ln()', cursorOffset: -1, isSpecialGlyph: true),
    MathwayKey(label: '!', insertText: '!'),
  ];

  // Fila 5 (11 teclas con barra espaciadora flex 2 = 12 columnas exactas)
  static const List<MathwayKey> p0Row5 = [
    MathwayKey(label: 'abc', insertText: '__ABC__', isOrange: true, flex: 1),
    MathwayKey(label: ',', insertText: ', ', flex: 1),
    MathwayKey(label: '0', insertText: '0', flex: 1),
    MathwayKey(label: '.', insertText: '.', flex: 1),
    MathwayKey(label: '%', insertText: '%', flex: 1),
    MathwayKey(label: '␣', insertText: ' ', flex: 2),
    MathwayKey(label: '=', insertText: '=', flex: 1),
    MathwayKey(label: '◀', insertText: '__LEFT__', isOrange: true, flex: 1),
    MathwayKey(label: '▶', insertText: '__RIGHT__', isOrange: true, flex: 1),
    MathwayKey(label: '⌫', insertText: '__BACKSPACE__', isOrange: true, flex: 1),
    MathwayKey(label: '⏎', insertText: '__ENTER__', isOrange: true, flex: 1),
  ];

  // =========================================================================
  // PÁGINA 1: MULTIVARIABLE Y DIFERENCIALES (ESPECIALIZADA EN INTEGRALES MÚLTIPLES)
  // =========================================================================

  static const List<MathwayKey> p1Row1 = [
    MathwayKey(label: '∬', insertText: '__TEMPLATE_DOUBLE__', isSpecialGlyph: true),
    MathwayKey(label: '∭', insertText: '__TEMPLATE_TRIPLE__', isSpecialGlyph: true),
    MathwayKey(label: '∮', insertText: 'oint ', isSpecialGlyph: true),
    MathwayKey(label: '∇', insertText: 'grad()', cursorOffset: -1, isSpecialGlyph: true),
    MathwayKey(label: '∂/∂x', insertText: 'diff(f, x)', isSpecialGlyph: true),
    MathwayKey(label: '∂/∂y', insertText: 'diff(f, y)', isSpecialGlyph: true),
    MathwayKey(label: '∂/∂z', insertText: 'diff(f, z)', isSpecialGlyph: true),
    MathwayKey(label: 'dx', insertText: '__DIF_dx__', isSpecialGlyph: true),
    MathwayKey(label: 'dy', insertText: '__DIF_dy__', isSpecialGlyph: true),
    MathwayKey(label: 'dz', insertText: '__DIF_dz__', isSpecialGlyph: true),
    MathwayKey(label: 'dr', insertText: '__DIF_dr__', isSpecialGlyph: true),
    MathwayKey(label: 'dθ', insertText: '__DIF_dtheta__', isSpecialGlyph: true),
  ];

  static const List<MathwayKey> p1Row2 = [
    MathwayKey(label: 'dy dx', insertText: '__ORDER_dy_dx__', isSpecialGlyph: true, flex: 2),
    MathwayKey(label: 'dx dy', insertText: '__ORDER_dx_dy__', isSpecialGlyph: true, flex: 2),
    MathwayKey(label: 'dz dy dx', insertText: '__ORDER_dz_dy_dx__', isSpecialGlyph: true, flex: 2),
    MathwayKey(label: 'r dr dθ', insertText: '__ORDER_r_dr_dtheta__', isSpecialGlyph: true, flex: 2),
    MathwayKey(label: 'dφ', insertText: '__DIF_dphi__', isSpecialGlyph: true, flex: 1),
    MathwayKey(label: 'ρ² sin φ', insertText: 'rho^2 * sin(phi)', isSpecialGlyph: true, flex: 2),
    MathwayKey(label: 'dρ', insertText: '__DIF_drho__', isSpecialGlyph: true, flex: 1),
  ];

  static const List<MathwayKey> p1Row3 = [
    MathwayKey(label: 'x²+y²', insertText: 'x^2 + y^2', flex: 2),
    MathwayKey(label: 'x²+y²+z²', insertText: 'x^2 + y^2 + z^2', flex: 2),
    MathwayKey(label: '√(4−x²)', insertText: 'sqrt(4 - x^2)', flex: 2),
    MathwayKey(label: '√(a²−x²)', insertText: 'sqrt(a^2 - x^2)', flex: 2),
    MathwayKey(label: '1−x', insertText: '1 - x', flex: 2),
    MathwayKey(label: '3y−5', insertText: '3*y - 5', flex: 2),
  ];

  static const List<MathwayKey> p1Row4 = [
    MathwayKey(label: 'r', insertText: 'r', isSpecialGlyph: true),
    MathwayKey(label: 'θ', insertText: 'theta', isSpecialGlyph: true),
    MathwayKey(label: 'φ', insertText: 'phi', isSpecialGlyph: true),
    MathwayKey(label: 'ρ', insertText: 'rho', isSpecialGlyph: true),
    MathwayKey(label: 'u', insertText: 'u', isSpecialGlyph: true),
    MathwayKey(label: 'v', insertText: 'v', isSpecialGlyph: true),
    MathwayKey(label: 'w', insertText: 'w', isSpecialGlyph: true),
    MathwayKey(label: 'R', insertText: 'R', isSpecialGlyph: true),
    MathwayKey(label: 'e^{-(x²+y²)}', insertText: 'exp(-(x^2 + y^2))', flex: 2),
    MathwayKey(label: 'xy²', insertText: 'x * y^2', flex: 2),
  ];

  static const List<MathwayKey> p1Row5 = [
    MathwayKey(label: '123', insertText: '__PAGE_0__', isOrange: true, flex: 1),
    MathwayKey(label: '(', insertText: '(', flex: 1),
    MathwayKey(label: ')', insertText: ')', flex: 1),
    MathwayKey(label: 'x²', insertText: '^2', flex: 1),
    MathwayKey(label: '√x', insertText: 'sqrt()', cursorOffset: -1, flex: 2),
    MathwayKey(label: '⇄ dy/dx', insertText: '__SWAP_DIFFERENTIAL__', isOrange: true, flex: 2),
    MathwayKey(label: '◀', insertText: '__LEFT__', isOrange: true, flex: 1),
    MathwayKey(label: '▶', insertText: '__RIGHT__', isOrange: true, flex: 1),
    MathwayKey(label: '⌫', insertText: '__BACKSPACE__', isOrange: true, flex: 1),
    MathwayKey(label: '⏎', insertText: '__ENTER__', isOrange: true, flex: 1),
  ];

  // =========================================================================
  // PÁGINA 2: TRIGONOMETRÍA Y FUNCIONES TRASCENDENTES
  // =========================================================================

  static const List<MathwayKey> p2Row1 = [
    MathwayKey(label: 'sin', insertText: 'sin()', cursorOffset: -1),
    MathwayKey(label: 'cos', insertText: 'cos()', cursorOffset: -1),
    MathwayKey(label: 'tan', insertText: 'tan()', cursorOffset: -1),
    MathwayKey(label: 'sec', insertText: 'sec()', cursorOffset: -1),
    MathwayKey(label: 'csc', insertText: 'csc()', cursorOffset: -1),
    MathwayKey(label: 'cot', insertText: 'cot()', cursorOffset: -1),
    MathwayKey(label: 'sin²', insertText: 'sin()^2', cursorOffset: -3),
    MathwayKey(label: 'cos²', insertText: 'cos()^2', cursorOffset: -3),
    MathwayKey(label: 'tan²', insertText: 'tan()^2', cursorOffset: -3),
    MathwayKey(label: 'sec²', insertText: 'sec()^2', cursorOffset: -3),
    MathwayKey(label: 'π', insertText: 'pi', isSpecialGlyph: true),
    MathwayKey(label: 'θ', insertText: 'theta', isSpecialGlyph: true),
  ];

  static const List<MathwayKey> p2Row2 = [
    MathwayKey(label: 'sin⁻¹', insertText: 'asin()', cursorOffset: -1),
    MathwayKey(label: 'cos⁻¹', insertText: 'acos()', cursorOffset: -1),
    MathwayKey(label: 'tan⁻¹', insertText: 'atan()', cursorOffset: -1),
    MathwayKey(label: 'sec⁻¹', insertText: 'asec()', cursorOffset: -1),
    MathwayKey(label: 'sinh', insertText: 'sinh()', cursorOffset: -1),
    MathwayKey(label: 'cosh', insertText: 'cosh()', cursorOffset: -1),
    MathwayKey(label: 'tanh', insertText: 'tanh()', cursorOffset: -1),
    MathwayKey(label: 'eˣ', insertText: 'exp()', cursorOffset: -1),
    MathwayKey(label: 'ln', insertText: 'ln()', cursorOffset: -1),
    MathwayKey(label: 'log', insertText: 'log()', cursorOffset: -1),
    MathwayKey(label: '2π', insertText: '2*pi'),
    MathwayKey(label: 'π/2', insertText: 'pi/2'),
  ];

  static const List<MathwayKey> p2Row3 = [
    MathwayKey(label: '|x|', insertText: 'abs()', cursorOffset: -1),
    MathwayKey(label: 'eˣ', insertText: 'exp(x)'),
    MathwayKey(label: '10ˣ', insertText: '10^()', cursorOffset: -1),
    MathwayKey(label: '√', insertText: 'sqrt()', cursorOffset: -1),
    MathwayKey(label: 'x', insertText: 'x', isSpecialGlyph: true),
    MathwayKey(label: 'y', insertText: 'y', isSpecialGlyph: true),
    MathwayKey(label: 'z', insertText: 'z', isSpecialGlyph: true),
    MathwayKey(label: 'r', insertText: 'r', isSpecialGlyph: true),
    MathwayKey(label: '(', insertText: '('),
    MathwayKey(label: ')', insertText: ')'),
    MathwayKey(label: '/', insertText: '/'),
    MathwayKey(label: '^', insertText: '^'),
  ];

  static const List<MathwayKey> p2Row4 = [
    MathwayKey(label: '7', insertText: '7'),
    MathwayKey(label: '8', insertText: '8'),
    MathwayKey(label: '9', insertText: '9'),
    MathwayKey(label: '4', insertText: '4'),
    MathwayKey(label: '5', insertText: '5'),
    MathwayKey(label: '6', insertText: '6'),
    MathwayKey(label: '1', insertText: '1'),
    MathwayKey(label: '2', insertText: '2'),
    MathwayKey(label: '3', insertText: '3'),
    MathwayKey(label: '0', insertText: '0'),
    MathwayKey(label: '+', insertText: '+'),
    MathwayKey(label: '−', insertText: '-'),
  ];

  static const List<MathwayKey> p2Row5 = [
    MathwayKey(label: '123', insertText: '__PAGE_0__', isOrange: true, flex: 2),
    MathwayKey(label: '.', insertText: '.', flex: 1),
    MathwayKey(label: '␣', insertText: ' ', flex: 3),
    MathwayKey(label: '◀', insertText: '__LEFT__', isOrange: true, flex: 1),
    MathwayKey(label: '▶', insertText: '__RIGHT__', isOrange: true, flex: 1),
    MathwayKey(label: '⌫', insertText: '__BACKSPACE__', isOrange: true, flex: 2),
    MathwayKey(label: '⏎', insertText: '__ENTER__', isOrange: true, flex: 2),
  ];

  // =========================================================================
  // PÁGINA 3: ALFABETO COMPLETO (abc LETRAS PARA PARÁMETROS Y VARIABLES)
  // =========================================================================

  List<List<MathwayKey>> _buildAlphaRows() {
    final shift = _isShiftCaps;
    String c(String char) => shift ? char.toUpperCase() : char.toLowerCase();

    return [
      [
        MathwayKey(label: c('q'), insertText: c('q')),
        MathwayKey(label: c('w'), insertText: c('w')),
        MathwayKey(label: c('e'), insertText: c('e')),
        MathwayKey(label: c('r'), insertText: c('r')),
        MathwayKey(label: c('t'), insertText: c('t')),
        MathwayKey(label: c('y'), insertText: c('y')),
        MathwayKey(label: c('u'), insertText: c('u')),
        MathwayKey(label: c('i'), insertText: c('i')),
        MathwayKey(label: c('o'), insertText: c('o')),
        MathwayKey(label: c('p'), insertText: c('p')),
      ],
      [
        MathwayKey(label: c('a'), insertText: c('a')),
        MathwayKey(label: c('s'), insertText: c('s')),
        MathwayKey(label: c('d'), insertText: c('d')),
        MathwayKey(label: c('f'), insertText: c('f')),
        MathwayKey(label: c('g'), insertText: c('g')),
        MathwayKey(label: c('h'), insertText: c('h')),
        MathwayKey(label: c('j'), insertText: c('j')),
        MathwayKey(label: c('k'), insertText: c('k')),
        MathwayKey(label: c('l'), insertText: c('l')),
      ],
      [
        MathwayKey(label: '⇧', insertText: '__SHIFT__', isOrange: true, flex: 1),
        MathwayKey(label: c('z'), insertText: c('z')),
        MathwayKey(label: c('x'), insertText: c('x')),
        MathwayKey(label: c('c'), insertText: c('c')),
        MathwayKey(label: c('v'), insertText: c('v')),
        MathwayKey(label: c('b'), insertText: c('b')),
        MathwayKey(label: c('n'), insertText: c('n')),
        MathwayKey(label: c('m'), insertText: c('m')),
        MathwayKey(label: '⌫', insertText: '__BACKSPACE__', isOrange: true, flex: 1),
      ],
      [
        MathwayKey(label: '123', insertText: '__PAGE_0__', isOrange: true, flex: 2),
        MathwayKey(label: ',', insertText: ', ', flex: 1),
        MathwayKey(label: '␣ Espacio', insertText: ' ', flex: 4),
        MathwayKey(label: '.', insertText: '.', flex: 1),
        MathwayKey(label: '◀', insertText: '__LEFT__', isOrange: true, flex: 1),
        MathwayKey(label: '▶', insertText: '__RIGHT__', isOrange: true, flex: 1),
        MathwayKey(label: '⏎', insertText: '__ENTER__', isOrange: true, flex: 2),
      ],
    ];
  }

  // =========================================================================
  // MANEJO DE PULSACIONES DE TECLAS
  // =========================================================================

  void _handleKeyPress(MathwayKey key) {
    HapticFeedback.lightImpact();

    // 1. Acciones de Navegación de Páginas
    if (key.insertText == '__PAGE_0__') {
      setState(() => _activePage = 0);
      return;
    }
    if (key.insertText == '__ABC__') {
      setState(() => _activePage = 3);
      widget.onSwitchToLetters?.call();
      return;
    }
    if (key.insertText == '__SWITCH_TO_TRIG__') {
      setState(() => _activePage = 2);
      return;
    }
    if (key.insertText == '__SHIFT__') {
      setState(() => _isShiftCaps = !_isShiftCaps);
      return;
    }

    // 2. Acciones del Formulario Matemático
    if (key.insertText == '__ENTER__') {
      widget.onEnter?.call();
      return;
    }

    if (key.insertText == '__INTEGRAL_LAYER__' || key.insertText == '__TEMPLATE_DOUBLE__') {
      widget.onSpecialTemplate?.call('double_integral');
      return;
    }

    if (key.insertText == '__TEMPLATE_TRIPLE__') {
      widget.onSpecialTemplate?.call('triple_integral');
      return;
    }

    if (key.insertText == '__SWAP_DIFFERENTIAL__') {
      widget.onSpecialTemplate?.call('swap_differential');
      return;
    }

    // 3. Diferenciales específicos
    if (key.insertText.startsWith('__DIF_')) {
      final dif = key.insertText.replaceFirst('__DIF_', '').replaceFirst('__', '');
      widget.onDifferentialSelected?.call(dif);
      return;
    }

    if (key.insertText.startsWith('__ORDER_')) {
      final order = key.label; // e.g. "dy dx", "dx dy", "dz dy dx", "r dr dθ"
      widget.onDifferentialSelected?.call(order);
      return;
    }

    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0) {
      start = text.length;
      end = text.length;
    }

    // Backspace
    if (key.insertText == '__BACKSPACE__') {
      if (start != end) {
        final newText = text.replaceRange(start, end, '');
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start),
        );
      } else if (start > 0) {
        final newText = text.replaceRange(start - 1, start, '');
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start - 1),
        );
      }
      return;
    }

    // Cursor Izquierda (Navegación carácter a carácter dentro de funciones)
    if (key.insertText == '__LEFT__') {
      if (start > 0) {
        controller.selection = TextSelection.collapsed(offset: start - 1);
      }
      return;
    }

    // Cursor Derecha (Navegación carácter a carácter y salida de argumentos)
    if (key.insertText == '__RIGHT__') {
      if (end < text.length) {
        controller.selection = TextSelection.collapsed(offset: end + 1);
      }
      return;
    }

    // Inserción de texto matemático en el controlador
    final newText = text.replaceRange(start, end, key.insertText);
    final targetPos = start + key.insertText.length + key.cursorOffset;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: targetPos.clamp(0, newText.length)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const activeOrange = Color(0xFFE65100);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // Slate 100 claro idéntico a Mathway
        border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de Pestañas Superiores del Teclado (Desplazable horizontalmente para móvil)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildPageTab(0, '123 Álgebra', Icons.calculate_outlined),
                  const SizedBox(width: 4),
                  _buildPageTab(1, '∬ Multivariable & Dif', Icons.all_inclusive_rounded),
                  const SizedBox(width: 4),
                  _buildPageTab(2, 'sin Trigo', Icons.functions_rounded),
                  const SizedBox(width: 4),
                  _buildPageTab(3, 'abc Letras', Icons.text_fields_rounded),
                  const SizedBox(width: 10),

                  // Botones rápidos de salto entre ranuras (cuadritos)
                  if (widget.onPrevSlot != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF475569)),
                      tooltip: 'Ranura anterior',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: widget.onPrevSlot,
                    ),
                  if (widget.onNextSlot != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF475569)),
                      tooltip: 'Siguiente ranura',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: widget.onNextSlot,
                    ),
                  if (widget.onClearSlot != null)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: activeOrange),
                      tooltip: 'Limpiar cuadrito actual',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: widget.onClearSlot,
                    ),
                ],
              ),
            ),
          ),

          // Grilla de Teclas de la Página Activa
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: _buildCurrentPageLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPageLayout() {
    switch (_activePage) {
      case 0:
        return Column(
          children: [
            _buildRow(p0Row1),
            const SizedBox(height: 3),
            _buildRow(p0Row2),
            const SizedBox(height: 3),
            _buildRow(p0Row3),
            const SizedBox(height: 3),
            _buildRow(p0Row4),
            const SizedBox(height: 3),
            _buildRow(p0Row5),
          ],
        );
      case 1:
        return Column(
          children: [
            _buildRow(p1Row1),
            const SizedBox(height: 3),
            _buildRow(p1Row2),
            const SizedBox(height: 3),
            _buildRow(p1Row3),
            const SizedBox(height: 3),
            _buildRow(p1Row4),
            const SizedBox(height: 3),
            _buildRow(p1Row5),
          ],
        );
      case 2:
        return Column(
          children: [
            _buildRow(p2Row1),
            const SizedBox(height: 3),
            _buildRow(p2Row2),
            const SizedBox(height: 3),
            _buildRow(p2Row3),
            const SizedBox(height: 3),
            _buildRow(p2Row4),
            const SizedBox(height: 3),
            _buildRow(p2Row5),
          ],
        );
      case 3:
      default:
        final alphaRows = _buildAlphaRows();
        return Column(
          children: alphaRows.map((r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 3.0),
              child: _buildRow(r),
            );
          }).toList(),
        );
    }
  }

  Widget _buildPageTab(int pageIndex, String label, IconData icon) {
    final isSelected = _activePage == pageIndex;
    const activeOrange = Color(0xFFE65100);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _activePage = pageIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? Border.all(color: activeOrange, width: 1.2) : null,
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? activeOrange : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeOrange : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<MathwayKey> row) {
    return Row(
      children: row.map((key) {
        return Expanded(
          flex: key.flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _buildKeyWidget(key),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyWidget(MathwayKey key) {
    const orangeColor = Color(0xFFE65100);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _handleKeyPress(key),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: key.isOrange ? orangeColor : (key.customBgColor ?? Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: key.isOrange ? orangeColor : const Color(0xFFCBD5E1),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            key.label,
            style: TextStyle(
              fontSize: key.label.length > 3 ? 10 : 15,
              fontWeight: key.isOrange ? FontWeight.bold : FontWeight.w500,
              fontFamily: key.isSpecialGlyph ? 'Times New Roman' : null,
              fontStyle: key.isSpecialGlyph ? FontStyle.italic : FontStyle.normal,
              color: key.isOrange ? Colors.white : (key.customTextColor ?? const Color(0xFF1E293B)),
            ),
          ),
        ),
      ),
    );
  }
}
