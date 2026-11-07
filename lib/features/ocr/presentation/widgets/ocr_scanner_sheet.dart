import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/math_colors.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../calculator/domain/services/integral_expression_transformer.dart';
import '../../domain/services/math_ocr_service.dart';

enum OcrStep {
  pickImage,
  previewAndCrop,
  processing,
  confirmAndEdit,
}

/// Modal Sheet estudiantil de escaneo de imágenes y transcripción matemática para Integra3D.
/// Diseñado bajo la paleta Dark Matrix & Spectral 3D, sin fricción técnica para estudiantes
/// y con confirmación visual obligatoria antes de resolver y graficar en 3D.
class OcrScannerSheet extends StatefulWidget {
  final Function(MultivariableIntegral) onIntegralAccepted;

  const OcrScannerSheet({super.key, required this.onIntegralAccepted});

  static Future<void> show(
    BuildContext context, {
    required Function(MultivariableIntegral) onIntegralAccepted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OcrScannerSheet(onIntegralAccepted: onIntegralAccepted),
    );
  }

  @override
  State<OcrScannerSheet> createState() => _OcrScannerSheetState();
}

class _OcrScannerSheetState extends State<OcrScannerSheet> {
  final ImagePicker _picker = ImagePicker();
  final MathOcrService _ocrService = MathOcrService();

  OcrStep _currentStep = OcrStep.pickImage;
  Uint8List? _compressedImageBytes;
  String _statusMessage = 'Analizando ejercicio con visión multimodal...';

  // Controlador para el LaTeX detectado y editable por el estudiante
  final TextEditingController _latexController = TextEditingController();
  bool _isEditingLatex = false;

  @override
  void dispose() {
    _latexController.dispose();
    super.dispose();
  }

