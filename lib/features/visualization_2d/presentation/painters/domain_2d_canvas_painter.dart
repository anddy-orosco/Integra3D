import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/domain_2d_model.dart';

class Domain2DCanvasPainter extends CustomPainter {
  final Domain2DModel domain;
  final SweepOrderType sweepOrder;
  final double sweepProgress; // 0.0 to 1.0 along domain span
  final double zoom;
  final Offset pan;
  final double baseScale; // world units to screen pixels multiplier

  const Domain2DCanvasPainter({
    required this.domain,
    required this.sweepOrder,
    required this.sweepProgress,
    required this.zoom,
    required this.pan,
    this.baseScale = 44.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.deepVoid,
    );

    if (size.width <= 0 || size.height <= 0) return;

    // Auto-fit world center based on domain bounds
    final worldCenterX = (domain.xMin + domain.xMax) / 2.0;
    final worldCenterY = (domain.yMin + domain.yMax) / 2.0;
    final spanX = math.max(1.5, (domain.xMax - domain.xMin).abs());
    final spanY = math.max(1.5, (domain.yMax - domain.yMin).abs());
    final fitPixelsPerUnit = math.min(
      (size.width * 0.62) / spanX,
      (size.height * 0.62) / spanY,
    ).clamp(16.0, 120.0);

    final effectiveScale = (fitPixelsPerUnit * zoom).clamp(6.0, 600.0);
    final screenCenter = Offset(size.width / 2.0, size.height / 2.0) + pan;

    Offset toScreen(double wx, double wy) {
      return Offset(
        screenCenter.dx + (wx - worldCenterX) * effectiveScale,
        screenCenter.dy - (wy - worldCenterY) * effectiveScale,
      );
    }

    Offset toWorld(Offset s) {
      return Offset(
        worldCenterX + (s.dx - screenCenter.dx) / effectiveScale,
        worldCenterY - (s.dy - screenCenter.dy) / effectiveScale,
      );
    }

    final topLeftWorld = toWorld(Offset.zero);
    final bottomRightWorld = toWorld(Offset(size.width, size.height));
    final visXMin = math.min(topLeftWorld.dx, bottomRightWorld.dx);
    final visXMax = math.max(topLeftWorld.dx, bottomRightWorld.dx);
    final visYMin = math.min(topLeftWorld.dy, bottomRightWorld.dy);
    final visYMax = math.max(topLeftWorld.dy, bottomRightWorld.dy);

    // 1. Adaptive Grid
    final gridStep = _niceGridStep(effectiveScale);
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle.withAlpha(90)
      ..strokeWidth = 0.8;

    final startX = (visXMin / gridStep).floor() * gridStep;
    for (double x = startX; x <= visXMax; x += gridStep) {
      final p1 = toScreen(x, visYMin);
      final p2 = toScreen(x, visYMax);
      canvas.drawLine(p1, p2, gridPaint);
    }

    final startY = (visYMin / gridStep).floor() * gridStep;
    for (double y = startY; y <= visYMax; y += gridStep) {
      final p1 = toScreen(visXMin, y);
      final p2 = toScreen(visXMax, y);
      canvas.drawLine(p1, p2, gridPaint);
    }

    // 2. Cartesian Axes & Ticks
    final originScreen = toScreen(0, 0);
    if (originScreen.dy >= -20 && originScreen.dy <= size.height + 20) {
      canvas.drawLine(
        Offset(0, originScreen.dy),
        Offset(size.width, originScreen.dy),
        Paint()
          ..color = AppColors.coralFlame.withAlpha(185)
          ..strokeWidth = 1.6,
      );
      _drawLabel(
        canvas,
        'X',
        Offset(size.width - 18, (originScreen.dy - 16).clamp(8.0, size.height - 20)),
        AppColors.coralFlame,
        fontSize: 11,
      );
    }

    if (originScreen.dx >= -20 && originScreen.dx <= size.width + 20) {
      canvas.drawLine(
        Offset(originScreen.dx, 0),
        Offset(originScreen.dx, size.height),
        Paint()
          ..color = AppColors.limePhosphor.withAlpha(185)
          ..strokeWidth = 1.6,
      );
      _drawLabel(
        canvas,
        'Y',
        Offset((originScreen.dx + 8).clamp(8.0, size.width - 20), 8),
        AppColors.limePhosphor,
        fontSize: 11,
      );
    }

    // Numeric Ticks
    for (double x = startX; x <= visXMax; x += gridStep) {
      if (x.abs() < gridStep * 0.1) continue;
      final sx = toScreen(x, 0).dx;
      if (sx < 14 || sx > size.width - 18) continue;
      final tickY = originScreen.dy.clamp(12.0, size.height - 16.0);
      canvas.drawLine(
        Offset(sx, tickY - 3),
        Offset(sx, tickY + 3),
        Paint()..color = AppColors.mutedGray.withAlpha(160)..strokeWidth = 1.0,
      );
      _drawTick(canvas, _formatTick(x), Offset(sx, tickY + 10));
    }

    for (double y = startY; y <= visYMax; y += gridStep) {
      if (y.abs() < gridStep * 0.1) continue;
      final sy = toScreen(0, y).dy;
      if (sy < 14 || sy > size.height - 14) continue;
      final tickX = originScreen.dx.clamp(18.0, size.width - 18.0);
      canvas.drawLine(
        Offset(tickX - 3, sy),
        Offset(tickX + 3, sy),
        Paint()..color = AppColors.mutedGray.withAlpha(160)..strokeWidth = 1.0,
      );
      _drawTick(canvas, _formatTick(y), Offset(tickX - 14, sy));
    }

    // 3. Shade Closed Region R in Cyber Emerald translucent (#10B981, alpha 0.25 = 64)
    final regionFillPaint = Paint()
      ..color = AppColors.cyberEmerald.withAlpha(64)
      ..style = PaintingStyle.fill;
    final regionBorderPaint = Paint()
      ..color = AppColors.cyberEmerald.withAlpha(170)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

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
      canvas.drawPath(path, regionFillPaint);
      canvas.drawPath(path, regionBorderPaint);
    }

