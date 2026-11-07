import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/integration_bound.dart';
import '../../domain/entities/multivariable_integral.dart';
import '../../domain/services/integral_expression_transformer.dart';
import 'keyboard/math_keyboard.dart';

enum MathSlot {
  outerLower,
  outerUpper,
  midLower,
  midUpper,
  innerLower,
  innerUpper,
  integrand,
}

/// Información contextual del argumento o función donde se encuentra el cursor.
class ActiveArgumentInfo {
  final String functionName;
  final String displayLabel;
  final int openParenIndex;
  final int closeParenIndex;
  final int exitOffset;

  const ActiveArgumentInfo({
    required this.functionName,
    required this.displayLabel,
    required this.openParenIndex,
    required this.closeParenIndex,
    required this.exitOffset,
  });
}

/// Editor matemático interactivo unificado idéntico a Mathway (Image 1, 2 y 3).
/// Incorpora el sistema de "Cuadritos" interactivos [?] donde el usuario ve en todo momento
/// dónde está situado su cursor, soporte para diferenciales de cierre (dx, dy, dz, dy dx, dx dy, r dr dθ),
/// selector de dimensión (1D, 2D, 3D), sugerencias rápidas y el teclado multivariable de 4 páginas.
class MathwayFormulaEditor extends StatefulWidget {
  final MultivariableIntegral initialIntegral;
  final Function(MultivariableIntegral) onSolve;
  final VoidCallback? onCameraOcr;

  const MathwayFormulaEditor({
    super.key,
    required this.initialIntegral,
    required this.onSolve,
    this.onCameraOcr,
  });

  @override
  State<MathwayFormulaEditor> createState() => _MathwayFormulaEditorState();
}

class _MathwayFormulaEditorState extends State<MathwayFormulaEditor> {
  // Dimensión de la integral: 1 (Simple), 2 (Doble), 3 (Triple)
  int _dimension = 2;

  // Controladores de texto para cada cuadrito
  late TextEditingController _integrandCtrl;
  late TextEditingController _innerLowerCtrl;
  late TextEditingController _innerUpperCtrl;
  late TextEditingController _outerLowerCtrl;
  late TextEditingController _outerUpperCtrl;
  late TextEditingController _midLowerCtrl;
  late TextEditingController _midUpperCtrl;

  // Variables asociadas a los diferenciales
  String _outerVar = 'x';
  String _innerVar = 'y';
  String _midVar = 'y';

  // Ranura actualmente activa (con foco)
  MathSlot _activeSlot = MathSlot.integrand;

  // Cursor parpadeante para el cuadrito activo
  bool _cursorBlink = true;
  Timer? _blinkTimer;

  bool _isKeyboardVisible = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _syncFromIntegral(widget.initialIntegral);

