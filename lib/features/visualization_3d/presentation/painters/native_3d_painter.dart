import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class Triangle3D {
  final List<Offset> points2D;
  final double depth; // Average Z in camera space for Painter's algorithm
  final double normalZ; // For directional shading
  final double avgHeight; // Real z-height for elevation colormap

  Triangle3D({
    required this.points2D,
    required this.depth,
    required this.normalZ,
    required this.avgHeight,
  });
}

class Native3DCanvasPainter extends CustomPainter {
  final List<double> vertices;
  final List<int> indices;
  final double yaw; // Rotation around Z axis (radians)
  final double pitch; // Rotation around horizontal axis (radians)
  final double zoom;
  final Offset pan;
  final bool showWireframe;
  final bool showAxes;
  final bool showGrid;

  Native3DCanvasPainter({
    required this.vertices,
    required this.indices,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    this.showWireframe = true,
    this.showAxes = true,
    this.showGrid = true,
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

    // 1. Draw XY Grid
    if (showGrid) {
      final gridPaint = Paint()
        ..color = AppColors.borderSubtle.withAlpha(90)
        ..strokeWidth = 1.0;

      const int gridLines = 5;
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

    // 2. Draw 3D Coordinate Axes (X = Coral Flame, Y = Lime Phosphor, Z = Neon Sky)
    if (showAxes) {
      final origin = project(0, 0, 0);
      const axisLength = 4.0;

      // Axis X (Coral Flame / î)
      final xEnd = project(axisLength, 0, 0);
      final xPaint = Paint()..color = AppColors.coralFlame..strokeWidth = 2.5;
      canvas.drawLine(origin, xEnd, xPaint);
      _drawText(canvas, 'X (î)', xEnd + const Offset(4, -4), AppColors.coralFlame);

      // Axis Y (Lime Phosphor / ĵ)
      final yEnd = project(0, axisLength, 0);
      final yPaint = Paint()..color = AppColors.limePhosphor..strokeWidth = 2.5;
      canvas.drawLine(origin, yEnd, yPaint);
      _drawText(canvas, 'Y (ĵ)', yEnd + const Offset(4, -4), AppColors.limePhosphor);

      // Axis Z (Neon Sky / k̂)
      final zEnd = project(0, 0, axisLength);
      final zPaint = Paint()..color = AppColors.neonSky..strokeWidth = 2.8;
      canvas.drawLine(origin, zEnd, zPaint);
      _drawText(canvas, 'Z (k̂ Cotas)', zEnd + const Offset(4, -14), AppColors.neonSky);
    }

    if (vertices.isEmpty || indices.isEmpty) return;

    // 3. Project vertices & build triangles
    final List<Triangle3D> triangles = [];
    final int triangleCount = indices.length ~/ 3;

    for (int t = 0; t < triangleCount; t++) {
      final i0 = indices[t * 3];
      final i1 = indices[t * 3 + 1];
      final i2 = indices[t * 3 + 2];

      if (i0 * 3 + 2 >= vertices.length ||
          i1 * 3 + 2 >= vertices.length ||
          i2 * 3 + 2 >= vertices.length) {
        continue;
      }

      final x0 = vertices[i0 * 3];
      final y0 = vertices[i0 * 3 + 1];
      final z0 = vertices[i0 * 3 + 2];

      final x1 = vertices[i1 * 3];
      final y1 = vertices[i1 * 3 + 1];
      final z1 = vertices[i1 * 3 + 2];

      final x2 = vertices[i2 * 3];
      final y2 = vertices[i2 * 3 + 1];
      final z2 = vertices[i2 * 3 + 2];

      final p0 = project(x0, y0, z0);
      final p1 = project(x1, y1, z1);
      final p2 = project(x2, y2, z2);

      final d0 = getDepth(x0, y0, z0);
      final d1 = getDepth(x1, y1, z1);
      final d2 = getDepth(x2, y2, z2);
      final avgDepth = (d0 + d1 + d2) / 3.0;

      // Surface normal vector approximation (cross product)
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
      ));
    }

    // 4. Painter's Algorithm: Sort by depth (farthest triangles rendered first)
    triangles.sort((a, b) => a.depth.compareTo(b.depth));

    // 5. Render Polygons
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 0.8;

    for (final tri in triangles) {
      final path = Path()
        ..moveTo(tri.points2D[0].dx, tri.points2D[0].dy)
        ..lineTo(tri.points2D[1].dx, tri.points2D[1].dy)
        ..lineTo(tri.points2D[2].dx, tri.points2D[2].dy)
        ..close();

      // Academic Heatmap: Indigo (valley) -> Cyan -> Emerald -> Amber (peak)
      final color = _getElevationColor(tri.avgHeight, tri.normalZ);
      fillPaint.color = color;

      canvas.drawPath(path, fillPaint);

      if (showWireframe) {
        canvas.drawPath(path, wirePaint);
      }
    }
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

  @override
  bool shouldRepaint(covariant Native3DCanvasPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan ||
        oldDelegate.showWireframe != showWireframe ||
        oldDelegate.showAxes != showAxes ||
        oldDelegate.vertices != vertices;
  }
}