    // Label 'R' inside centroid of primary shaded region
    if (domain.shadedRegions.isNotEmpty && domain.shadedRegions.first.length >= 3) {
      final poly = domain.shadedRegions.first;
      final cx = poly.fold(0.0, (s, p) => s + p.dx) / poly.length;
      final cy = poly.fold(0.0, (s, p) => s + p.dy) / poly.length;
      final cScreen = toScreen(cx, cy);
      _drawLabel(
        canvas,
        'R',
        cScreen + const Offset(10, -14),
        AppColors.cyberEmerald.withAlpha(220),
        fontSize: 14,
      );
    }

    // 4. Draw Boundary Curves (explicit, polar, implicit marching squares, segments)
    for (final curve in domain.curves) {
      _drawCurve(canvas, size, curve, toScreen, visXMin, visXMax, visYMin, visYMax);
    }

    // 5. Draw Animated Sweep Arrow ("Orden de Barrido")
    _drawSweepArrow(canvas, size, toScreen);

    // 6. Draw Intersection Points with Floating (x, y) Labels
    for (final pt in domain.intersectionPoints) {
      final pos = toScreen(pt.x, pt.y);
      if (pos.dx < -30 || pos.dx > size.width + 30 || pos.dy < -30 || pos.dy > size.height + 30) {
        continue;
      }

      // Outer glow
      canvas.drawCircle(
        pos,
        8.5,
        Paint()..color = AppColors.amberGlow.withAlpha(55),
      );
      // Inner circle
      canvas.drawCircle(
        pos,
        4.6,
        Paint()..color = AppColors.amberGlow,
      );
      canvas.drawCircle(
        pos,
        4.6,
        Paint()
          ..color = AppColors.pureWhite
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      _drawPointPill(canvas, size, pos, pt.label);
    }
  }

  void _drawCurve(
    Canvas canvas,
    Size size,
    PlotCurve2D curve,
    Offset Function(double, double) toScreen,
    double visXMin,
    double visXMax,
    double visYMin,
    double visYMax,
  ) {
    final paint = Paint()
      ..color = curve.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (curve.kind) {
      case Curve2DKind.segment:
        if (curve.segmentStart != null && curve.segmentEnd != null) {
          final a = toScreen(curve.segmentStart!.dx, curve.segmentStart!.dy);
          final b = toScreen(curve.segmentEnd!.dx, curve.segmentEnd!.dy);
          canvas.drawLine(a, b, paint);
        }
      case Curve2DKind.explicitYOfX:
        if (curve.eval1D == null) return;
        final a = math.min(visXMin, curve.minParam ?? visXMin);
        final b = math.max(visXMax, curve.maxParam ?? visXMax);
        final path = Path();
        bool started = false;
        const n = 160;
        for (int i = 0; i <= n; i++) {
          final x = a + (b - a) * (i / n);
          final y = curve.eval1D!(x);
          if (y.isFinite && y >= visYMin - 20 && y <= visYMax + 20) {
            final p = toScreen(x, y);
            if (!started) {
              path.moveTo(p.dx, p.dy);
              started = true;
            } else {
              path.lineTo(p.dx, p.dy);
            }
          } else {
            started = false;
          }
        }
        canvas.drawPath(path, paint);
      case Curve2DKind.explicitXOfY:
        if (curve.eval1D == null) return;
        final a = math.min(visYMin, curve.minParam ?? visYMin);
        final b = math.max(visYMax, curve.maxParam ?? visYMax);
        final path = Path();
        bool started = false;
        const n = 160;
        for (int i = 0; i <= n; i++) {
          final y = a + (b - a) * (i / n);
          final x = curve.eval1D!(y);
          if (x.isFinite && x >= visXMin - 20 && x <= visXMax + 20) {
            final p = toScreen(x, y);
            if (!started) {
              path.moveTo(p.dx, p.dy);
              started = true;
            } else {
              path.lineTo(p.dx, p.dy);
            }
          } else {
            started = false;
          }
        }
        canvas.drawPath(path, paint);
      case Curve2DKind.polarROfTheta:
        if (curve.eval1D == null) return;
        final a = curve.minParam ?? 0.0;
        final b = curve.maxParam ?? (2.0 * math.pi);
        final path = Path();
        bool started = false;
        const n = 180;
        for (int i = 0; i <= n; i++) {
          final th = a + (b - a) * (i / n);
          final r = curve.eval1D!(th);
          if (r.isFinite) {
            final p = toScreen(r * math.cos(th), r * math.sin(th));
            if (!started) {
              path.moveTo(p.dx, p.dy);
              started = true;
            } else {
              path.lineTo(p.dx, p.dy);
            }
          } else {
            started = false;
          }
        }
        canvas.drawPath(path, paint);
      case Curve2DKind.implicitFxy:
        if (curve.evalImplicit == null) return;
        _drawImplicitContour(canvas, curve.evalImplicit!, paint, toScreen, visXMin, visXMax, visYMin, visYMax);
    }
  }

