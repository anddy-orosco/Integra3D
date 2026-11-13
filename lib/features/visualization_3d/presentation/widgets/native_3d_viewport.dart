import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../solver/domain/entities/integral_solution.dart';
import '../../../visualization_2d/domain/services/domain_2d_extractor.dart';
import '../painters/native_3d_painter.dart';

class Native3DViewport extends StatefulWidget {
  final Map<String, dynamic>? meshData;
  final MultivariableIntegral? integral;
  final IntegralSolution? solution;

  const Native3DViewport({
    super.key,
    this.meshData,
    this.integral,
    this.solution,
  });

  @override
  State<Native3DViewport> createState() => _Native3DViewportState();
}

class _Native3DViewportState extends State<Native3DViewport>
    with SingleTickerProviderStateMixin {
  double _yaw = -math.pi / 4;
  double _pitch = math.pi / 6;
  double _zoom = 1.3;
  double _baseZoom = 1.3;
  Offset _pan = Offset.zero;

  bool _showWireframe = true;
  final bool _showAxes = true;
  bool _showProjection = true;
  bool _showBottomSurface = true;
  bool _autoRotate = false;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..addListener(() {
        if (_autoRotate) {
          setState(() {
            _yaw += 0.012;
          });
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _resetCamera() {
    setState(() {
      _yaw = -math.pi / 4;
      _pitch = math.pi / 6;
      _zoom = 1.3;
      _baseZoom = 1.3;
      _pan = Offset.zero;
    });
  }

  void _toggleAutoRotate() {
    setState(() {
      _autoRotate = !_autoRotate;
      if (_autoRotate) {
        _animController.repeat();
      } else {
        _animController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Extract top & bottom surface vertices/indices and base XY projection R from meshData
    List<double> vertices = [];
    List<int> indices = [];
    List<double> bottomVertices = [];
    List<int> bottomIndices = [];
    List<List<Offset>> projectionPolygons = [];
    String title = 'Visualización del Sólido 3D';

    if (widget.meshData != null) {
      final md = widget.meshData!;
      title = md['title'] as String? ?? title;

      final topSurf = md['top_surface'];
      final botSurf = md['bottom_surface'];
      if (topSurf is Map<String, dynamic>) {
        final rawTopV = topSurf['vertices'] as List<dynamic>?;
        final rawTopI = topSurf['indices'] as List<dynamic>?;
        if (rawTopV != null && rawTopI != null) {
          vertices = rawTopV.map((e) => (e as num).toDouble()).toList();
          indices = rawTopI.map((e) => (e as num).toInt()).toList();
        }
      }
      if (botSurf is Map<String, dynamic>) {
        final rawBotV = botSurf['vertices'] as List<dynamic>?;
        final rawBotI = botSurf['indices'] as List<dynamic>?;
        if (rawBotV != null && rawBotI != null) {
          bottomVertices = rawBotV.map((e) => (e as num).toDouble()).toList();
          bottomIndices = rawBotI.map((e) => (e as num).toInt()).toList();
        }
      }

      if (vertices.isEmpty) {
        final rawVerts = md['vertices'] as List<dynamic>?;
        final rawInds = md['indices'] as List<dynamic>?;
        if (rawVerts != null && rawInds != null) {
          vertices = rawVerts.map((e) => (e as num).toDouble()).toList();
          indices = rawInds.map((e) => (e as num).toInt()).toList();
        }
      }

      final rawProj = md['domain_projection'] as List<dynamic>?;
      if (rawProj != null) {
        for (final polyRaw in rawProj) {
          if (polyRaw is List) {
            final poly = <Offset>[];
            for (final pt in polyRaw) {
              if (pt is List && pt.length >= 2) {
                poly.add(Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble()));
              }
            }
            if (poly.length >= 3) projectionPolygons.add(poly);
          }
        }
      }
    }

    if (projectionPolygons.isEmpty && widget.integral != null) {
      final domain2D = Domain2DExtractor.extract(
        integral: widget.integral!,
        solution: widget.solution,
      );
      projectionPolygons = domain2D.shadedRegions;
    }

    final hasDualSurfaces = bottomVertices.isNotEmpty && bottomIndices.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 3D Canvas with gesture detection + mouse wheel zoom
          Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                setState(() {
                  final delta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
                  _zoom = (_zoom * delta).clamp(0.4, 7.0);
                });
              }
            },
            child: GestureDetector(
              onScaleStart: (details) {
                _baseZoom = _zoom;
              },
              onScaleUpdate: (details) {
                setState(() {
                  if (details.pointerCount == 1) {
                    // Controlled smooth rotation
                    _yaw += details.focalPointDelta.dx * 0.006;
                    _pitch = (_pitch - details.focalPointDelta.dy * 0.006)
                        .clamp(-math.pi / 2.2, math.pi / 2.2);
                  } else if (details.pointerCount >= 2) {
                    // Pan and Damped Smooth Zoom
                    _pan += details.focalPointDelta;
                    final scaleFactor = 1.0 + (details.scale - 1.0) * 0.55;
                    _zoom = (_baseZoom * scaleFactor).clamp(0.4, 7.0);
                  }
                });
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: Native3DCanvasPainter(
                  vertices: vertices,
                  indices: indices,
                  bottomVertices: bottomVertices,
                  bottomIndices: bottomIndices,
                  domainProjectionPolygons: projectionPolygons,
                  yaw: _yaw,
                  pitch: _pitch,
                  zoom: _zoom,
                  pan: _pan,
                  showWireframe: _showWireframe,
                  showAxes: _showAxes,
                  showProjection: _showProjection,
                  showBottomSurface: _showBottomSurface,
                ),
              ),
            ),
          ),

          // Header Overlay: Title & Axis Legend
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground.withAlpha(220),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        const Text('■ Eje X', style: TextStyle(color: AppColors.coralFlame, fontSize: 10, fontWeight: FontWeight.bold)),
                        const Text('■ Eje Y', style: TextStyle(color: AppColors.limePhosphor, fontSize: 10, fontWeight: FontWeight.bold)),
                        const Text('■ Eje Z', style: TextStyle(color: AppColors.neonSky, fontSize: 10, fontWeight: FontWeight.bold)),
                        if (projectionPolygons.isNotEmpty)
                          const Text('■ Proyección R (z=0)', style: TextStyle(color: AppColors.cyberEmerald, fontSize: 10, fontWeight: FontWeight.bold)),
                        if (hasDualSurfaces)
                          const Text('■ z_inf', style: TextStyle(color: AppColors.amberGlow, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Positioned(
            bottom: 12,
            right: 12,
            left: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info gesture hint
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground.withAlpha(180),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Gira con 1 dedo • Zoom con 2',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (projectionPolygons.isNotEmpty) ...[
                      _buildHUDButton(
                        icon: Icons.layers_rounded,
                        tooltip: 'Proyección Dominio R (z=0)',
                        active: _showProjection,
                        onTap: () => setState(() => _showProjection = !_showProjection),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (hasDualSurfaces) ...[
                      _buildHUDButton(
                        icon: Icons.flip_to_back_rounded,
                        tooltip: 'Superficie Inferior z_inf',
                        active: _showBottomSurface,
                        onTap: () => setState(() => _showBottomSurface = !_showBottomSurface),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _buildHUDButton(
                      icon: _showWireframe ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                      tooltip: 'Malla / Wireframe',
                      active: _showWireframe,
                      onTap: () => setState(() => _showWireframe = !_showWireframe),
                    ),
                    const SizedBox(width: 6),
                    _buildHUDButton(
                      icon: _autoRotate ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                      tooltip: 'Rotación Automática',
                      active: _autoRotate,
                      onTap: _toggleAutoRotate,
                    ),
                    const SizedBox(width: 6),
                    _buildHUDButton(
                      icon: Icons.center_focus_strong_rounded,
                      tooltip: 'Centrar Vista',
                      active: false,
                      onTap: _resetCamera,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHUDButton({
    required IconData icon,
    required String tooltip,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.cyberEmerald : AppTheme.darkBackground.withAlpha(220),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: active ? AppColors.cyberEmerald : AppTheme.cardBorder,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? AppColors.deepVoid : AppTheme.textLight,
            ),
          ),
        ),
      ),
    );
  }
}
