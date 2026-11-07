import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/math_colors.dart';
import '../../../calculator/domain/entities/integration_bound.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../calculator/presentation/widgets/mathway_formula_editor.dart';
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

  XFile? _selectedFile;
  Uint8List? _imageBytes;
  bool _isProcessing = false;
  bool _needsApiKey = false;
  String? _errorMessage;
  OcrIntegralResult? _transcriptionResult;

  @override
  void initState() {
    super.initState();
    _checkApiKeyStatus();
  }

  Future<void> _checkApiKeyStatus() async {
    final key = await _ocrDataSource.getSavedApiKey();
    if (mounted) {
      setState(() {
        _needsApiKey = (key == null || key.isEmpty);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 92,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _selectedFile = file;
        _imageBytes = bytes;
        _isProcessing = true;
        _errorMessage = null;
        _transcriptionResult = null;
      });

      await _processImage(file);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error al seleccionar imagen: $e';
      });
    }
  }

  Future<void> _processImage(XFile file) async {
    try {
      final result = await _ocrDataSource.transcribeImage(file);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _transcriptionResult = result;
          _needsApiKey = false;
        });
      }
    } on OcrNeedsApiKeyException {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _needsApiKey = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _loadDemoIntegral() {
    setState(() {
      _transcriptionResult = OcrIntegralResult(
        dimension: 2,
        integrand: 'x * y^2',
        bounds: const [
          IntegrationBound(variable: 'x', lower: '0', upper: '3*y - 5'),
          IntegrationBound(variable: 'y', lower: '-2', upper: '1'),
        ],
        coordinateSystem: CoordinateSystemType.cartesian,
        rawLatex: r'\int_{-2}^{1} \int_{0}^{3y-5} x y^2 \, dx \, dy',
        confidence: 0.98,
        imagePath: _selectedFile?.path,
      );
      _needsApiKey = false;
      _errorMessage = null;
    });
  }

  void _showApiKeyDialog() async {
    final currentKey = await _ocrDataSource.getSavedApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.slateDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: AppColors.electricCyan, size: 22),
              SizedBox(width: 8),
              Text(
                'Gemini Vision API Key',
                style: TextStyle(fontSize: 16, color: AppColors.pureWhite, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para transcribir cualquier foto de integrales dobles o triples con IA en Android e iOS, ingresa tu clave gratuita de Google AI Studio.',
                style: TextStyle(fontSize: 12, color: AppColors.mutedGray, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(fontSize: 13, color: AppColors.pureWhite, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Pega tu clave AIzaSy...',
                  hintStyle: const TextStyle(color: AppColors.mutedGray, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.slateElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.mutedGray),
                    onPressed: () => controller.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '100% gratuita en: aistudio.google.com/app/apikey',
                style: TextStyle(fontSize: 10, color: AppColors.electricCyan),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.mutedGray)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyberEmerald,
                foregroundColor: AppColors.deepVoid,
              ),
              onPressed: () async {
                final key = controller.text.trim();
                if (key.isNotEmpty) {
                  await _ocrDataSource.saveApiKey(key);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API Key guardada correctamente.')),
                    );
                    if (_selectedFile != null) {
                      setState(() => _isProcessing = true);
                      _processImage(_selectedFile!);
                    } else {
                      setState(() => _needsApiKey = false);
                    }
                  }
                }
              },
              child: const Text('Guardar y Activar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mathColors = context.mathColors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: AppColors.deepVoid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1.5)),
      ),
      child: Column(
        children: [
          // 1. Barra superior
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.slateDark,
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
                          'Escáner Matemático OCR & Editor Mathway',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: mathColors.formulaText),
                        ),
                        Text(
                          'Reconoce cualquier integral doble o triple y corrígela',
                          style: TextStyle(fontSize: 10, color: mathColors.metadataText),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.vpn_key_rounded, size: 20, color: AppColors.amberGlow),
                      tooltip: 'Configurar Gemini Vision API Key',
                      onPressed: _showApiKeyDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.mutedGray),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Botones de captura / subida de foto
          if (_transcriptionResult == null && !_isProcessing) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.slateElevated,
                        foregroundColor: mathColors.formulaText,
                        side: const BorderSide(color: AppColors.borderSubtle),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(Icons.camera_alt_rounded, size: 20, color: mathColors.secondaryAccent),
                      label: const Text('Tomar Foto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(Icons.photo_library_rounded, size: 20, color: mathColors.primaryAction),
                      label: const Text('Subir Imagen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 3. Estado: Procesando con IA
          if (_isProcessing) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: mathColors.primaryAction),
                    const SizedBox(height: 16),
                    Text(
                      'Reconociendo fórmula con Gemini Vision AI...',
                      style: TextStyle(fontWeight: FontWeight.bold, color: mathColors.formulaText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Analizando integrando, límites y diferenciales en la imagen...',
                      style: TextStyle(fontSize: 11, color: mathColors.metadataText),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 4. Estado: Requiere API Key o Mensaje de Error
          if (_needsApiKey && !_isProcessing && _transcriptionResult == null) ...[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.slateDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.amberGlow.withAlpha(120)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: AppColors.amberGlow, size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Reconocimiento Universal con IA',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.pureWhite,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Para que la app reconozca cualquier ejercicio escrito a mano o de libros en Android e iOS, conecta tu API Key gratuita de Google Gemini.',
                            style: TextStyle(fontSize: 12, color: AppColors.mutedGray, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.amberGlow,
                                    foregroundColor: AppColors.deepVoid,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.vpn_key_rounded, size: 16),
                                  label: const Text('Ingresar API Key Gratuita', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: _showApiKeyDialog,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.borderSubtle),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.flash_on_rounded, size: 16, color: AppColors.electricCyan),
                                  label: const Text(
                                    'Usar Foto de Muestra (Demostración)',
                                    style: TextStyle(color: AppColors.pureWhite, fontSize: 12),
                                  ),
                                  onPressed: _loadDemoIntegral,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.coralFlame, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // 5. Estado: Transcripción lista con el Editor Mathway
          if (_transcriptionResult != null && !_isProcessing) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: mathColors.primaryAction.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: mathColors.primaryAction.withAlpha(90)),
              ),
              child: Row(
                children: [
                  if (_imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.memory(
                        _imageBytes!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(Icons.check_circle_rounded, size: 16, color: mathColors.primaryAction),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Transcripción exitosa (${(_transcriptionResult!.confidence * 100).toInt()}%). Corrige cualquier dato con el teclado:',
                      style: TextStyle(fontSize: 11, color: mathColors.formulaText),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _transcriptionResult = null;
                      _imageBytes = null;
                      _selectedFile = null;
                    }),
                    child: const Text('Cambiar Foto', style: TextStyle(fontSize: 10, color: AppColors.electricCyan)),
                  ),
                ],
              ),
            ),

            // Editor visual Mathway con teclado integrado
            Expanded(
              child: MathwayFormulaEditor(
                initialIntegral: _transcriptionResult!.toMultivariableIntegral(),
                onSolve: (integral) {
                  widget.onIntegralAccepted(integral);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
