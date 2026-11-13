import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/latex_sanitizer.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../solver/domain/entities/integral_solution.dart';
import '../../domain/entities/domain_2d_model.dart';
import '../../domain/services/domain_2d_extractor.dart';

class UvPlaneViewport extends StatelessWidget {
  final MultivariableIntegral integral;
  final IntegralSolution? solution;

  const UvPlaneViewport({
    super.key,
    required this.integral,
    this.solution,
  });

  @override
  Widget build(BuildContext context) {
    final domain = Domain2DExtractor.extract(
      integral: integral,
      solution: solution,
    );
    final uv = domain.uvMapping;

    if (uv == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.slateDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.violetHeatmap.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.violetHeatmap.withAlpha(110)),
              ),
              child: const Icon(
                Icons.transform_rounded,
                size: 32,
                color: AppColors.violetHeatmap,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Visor del Plano UV (Transformación Jacobiana)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.pureWhite,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Este visor se activa automáticamente cuando el ejercicio utiliza cambio de variables (u, v) o coordenadas polares / cilíndricas (r, θ), mostrando cómo la región curvilínea R en XY se transforma en un rectángulo simple en UV.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedGray,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.deepVoid,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Math.tex(
                r'dA = dx\,dy = \left|\frac{\partial(x,y)}{\partial(u,v)}\right| du\,dv',
                textStyle: const TextStyle(fontSize: 13, color: AppColors.electricCyan),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with Transformation Equations & Jacobian
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.slateDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.violetHeatmap.withAlpha(120)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.transform_rounded, size: 15, color: AppColors.violetHeatmap),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      uv.title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.pureWhite,
                      ),
                    ),
                  ),
                ],
              ),
              if (uv.transformForwardLatex.isNotEmpty || uv.jacobianLatex.isNotEmpty) ...[
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(
                    LatexSanitizer.sanitize(
                      [
                        if (uv.transformInverseLatex.isNotEmpty) uv.transformInverseLatex,
                        if (uv.transformForwardLatex.isNotEmpty) uv.transformForwardLatex,
                        if (uv.jacobianLatex.isNotEmpty) uv.jacobianLatex,
                      ].join(r', \quad '),
                    ),
                    textStyle: const TextStyle(fontSize: 12, color: AppColors.electricCyan),
                    onErrorFallback: (_) => Text(
                      uv.jacobianLatex,
                      style: const TextStyle(fontSize: 11, color: AppColors.electricCyan),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Dual XY <-> UV Canvas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final paneXy = _buildPane(
                label: 'Plano Original XY (Región R)',
                accent: AppColors.violetHeatmap,
                painter: _UvTransformCanvasPainter(
                  domain: domain,
                  uv: uv,
                  isUvPlane: false,
                ),
              );
              final paneUv = _buildPane(
                label: 'Plano Transformado (${uv.uVarLabel}, ${uv.vVarLabel})',
                accent: AppColors.cyberEmerald,
                painter: _UvTransformCanvasPainter(
                  domain: domain,
                  uv: uv,
                  isUvPlane: true,
                ),
              );
              final arrowBadge = Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.slateElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.amberGlow.withAlpha(140)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isWide ? Icons.arrow_forward_rounded : Icons.arrow_downward_rounded,
                        size: 16,
                        color: AppColors.amberGlow,
                      ),
                      const Text(
                        'T⁻¹',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amberGlow,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: paneXy),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: arrowBadge,
                    ),
                    Expanded(child: paneUv),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(child: paneXy),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: arrowBadge,
                  ),
                  Expanded(child: paneUv),
                ],
              );
            },
          ),
        ),

        if (uv.transformedIntegralLatex.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.slateDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cyberEmerald.withAlpha(110)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                LatexSanitizer.sanitize(uv.transformedIntegralLatex),
                textStyle: const TextStyle(fontSize: 13.5, color: AppColors.pureWhite),
                onErrorFallback: (_) => Text(
                  LatexSanitizer.toReadableUnicode(uv.transformedIntegralLatex),
                  style: const TextStyle(fontSize: 12, color: AppColors.pureWhite),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPane({
    required String label,
    required Color accent,
    required CustomPainter painter,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.deepVoid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(110)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CustomPaint(size: Size.infinite, painter: painter),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.slateDark.withAlpha(220),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accent.withAlpha(130)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UvTransformCanvasPainter extends CustomPainter {
  final Domain2DModel domain;
  final UvMappingModel uv;
  final bool isUvPlane;

  const _UvTransformCanvasPainter({
    required this.domain,
    required this.uv,
    required this.isUvPlane,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.deepVoid);
    if (size.width <= 0 || size.height <= 0) return;

    if (isUvPlane) {
      _paintUvRect(canvas, size);
    } else {
      _paintXyCurvilinear(canvas, size);
    }
  }

  void _paintUvRect(Canvas canvas, Size size) {
    final uMin = uv.uMin;
    final uMax = uv.uMax;
    final vMin = uv.vMin;
    final vMax = uv.vMax;

    final spanU = math.max(0.5, (uMax - uMin).abs());
    final spanV = math.max(0.5, (vMax - vMin).abs());

    // Add margin around rectangle
    final padU = spanU * 0.35;
    final padV = spanV * 0.35;
    final wMinU = math.min(0.0, uMin) - padU;
    final wMaxU = uMax + padU;
    final wMinV = math.min(0.0, vMin) - padV;
    final wMaxV = vMax + padV;

    Offset toScreen(double u, double v) {
      final nx = (u - wMinU) / math.max(1e-6, wMaxU - wMinU);
      final ny = (v - wMinV) / math.max(1e-6, wMaxV - wMinV);
      return Offset(
        18 + nx * (size.width - 36),
        size.height - 22 - ny * (size.height - 44),
      );
    }

    // Axes
    final o = toScreen(0, 0);
    canvas.drawLine(
      Offset(10, o.dy.clamp(24.0, size.height - 16.0)),
      Offset(size.width - 10, o.dy.clamp(24.0, size.height - 16.0)),
      Paint()..color = AppColors.coralFlame.withAlpha(140)..strokeWidth = 1.2,
    );
    canvas.drawLine(
      Offset(o.dx.clamp(16.0, size.width - 16.0), 22),
      Offset(o.dx.clamp(16.0, size.width - 16.0), size.height - 12),
      Paint()..color = AppColors.limePhosphor.withAlpha(140)..strokeWidth = 1.2,
    );

    // Simple rectangle in UV
    final p00 = toScreen(uMin, vMin);
    final p10 = toScreen(uMax, vMin);
    final p11 = toScreen(uMax, vMax);
    final p01 = toScreen(uMin, vMax);

    final rectPath = Path()
      ..moveTo(p00.dx, p00.dy)
      ..lineTo(p10.dx, p10.dy)
      ..lineTo(p11.dx, p11.dy)
      ..lineTo(p01.dx, p01.dy)
      ..close();

    canvas.drawPath(rectPath, Paint()..color = AppColors.cyberEmerald.withAlpha(64));
    canvas.drawPath(
      rectPath,
      Paint()
        ..color = AppColors.cyberEmerald
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Internal UV grid lines
    final gridPaint = Paint()
      ..color = AppColors.cyberEmerald.withAlpha(90)
      ..strokeWidth = 0.9;
    for (int k = 1; k < 5; k++) {
      final f = k / 5.0;
      final uk = uMin + (uMax - uMin) * f;
      final vk = vMin + (vMax - vMin) * f;
      canvas.drawLine(toScreen(uk, vMin), toScreen(uk, vMax), gridPaint);
      canvas.drawLine(toScreen(uMin, vk), toScreen(uMax, vk), gridPaint);
    }

    // Corner labels
    _drawMiniText(canvas, '${uv.uVarLabel}∈[${_fmt(uMin)}, ${_fmt(uMax)}]', Offset(p00.dx, p00.dy + 4), AppColors.cyberEmerald);
    _drawMiniText(canvas, '${uv.vVarLabel}∈[${_fmt(vMin)}, ${_fmt(vMax)}]', Offset(p01.dx, p01.dy - 14), AppColors.electricCyan);
  }

  void _paintXyCurvilinear(Canvas canvas, Size size) {
    // Collect sample points from shadedRegions or mapUvToXy
    final pts = <Offset>[];
    for (final poly in domain.shadedRegions) {
      pts.addAll(poly);
    }
    if (pts.isEmpty && uv.mapUvToXy != null) {
      for (int i = 0; i <= 16; i++) {
        for (int j = 0; j <= 16; j++) {
          final u = uv.uMin + (uv.uMax - uv.uMin) * (i / 16);
          final v = uv.vMin + (uv.vMax - uv.vMin) * (j / 16);
          pts.add(uv.mapUvToXy!(u, v));
        }
      }
    }

    double minX = -2, maxX = 2, minY = -2, maxY = 2;
    if (pts.isNotEmpty) {
      minX = pts.map((p) => p.dx).reduce(math.min);
      maxX = pts.map((p) => p.dx).reduce(math.max);
      minY = pts.map((p) => p.dy).reduce(math.min);
      maxY = pts.map((p) => p.dy).reduce(math.max);
    }
    final padX = math.max(0.5, (maxX - minX) * 0.25);
    final padY = math.max(0.5, (maxY - minY) * 0.25);
    final wMinX = minX - padX;
    final wMaxX = maxX + padX;
    final wMinY = minY - padY;
    final wMaxY = maxY + padY;

    Offset toScreen(double x, double y) {
      final nx = (x - wMinX) / math.max(1e-6, wMaxX - wMinX);
      final ny = (y - wMinY) / math.max(1e-6, wMaxY - wMinY);
      return Offset(
        18 + nx * (size.width - 36),
        size.height - 20 - ny * (size.height - 42),
      );
    }

    // Axes
    final o = toScreen(0, 0);
    if (o.dy >= 20 && o.dy <= size.height - 10) {
      canvas.drawLine(
        Offset(10, o.dy),
        Offset(size.width - 10, o.dy),
        Paint()..color = AppColors.coralFlame.withAlpha(140)..strokeWidth = 1.2,
      );
    }
    if (o.dx >= 10 && o.dx <= size.width - 10) {
      canvas.drawLine(
        Offset(o.dx, 22),
        Offset(o.dx, size.height - 10),
        Paint()..color = AppColors.limePhosphor.withAlpha(140)..strokeWidth = 1.2,
      );
    }

    // Shaded region R
    for (final poly in domain.shadedRegions) {
      if (poly.length < 3) continue;
      final path = Path();
      final p0 = toScreen(poly.first.dx, poly.first.dy);
      path.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < poly.length; i++) {
        final pi = toScreen(poly[i].dx, poly[i].dy);
        path.lineTo(pi.dx, pi.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = AppColors.violetHeatmap.withAlpha(64));
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.violetHeatmap
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // Draw curvilinear UV grid inside XY
    if (uv.mapUvToXy != null) {
      final gridPaint = Paint()
        ..color = AppColors.electricCyan.withAlpha(115)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      for (int k = 0; k <= 5; k++) {
        final uFixed = uv.uMin + (uv.uMax - uv.uMin) * (k / 5.0);
        final pth = Path();
        for (int j = 0; j <= 24; j++) {
          final v = uv.vMin + (uv.vMax - uv.vMin) * (j / 24.0);
          final xy = uv.mapUvToXy!(uFixed, v);
          final sp = toScreen(xy.dx, xy.dy);
          if (j == 0) {
            pth.moveTo(sp.dx, sp.dy);
          } else {
            pth.lineTo(sp.dx, sp.dy);
          }
        }
        canvas.drawPath(pth, gridPaint);

        final vFixed = uv.vMin + (uv.vMax - uv.vMin) * (k / 5.0);
        final pth2 = Path();
        for (int i = 0; i <= 24; i++) {
          final u = uv.uMin + (uv.uMax - uv.uMin) * (i / 24.0);
          final xy = uv.mapUvToXy!(u, vFixed);
          final sp = toScreen(xy.dx, xy.dy);
          if (i == 0) {
            pth2.moveTo(sp.dx, sp.dy);
          } else {
            pth2.lineTo(sp.dx, sp.dy);
          }
        }
        canvas.drawPath(pth2, gridPaint);
      }
    }
  }

  void _drawMiniText(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  String _fmt(double v) {
    if ((v - v.roundToDouble()).abs() < 1e-4) return '${v.round()}';
    if ((v - math.pi).abs() < 1e-2) return 'π';
    if ((v - 2 * math.pi).abs() < 1e-2) return '2π';
    if ((v - math.pi / 2).abs() < 1e-2) return 'π/2';
    if ((v + math.pi / 2).abs() < 1e-2) return '-π/2';
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  bool shouldRepaint(covariant _UvTransformCanvasPainter oldDelegate) {
    return oldDelegate.domain != domain ||
        oldDelegate.uv != uv ||
        oldDelegate.isUvPlane != isUvPlane;
  }
}
