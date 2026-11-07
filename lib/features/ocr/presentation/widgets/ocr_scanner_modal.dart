import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/math_colors.dart';
import '../../../calculator/domain/entities/integration_bound.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../calculator/presentation/widgets/keyboard/math_keyboard.dart';
import '../../../solver/presentation/widgets/latex_card.dart';
import '../../data/datasources/ocr_remote_datasource.dart';
import '../../domain/entities/ocr_integral_result.dart';

class OcrScannerModal extends StatefulWidget {
  final Function(MultivariableIntegral) onIntegralAccepted;

  const OcrScannerModal({super.key, required this.onIntegralAccepted});

  static Future<void> show(BuildContext context, {required Function(MultivariableIntegral) onIntegralAccepted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OcrScannerModal(onIntegralAccepted: onIntegralAccepted),
    );
  }

  @override
  State<OcrScannerModal> createState() => _OcrScannerModalState();
}

class _OcrScannerModalState extends State<OcrScannerModal> {
  final ImagePicker _picker = ImagePicker();
  final OcrRemoteDataSource _ocrDataSource = OcrRemoteDataSourceImpl();

  XFile? _selectedImage;
  bool _isProcessing = false;
  OcrIntegralResult? _transcriptionResult;

  // Controladores de edición para corrección manual
  late TextEditingController _integrandCtrl;
  final List<TextEditingController> _lowerControllers = [];
  final List<TextEditingController> _upperControllers = [];

  // Controlador activo sobre el que opera el MathKeyboard
  TextEditingController? _activeController;
  String _activeFieldLabel = 'Integrando f(x, y, z)';
  bool _showKeyboard = false;

  @override
  void initState() {
    super.initState();
    _integrandCtrl = TextEditingController(text: '4 - x^2 - y^2');
    _activeController = _integrandCtrl;
  }

  @override
  void dispose() {
    _integrandCtrl.dispose();
    for (final c in _lowerControllers) {
      c.dispose();
    }
    for (final c in _upperControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (file == null) return;

      setState(() {
        _selectedImage = file;
        _isProcessing = true;
        _transcriptionResult = null;
      });

      final result = await _ocrDataSource.transcribeImage(file);

      // Sincronizar controladores con los datos leídos
      _integrandCtrl.text = result.integrand;
      _lowerControllers.clear();
      _upperControllers.clear();
      for (final bound in result.bounds) {
        _lowerControllers.add(TextEditingController(text: bound.lower));
        _upperControllers.add(TextEditingController(text: bound.upper));
      }

      setState(() {
        _isProcessing = false;
        _transcriptionResult = result;
        _activeController = _integrandCtrl;
        _activeFieldLabel = 'Integrando f(x, y, z)';
        _showKeyboard = true;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar imagen: $e')),
        );
      }
    }
  }

  void _setActiveField(TextEditingController ctrl, String label) {
    setState(() {
      _activeController = ctrl;
      _activeFieldLabel = label;
      _showKeyboard = true;
    });
  }

