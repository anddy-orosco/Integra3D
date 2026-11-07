import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:integra_3d/core/theme/app_colors.dart';

/// Modelo de tecla matemática con símbolo visual y texto a insertar.
class MathKeyItem {
  final String label;          // Texto o símbolo que se muestra en la tecla
  final String insertText;     // Cadena que se inserta en el TextEditingController
  final int cursorOffset;      // Desplazamiento del cursor relativo al final del texto insertado
  final bool isVariable;       // Si es variable (x, y, z, r, theta, etc.)
  final bool isAction;         // Si es acción (backspace, flechas, cerrar)
  final bool isOperator;       // Si es operador (+, -, *, /, ^, etc.)

  const MathKeyItem({
    required this.label,
    required this.insertText,
    this.cursorOffset = 0,
    this.isVariable = false,
    this.isAction = false,
    this.isOperator = false,
  });
}

/// Teclado matemático táctil especializado para cálculo multivariable (Mathway/Desmos style).
/// Permite ingresar símbolos que son difíciles o poco intuitivos de escribir a mano
/// como raíces cuadradas, potencias, diferenciales e integrales iteradas.
class MathKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onClose;
  final VoidCallback? onSubmit;

  const MathKeyboard({
    super.key,
    required this.controller,
    this.onClose,
    this.onSubmit,
  });

  @override
  State<MathKeyboard> createState() => _MathKeyboardState();
}

class _MathKeyboardState extends State<MathKeyboard> {
  int _activeCategory = 0; // 0: Álgebra & Números, 1: Integrales & Multivariable, 2: Funciones & Trigo

