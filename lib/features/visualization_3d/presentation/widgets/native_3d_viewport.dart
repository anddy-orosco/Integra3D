import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../painters/native_3d_painter.dart';

class Native3DViewport extends StatefulWidget {
  final Map<String, dynamic>? meshData;

  const Native3DViewport({super.key, this.meshData});

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
    // Extract vertices and indices from meshData
    List<double> vertices = [];
    List<int> indices = [];
    String title = 'Visualización del Sólido 3D';

    if (widget.meshData != null) {
      title = widget.meshData!['title'] as String? ?? title;
      final rawVerts = widget.meshData!['vertices'] as List<dynamic>?;
      final rawInds = widget.meshData!['indices'] as List<dynamic>?;

      if (rawVerts != null && rawInds != null) {
        vertices = rawVerts.map((e) => (e as num).toDouble()).toList();
        indices = rawInds.map((e) => (e as num).toInt()).toList();
      }
    }

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
          // 3D Canvas with gesture detection
          GestureDetector(
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
                yaw: _yaw,
                pitch: _pitch,
                zoom: _zoom,
                pan: _pan,
                showWireframe: _showWireframe,
                showAxes: _showAxes,
              ),
            ),
          ),

          // Header Overlay: Title & Axis Legend
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground.withAlpha(220),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Text('■ Eje X ', style: TextStyle(color: AppColors.coralFlame, fontSize: 10, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text('■ Eje Y ', style: TextStyle(color: AppColors.limePhosphor, fontSize: 10, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text('■ Eje Z (Cotas)', style: TextStyle(color: AppColors.neonSky, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground.withAlpha(180),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Gira con 1 dedo • Zoom con 2',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ),

                // Controls
                Row(
                  children: [
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
