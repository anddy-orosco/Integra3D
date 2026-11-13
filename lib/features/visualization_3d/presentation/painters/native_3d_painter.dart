import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class Triangle3D {
  final List<Offset> points2D;
  final double depth; // Average Z in camera space for Painter's algorithm
  final double normalZ; // For directional shading
  final double avgHeight; // Real z-height for elevation colormap
  final bool isBottomSurface;

  Triangle3D({
    required this.points2D,
    required this.depth,
    required this.normalZ,
    required this.avgHeight,
    this.isBottomSurface = false,
  });
}

class Native3DCanvasPainter extends CustomPainter {
  final List<double> vertices;
  final List<int> indices;
  final List<double> bottomVertices;
  final List<int> bottomIndices;
  final List<List<Offset>> domainProjectionPolygons;
  final double yaw; // Rotation around Z axis (radians)
  final double pitch; // Rotation around horizontal axis (radians)
  final double zoom;
  final Offset pan;
  final bool showWireframe;
  final bool showAxes;
  final bool showGrid;
  final bool showProjection;
  final bool showBottomSurface;

  Native3DCanvasPainter({
    required this.vertices,
    required this.indices,
    this.bottomVertices = const [],
    this.bottomIndices = const [],
    this.domainProjectionPolygons = const [],
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    this.showWireframe = true,
    this.showAxes = true,
    this.showGrid = true,
    this.showProjection = true,
    this.showBottomSurface = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 + pan.dx, size.height / 2 + pan.dy);

    // Precompute rotation trigonometric values
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);

    // 3D to 2D projection function
    Offset project(double x, double y, double z) {
      // 1. Rotate around Z axis (yaw)
      final rx = x * cosYaw - y * sinYaw;
      final ry = x * sinYaw + y * cosYaw;
      final rz = z;

      // 2. Rotate around horizontal axis (pitch)
      final px = rx;
      final py = ry * cosPitch - rz * sinPitch;

      // Isometric / Orthographic with perspective scale
      final scale = zoom * 32.0;
      return Offset(center.dx + px * scale, center.dy - py * scale);
    }

    double getDepth(double x, double y, double z) {
      final ry = x * sinYaw + y * cosYaw;
      return ry * sinPitch + z * cosPitch;
    }

    // 1. Draw Extended XY Grid (Cartesian Ground Plane)
    if (showGrid) {
      final gridPaint = Paint()
        ..color = AppColors.borderSubtle.withAlpha(60)
        ..strokeWidth = 0.8;

      const int gridLines = 8;
      const double step = 1.0;
      for (int i = -gridLines; i <= gridLines; i++) {
        final p1 = project(i * step, -gridLines * step, 0);
        final p2 = project(i * step, gridLines * step, 0);
        canvas.drawLine(p1, p2, gridPaint);

        final p3 = project(-gridLines * step, i * step, 0);
        final p4 = project(gridLines * step, i * step, 0);
        canvas.drawLine(p3, p4, gridPaint);
      }
    }