  /// Lightweight Marching Squares contour drawer for implicit equations F(x,y) = 0
  void _drawImplicitContour(
    Canvas canvas,
    double Function(double, double) fn,
    Paint paint,
    Offset Function(double, double) toScreen,
    double xMin,
    double xMax,
    double yMin,
    double yMax,
  ) {
    const nx = 52;
    const ny = 52;
    final dx = (xMax - xMin) / nx;
    final dy = (yMax - yMin) / ny;
    if (dx <= 0 || dy <= 0) return;

    final grid = List.generate(
      nx + 1,
      (i) => List.generate(ny + 1, (j) => fn(xMin + i * dx, yMin + j * dy)),
    );

    Offset? interp(double x1, double y1, double v1, double x2, double y2, double v2) {
      if (!v1.isFinite || !v2.isFinite) return null;
      if ((v1 > 0 && v2 > 0) || (v1 < 0 && v2 < 0)) return null;
      final denom = v2 - v1;
      final t = denom.abs() < 1e-12 ? 0.5 : (-v1 / denom).clamp(0.0, 1.0);
      return toScreen(x1 + t * (x2 - x1), y1 + t * (y2 - y1));
    }

    for (int i = 0; i < nx; i++) {
      final x0 = xMin + i * dx;
      final x1 = x0 + dx;
      for (int j = 0; j < ny; j++) {
        final y0 = yMin + j * dy;
        final y1 = y0 + dy;
        final v00 = grid[i][j];
        final v10 = grid[i + 1][j];
        final v11 = grid[i + 1][j + 1];
        final v01 = grid[i][j + 1];
        if (!v00.isFinite || !v10.isFinite || !v11.isFinite || !v01.isFinite) continue;

        final crossings = <Offset>[];
        final e0 = interp(x0, y0, v00, x1, y0, v10);
        final e1 = interp(x1, y0, v10, x1, y1, v11);
        final e2 = interp(x1, y1, v11, x0, y1, v01);
        final e3 = interp(x0, y1, v01, x0, y0, v00);
        if (e0 != null) crossings.add(e0);
        if (e1 != null) crossings.add(e1);
        if (e2 != null) crossings.add(e2);
        if (e3 != null) crossings.add(e3);

        if (crossings.length >= 2) {
          canvas.drawLine(crossings[0], crossings[1], paint);
          if (crossings.length == 4) {
            canvas.drawLine(crossings[2], crossings[3], paint);
          }
        }
      }
    }
  }

