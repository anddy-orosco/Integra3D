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

  const MathwayKey({
    required this.label,
    required this.insertText,
    this.cursorOffset = 0,
    this.isOrange = false,
    this.isSpecialGlyph = false,
    this.flex = 1,
  });
}

/// Teclado virtual idéntico a Mathway (Image 1 y 2):
/// 5 filas y 12 columnas exactas con la botonera de cálculo y álgebra.
class MathwayKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onEnter;
  final VoidCallback? onSwitchToLetters;
  final Function(String)? onSpecialTemplate;

  const MathwayKeyboard({
    super.key,
    required this.controller,
    this.onEnter,
    this.onSwitchToLetters,
    this.onSpecialTemplate,
  });

  // Fila 1 (12 teclas): Delimitadores, Raíces, Desigualdad, Sumatoria, Integrales y Función
  static const List<MathwayKey> row1 = [
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
  static const List<MathwayKey> row2 = [
    MathwayKey(label: 'x', insertText: 'x', isSpecialGlyph: true),
    MathwayKey(label: '7', insertText: '7'),
    MathwayKey(label: '8', insertText: '8'),
    MathwayKey(label: '9', insertText: '9'),
    MathwayKey(label: '■/■', insertText: '/', isSpecialGlyph: true),
    MathwayKey(label: '■²', insertText: '^2', isSpecialGlyph: true),
    MathwayKey(label: '■_■', insertText: '_', isSpecialGlyph: true),
    MathwayKey(label: '≤', insertText: '<=', isSpecialGlyph: true),
    MathwayKey(label: 'sincos', insertText: 'sin()', cursorOffset: -1, isSpecialGlyph: true),
    MathwayKey(label: '°', insertText: '°', isSpecialGlyph: true),
    MathwayKey(label: 'θ', insertText: 'theta', isSpecialGlyph: true),
    MathwayKey(label: 'e', insertText: 'e', isSpecialGlyph: true),
  ];

  // Fila 3 (12 teclas): Variable y, 4 5 6, División, Caret, Multiplicación, Mayor que, i, π, log, log_b
  static const List<MathwayKey> row3 = [
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
  static const List<MathwayKey> row4 = [
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
  static const List<MathwayKey> row5 = [
    MathwayKey(label: 'abc', insertText: '__ABC__', isOrange: true, flex: 1),
    MathwayKey(label: ',', insertText: ', ', flex: 1),
    MathwayKey(label: '0', insertText: '0', flex: 1),
    MathwayKey(label: '.', insertText: '.', flex: 1),
    MathwayKey(label: '%', insertText: '%', flex: 1),
    MathwayKey(label: '␣', insertText: ' ', flex: 2), // Barra espaciadora proporcional
    MathwayKey(label: '=', insertText: '=', flex: 1),
    MathwayKey(label: '◀', insertText: '__LEFT__', isOrange: true, flex: 1),
    MathwayKey(label: '▶', insertText: '__RIGHT__', isOrange: true, flex: 1),
    MathwayKey(label: '⌫', insertText: '__BACKSPACE__', isOrange: true, flex: 1),
    MathwayKey(label: '⏎', insertText: '__ENTER__', isOrange: true, flex: 1),
  ];

  void _handleKeyPress(MathwayKey key) {
    HapticFeedback.lightImpact();

    if (key.insertText == '__ENTER__') {
      onEnter?.call();
      return;
    }

    if (key.insertText == '__ABC__') {
      onSwitchToLetters?.call();
      return;
    }

    if (key.insertText == '__INTEGRAL_LAYER__') {
      onSpecialTemplate?.call('double_integral');
      return;
    }

    final text = controller.text;
    final selection = controller.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

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

    if (key.insertText == '__LEFT__') {
      if (start > 0) {
        controller.selection = TextSelection.collapsed(offset: start - 1);
      }
      return;
    }

    if (key.insertText == '__RIGHT__') {
      if (end < text.length) {
        controller.selection = TextSelection.collapsed(offset: end + 1);
      }
      return;
    }

    // Inserción de texto
    final newText = text.replaceRange(start, end, key.insertText);
    final targetPos = start + key.insertText.length + key.cursorOffset;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: targetPos.clamp(0, newText.length)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // Slate 100 claro idéntico a Mathway
        border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(row1),
          const SizedBox(height: 4),
          _buildRow(row2),
          const SizedBox(height: 4),
          _buildRow(row3),
          const SizedBox(height: 4),
          _buildRow(row4),
          const SizedBox(height: 4),
          _buildRow(row5),
        ],
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
    // Naranja institucional idéntico a Mathway (#E65100 / #EA580C)
    const orangeColor = Color(0xFFE65100);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _handleKeyPress(key),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: key.isOrange ? orangeColor : Colors.white,
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
              fontSize: key.label.length > 2 ? 11 : 16,
              fontWeight: key.isOrange ? FontWeight.bold : FontWeight.w500,
              fontFamily: key.isSpecialGlyph ? 'Times New Roman' : null,
              fontStyle: key.isSpecialGlyph ? FontStyle.italic : FontStyle.normal,
              color: key.isOrange ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }
}