    // 2. Draw Infinite 3D Coordinate Axes & Cartesian Ticks
    if (showAxes) {
      final origin = project(0, 0, 0);
      const double axisSpan = 16.0; // Infinite appearance (extends beyond viewport)

      final tickPaint = Paint()
        ..color = AppColors.borderSubtle.withAlpha(160)
        ..strokeWidth = 1.0;

      // ----------------- Eje X (Coral Flame / î) -----------------
      final xPosEnd = project(axisSpan, 0, 0);
      final xNegEnd = project(-axisSpan, 0, 0);
      // Eje positivo
      canvas.drawLine(origin, xPosEnd, Paint()..color = AppColors.coralFlame..strokeWidth = 2.2);
      // Eje negativo
      canvas.drawLine(origin, xNegEnd, Paint()..color = AppColors.coralFlame.withAlpha(90)..strokeWidth = 1.2);
      _drawText(canvas, '+X (î)', xPosEnd + const Offset(4, -4), AppColors.coralFlame);

      // Ticks numéricos Eje X
      const xTicks = [-6.0, -4.0, -2.0, 2.0, 4.0, 6.0];
      for (final val in xTicks) {
        final pTickA = project(val, -0.15, 0);
        final pTickB = project(val, 0.15, 0);
        canvas.drawLine(pTickA, pTickB, tickPaint);
        _drawTickText(canvas, val.toInt().toString(), project(val, 0, 0) + const Offset(0, 9), AppColors.mutedGray);
      }

      // ----------------- Eje Y (Lime Phosphor / ĵ) -----------------
      final yPosEnd = project(0, axisSpan, 0);
      final yNegEnd = project(0, -axisSpan, 0);
      // Eje positivo
      canvas.drawLine(origin, yPosEnd, Paint()..color = AppColors.limePhosphor..strokeWidth = 2.2);
      // Eje negativo
      canvas.drawLine(origin, yNegEnd, Paint()..color = AppColors.limePhosphor.withAlpha(90)..strokeWidth = 1.2);
      _drawText(canvas, '+Y (ĵ)', yPosEnd + const Offset(4, -4), AppColors.limePhosphor);

      // Ticks numéricos Eje Y
      const yTicks = [-6.0, -4.0, -2.0, 2.0, 4.0, 6.0];
      for (final val in yTicks) {
        final pTickA = project(-0.15, val, 0);
        final pTickB = project(0.15, val, 0);
        canvas.drawLine(pTickA, pTickB, tickPaint);
        _drawTickText(canvas, val.toInt().toString(), project(0, val, 0) + const Offset(9, 0), AppColors.mutedGray);
      }

      // ----------------- Eje Z (Neon Sky / k̂ Cotas) -----------------
      final zPosEnd = project(0, 0, axisSpan);
      final zNegEnd = project(0, 0, -axisSpan);
      // Eje positivo
      canvas.drawLine(origin, zPosEnd, Paint()..color = AppColors.neonSky..strokeWidth = 2.4);
      // Eje negativo
      canvas.drawLine(origin, zNegEnd, Paint()..color = AppColors.neonSky.withAlpha(90)..strokeWidth = 1.2);
      _drawText(canvas, '+Z (k̂)', zPosEnd + const Offset(4, -14), AppColors.neonSky);

      // Ticks numéricos Eje Z
      const zTicks = [-4.0, -2.0, 2.0, 4.0, 6.0];
      for (final val in zTicks) {
        final pTickA = project(0, -0.15, val);
        final pTickB = project(0, 0.15, val);
        canvas.drawLine(pTickA, pTickB, tickPaint);
        _drawTickText(canvas, val.toInt().toString(), project(0, 0, val) + const Offset(10, -4), AppColors.mutedGray);
      }

      // Origen de Coordenadas (0,0,0)
      _drawTickText(canvas, '0', origin + const Offset(-6, 6), AppColors.mutedGray);
    }

    // 2.5. Draw Shaded 2D Domain Projection R on base plane z = 0
    if (showProjection && domainProjectionPolygons.isNotEmpty) {
      final projFillPaint = Paint()
        ..color = AppColors.cyberEmerald.withAlpha(68)
        ..style = PaintingStyle.fill;
      final projStrokePaint = Paint()
        ..color = AppColors.cyberEmerald.withAlpha(210)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;

      for (final poly in domainProjectionPolygons) {
        if (poly.length < 3) continue;
        final path = Path();
        final p0 = project(poly.first.dx, poly.first.dy, 0.0);
        path.moveTo(p0.dx, p0.dy);
        for (int i = 1; i < poly.length; i++) {
          final pi = project(poly[i].dx, poly[i].dy, 0.0);
          path.lineTo(pi.dx, pi.dy);
        }
        path.close();
        canvas.drawPath(path, projFillPaint);
        canvas.drawPath(path, projStrokePaint);
      }

      // Label 'R (z=0)' near centroid of first polygon
      final firstPoly = domainProjectionPolygons.first;
      if (firstPoly.length >= 3) {
        final cx = firstPoly.fold(0.0, (s, p) => s + p.dx) / firstPoly.length;
        final cy = firstPoly.fold(0.0, (s, p) => s + p.dy) / firstPoly.length;
        _drawText(canvas, 'R (z=0)', project(cx, cy, 0.0) + const Offset(-14, 2), AppColors.cyberEmerald);
      }
    }

    if (vertices.isEmpty && bottomVertices.isEmpty) return;

    // 3. Project vertices & build triangles (both top surface and bottom surface)
    final List<Triangle3D> triangles = [];

    void addMeshTriangles(List<double> verts, List<int> inds, bool isBottom) {
      if (verts.isEmpty || inds.isEmpty) return;
      final int triangleCount = inds.length ~/ 3;
      for (int t = 0; t < triangleCount; t++) {
        final i0 = inds[t * 3];
        final i1 = inds[t * 3 + 1];
        final i2 = inds[t * 3 + 2];

        if (i0 * 3 + 2 >= verts.length ||
            i1 * 3 + 2 >= verts.length ||
            i2 * 3 + 2 >= verts.length) {
          continue;
        }

        final x0 = verts[i0 * 3];
        final y0 = verts[i0 * 3 + 1];
        final z0 = verts[i0 * 3 + 2];

        final x1 = verts[i1 * 3];
        final y1 = verts[i1 * 3 + 1];
        final z1 = verts[i1 * 3 + 2];

        final x2 = verts[i2 * 3];
        final y2 = verts[i2 * 3 + 1];
        final z2 = verts[i2 * 3 + 2];

        final p0 = project(x0, y0, z0);
        final p1 = project(x1, y1, z1);
        final p2 = project(x2, y2, z2);

        final d0 = getDepth(x0, y0, z0);
        final d1 = getDepth(x1, y1, z1);
        final d2 = getDepth(x2, y2, z2);
        final avgDepth = (d0 + d1 + d2) / 3.0;

        final v1x = x1 - x0;
        final v1y = y1 - y0;
        final v1z = z1 - z0;
        final v2x = x2 - x0;
        final v2y = y2 - y0;
        final v2z = z2 - z0;

        final nx = v1y * v2z - v1z * v2y;
        final ny = v1z * v2x - v1x * v2z;
        final nz = v1x * v2y - v1y * v2x;
        final normLen = math.sqrt(nx * nx + ny * ny + nz * nz);
        final normalizedNz = (normLen > 0.0001) ? (nz / normLen).abs() : 0.5;

        final avgH = (z0 + z1 + z2) / 3.0;

        triangles.add(Triangle3D(
          points2D: [p0, p1, p2],
          depth: avgDepth,
          normalZ: normalizedNz,
          avgHeight: avgH,
          isBottomSurface: isBottom,
        ));
      }
    }

