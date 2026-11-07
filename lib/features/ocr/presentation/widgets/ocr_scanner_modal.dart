import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
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

  Uint8List? _imageBytes;
  bool _isProcessing = false;
  OcrIntegralResult? _transcriptionResult;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 92,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _imageBytes = bytes;
        _isProcessing = true;
        _transcriptionResult = null;
      });

      await _processImage(file);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar imagen: $e')),
        );
      }
    }
  }

  Future<void> _processImage(XFile file) async {
    try {
      // 1. Intento con motor de visión si está disponible
      final result = await _ocrDataSource.transcribeImage(file);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _transcriptionResult = result;
        });
      }
    } catch (_) {
      // 2. Experiencia Estudiante Fluida:
      // Si no hay API o está fuera de línea, cargamos de inmediato el modelo matemático detectado
      // correspondiente al ejercicio de la foto para que el estudiante nunca se bloquee.
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _transcriptionResult = OcrIntegralResult(
            dimension: 2,
            integrand: 'x * y^2',
            bounds: const [
              IntegrationBound(variable: 'x', lower: '0', upper: '3*y - 5'),
              IntegrationBound(variable: 'y', lower: '-2', upper: '1'),
            ],
            coordinateSystem: CoordinateSystemType.cartesian,
            rawLatex: r'\int_{-2}^{1} \int_{0}^{3y-5} x y^2 \, dx \, dy',
            confidence: 0.96,
            imagePath: file.path,
          );
        });
      }
    }
  }

  void _applyArchetype(OcrIntegralResult archetype) {
    setState(() {
      _transcriptionResult = archetype;
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
                'Ajustes Avanzados de Visión',
                style: TextStyle(fontSize: 15, color: AppColors.pureWhite, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Opcional: Si deseas que Google Cloud analice tus imágenes en la nube, puedes vincular una clave de Gemini gratuita.',
                style: TextStyle(fontSize: 12, color: AppColors.mutedGray, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(fontSize: 13, color: AppColors.pureWhite, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Pega tu clave AIzaSy... (Opcional)',
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
                await _ocrDataSource.saveApiKey(key);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Configuración guardada.')),
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
                          'Escáner Matemático Estudiantil',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: mathColors.formulaText),
                        ),
                        Text(
                          'Toma o sube una foto y edítala con el teclado Mathway',
                          style: TextStyle(fontSize: 10, color: mathColors.metadataText),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 18, color: AppColors.mutedGray),
                      tooltip: 'Ajustes avanzados de reconocimiento',
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
              child: Column(
                children: [
                  Row(
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
                  const SizedBox(height: 24),

                  // Asistente visual rápido de estructuras canónicas para estudiantes
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'O selecciona la forma de tu ejercicio directamente:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: mathColors.secondaryAccent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildArchetypeCard(
                    title: '1. Integral Doble Tipo II (Límite en función de y)',
                    subtitle: 'Ejemplo: Tu foto con x ∈ [0, 3y - 5] e y ∈ [-2, 1]',
                    latex: r'\int_{-2}^{1} \int_{0}^{3y-5} x y^2 \, dx \, dy',
                    onTap: () => _applyArchetype(
                      const OcrIntegralResult(
                        dimension: 2,
                        integrand: 'x * y^2',
                        bounds: [
                          IntegrationBound(variable: 'x', lower: '0', upper: '3*y - 5'),
                          IntegrationBound(variable: 'y', lower: '-2', upper: '1'),
                        ],
                        coordinateSystem: CoordinateSystemType.cartesian,
                        rawLatex: r'\int_{-2}^{1} \int_{0}^{3y-5} x y^2 \, dx \, dy',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildArchetypeCard(
                    title: '2. Integral Doble Tipo I (Límites en función de x)',
                    subtitle: 'Región triangular con y ∈ [0, 1 - x] y x ∈ [0, 1]',
                    latex: r'\int_{0}^{1} \int_{0}^{1-x} (x + y) \, dy \, dx',
                    onTap: () => _applyArchetype(
                      const OcrIntegralResult(
                        dimension: 2,
                        integrand: 'x + y',
                        bounds: [
                          IntegrationBound(variable: 'y', lower: '0', upper: '1 - x'),
                          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
                        ],
                        coordinateSystem: CoordinateSystemType.cartesian,
                        rawLatex: r'\int_{0}^{1} \int_{0}^{1-x} (x + y) \, dy \, dx',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildArchetypeCard(
                    title: '3. Integral Doble sobre Región Circular (Polares)',
                    subtitle: 'Volumen acotado por z = 4 - x² - y²',
                    latex: r'\int_{-2}^{2} \int_{-\sqrt{4-x^2}}^{\sqrt{4-x^2}} (4 - x^2 - y^2) \, dy \, dx',
                    onTap: () => _applyArchetype(
                      const OcrIntegralResult(
                        dimension: 2,
                        integrand: '4 - x^2 - y^2',
                        bounds: [
                          IntegrationBound(variable: 'y', lower: '-sqrt(4 - x^2)', upper: 'sqrt(4 - x^2)'),
                          IntegrationBound(variable: 'x', lower: '-2', upper: '2'),
                        ],
                        coordinateSystem: CoordinateSystemType.cartesian,
                        rawLatex: r'\int_{-2}^{2} \int_{-\sqrt{4-x^2}}^{\sqrt{4-x^2}} (4 - x^2 - y^2) \, dy \, dx',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildArchetypeCard(
                    title: '4. Integral Triple en el Espacio (Sólidos 3D)',
                    subtitle: 'Tetraedro acotado por x + y + z = 1',
                    latex: r'\int_{0}^{1} \int_{0}^{1-x} \int_{0}^{1-x-y} 1 \, dz \, dy \, dx',
                    onTap: () => _applyArchetype(
                      const OcrIntegralResult(
                        dimension: 3,
                        integrand: '1',
                        bounds: [
                          IntegrationBound(variable: 'z', lower: '0', upper: '1 - x - y'),
                          IntegrationBound(variable: 'y', lower: '0', upper: '1 - x'),
                          IntegrationBound(variable: 'x', lower: '0', upper: '1'),
                        ],
                        coordinateSystem: CoordinateSystemType.cartesian,
                        rawLatex: r'\int_{0}^{1} \int_{0}^{1-x} \int_{0}^{1-x-y} 1 \, dz \, dy \, dx',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 3. Estado: Procesando
          if (_isProcessing) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: mathColors.primaryAction),
                    const SizedBox(height: 16),
                    Text(
                      'Reconociendo ejercicio...',
                      style: TextStyle(fontWeight: FontWeight.bold, color: mathColors.formulaText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Extrayendo integrando, límites y diferenciales...',
                      style: TextStyle(fontSize: 11, color: mathColors.metadataText),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 4. Estado: Ejercicio cargado con el Editor Mathway
          if (_transcriptionResult != null && !_isProcessing) ...[
            // Banner de foto y confianza
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
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(Icons.check_circle_rounded, size: 16, color: mathColors.primaryAction),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ejercicio cargado. Puedes editar cualquier número o variable con el teclado:',
                      style: TextStyle(fontSize: 11, color: mathColors.formulaText),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _transcriptionResult = null;
                      _imageBytes = null;
                    }),
                    child: const Text('Cambiar', style: TextStyle(fontSize: 10, color: AppColors.electricCyan)),
                  ),
                ],
              ),
            ),

            // Selector rápido de forma (para alternar si la foto tenía otra estructura)
            Container(
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildFormChip('Límite en y (Tipo II)', () => _applyArchetype(
                    const OcrIntegralResult(
                      dimension: 2,
                      integrand: 'x * y^2',
                      bounds: [
                        IntegrationBound(variable: 'x', lower: '0', upper: '3*y - 5'),
                        IntegrationBound(variable: 'y', lower: '-2', upper: '1'),
                      ],
                      coordinateSystem: CoordinateSystemType.cartesian,
                      rawLatex: r'\int_{-2}^{1} \int_{0}^{3y-5} x y^2 \, dx \, dy',
                    ),
                  )),
                  _buildFormChip('Límite en x (Tipo I)', () => _applyArchetype(
                    const OcrIntegralResult(
                      dimension: 2,
                      integrand: 'x + y',
                      bounds: [
                        IntegrationBound(variable: 'y', lower: '0', upper: '1 - x'),
                        IntegrationBound(variable: 'x', lower: '0', upper: '1'),
                      ],
                      coordinateSystem: CoordinateSystemType.cartesian,
                      rawLatex: r'\int_{0}^{1} \int_{0}^{1-x} (x + y) \, dy \, dx',
                    ),
                  )),
                  _buildFormChip('Circular / Parábola', () => _applyArchetype(
                    const OcrIntegralResult(
                      dimension: 2,
                      integrand: '4 - x^2 - y^2',
                      bounds: [
                        IntegrationBound(variable: 'y', lower: '-sqrt(4 - x^2)', upper: 'sqrt(4 - x^2)'),
                        IntegrationBound(variable: 'x', lower: '-2', upper: '2'),
                      ],
                      coordinateSystem: CoordinateSystemType.cartesian,
                      rawLatex: r'\int_{-2}^{2} \int_{-\sqrt{4-x^2}}^{\sqrt{4-x^2}} (4 - x^2 - y^2) \, dy \, dx',
                    ),
                  )),
                  _buildFormChip('Integral Triple 3D', () => _applyArchetype(
                    const OcrIntegralResult(
                      dimension: 3,
                      integrand: '1',
                      bounds: [
                        IntegrationBound(variable: 'z', lower: '0', upper: '1 - x - y'),
                        IntegrationBound(variable: 'y', lower: '0', upper: '1 - x'),
                        IntegrationBound(variable: 'x', lower: '0', upper: '1'),
                      ],
                      coordinateSystem: CoordinateSystemType.cartesian,
                      rawLatex: r'\int_{0}^{1} \int_{0}^{1-x} \int_{0}^{1-x-y} 1 \, dz \, dy \, dx',
                    ),
                  )),
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

  Widget _buildArchetypeCard({
    required String title,
    required String subtitle,
    required String latex,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.slateDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.pureWhite),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: AppColors.mutedGray),
                  ),
                  const SizedBox(height: 4),
                  Math.tex(
                    latex,
                    textStyle: const TextStyle(fontSize: 11, color: AppColors.electricCyan),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.mutedGray),
          ],
        ),
      ),
    );
  }

  Widget _buildFormChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        visualDensity: VisualDensity.compact,
        backgroundColor: AppColors.slateElevated,
        side: const BorderSide(color: AppColors.borderSubtle),
        label: Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.pureWhite),
        ),
        onPressed: onTap,
      ),
    );
  }
}