  void _confirmAndApply() {
    if (_transcriptionResult == null) return;

    final updatedBounds = <IntegrationBound>[];
    for (int i = 0; i < _transcriptionResult!.bounds.length; i++) {
      final original = _transcriptionResult!.bounds[i];
      updatedBounds.add(
        IntegrationBound(
          variable: original.variable,
          lower: i < _lowerControllers.length ? _lowerControllers[i].text : original.lower,
          upper: i < _upperControllers.length ? _upperControllers[i].text : original.upper,
        ),
      );
    }

    final finalIntegral = MultivariableIntegral(
      integrand: _integrandCtrl.text,
      bounds: updatedBounds,
      coordinateSystem: _transcriptionResult!.coordinateSystem,
    );

    widget.onIntegralAccepted(finalIntegral);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mathColors = context.mathColors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.deepVoid, // #0D1117
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1.5)),
      ),
      child: Column(
        children: [
          // 1. Barra superior / Handle
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.slateDark, // #161B22
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: mathColors.primaryAction.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.document_scanner_rounded, size: 20, color: mathColors.primaryAction),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Escáner Matemático OCR',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: mathColors.formulaText),
                        ),
                        Text(
                          'Transcribe y corrige con teclado especializado',
                          style: TextStyle(fontSize: 10, color: mathColors.metadataText),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.mutedGray),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // 2. Contenido Scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Botones para Capturar Foto o Subir Galería
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.slateElevated,
                            foregroundColor: mathColors.formulaText,
                            side: const BorderSide(color: AppColors.borderSubtle),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: Icon(Icons.camera_alt_rounded, size: 18, color: mathColors.secondaryAccent),
                          label: const Text('Tomar Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.slateElevated,
                            foregroundColor: mathColors.formulaText,
                            side: const BorderSide(color: AppColors.borderSubtle),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: Icon(Icons.photo_library_rounded, size: 18, color: mathColors.primaryAction),
                          label: const Text('Subir Imagen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Si está procesando
                  if (_isProcessing) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.slateDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: mathColors.primaryAction),
                          const SizedBox(height: 16),
                          Text(
                            'Digitalizando ejercicio multivariable...',
                            style: TextStyle(fontWeight: FontWeight.bold, color: mathColors.formulaText),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Identificando integrales iteradas, límites y diferenciales...',
                            style: TextStyle(fontSize: 11, color: mathColors.metadataText),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Vista previa de la transcripción y campos corregibles
                  if (_transcriptionResult != null && !_isProcessing) ...[
                    // Tarjeta de Vista Previa LaTeX
                    LatexCard(
                      title: 'Transcripción Detectada',
                      subtitle: 'Precisión estimada: ${(_transcriptionResult!.confidence * 100).toInt()}% • Pulsa cualquier campo para corregir',
                      latex: _transcriptionResult!.rawLatex.isNotEmpty
                          ? _transcriptionResult!.rawLatex
                          : r'\iint_D (' + _integrandCtrl.text + r') \, dA',
                      isHighlight: true,
                    ),
                    const SizedBox(height: 12),

                    // Campo Integrando (con foco para el teclado)
                    _buildEditableFieldTile(
                      label: 'Función Integrando f(x, y, z)',
                      controller: _integrandCtrl,
                      hint: 'Ej: 4 - x^2 - y^2',
                      isActive: _activeController == _integrandCtrl,
                      onTap: () => _setActiveField(_integrandCtrl, 'Integrando f(x, y, z)'),
                      mathColors: mathColors,
                    ),
                    const SizedBox(height: 10),

                    // Campos de Límites de Integración
                    Text(
                      'Límites Identificados (Capas de Integración):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mathColors.metadataText),
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(_transcriptionResult!.bounds.length, (idx) {
                      final bound = _transcriptionResult!.bounds[idx];
                      final lowerCtrl = _lowerControllers[idx];
                      final upperCtrl = _upperControllers[idx];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.slateDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Variable d${bound.variable} (Capa ${idx + 1})',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: mathColors.secondaryAccent),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactInput(
                                    label: 'Límite Inferior (a)',
                                    controller: lowerCtrl,
                                    isActive: _activeController == lowerCtrl,
                                    onTap: () => _setActiveField(lowerCtrl, 'Límite Inferior de d${bound.variable}'),
                                    mathColors: mathColors,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildCompactInput(
                                    label: 'Límite Superior (b)',
                                    controller: upperCtrl,
                                    isActive: _activeController == upperCtrl,
                                    onTap: () => _setActiveField(upperCtrl, 'Límite Superior de d${bound.variable}'),
                                    mathColors: mathColors,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // Botón para aplicar y calcular
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mathColors.primaryAction,
                        foregroundColor: AppColors.deepVoid,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('CONFIRMAR Y RESOLVER EN INTEGRA3D', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _confirmAndApply,
                    ),
                  ],

                  // Imagen capturada previa (miniatura)
                  if (_selectedImage != null && !_isProcessing) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          decoration: BoxDecoration(border: Border.all(color: AppColors.borderSubtle)),
                          child: Image.file(
                            File(_selectedImage!.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. Teclado Matemático Especializado Acoplado en la Parte Inferior
          if (_showKeyboard && _activeController != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              color: AppColors.deepVoid,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, size: 14, color: AppColors.electricCyan),
                      const SizedBox(width: 6),
                      Text(
                        'Editando: $_activeFieldLabel',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.electricCyan),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showKeyboard = false),
                    child: const Text('Ocultar', style: TextStyle(fontSize: 11, color: AppColors.mutedGray)),
                  ),
                ],
              ),
            ),
            MathKeyboard(
              controller: _activeController!,
              onClose: () => setState(() => _showKeyboard = false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableFieldTile({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isActive,
    required VoidCallback onTap,
    required MathColors mathColors,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.slateDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? mathColors.secondaryAccent : AppColors.borderSubtle,
            width: isActive ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: mathColors.metadataText)),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: mathColors.secondaryAccent.withAlpha(35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Activo', style: TextStyle(fontSize: 9, color: AppColors.electricCyan, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              controller.text.isEmpty ? hint : controller.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: controller.text.isEmpty ? AppColors.mutedGray : mathColors.formulaText,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactInput({
    required String label,
    required TextEditingController controller,
    required bool isActive,
    required VoidCallback onTap,
    required MathColors mathColors,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.slateElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? mathColors.secondaryAccent : AppColors.borderSubtle,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: mathColors.metadataText)),
            const SizedBox(height: 3),
            Text(
              controller.text.isEmpty ? '-' : controller.text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: controller.text.isEmpty ? AppColors.mutedGray : mathColors.formulaText,
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
}