    _blinkTimer = Timer.periodic(const Duration(milliseconds: 550), (timer) {
      if (mounted) {
        setState(() => _cursorBlink = !_cursorBlink);
      }
    });
  }

  void _initControllers() {
    _integrandCtrl = TextEditingController();
    _innerLowerCtrl = TextEditingController();
    _innerUpperCtrl = TextEditingController();
    _outerLowerCtrl = TextEditingController();
    _outerUpperCtrl = TextEditingController();
    _midLowerCtrl = TextEditingController();
    _midUpperCtrl = TextEditingController();

    _integrandCtrl.addListener(_onFieldChanged);
    _innerLowerCtrl.addListener(_onFieldChanged);
    _innerUpperCtrl.addListener(_onFieldChanged);
    _outerLowerCtrl.addListener(_onFieldChanged);
    _outerUpperCtrl.addListener(_onFieldChanged);
    _midLowerCtrl.addListener(_onFieldChanged);
    _midUpperCtrl.addListener(_onFieldChanged);
  }

  @override
  void didUpdateWidget(covariant MathwayFormulaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIntegral != widget.initialIntegral) {
      _syncFromIntegral(widget.initialIntegral);
    }
  }

  void _syncFromIntegral(MultivariableIntegral integral) {
    _dimension = integral.dimension.clamp(1, 3);
    _integrandCtrl.text = integral.integrand;

    if (integral.bounds.length >= 3) {
      // Caso 3D (Integral Triple)
      _dimension = 3;
      _innerVar = integral.bounds[0].variable;
      _innerLowerCtrl.text = integral.bounds[0].lower;
      _innerUpperCtrl.text = integral.bounds[0].upper;

      _midVar = integral.bounds[1].variable;
      _midLowerCtrl.text = integral.bounds[1].lower;
      _midUpperCtrl.text = integral.bounds[1].upper;

      _outerVar = integral.bounds[2].variable;
      _outerLowerCtrl.text = integral.bounds[2].lower;
      _outerUpperCtrl.text = integral.bounds[2].upper;
    } else if (integral.bounds.length == 2) {
      // Caso 2D (Integral Doble)
      _dimension = 2;
      _innerVar = integral.bounds[0].variable;
      _innerLowerCtrl.text = integral.bounds[0].lower;
      _innerUpperCtrl.text = integral.bounds[0].upper;

      _outerVar = integral.bounds[1].variable;
      _outerLowerCtrl.text = integral.bounds[1].lower;
      _outerUpperCtrl.text = integral.bounds[1].upper;
    } else if (integral.bounds.length == 1) {
      // Caso 1D (Simple)
      _dimension = 1;
      _outerVar = integral.bounds[0].variable;
      _outerLowerCtrl.text = integral.bounds[0].lower;
      _outerUpperCtrl.text = integral.bounds[0].upper;
    } else {
      // Valores por defecto canónicos para 2D
      _innerVar = 'y';
      _innerLowerCtrl.text = '0';
      _innerUpperCtrl.text = '2 - 2*x';

      _outerVar = 'x';
      _outerLowerCtrl.text = '0';
      _outerUpperCtrl.text = '1';
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _integrandCtrl.dispose();
    _innerLowerCtrl.dispose();
    _innerUpperCtrl.dispose();
    _outerLowerCtrl.dispose();
    _outerUpperCtrl.dispose();
    _midLowerCtrl.dispose();
    _midUpperCtrl.dispose();
    super.dispose();
  }

  TextEditingController get _currentActiveController {
    switch (_activeSlot) {
      case MathSlot.outerLower:
        return _outerLowerCtrl;
      case MathSlot.outerUpper:
        return _outerUpperCtrl;
      case MathSlot.midLower:
        return _midLowerCtrl;
      case MathSlot.midUpper:
        return _midUpperCtrl;
      case MathSlot.innerLower:
        return _innerLowerCtrl;
      case MathSlot.innerUpper:
        return _innerUpperCtrl;
      case MathSlot.integrand:
        return _integrandCtrl;
    }
  }

  String get _activeSlotDescription {
    switch (_activeSlot) {
      case MathSlot.outerLower:
        return 'Límite Inferior Exterior [$_outerVar]';
      case MathSlot.outerUpper:
        return 'Límite Superior Exterior [$_outerVar]';
      case MathSlot.midLower:
        return 'Límite Inferior Medio [$_midVar]';
      case MathSlot.midUpper:
        return 'Límite Superior Medio [$_midVar]';
      case MathSlot.innerLower:
        return 'Límite Inferior Interior [$_innerVar]';
      case MathSlot.innerUpper:
        return 'Límite Superior Interior [$_innerVar]';
      case MathSlot.integrand:
        return _dimension == 3 ? 'Integrando f(x, y, z)' : 'Integrando f(x, y)';
    }
  }

  /// Detecta si el cursor se encuentra dentro de un argumento o función (sqrt, exp, ln, etc.)
  ActiveArgumentInfo? _getActiveArgumentInfo() {
    final ctrl = _currentActiveController;
    final text = ctrl.text;
    final cursor = ctrl.selection.baseOffset.clamp(0, text.length);

    int bestOpen = -1;
    int bestClose = -1;

    final openStack = <int>[];
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '(') {
        openStack.add(i);
      } else if (text[i] == ')') {
        if (openStack.isNotEmpty) {
          final openIdx = openStack.removeLast();
          if (cursor > openIdx && cursor <= i) {
            if (openIdx > bestOpen) {
              bestOpen = openIdx;
              bestClose = i;
            }
          }
        }
      }
    }

    for (final openIdx in openStack.reversed) {
      if (cursor > openIdx) {
        if (openIdx > bestOpen) {
          bestOpen = openIdx;
          bestClose = text.length;
        }
      }
    }

    if (bestOpen == -1) return null;

    final prefix = text.substring(0, bestOpen).trimRight();
    String func = 'paréntesis';
    String label = '( ... )';

    if (prefix.endsWith('sqrt')) {
      func = 'raíz cuadrada';
      label = '√( ... )';
    } else if (prefix.endsWith('cbrt')) {
      func = 'raíz cúbica';
      label = '∛( ... )';
    } else if (prefix.endsWith('exp')) {
      func = 'potencia e';
      label = 'e^( ... )';
    } else if (prefix.endsWith('ln')) {
      func = 'ln';
      label = 'ln( ... )';
    } else if (prefix.endsWith('log')) {
      func = 'log';
      label = 'log( ... )';
    } else if (prefix.endsWith('sin')) {
      func = 'seno';
      label = 'sin( ... )';
    } else if (prefix.endsWith('cos')) {
      func = 'coseno';
      label = 'cos( ... )';
    } else if (prefix.endsWith('tan')) {
      func = 'tangente';
      label = 'tan( ... )';
    } else if (prefix.endsWith('asin')) {
      func = 'arcsin';
      label = 'sin⁻¹( ... )';
    } else if (prefix.endsWith('acos')) {
      func = 'arccos';
      label = 'cos⁻¹( ... )';
    } else if (prefix.endsWith('atan')) {
      func = 'arctan';
      label = 'tan⁻¹( ... )';
    } else if (prefix.endsWith('abs')) {
      func = 'valor absoluto';
      label = '| ... |';
    } else if (prefix.endsWith('^')) {
      func = 'exponente';
      label = '^( ... )';
    }

    return ActiveArgumentInfo(
      functionName: func,
      displayLabel: label,
      openParenIndex: bestOpen,
      closeParenIndex: bestClose,
      exitOffset: bestClose < text.length ? bestClose + 1 : text.length + 1,
    );
  }

  /// Permite al estudiante salir del argumento o función actual con 1 tap
  void _exitActiveArgument() {
    final argInfo = _getActiveArgumentInfo();
    if (argInfo != null) {
      final ctrl = _currentActiveController;
      String t = ctrl.text;
      int target = argInfo.exitOffset;
      if (argInfo.closeParenIndex >= t.length) {
        t = '$t)';
        target = t.length;
        ctrl.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: target),
        );
      } else {
        ctrl.selection = TextSelection.collapsed(offset: target.clamp(0, t.length));
      }
      setState(() {});
    }
  }

  // =========================================================================
  // NAVEGACIÓN ENTRE CUADRITOS (ANTERIOR / SIGUIENTE)
  // =========================================================================

  void _prevSlot() {
    setState(() {
      if (_dimension == 1) {
        if (_activeSlot == MathSlot.integrand) {
          _activeSlot = MathSlot.outerUpper;
        } else if (_activeSlot == MathSlot.outerUpper) {
          _activeSlot = MathSlot.outerLower;
        } else {
          _activeSlot = MathSlot.integrand;
        }
      } else if (_dimension == 2) {
        switch (_activeSlot) {
          case MathSlot.integrand:
            _activeSlot = MathSlot.innerUpper;
            break;
          case MathSlot.innerUpper:
            _activeSlot = MathSlot.innerLower;
            break;
          case MathSlot.innerLower:
            _activeSlot = MathSlot.outerUpper;
            break;
          case MathSlot.outerUpper:
            _activeSlot = MathSlot.outerLower;
            break;
          case MathSlot.outerLower:
            _activeSlot = MathSlot.integrand;
            break;
          case MathSlot.midLower:
          case MathSlot.midUpper:
            _activeSlot = MathSlot.innerUpper;
            break;
        }
      } else {
        // 3D
        switch (_activeSlot) {
          case MathSlot.integrand:
            _activeSlot = MathSlot.innerUpper;
            break;
          case MathSlot.innerUpper:
            _activeSlot = MathSlot.innerLower;
            break;
          case MathSlot.innerLower:
            _activeSlot = MathSlot.midUpper;
            break;
          case MathSlot.midUpper:
            _activeSlot = MathSlot.midLower;
            break;
          case MathSlot.midLower:
            _activeSlot = MathSlot.outerUpper;
            break;
          case MathSlot.outerUpper:
            _activeSlot = MathSlot.outerLower;
            break;
          case MathSlot.outerLower:
            _activeSlot = MathSlot.integrand;
            break;
        }
      }
    });
  }

  void _nextSlot() {
    setState(() {
      if (_dimension == 1) {
        if (_activeSlot == MathSlot.outerLower) {
          _activeSlot = MathSlot.outerUpper;
        } else if (_activeSlot == MathSlot.outerUpper) {
          _activeSlot = MathSlot.integrand;
        } else {
          _activeSlot = MathSlot.outerLower;
        }
      } else if (_dimension == 2) {
        switch (_activeSlot) {
          case MathSlot.outerLower:
            _activeSlot = MathSlot.outerUpper;
            break;
          case MathSlot.outerUpper:
            _activeSlot = MathSlot.innerLower;
            break;
          case MathSlot.innerLower:
            _activeSlot = MathSlot.innerUpper;
            break;
          case MathSlot.innerUpper:
            _activeSlot = MathSlot.integrand;
            break;
          case MathSlot.integrand:
            _activeSlot = MathSlot.outerLower;
            break;
          case MathSlot.midLower:
          case MathSlot.midUpper:
            _activeSlot = MathSlot.innerLower;
            break;
        }
      } else {
        // 3D
        switch (_activeSlot) {
          case MathSlot.outerLower:
            _activeSlot = MathSlot.outerUpper;
            break;
          case MathSlot.outerUpper:
            _activeSlot = MathSlot.midLower;
            break;
          case MathSlot.midLower:
            _activeSlot = MathSlot.midUpper;
            break;
          case MathSlot.midUpper:
            _activeSlot = MathSlot.innerLower;
            break;
          case MathSlot.innerLower:
            _activeSlot = MathSlot.innerUpper;
            break;
          case MathSlot.innerUpper:
            _activeSlot = MathSlot.integrand;
            break;
          case MathSlot.integrand:
            _activeSlot = MathSlot.outerLower;
            break;
        }
      }
    });
  }

  void _clearActiveSlot() {
    setState(() {
      _currentActiveController.clear();
    });
  }

  // =========================================================================
  // GESTIÓN DE DIFERENCIALES Y ÓRDENES DE INTEGRACIÓN
  // =========================================================================

  void _swapDifferentialOrder() {
    setState(() {
      if (_dimension == 2) {
        // Intercambiar variables entre inner y outer
        final tempVar = _innerVar;
        _innerVar = _outerVar;
        _outerVar = tempVar;
      } else if (_dimension == 3) {
        // Rotar orden cíclico: dz dy dx -> dz dx dy -> dy dz dx
        if (_innerVar == 'z' && _midVar == 'y' && _outerVar == 'x') {
          _midVar = 'x';
          _outerVar = 'y';
        } else {
          _innerVar = 'z';
          _midVar = 'y';
          _outerVar = 'x';
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1200),
        backgroundColor: AppColors.slateDark,
        content: Text(
          'Orden de diferenciales actualizado: $_closingDifferentialString',
          style: const TextStyle(color: AppColors.electricCyan, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _handleDifferentialSelected(String diff) {
    setState(() {
      if (diff == 'dy dx') {
        _dimension = 2;
        _innerVar = 'y';
        _outerVar = 'x';
      } else if (diff == 'dx dy') {
        _dimension = 2;
        _innerVar = 'x';
        _outerVar = 'y';
      } else if (diff == 'dz dy dx') {
        _dimension = 3;
        _innerVar = 'z';
        _midVar = 'y';
        _outerVar = 'x';
      } else if (diff == 'r dr dθ') {
        _dimension = 2;
        _innerVar = 'r';
        _outerVar = 'theta';
      } else if (diff == 'dx') {
        _innerVar = 'x';
      } else if (diff == 'dy') {
        _innerVar = 'y';
      } else if (diff == 'dz') {
        _innerVar = 'z';
      } else if (diff == 'dr') {
        _innerVar = 'r';
      } else if (diff == 'dtheta') {
        _outerVar = 'theta';
      }
    });
  }

  void _handleSpecialTemplate(String template) {
    if (template == 'double_integral') {
      setState(() {
        _dimension = 2;
        _activeSlot = MathSlot.integrand;
      });
    } else if (template == 'triple_integral') {
      setState(() {
        _dimension = 3;
        _innerVar = 'z';
        _midVar = 'y';
        _outerVar = 'x';
        _activeSlot = MathSlot.integrand;
      });
    } else if (template == 'swap_differential') {
      _swapDifferentialOrder();
    }
  }

  String get _closingDifferentialString {
    if (_dimension == 1) {
      return 'd$_outerVar';
    } else if (_dimension == 2) {
      return 'd$_innerVar d$_outerVar';
    } else {
      return 'd$_innerVar d$_midVar d$_outerVar';
    }
  }

  // =========================================================================
  // SUBMIT Y COMPILACIÓN PARA EL MOTOR DE CÁLCULO
  // =========================================================================

  void _submit() {
    final integrandText = _integrandCtrl.text.trim();
    if (integrandText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.slateDark,
          content: Text(
            'Por favor ingresa la función integrando f(x, y).',
            style: TextStyle(color: AppColors.amberGlow),
          ),
        ),
      );
      setState(() => _activeSlot = MathSlot.integrand);
      return;
    }

    final normIntegrand = IntegralExpressionTransformer.normalizeExpression(integrandText);

    List<IntegrationBound> bounds = [];

    if (_dimension == 1) {
      final low = IntegralExpressionTransformer.normalizeExpression(_outerLowerCtrl.text);
      final upp = IntegralExpressionTransformer.normalizeExpression(_outerUpperCtrl.text);
      bounds = [
        IntegrationBound(variable: _outerVar, lower: low.isEmpty ? '0' : low, upper: upp.isEmpty ? '1' : upp),
      ];
    } else if (_dimension == 2) {
      final inLow = IntegralExpressionTransformer.normalizeExpression(_innerLowerCtrl.text);
      final inUpp = IntegralExpressionTransformer.normalizeExpression(_innerUpperCtrl.text);
      final outLow = IntegralExpressionTransformer.normalizeExpression(_outerLowerCtrl.text);
      final outUpp = IntegralExpressionTransformer.normalizeExpression(_outerUpperCtrl.text);

      bounds = [
        IntegrationBound(variable: _innerVar, lower: inLow.isEmpty ? '0' : inLow, upper: inUpp.isEmpty ? '1' : inUpp),
        IntegrationBound(variable: _outerVar, lower: outLow.isEmpty ? '0' : outLow, upper: outUpp.isEmpty ? '1' : outUpp),
      ];
    } else {
      // 3D
      final inLow = IntegralExpressionTransformer.normalizeExpression(_innerLowerCtrl.text);
      final inUpp = IntegralExpressionTransformer.normalizeExpression(_innerUpperCtrl.text);
      final midLow = IntegralExpressionTransformer.normalizeExpression(_midLowerCtrl.text);
      final midUpp = IntegralExpressionTransformer.normalizeExpression(_midUpperCtrl.text);
      final outLow = IntegralExpressionTransformer.normalizeExpression(_outerLowerCtrl.text);
      final outUpp = IntegralExpressionTransformer.normalizeExpression(_outerUpperCtrl.text);

      bounds = [
        IntegrationBound(variable: _innerVar, lower: inLow.isEmpty ? '0' : inLow, upper: inUpp.isEmpty ? '1' : inUpp),
        IntegrationBound(variable: _midVar, lower: midLow.isEmpty ? '0' : midLow, upper: midUpp.isEmpty ? '1' : midUpp),
        IntegrationBound(variable: _outerVar, lower: outLow.isEmpty ? '0' : outLow, upper: outUpp.isEmpty ? '1' : outUpp),
      ];
    }

    final compiled = MultivariableIntegral(
      integrand: normIntegrand,
      bounds: bounds,
      coordinateSystem: CoordinateSystemType.cartesian,
    );

    widget.onSolve(compiled);
  }

  void _loadPresetTemplate({
    required int dimension,
    required String integrand,
    required String inLow,
    required String inUpp,
    required String inVar,
    required String outLow,
    required String outUpp,
    required String outVar,
    String midLow = '0',
    String midUpp = '1',
    String midVar = 'y',
  }) {
    setState(() {
      _dimension = dimension;
      _integrandCtrl.text = integrand;
      _innerLowerCtrl.text = inLow;
      _innerUpperCtrl.text = inUpp;
      _innerVar = inVar;

      _outerLowerCtrl.text = outLow;
      _outerUpperCtrl.text = outUpp;
      _outerVar = outVar;

      _midLowerCtrl.text = midLow;
      _midUpperCtrl.text = midUpp;
      _midVar = midVar;

      _activeSlot = MathSlot.integrand;
    });
  }

  // =========================================================================
  // VISTA PRINCIPAL
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    const activeOrange = Color(0xFFE65100);

    return Column(
      children: [
        // 1. Selector Superior de Dimensión (1D, 2D, 3D)
        Container(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Row(
            children: [
              _buildDimensionPill(2, '∬ Doble (2D)'),
              const SizedBox(width: 8),
              _buildDimensionPill(3, '∭ Triple (3D)'),
              const SizedBox(width: 8),
              _buildDimensionPill(1, '∫ Simple (1D)'),
              const Spacer(),
              // Botón para alternar teclado
              IconButton(
                icon: Icon(
                  _isKeyboardVisible ? Icons.keyboard_hide_rounded : Icons.keyboard_rounded,
                  size: 20,
                  color: AppColors.mutedGray,
                ),
                tooltip: _isKeyboardVisible ? 'Ocultar teclado' : 'Mostrar teclado',
                onPressed: () => setState(() => _isKeyboardVisible = !_isKeyboardVisible),
              ),
            ],
          ),
        ),

        // 2. Tarjeta Visual Display Card con los CUADRITOS INTERACTIVOS (Image 1 y 2 Mathway)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white, // Blanco idéntico a Mathway
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cuadritos interactivos de la integral en horizontal con scroll
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Integral Exterior (o única si 1D)
                      _buildIntegralSymbolColumn(
                        upperSlot: MathSlot.outerUpper,
                        lowerSlot: MathSlot.outerLower,
                        upperCtrl: _outerUpperCtrl,
                        lowerCtrl: _outerLowerCtrl,
                        variable: _outerVar,
                      ),

                      // Integral Media (si 3D)
                      if (_dimension == 3) ...[
                        const SizedBox(width: 4),
                        _buildIntegralSymbolColumn(
                          upperSlot: MathSlot.midUpper,
                          lowerSlot: MathSlot.midLower,
                          upperCtrl: _midUpperCtrl,
                          lowerCtrl: _midLowerCtrl,
                          variable: _midVar,
                        ),
                      ],

                      // Integral Interior (si 2D o 3D)
                      if (_dimension >= 2) ...[
                        const SizedBox(width: 4),
                        _buildIntegralSymbolColumn(
                          upperSlot: MathSlot.innerUpper,
                          lowerSlot: MathSlot.innerLower,
                          upperCtrl: _innerUpperCtrl,
                          lowerCtrl: _innerLowerCtrl,
                          variable: _innerVar,
                        ),
                      ],

                      const SizedBox(width: 8),

                      // Cuadrito del Integrando f(x,y)
                      _buildCuadrito(
                        slot: MathSlot.integrand,
                        controller: _integrandCtrl,
                        placeholder: _dimension == 3 ? 'f(x, y, z)' : 'f(x, y)',
                        minWidth: 70,
                        height: 38,
                        label: 'Integrando',
                      ),

                      const SizedBox(width: 8),

                      // Cuadrito de Cierre: Diferenciales con botón de cambio de orden (⇄)
                      _buildDifferentialClosingBox(),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Botón de Cámara OCR (si está provisto)
              if (widget.onCameraOcr != null) ...[
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF64748B), size: 24),
                  tooltip: 'Escanear ejercicio con foto (OCR)',
                  onPressed: widget.onCameraOcr,
                ),
              ],

              // Botón Enviar / Resolver Naranja (Flecha Mathway)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _submit,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activeOrange.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: activeOrange,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Barra de Información del Cuadrito Activo, Argumentos y Controles de Ranura
        Builder(
          builder: (context) {
            final argInfo = _getActiveArgumentInfo();
            final hasArg = argInfo != null;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.slateDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasArg ? AppColors.electricCyan.withAlpha(120) : AppColors.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasArg ? Icons.adjust_rounded : Icons.edit_note_rounded,
                    size: 15,
                    color: hasArg ? AppColors.electricCyan : activeOrange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'Editando: $_activeSlotDescription',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.pureWhite,
                            ),
                          ),
                          if (hasArg) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.electricCyan.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.electricCyan.withAlpha(90)),
                              ),
                              child: Text(
                                '📍 En argumento: ${argInfo.displayLabel}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.electricCyan,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Botón inteligente para salir del argumento actual con 1 tap
                  if (hasArg) ...[
                    InkWell(
                      onTap: _exitActiveArgument,
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.cyberEmerald.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.cyberEmerald.withAlpha(120)),
                        ),
                        child: const Text(
                          '➔ Salir de función',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.cyberEmerald,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],

                  InkWell(
                    onTap: _clearActiveSlot,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('Limpiar', style: TextStyle(fontSize: 10, color: AppColors.coralFlame, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: _prevSlot,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('◄ Ranura', style: TextStyle(fontSize: 10, color: AppColors.electricCyan)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: _nextSlot,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('Ranura ►', style: TextStyle(fontSize: 10, color: AppColors.cyberEmerald, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 4. Barra de Sugerencias Rápidas de Ejercicios Modelo (Image 2 style)
        Container(
          height: 34,
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _buildSuggestionChip(
                  r'\int_{-2}^1 \int_0^{3y-5} xy^2 \, dx \, dy',
                  () => _loadPresetTemplate(
                    dimension: 2,
                    integrand: 'x * y^2',
                    inLow: '0',
                    inUpp: '3*y - 5',
                    inVar: 'x',
                    outLow: '-2',
                    outUpp: '1',
                    outVar: 'y',
                  ),
                ),
                _buildSuggestionChip(
                  r'\int_{0}^{1} \int_{0}^{2-2x} (6-2x-y) dy dx',
                  () => _loadPresetTemplate(
                    dimension: 2,
                    integrand: '6 - 2*x - y',
                    inLow: '0',
                    inUpp: '2 - 2*x',
                    inVar: 'y',
                    outLow: '0',
                    outUpp: '1',
                    outVar: 'x',
                  ),
                ),
                _buildSuggestionChip(
                  r'\int_{-2}^2 \int_{-\sqrt{4-x^2}}^{\sqrt{4-x^2}} (4-x^2-y^2) dy dx',
                  () => _loadPresetTemplate(
                    dimension: 2,
                    integrand: '4 - x^2 - y^2',
                    inLow: '-sqrt(4 - x^2)',
                    inUpp: 'sqrt(4 - x^2)',
                    inVar: 'y',
                    outLow: '-2',
                    outUpp: '2',
                    outVar: 'x',
                  ),
                ),
                _buildSuggestionChip(
                  r'\int_{0}^{1} \int_{0}^{1-x} \int_{0}^{1-x-y} 1 dz dy dx',
                  () => _loadPresetTemplate(
                    dimension: 3,
                    integrand: '1',
                    inLow: '0',
                    inUpp: '1 - x - y',
                    inVar: 'z',
                    midLow: '0',
                    midUpp: '1 - x',
                    midVar: 'y',
                    outLow: '0',
                    outUpp: '1',
                    outVar: 'x',
                  ),
                ),
              ],
            ),
          ),
        ),

        // 5. Teclado Virtual Completo Mathway con Pestañas
        if (_isKeyboardVisible)
          Expanded(
            child: MathwayKeyboard(
              controller: _currentActiveController,
              onEnter: _submit,
              onPrevSlot: _prevSlot,
              onNextSlot: _nextSlot,
              onClearSlot: _clearActiveSlot,
              onDifferentialSelected: _handleDifferentialSelected,
              onSpecialTemplate: _handleSpecialTemplate,
            ),
          ),
      ],
    );
  }

  // =========================================================================
  // CONSTRUCTORES DE ELEMENTOS VISUALES (CUADRITOS Y SÍMBOLOS)
  // =========================================================================

  Widget _buildDimensionPill(int dim, String label) {
    final isSelected = _dimension == dim;
    const activeOrange = Color(0xFFE65100);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          _dimension = dim;
          _activeSlot = MathSlot.integrand;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeOrange.withAlpha(35) : AppColors.slateDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeOrange : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.pureWhite : AppColors.mutedGray,
          ),
        ),
      ),
    );
  }

  /// Construye la columna matemática de un símbolo integral con sus dos cuadritos (superior e inferior)
  Widget _buildIntegralSymbolColumn({
    required MathSlot upperSlot,
    required MathSlot lowerSlot,
    required TextEditingController upperCtrl,
    required TextEditingController lowerCtrl,
    required String variable,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Cuadrito Límite Superior
        _buildCuadrito(
          slot: upperSlot,
          controller: upperCtrl,
          placeholder: '?',
          minWidth: 32,
          height: 24,
          label: 'sup $variable',
          isSmall: true,
        ),
        const SizedBox(height: 2),

        // Símbolo ∫ elegante grande
        const Text(
          '∫',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w300,
            fontFamily: 'serif',
            color: Color(0xFF0F172A),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),

        // Cuadrito Límite Inferior
        _buildCuadrito(
          slot: lowerSlot,
          controller: lowerCtrl,
          placeholder: '?',
          minWidth: 32,
          height: 24,
          label: 'inf $variable',
          isSmall: true,
        ),
      ],
    );
  }

  /// Construye el "Cuadrito" interactivo fiel a Mathway (Image 2)
  Widget _buildCuadrito({
    required MathSlot slot,
    required TextEditingController controller,
    required String placeholder,
    required double minWidth,
    required double height,
    required String label,
    bool isSmall = false,
  }) {
    final isActive = _activeSlot == slot;
    const activeOrange = Color(0xFFE65100);
    final text = controller.text;
    final isEmpty = text.isEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        setState(() => _activeSlot = slot);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: BoxConstraints(minWidth: minWidth, minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? activeOrange : const Color(0xFFCBD5E1),
            width: isActive ? 2.0 : 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeOrange.withAlpha(45),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isEmpty) ...[
              // Placeholder [?] idéntico a Mathway Image 2
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                  border: isActive ? Border.all(color: activeOrange, width: 1.0) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      placeholder,
                      style: TextStyle(
                        fontSize: isSmall ? 11 : 13,
                        fontWeight: FontWeight.bold,
                        color: isActive ? activeOrange : const Color(0xFF64748B),
                      ),
                    ),
                    if (isActive && _cursorBlink) ...[
                      Container(
                        width: 2,
                        height: isSmall ? 12 : 16,
                        margin: const EdgeInsets.only(left: 2),
                        color: activeOrange,
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (!isActive) ...[
              // Expresión matemática formateada con KaTeX para ranuras inactivas
              Math.tex(
                IntegralExpressionTransformer.toDisplayLatex(text),
                textStyle: TextStyle(
                  fontSize: isSmall ? 13 : 16,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
                onErrorFallback: (_) => Text(
                  IntegralExpressionTransformer.formatMathInline(text),
                  style: TextStyle(
                    fontSize: isSmall ? 12 : 15,
                    fontFamily: 'serif',
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              // Ranura ACTIVA: Muestra el cursor interactivo en tiempo real exactamente
              // donde está situado, formateando el texto a símbolos matemáticos reales.
              Builder(
                builder: (context) {
                  int cursorOffset = controller.selection.baseOffset;
                  if (cursorOffset < 0 || cursorOffset > text.length) {
                    cursorOffset = text.length;
                  }

                  final beforeCursor = text.substring(0, cursorOffset);
                  final afterCursor = text.substring(cursorOffset);

                  final formattedBefore = IntegralExpressionTransformer.formatMathInline(beforeCursor);
                  final formattedAfter = IntegralExpressionTransformer.formatMathInline(afterCursor);

                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: formattedBefore,
                          style: TextStyle(
                            fontSize: isSmall ? 13 : 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                            fontFamily: 'serif',
                          ),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: AnimatedOpacity(
                            opacity: _cursorBlink ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 90),
                            child: Container(
                              width: 2.2,
                              height: isSmall ? 16 : 22,
                              margin: const EdgeInsets.symmetric(horizontal: 1.0),
                              decoration: BoxDecoration(
                                color: activeOrange,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: formattedAfter,
                          style: TextStyle(
                            fontSize: isSmall ? 13 : 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                            fontFamily: 'serif',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construye el cuadrito interactivo que cierra la integral con sus diferenciales respectivos
  Widget _buildDifferentialClosingBox() {
    const activeOrange = Color(0xFFE65100);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _swapDifferentialOrder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: activeOrange, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _closingDifferentialString,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                color: activeOrange,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.swap_horiz_rounded, size: 16, color: activeOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String latex, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Math.tex(
                latex,
                textStyle: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
