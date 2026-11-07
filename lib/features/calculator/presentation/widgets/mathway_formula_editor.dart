import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/integration_bound.dart';
import '../../domain/entities/multivariable_integral.dart';
import '../../domain/services/integral_expression_transformer.dart';
import 'keyboard/math_keyboard.dart';

enum MathwayActiveSlot {
  integrand,
  innerLower,
  innerUpper,
  outerLower,
  outerUpper,
}

/// Editor matemático interactivo unificado idéntico a Mathway (Image 1 y Image 2).
/// Permite ingresar y editar integrales dobles de forma totalmente entendible para el usuario,
/// con visualización matemática en tiempo real (KaTeX), selección de ranuras (slots)
/// intuitivas y teclado Mathway de 5 filas x 12 columnas.
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
  late TextEditingController _integrandCtrl;
  late TextEditingController _innerLowerCtrl;
  late TextEditingController _innerUpperCtrl;
  late TextEditingController _outerLowerCtrl;
  late TextEditingController _outerUpperCtrl;

  MathwayActiveSlot _activeSlot = MathwayActiveSlot.integrand;
  String _innerVar = 'x';
  String _outerVar = 'y';

  @override
  void initState() {
    super.initState();
    _syncFromIntegral(widget.initialIntegral);
  }

  @override
  void didUpdateWidget(covariant MathwayFormulaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIntegral != widget.initialIntegral) {
      _syncFromIntegral(widget.initialIntegral);
    }
  }

  void _syncFromIntegral(MultivariableIntegral integral) {
    _integrandCtrl = TextEditingController(text: integral.integrand);

    if (integral.bounds.isNotEmpty) {
      _innerVar = integral.bounds[0].variable;
      _innerLowerCtrl = TextEditingController(text: integral.bounds[0].lower);
      _innerUpperCtrl = TextEditingController(text: integral.bounds[0].upper);
    } else {
      _innerVar = 'x';
      _innerLowerCtrl = TextEditingController(text: '0');
      _innerUpperCtrl = TextEditingController(text: '3*y - 5');
    }

    if (integral.bounds.length > 1) {
      _outerVar = integral.bounds[1].variable;
      _outerLowerCtrl = TextEditingController(text: integral.bounds[1].lower);
      _outerUpperCtrl = TextEditingController(text: integral.bounds[1].upper);
    } else {
      _outerVar = 'y';
      _outerLowerCtrl = TextEditingController(text: '-2');
      _outerUpperCtrl = TextEditingController(text: '1');
    }

    _integrandCtrl.addListener(_onFieldChanged);
    _innerLowerCtrl.addListener(_onFieldChanged);
    _innerUpperCtrl.addListener(_onFieldChanged);
    _outerLowerCtrl.addListener(_onFieldChanged);
    _outerUpperCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _integrandCtrl.dispose();
    _innerLowerCtrl.dispose();
    _innerUpperCtrl.dispose();
    _outerLowerCtrl.dispose();
    _outerUpperCtrl.dispose();
    super.dispose();
  }

  TextEditingController get _currentActiveController {
    switch (_activeSlot) {
      case MathwayActiveSlot.integrand:
        return _integrandCtrl;
      case MathwayActiveSlot.innerLower:
        return _innerLowerCtrl;
      case MathwayActiveSlot.innerUpper:
        return _innerUpperCtrl;
      case MathwayActiveSlot.outerLower:
        return _outerLowerCtrl;
      case MathwayActiveSlot.outerUpper:
        return _outerUpperCtrl;
    }
  }

  String get _activeSlotDescription {
    switch (_activeSlot) {
      case MathwayActiveSlot.integrand:
        return 'Función Integrando f(x, y)';
      case MathwayActiveSlot.innerUpper:
        return 'Límite Superior Interior [$_innerVar]';
      case MathwayActiveSlot.innerLower:
        return 'Límite Inferior Interior [$_innerVar]';
      case MathwayActiveSlot.outerUpper:
        return 'Límite Superior Exterior [$_outerVar]';
      case MathwayActiveSlot.outerLower:
        return 'Límite Inferior Exterior [$_outerVar]';
    }
  }

  String _buildLiveLatex() {
    final outLow = _outerLowerCtrl.text.isEmpty ? '?' : _outerLowerCtrl.text;
    final outUpp = _outerUpperCtrl.text.isEmpty ? '?' : _outerUpperCtrl.text;
    final inLow = _innerLowerCtrl.text.isEmpty ? '?' : _innerLowerCtrl.text;
    final inUpp = _innerUpperCtrl.text.isEmpty ? '?' : _innerUpperCtrl.text;
    final integrand = _integrandCtrl.text.isEmpty ? '?' : _integrandCtrl.text;

    return r'\int_{' + outLow + r'}^{' + outUpp + r'} \int_{' + inLow + r'}^{' + inUpp + r'} ' +
        integrand +
        r' \, d' + _innerVar + r' \, d' + _outerVar;
  }

  void _submit() {
    // Normalizar todas las expresiones ingresadas con el transformador matemático
    final normalizedIntegrand = IntegralExpressionTransformer.normalizeExpression(_integrandCtrl.text);
    final normalizedInLower = IntegralExpressionTransformer.normalizeExpression(_innerLowerCtrl.text);
    final normalizedInUpper = IntegralExpressionTransformer.normalizeExpression(_innerUpperCtrl.text);
    final normalizedOutLower = IntegralExpressionTransformer.normalizeExpression(_outerLowerCtrl.text);
    final normalizedOutUpper = IntegralExpressionTransformer.normalizeExpression(_outerUpperCtrl.text);

    final bounds = [
      IntegrationBound(
        variable: _innerVar,
        lower: normalizedInLower,
        upper: normalizedInUpper,
      ),
      IntegrationBound(
        variable: _outerVar,
        lower: normalizedOutLower,
        upper: normalizedOutUpper,
      ),
    ];

    final compiled = MultivariableIntegral(
      integrand: normalizedIntegrand,
      bounds: bounds,
      coordinateSystem: CoordinateSystemType.cartesian,
    );

    widget.onSolve(compiled);
  }

  void _loadTemplate({
    required String integrand,
    required String inLow,
    required String inUpp,
    required String inVar,
    required String outLow,
    required String outUpp,
    required String outVar,
  }) {
    setState(() {
      _integrandCtrl.text = integrand;
      _innerLowerCtrl.text = inLow;
      _innerUpperCtrl.text = inUpp;
      _innerVar = inVar;
      _outerLowerCtrl.text = outLow;
      _outerUpperCtrl.text = outUpp;
      _outerVar = outVar;
      _activeSlot = MathwayActiveSlot.integrand;
    });
  }

  @override
  Widget build(BuildContext context) {
    const orangeColor = Color(0xFFE65100);

    return Column(
      children: [
        // 1. Tarjeta Superior de Entrada (Mathway Display Card - Image 1 y 2)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white, // Blanco brillante idéntico a Mathway
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
            children: [
              // Expresión matemática renderizada en tiempo real con KaTeX
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Math.tex(
                      _buildLiveLatex(),
                      textStyle: const TextStyle(
                        fontSize: 22,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                      onErrorFallback: (err) => Text(
                        _buildLiveLatex(),
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ),
                  ),
                ),
              ),

              // Botón de Cámara OCR (estilo Mathway)
              if (widget.onCameraOcr != null) ...[
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF64748B), size: 24),
                  tooltip: 'Escanear ejercicio con foto (OCR)',
                  onPressed: widget.onCameraOcr,
                ),
                const SizedBox(width: 4),
              ],

              // Botón Enviar / Resolver Naranja (Flecha de navegación Mathway)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _submit,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: orangeColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: orangeColor,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Selector visual interactivo de partes de la integral (Didáctico y claro)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.slateDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              // Barra con las tres ranuras principales
              Row(
                children: [
                  Expanded(
                    child: _buildSlotPill(
                      label: 'Lím. Ext [$_outerVar]',
                      value: '[${_outerLowerCtrl.text}, ${_outerUpperCtrl.text}]',
                      isActive: _activeSlot == MathwayActiveSlot.outerLower || _activeSlot == MathwayActiveSlot.outerUpper,
                      onTap: () {
                        setState(() => _activeSlot = MathwayActiveSlot.outerUpper);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildSlotPill(
                      label: 'Lím. Int [$_innerVar]',
                      value: '[${_innerLowerCtrl.text}, ${_innerUpperCtrl.text}]',
                      isActive: _activeSlot == MathwayActiveSlot.innerLower || _activeSlot == MathwayActiveSlot.innerUpper,
                      onTap: () {
                        setState(() => _activeSlot = MathwayActiveSlot.innerUpper);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildSlotPill(
                      label: 'Integrando',
                      value: _integrandCtrl.text.isEmpty ? 'f(x,y)' : _integrandCtrl.text,
                      isActive: _activeSlot == MathwayActiveSlot.integrand,
                      onTap: () {
                        setState(() => _activeSlot = MathwayActiveSlot.integrand);
                      },
                    ),
                  ),
                ],
              ),

              // Sub-selector fino si se están editando los límites
              if (_activeSlot != MathwayActiveSlot.integrand) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tocar para editar: ',
                      style: TextStyle(fontSize: 10, color: AppColors.mutedGray),
                    ),
                    _buildSubSlotButton(
                      'Lím. Inferior',
                      _activeSlot == MathwayActiveSlot.innerLower || _activeSlot == MathwayActiveSlot.outerLower,
                      () {
                        setState(() {
                          if (_activeSlot == MathwayActiveSlot.innerUpper || _activeSlot == MathwayActiveSlot.innerLower) {
                            _activeSlot = MathwayActiveSlot.innerLower;
                          } else {
                            _activeSlot = MathwayActiveSlot.outerLower;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildSubSlotButton(
                      'Lím. Superior',
                      _activeSlot == MathwayActiveSlot.innerUpper || _activeSlot == MathwayActiveSlot.outerUpper,
                      () {
                        setState(() {
                          if (_activeSlot == MathwayActiveSlot.innerUpper || _activeSlot == MathwayActiveSlot.innerLower) {
                            _activeSlot = MathwayActiveSlot.innerUpper;
                          } else {
                            _activeSlot = MathwayActiveSlot.outerUpper;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],

              // Indicador de campo activo
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.slateElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 14, color: orangeColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Editando: $_activeSlotDescription  =  "${_currentActiveController.text}"',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pureWhite,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _currentActiveController.clear()),
                      child: const Text('Limpiar', style: TextStyle(fontSize: 10, color: AppColors.coralFlame)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. Barra de Sugerencias / Chips Rápidos (Estilo Mathway Image 2)
        Container(
          height: 38,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _buildSuggestionChip(
                  r'\int_{-2}^1 \int_0^{3y-5} x y^2 \, dx \, dy',
                  () => _loadTemplate(
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
                  r'\int_{-2}^2 \int_{-\sqrt{4-x^2}}^{\sqrt{4-x^2}} (4-x^2-y^2) dy dx',
                  () => _loadTemplate(
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
                  r'\int_0^1 \int_0^{1-x} (x+y) dy dx',
                  () => _loadTemplate(
                    integrand: 'x + y',
                    inLow: '0',
                    inUpp: '1 - x',
                    inVar: 'y',
                    outLow: '0',
                    outUpp: '1',
                    outVar: 'x',
                  ),
                ),
              ],
            ),
          ),
        ),

        // 4. Teclado Virtual Completo Mathway (5 Filas x 12 Columnas)
        Expanded(
          child: MathwayKeyboard(
            controller: _currentActiveController,
            onEnter: _submit,
            onSpecialTemplate: (template) {
              if (template == 'double_integral') {
                _loadTemplate(
                  integrand: 'x * y^2',
                  inLow: '0',
                  inUpp: '3*y - 5',
                  inVar: 'x',
                  outLow: '-2',
                  outUpp: '1',
                  outVar: 'y',
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSlotPill({
    required String label,
    required String value,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    const orangeColor = Color(0xFFE65100);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? orangeColor.withAlpha(35) : AppColors.slateElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? orangeColor : AppColors.borderSubtle,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? orangeColor : AppColors.mutedGray,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.pureWhite : const Color(0xFFCBD5E1),
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubSlotButton(String title, bool isSelected, VoidCallback onTap) {
    const orangeColor = Color(0xFFE65100);
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? orangeColor.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? orangeColor : AppColors.borderSubtle),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? orangeColor : AppColors.mutedGray,
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Math.tex(
                latex,
                textStyle: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