  // 1. Teclas de Álgebra y Aritmética
  static const List<List<MathKeyItem>> algebraLayout = [
    [
      MathKeyItem(label: '(', insertText: '(', isOperator: true),
      MathKeyItem(label: ')', insertText: ')', isOperator: true),
      MathKeyItem(label: '√x', insertText: 'sqrt()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'x²', insertText: '^2', isOperator: true),
      MathKeyItem(label: 'xⁿ', insertText: '^()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'a/b', insertText: '/()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'π', insertText: 'pi', isVariable: true),
      MathKeyItem(label: 'e', insertText: 'E', isVariable: true),
    ],
    [
      MathKeyItem(label: 'x', insertText: 'x', isVariable: true),
      MathKeyItem(label: '7', insertText: '7'),
      MathKeyItem(label: '8', insertText: '8'),
      MathKeyItem(label: '9', insertText: '9'),
      MathKeyItem(label: '×', insertText: '*', isOperator: true),
      MathKeyItem(label: '÷', insertText: '/', isOperator: true),
      MathKeyItem(label: 'ln', insertText: 'ln()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'exp', insertText: 'exp()', cursorOffset: -1, isOperator: true),
    ],
    [
      MathKeyItem(label: 'y', insertText: 'y', isVariable: true),
      MathKeyItem(label: '4', insertText: '4'),
      MathKeyItem(label: '5', insertText: '5'),
      MathKeyItem(label: '6', insertText: '6'),
      MathKeyItem(label: '+', insertText: '+', isOperator: true),
      MathKeyItem(label: '−', insertText: '-', isOperator: true),
      MathKeyItem(label: '=', insertText: '=', isOperator: true),
      MathKeyItem(label: '∞', insertText: 'oo', isOperator: true),
    ],
    [
      MathKeyItem(label: 'z', insertText: 'z', isVariable: true),
      MathKeyItem(label: '1', insertText: '1'),
      MathKeyItem(label: '2', insertText: '2'),
      MathKeyItem(label: '3', insertText: '3'),
      MathKeyItem(label: '0', insertText: '0'),
      MathKeyItem(label: '.', insertText: '.'),
      MathKeyItem(label: '←', insertText: '__LEFT__', isAction: true),
      MathKeyItem(label: '→', insertText: '__RIGHT__', isAction: true),
      MathKeyItem(label: '⌫', insertText: '__BACKSPACE__', isAction: true),
    ],
  ];

  // 2. Teclas específicas para Cálculo Multivariable e Integrales
  static const List<List<MathKeyItem>> calculusLayout = [
    [
      MathKeyItem(label: '∬', insertText: '', isOperator: true),
      MathKeyItem(label: '∭', insertText: '', isOperator: true),
      MathKeyItem(label: 'dx', insertText: 'dx', isVariable: true),
      MathKeyItem(label: 'dy', insertText: 'dy', isVariable: true),
      MathKeyItem(label: 'dz', insertText: 'dz', isVariable: true),
      MathKeyItem(label: 'r dr', insertText: 'r', isVariable: true),
      MathKeyItem(label: 'dθ', insertText: 'theta', isVariable: true),
      MathKeyItem(label: 'dφ', insertText: 'phi', isVariable: true),
    ],
    [
      MathKeyItem(label: '√(a²−x²)', insertText: 'sqrt(4 - x^2)', isOperator: true),
      MathKeyItem(label: 'x²+y²', insertText: 'x^2 + y^2', isOperator: true),
      MathKeyItem(label: '4−x²−y²', insertText: '4 - x^2 - y^2', isOperator: true),
      MathKeyItem(label: 'r²', insertText: 'r^2', isOperator: true),
      MathKeyItem(label: 'ρ²sin(φ)', insertText: 'rho^2 * sin(phi)', isOperator: true),
      MathKeyItem(label: '1−x−y', insertText: '1 - x - y', isOperator: true),
    ],
    [
      MathKeyItem(label: 'r', insertText: 'r', isVariable: true),
      MathKeyItem(label: 'θ', insertText: 'theta', isVariable: true),
      MathKeyItem(label: 'φ', insertText: 'phi', isVariable: true),
      MathKeyItem(label: 'ρ', insertText: 'rho', isVariable: true),
      MathKeyItem(label: '≤', insertText: '<=', isOperator: true),
      MathKeyItem(label: '≥', insertText: '>=', isOperator: true),
      MathKeyItem(label: '2π', insertText: '2*pi', isVariable: true),
      MathKeyItem(label: 'π/2', insertText: 'pi/2', isVariable: true),
    ],
    [
      MathKeyItem(label: '(', insertText: '(', isOperator: true),
      MathKeyItem(label: ')', insertText: ')', isOperator: true),
      MathKeyItem(label: '+', insertText: '+', isOperator: true),
      MathKeyItem(label: '−', insertText: '-', isOperator: true),
      MathKeyItem(label: '0', insertText: '0'),
      MathKeyItem(label: '←', insertText: '__LEFT__', isAction: true),
      MathKeyItem(label: '→', insertText: '__RIGHT__', isAction: true),
      MathKeyItem(label: '⌫', insertText: '__BACKSPACE__', isAction: true),
    ],
  ];

  // 3. Teclas de Funciones Trascendentes y Geometría
  static const List<List<MathKeyItem>> functionsLayout = [
    [
      MathKeyItem(label: 'sin', insertText: 'sin()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'cos', insertText: 'cos()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'tan', insertText: 'tan()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'sec', insertText: 'sec()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'csc', insertText: 'csc()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'cot', insertText: 'cot()', cursorOffset: -1, isOperator: true),
    ],
    [
      MathKeyItem(label: 'arcsin', insertText: 'asin()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'arccos', insertText: 'acos()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'arctan', insertText: 'atan()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'sinh', insertText: 'sinh()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'cosh', insertText: 'cosh()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'tanh', insertText: 'tanh()', cursorOffset: -1, isOperator: true),
    ],
    [
      MathKeyItem(label: 'ln(x)', insertText: 'ln()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'log₁₀', insertText: 'log()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: 'eˣ', insertText: 'exp()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: '|x|', insertText: 'abs()', cursorOffset: -1, isOperator: true),
      MathKeyItem(label: '∛x', insertText: '()^(1/3)', cursorOffset: -6, isOperator: true),
      MathKeyItem(label: 'x³', insertText: '^3', isOperator: true),
    ],
    [
      MathKeyItem(label: 'x', insertText: 'x', isVariable: true),
      MathKeyItem(label: 'y', insertText: 'y', isVariable: true),
      MathKeyItem(label: 'z', insertText: 'z', isVariable: true),
      MathKeyItem(label: '←', insertText: '__LEFT__', isAction: true),
      MathKeyItem(label: '→', insertText: '__RIGHT__', isAction: true),
      MathKeyItem(label: '⌫', insertText: '__BACKSPACE__', isAction: true),
    ],
  ];

  void _onKeyPress(MathKeyItem item) {
    HapticFeedback.lightImpact();
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    int start = selection.start;
    int end = selection.end;

    // Si no hay selección activa, posicionar al final
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    if (item.insertText == '__BACKSPACE__') {
      if (start != end) {
        // Borrar selección
        final newText = text.replaceRange(start, end, '');
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start),
        );
      } else if (start > 0) {
        // Borrar caracter anterior
        final newText = text.replaceRange(start - 1, start, '');
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start - 1),
        );
      }
      return;
    }

    if (item.insertText == '__LEFT__') {
      if (start > 0) {
        widget.controller.selection = TextSelection.collapsed(offset: start - 1);
      }
      return;
    }

    if (item.insertText == '__RIGHT__') {
      if (end < text.length) {
        widget.controller.selection = TextSelection.collapsed(offset: end + 1);
      }
      return;
    }

    // Inserción normal de texto matemático
    final newText = text.replaceRange(start, end, item.insertText);
    final targetPos = start + item.insertText.length + item.cursorOffset;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: targetPos.clamp(0, newText.length)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLayout = _activeCategory == 0
        ? algebraLayout
        : (_activeCategory == 1 ? calculusLayout : functionsLayout);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.slateDark, // #161B22
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.5), // #30363D
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Barra de Categorías / Tabs (Mathway Header Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: AppColors.deepVoid, // #0D1117
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
                _buildCategoryTab(0, 'Álgebra', Icons.calculate_outlined),
                const SizedBox(width: 6),
                _buildCategoryTab(1, 'Integrales', Icons.all_inclusive_rounded),
                const SizedBox(width: 6),
                _buildCategoryTab(2, 'Funciones', Icons.auto_graph_rounded),
                const Spacer(),

                // Botón Limpiar Todo
                IconButton(
                  icon: const Icon(Icons.clear_all_rounded, size: 20, color: AppColors.mutedGray),
                  tooltip: 'Borrar todo',
                  onPressed: () {
                    widget.controller.clear();
                  },
                ),

                // Botón Cerrar Teclado
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.keyboard_hide_rounded, size: 20, color: AppColors.electricCyan),
                    tooltip: 'Ocultar teclado',
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // 2. Grilla de Teclas Matemáticas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              children: currentLayout.map((row) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    children: row.map((keyItem) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5),
                          child: _buildKeyButton(keyItem),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(int index, String label, IconData icon) {
    final isSelected = _activeCategory == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _activeCategory = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.slateElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: AppColors.electricCyan.withAlpha(140)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.electricCyan : AppColors.mutedGray,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.pureWhite : AppColors.mutedGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyButton(MathKeyItem item) {
    Color bg = AppColors.slateElevated; // #21262D
    Color fg = AppColors.pureWhite;     // #F0F6FC
    Border border = Border.all(color: AppColors.borderSubtle);

    if (item.isVariable) {
      bg = AppColors.deepVoid;
      fg = AppColors.cyberEmerald; // #10B981
      border = Border.all(color: AppColors.cyberEmerald.withAlpha(60));
    } else if (item.isOperator) {
      bg = AppColors.slateDark;
      fg = AppColors.electricCyan;  // #06B6D4
    } else if (item.isAction) {
      bg = AppColors.deepVoid;
      fg = AppColors.amberGlow;    // #F59E0B
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => _onKeyPress(item),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            border: border,
          ),
          alignment: Alignment.center,
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: item.label.length > 3 ? 11 : 15,
              fontWeight: FontWeight.bold,
              fontFamily: item.isVariable ? 'serif' : null,
              fontStyle: item.isVariable ? FontStyle.italic : FontStyle.normal,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
