import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/math_colors.dart';
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
        imageQuality: 90,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _imageBytes = bytes;
        _isProcessing = true;
        _transcriptionResult = null;
      });

      final result = await _ocrDataSource.transcribeImage(file);

      setState(() {
        _isProcessing = false;
        _transcriptionResult = result;
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

  @override
  Widget build(BuildContext context) {
    final mathColors = context.mathColors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: AppColors.deepVoid, // #0D1117
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1.5)),
      ),
      child: Column(
        children: [
          // 1. Barra superior / Handle
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
                          'Escáner Matemático OCR & Corrector Mathway',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: mathColors.formulaText),
                        ),
                        Text(
                          'Sube tu ejercicio y edítalo visualmente con el teclado',
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

          // 2. Acciones de cámara y galería (si aún no se ha transcrito)
          if (_transcriptionResult == null) ...[
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

          // 3. Indicador de Procesamiento
          if (_isProcessing) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: mathColors.primaryAction),
                    const SizedBox(height: 16),
                    Text(
                      'Reconociendo fórmula matemática...',
                      style: TextStyle(fontWeight: FontWeight.bold, color: mathColors.formulaText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Transcribiendo integral multivariable con precisión...',
                      style: TextStyle(fontSize: 11, color: mathColors.metadataText),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 4. Editor Visual Mathway Completo con la Integral Transcrita
          if (_transcriptionResult != null && !_isProcessing) ...[
            // Banner de éxito en transcripción
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
                      'Transcripción exitosa (${(_transcriptionResult!.confidence * 100).toInt()}%). Puedes tocar cualquier parte para corregirla con el teclado:',
                      style: TextStyle(fontSize: 11, color: mathColors.formulaText),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _transcriptionResult = null;
                      _imageBytes = null;
                    }),
                    child: const Text('Cambiar Foto', style: TextStyle(fontSize: 10, color: AppColors.electricCyan)),
                  ),
                ],
              ),
            ),

            // Editor visual Mathway acoplado
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