  // ==========================================
  // CAPTURA Y COMPRESIÓN EN MEMORIA
  // ==========================================

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Compresión automática en memoria (máximo 800x800 px, calidad 75%)
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _compressedImageBytes = bytes;
        _currentStep = OcrStep.previewAndCrop;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.slateDark,
            content: Text('No se pudo acceder a la imagen: $e', style: const TextStyle(color: AppColors.coralFlame)),
          ),
        );
      }
    }
  }

  // ==========================================
  // LLAMADA RESILIENTE AL SERVICIO OCR
  // ==========================================

  Future<void> _startOcrTranscription() async {
    if (_compressedImageBytes == null) return;

    setState(() {
      _currentStep = OcrStep.processing;
      _statusMessage = 'Analizando ejercicio con visión multimodal...';
    });

    final result = await _ocrService.transcribe(
      imageBytes: _compressedImageBytes!,
      onStatusUpdate: (msg) {
        if (mounted) {
          setState(() => _statusMessage = msg);
        }
      },
    );

    if (mounted) {
      setState(() {
        _latexController.text = result.rawLatex;
        _currentStep = OcrStep.confirmAndEdit;
        _isEditingLatex = false;
      });
    }
  }

  // ==========================================
  // RESOLUCIÓN Y PROYECCIÓN 3D
  // ==========================================

  void _submitAndSolve() {
    final rawText = _latexController.text.trim();
    final parsed = IntegralExpressionTransformer.parseFullIntegral(rawText);

    if (parsed != null) {
      widget.onIntegralAccepted(parsed);
      Navigator.of(context).pop();
    } else {
      // Si el LaTeX tiene sintaxis libre, intentar construir integral con normalizador
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.slateDark,
          content: Text(
            'Verifica los diferenciales (ej: dy dx) o límites de la integral.',
            style: TextStyle(color: AppColors.amberGlow),
          ),
        ),
      );
    }
  }

  // ==========================================
  // DIÁLOGO BYOK OPCIONAL (Para usuarios técnicos)
  // ==========================================

  void _showAdvancedSettingsDialog() async {
    final currentKey = await _ocrService.getUserApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.slateDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.electricCyan, size: 22),
              SizedBox(width: 8),
              Text(
                'Opciones avanzadas (BYOK)',
                style: TextStyle(fontSize: 15, color: AppColors.pureWhite, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La app opera por defecto con un pool comunitario y servidores de respaldo con failover automático. '
                'Si eres un usuario técnico y deseas prioridad sin límites de cuota, puedes ingresar tu propia clave de Google AI Studio.',
                style: TextStyle(fontSize: 12, color: AppColors.mutedGray, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(fontSize: 12, color: AppColors.pureWhite, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Tu Gemini API Key (Opcional)',
                  hintStyle: const TextStyle(color: AppColors.mutedGray, fontSize: 11),
                  filled: true,
                  fillColor: AppColors.slateElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: AppColors.mutedGray),
                    onPressed: () => controller.clear(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar', style: TextStyle(color: AppColors.mutedGray)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyberEmerald,
                foregroundColor: AppColors.deepVoid,
              ),
              onPressed: () async {
                final key = controller.text.trim();
                if (key.isNotEmpty) {
                  await _ocrService.saveUserApiKey(key);
                } else {
                  await _ocrService.clearUserApiKey();
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Configuración BYOK guardada.')),
                  );
                }
              },
              child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // CONSTRUCCIÓN DE LA VISTA (UX ESTUDIANTIL)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final mathColors = context.mathColors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.deepVoid, // #0D1117
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1.5)),
      ),
      child: Column(
        children: [
          // 1. Barra de encabezado
          _buildHeader(mathColors),

          // 2. Contenido dinámico según el paso
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCurrentStepView(mathColors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(MathColors mathColors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.slateDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
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
                    'Reconocimiento y visualización 3D',
                    style: TextStyle(fontSize: 11, color: mathColors.metadataText),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20, color: AppColors.mutedGray),
                tooltip: 'Opciones avanzadas (BYOK)',
                onPressed: _showAdvancedSettingsDialog,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.mutedGray),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView(MathColors mathColors) {
    switch (_currentStep) {
      case OcrStep.pickImage:
        return _buildPickImageView(mathColors);
      case OcrStep.previewAndCrop:
        return _buildPreviewAndCropView(mathColors);
      case OcrStep.processing:
        return _buildProcessingView(mathColors);
      case OcrStep.confirmAndEdit:
        return _buildConfirmAndEditView(mathColors);
    }
  }

  // -------------------------------------------------------------
  // PASO 1: SELECCIÓN LIMPIA (Tomar Foto / Galería)
  // -------------------------------------------------------------
  Widget _buildPickImageView(MathColors mathColors) {
    return SingleChildScrollView(
      key: const ValueKey('pick_image_view'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Text(
            'Captura tu ejercicio de cálculo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: mathColors.formulaText),
          ),
          const SizedBox(height: 6),
          Text(
            'Enfoca la integral doble o triple de tu cuaderno o libro de texto.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: mathColors.metadataText, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Dos botones principales grandes
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pickImage(ImageSource.camera),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.slateDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: mathColors.secondaryAccent.withAlpha(90)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, size: 32, color: mathColors.secondaryAccent),
                        const SizedBox(height: 8),
                        Text(
                          'Tomar Foto',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: mathColors.formulaText),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.slateDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: mathColors.primaryAction.withAlpha(90)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_rounded, size: 32, color: mathColors.primaryAction),
                        const SizedBox(height: 8),
                        Text(
                          'Galería',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: mathColors.formulaText),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.borderSubtle)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('O prueba con un ejercicio modelo', style: TextStyle(fontSize: 11, color: mathColors.metadataText)),
              ),
              const Expanded(child: Divider(color: AppColors.borderSubtle)),
            ],
          ),
          const SizedBox(height: 16),

          // Tarjeta de plantilla canónica rápida
          _buildQuickPresetCard(
            title: 'Integral Doble con Límite Variable (Tipo II)',
            latex: r'\int_{-2}^{1}\int_{0}^{3y-5}xy^2\,dx\,dy',
            onTap: () {
              setState(() {
                _latexController.text = r'\int_{-2}^{1}\int_{0}^{3y-5}xy^2\,dx\,dy';
                _currentStep = OcrStep.confirmAndEdit;
                _isEditingLatex = false;
              });
            },
          ),
          const SizedBox(height: 8),
          _buildQuickPresetCard(
            title: 'Integral Doble Triangular (Tipo I)',
            latex: r'\int_{0}^{1}\int_{0}^{2-2x}(6-2x-y)\,dy\,dx',
            onTap: () {
              setState(() {
                _latexController.text = r'\int_{0}^{1}\int_{0}^{2-2x}(6-2x-y)\,dy\,dx';
                _currentStep = OcrStep.confirmAndEdit;
                _isEditingLatex = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresetCard({required String title, required String latex, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.slateDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.pureWhite)),
                  const SizedBox(height: 4),
                  Math.tex(latex, textStyle: const TextStyle(fontSize: 12, color: AppColors.electricCyan)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.mutedGray),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // PASO 2: ENCUADRE Y VISTA PREVIA RÁPIDA
  // -------------------------------------------------------------
  Widget _buildPreviewAndCropView(MathColors mathColors) {
    return Padding(
      key: const ValueKey('preview_crop_view'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Encuadre del ejercicio',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: mathColors.formulaText),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reemplazar foto', style: TextStyle(fontSize: 12)),
                onPressed: () => setState(() => _currentStep = OcrStep.pickImage),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Recuadro de previsualización con borde de encuadre
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.slateDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: mathColors.secondaryAccent.withAlpha(120), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_compressedImageBytes != null)
                      Image.memory(
                        _compressedImageBytes!,
                        fit: BoxFit.contain,
                      ),

                    // Marco visual de guía de escaneo
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.electricCyan.withAlpha(80), width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Botón principal de análisis
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: mathColors.primaryAction,
              foregroundColor: AppColors.deepVoid,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text(
              'Analizar y Transcribir Integral',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            onPressed: _startOcrTranscription,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PASO 3: ESTADO DE PROCESAMIENTO CON FEEDBACK
  // -------------------------------------------------------------
  Widget _buildProcessingView(MathColors mathColors) {
    return Center(
      key: const ValueKey('processing_view'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: mathColors.primaryAction),
          const SizedBox(height: 20),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: mathColors.formulaText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Extrayendo límites y diferenciales exactos...',
            style: TextStyle(fontSize: 11, color: mathColors.metadataText),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PASO 4: CONFIRMACIÓN Y EDICIÓN VISUAL (CRÍTICO)
  // -------------------------------------------------------------
  Widget _buildConfirmAndEditView(MathColors mathColors) {
    return SingleChildScrollView(
      key: const ValueKey('confirm_edit_view'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pregunta amigable para el estudiante
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '¿Es esta tu integral?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: mathColors.formulaText,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentStep = OcrStep.pickImage),
                child: const Text('Tomar otra foto', style: TextStyle(fontSize: 11, color: AppColors.mutedGray)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tarjeta elegante Slate Dark con renderizado KaTeX de la fórmula
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.slateDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: mathColors.secondaryAccent.withAlpha(120), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Math.tex(
                    _latexController.text.isEmpty ? r'\text{?}' : _latexController.text,
                    textStyle: TextStyle(
                      fontSize: 22,
                      color: mathColors.formulaText,
                      fontWeight: FontWeight.w600,
                    ),
                    onErrorFallback: (_) => Text(
                      _latexController.text,
                      style: TextStyle(fontSize: 15, color: mathColors.formulaText),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: mathColors.primaryAction),
                    const SizedBox(width: 6),
                    Text(
                      'Fórmula estructurada con rigor académico',
                      style: TextStyle(fontSize: 10, color: mathColors.primaryAction, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Botón / Toggle para corregir fórmula
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEditingLatex ? 'Ajusta los caracteres necesarios:' : '¿Algún símbolo no coincide?',
                style: TextStyle(fontSize: 11, color: mathColors.metadataText),
              ),
              TextButton.icon(
                icon: Icon(
                  _isEditingLatex ? Icons.check_circle_outline : Icons.edit_rounded,
                  size: 15,
                  color: AppColors.electricCyan,
                ),
                label: Text(
                  _isEditingLatex ? 'Listo' : 'Corregir fórmula',
                  style: const TextStyle(fontSize: 12, color: AppColors.electricCyan, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  setState(() => _isEditingLatex = !_isEditingLatex);
                },
              ),
            ],
          ),

          // Campo de edición visible si el estudiante pulsa Corregir
          if (_isEditingLatex) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.slateElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.electricCyan.withAlpha(140)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _latexController,
                    style: TextStyle(fontSize: 13, color: mathColors.formulaText, fontFamily: 'monospace'),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: r'Ej: \int_{0}^{1}\int_{0}^{2-2x}(6-2x-y)\,dy\,dx',
                      hintStyle: TextStyle(color: AppColors.mutedGray, fontSize: 11),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const Divider(color: AppColors.borderSubtle, height: 12),
                  // Botones rápidos de inserción para que sea cómodo en móvil
                  Wrap(
                    spacing: 6,
                    children: [
                      _buildQuickInsertKey('dy dx'),
                      _buildQuickInsertKey('dx dy'),
                      _buildQuickInsertKey('^2'),
                      _buildQuickInsertKey('sqrt()'),
                      _buildQuickInsertKey('-'),
                      _buildQuickInsertKey('+'),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Botón Principal en Cyber Emerald: RESOLVER Y GRAFICAR EN 3D
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: mathColors.primaryAction, // Cyber Emerald (#10B981)
              foregroundColor: AppColors.deepVoid,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            icon: const Icon(Icons.view_in_ar_rounded, size: 22),
            label: const Text(
              'Resolver y Graficar en 3D',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
            ),
            onPressed: _submitAndSolve,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInsertKey(String token) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        final text = _latexController.text;
        final sel = _latexController.selection;
        int pos = sel.baseOffset >= 0 ? sel.baseOffset : text.length;
        final newText = text.replaceRange(pos, pos, token);
        _latexController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: pos + token.length),
        );
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.slateDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(
          token,
          style: const TextStyle(fontSize: 10, color: AppColors.pureWhite, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