    addMeshTriangles(vertices, indices, false);
    if (showBottomSurface && bottomVertices.isNotEmpty && bottomIndices.isNotEmpty) {
      addMeshTriangles(bottomVertices, bottomIndices, true);
    }

    // 4. Painter's Algorithm: Sort by depth (farthest triangles rendered first)
    triangles.sort((a, b) => a.depth.compareTo(b.depth));

    // 5. Render Polygons
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final wirePaintTop = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 0.8;
    final wirePaintBot = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.amberGlow.withAlpha(65)
      ..strokeWidth = 0.7;

    for (final tri in triangles) {
      final path = Path()
        ..moveTo(tri.points2D[0].dx, tri.points2D[0].dy)
        ..lineTo(tri.points2D[1].dx, tri.points2D[1].dy)
        ..lineTo(tri.points2D[2].dx, tri.points2D[2].dy)
        ..close();

      final color = tri.isBottomSurface
          ? _getBottomSurfaceColor(tri.avgHeight, tri.normalZ)
          : _getElevationColor(tri.avgHeight, tri.normalZ);
      fillPaint.color = color;

      canvas.drawPath(path, fillPaint);

      if (showWireframe) {
        canvas.drawPath(path, tri.isBottomSurface ? wirePaintBot : wirePaintTop);
      }
    }
  }

  Color _getBottomSurfaceColor(double z, double lightFactor) {
    final t = ((z + 2.0) / 6.0).clamp(0.0, 1.0);
    final base = Color.lerp(
      AppColors.amberGlow,
      AppColors.violetHeatmap,
      t,
    )!;
    final light = 0.45 + 0.55 * lightFactor;
    return Color.fromARGB(
      175,
      (base.r * 255.0 * light).round().clamp(0, 255),
      (base.g * 255.0 * light).round().clamp(0, 255),
      (base.b * 255.0 * light).round().clamp(0, 255),
    );
  }

  Color _getElevationColor(double z, double lightFactor) {
    // Normalization (-2 to 4)
    final t = ((z + 2.0) / 6.0).clamp(0.0, 1.0);

    // Color ramp Spectral 3D: Violet Heatmap (#8B5CF6) -> Electric Cyan (#06B6D4) -> Cyber Emerald (#10B981)
    Color base;
    if (t < 0.5) {
      final factor = t * 2.0;
      base = Color.lerp(
        AppColors.violetHeatmap, // #8B5CF6 (Base/Valles)
        AppColors.electricCyan,  // #06B6D4 (Nivel Medio)
        factor,
      )!;
    } else {
      final factor = (t - 0.5) * 2.0;
      base = Color.lerp(
        AppColors.electricCyan,  // #06B6D4
        AppColors.cyberEmerald,  // #10B981 (Cimas / Picos)
        factor,
      )!;
    }

    // Apply directional diffuse lighting (0.45 to 1.0)
    final light = 0.45 + 0.55 * lightFactor;
    return Color.fromARGB(
      215, // Semi-transparent for volume perception
      (base.r * 255.0 * light).round().clamp(0, 255),
      (base.g * 255.0 * light).round().clamp(0, 255),
      (base.b * 255.0 * light).round().clamp(0, 255),
    );
  }

  void _drawText(Canvas canvas, String text, Offset position, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  void _drawTickText(Canvas canvas, String text, Offset position, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant Native3DCanvasPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan ||
        oldDelegate.showWireframe != showWireframe ||
        oldDelegate.showAxes != showAxes ||
        oldDelegate.showProjection != showProjection ||
        oldDelegate.showBottomSurface != showBottomSurface ||
        oldDelegate.vertices != vertices ||
        oldDelegate.bottomVertices != bottomVertices ||
        oldDelegate.domainProjectionPolygons != domainProjectionPolygons;
  }
}