  void _drawSweepArrow(
    Canvas canvas,
    Size size,
    Offset Function(double, double) toScreen,
  ) {
    final t = sweepProgress.clamp(0.12, 0.88);
    final arrowPaint = Paint()
      ..color = AppColors.amberGlow
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = AppColors.amberGlow.withAlpha(65)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;

    if (sweepOrder == SweepOrderType.typeI) {
      if (domain.yLowerAtX == null || domain.yUpperAtX == null) return;
      final x0 = domain.xMin + (domain.xMax - domain.xMin) * t;
      final yl = domain.yLowerAtX!(x0);
      final yu = domain.yUpperAtX!(x0);
      if (!yl.isFinite || !yu.isFinite || (yu - yl).abs() < 1e-4) return;

      final yLow = math.min(yl, yu);
      final yUpp = math.max(yl, yu);
      final pStart = toScreen(x0, yLow);
      final pEnd = toScreen(x0, yUpp);

      // Vertical arrow
      canvas.drawLine(pStart, pEnd, glowPaint);
      canvas.drawLine(pStart, pEnd, arrowPaint);
      _drawArrowHead(canvas, pStart, pEnd, AppColors.amberGlow);

      // Entry / exit dots
      canvas.drawCircle(pStart, 4.0, Paint()..color = AppColors.violetHeatmap);
      canvas.drawCircle(pEnd, 4.0, Paint()..color = AppColors.electricCyan);

      _drawSweepTag(canvas, size, pStart + const Offset(8, 8), 'Entra: y_inf');
      _drawSweepTag(canvas, size, pEnd + const Offset(8, -16), 'Sale: y_sup');
    } else {
      if (domain.xLowerAtY == null || domain.xUpperAtY == null) return;
      final y0 = domain.yMin + (domain.yMax - domain.yMin) * t;
      final xl = domain.xLowerAtY!(y0);
      final xu = domain.xUpperAtY!(y0);
      if (!xl.isFinite || !xu.isFinite || (xu - xl).abs() < 1e-4) return;

      final xLow = math.min(xl, xu);
      final xUpp = math.max(xl, xu);
      final pStart = toScreen(xLow, y0);
      final pEnd = toScreen(xUpp, y0);

      // Horizontal arrow
      canvas.drawLine(pStart, pEnd, glowPaint);
      canvas.drawLine(pStart, pEnd, arrowPaint);
      _drawArrowHead(canvas, pStart, pEnd, AppColors.amberGlow);

      canvas.drawCircle(pStart, 4.0, Paint()..color = AppColors.violetHeatmap);
      canvas.drawCircle(pEnd, 4.0, Paint()..color = AppColors.electricCyan);

      _drawSweepTag(canvas, size, pStart + const Offset(-10, 12), 'Entra: x_izq');
      _drawSweepTag(canvas, size, pEnd + const Offset(8, -10), 'Sale: x_der');
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Color color) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 6.0) return;

    final angle = math.atan2(dy, dx);
    const headLen = 10.0;
    const spread = 0.45;
    final p1 = Offset(
      to.dx - headLen * math.cos(angle - spread),
      to.dy - headLen * math.sin(angle - spread),
    );
    final p2 = Offset(
      to.dx - headLen * math.cos(angle + spread),
      to.dy - headLen * math.sin(angle + spread),
    );
    final headPath = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(headPath, Paint()..color = color);
  }

  void _drawSweepTag(Canvas canvas, Size size, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.amberGlow,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final clampedX = pos.dx.clamp(4.0, math.max<double>(4.0, size.width - tp.width - 10)).toDouble();
    final clampedY = pos.dy.clamp(4.0, math.max<double>(4.0, size.height - tp.height - 6)).toDouble();
    final rect = Rect.fromLTWH(clampedX - 3, clampedY - 2, tp.width + 6, tp.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = AppColors.slateDark.withAlpha(225),
    );
    tp.paint(canvas, Offset(clampedX, clampedY));
  }

  void _drawPointPill(Canvas canvas, Size size, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.pureWhite,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final px = (pos.dx + 8).clamp(4.0, math.max<double>(4.0, size.width - tp.width - 12)).toDouble();
    final py = (pos.dy - tp.height - 10).clamp(4.0, math.max<double>(4.0, size.height - tp.height - 8)).toDouble();
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(px - 4, py - 2, tp.width + 8, tp.height + 4),
      const Radius.circular(5),
    );
    canvas.drawRRect(rrect, Paint()..color = AppColors.slateDark.withAlpha(235));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppColors.amberGlow.withAlpha(170)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    tp.paint(canvas, Offset(px, py));
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset pos,
    Color color, {
    double fontSize = 11,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  void _drawTick(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.mutedGray, fontSize: 8.5, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  double _niceGridStep(double pixelsPerUnit) {
    final targetWorld = 48.0 / pixelsPerUnit;
    final exp = (math.log(targetWorld) / math.ln10).floor();
    final base = math.pow(10.0, exp).toDouble();
    final frac = targetWorld / base;
    if (frac <= 1.5) return base;
    if (frac <= 3.5) return 2.0 * base;
    if (frac <= 7.5) return 5.0 * base;
    return 10.0 * base;
  }

  String _formatTick(double v) {
    if ((v - v.roundToDouble()).abs() < 1e-6) return '${v.round()}';
    return v.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant Domain2DCanvasPainter oldDelegate) {
    return oldDelegate.domain != domain ||
        oldDelegate.sweepOrder != sweepOrder ||
        oldDelegate.sweepProgress != sweepProgress ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan;
  }
}
