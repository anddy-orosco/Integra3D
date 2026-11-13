import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/latex_sanitizer.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../solver/domain/entities/integral_solution.dart';
import '../../domain/entities/domain_2d_model.dart';
import '../../domain/services/domain_2d_extractor.dart';
import '../painters/domain_2d_canvas_painter.dart';

class Native2DDomainViewport extends StatefulWidget {
  final MultivariableIntegral integral;
  final IntegralSolution? solution;
  final double? minCanvasHeight;

  const Native2DDomainViewport({
    super.key,
    required this.integral,
    this.solution,
    this.minCanvasHeight,
  });

  @override
  State<Native2DDomainViewport> createState() => _Native2DDomainViewportState();
}

class _Native2DDomainViewportState extends State<Native2DDomainViewport>
    with SingleTickerProviderStateMixin {
  late Domain2DModel _domain;
  late SweepOrderType _sweepOrder;
  double _zoom = 1.0;
  double _baseZoom = 1.0;
  Offset _pan = Offset.zero;
  double _sweepProgress = 0.52;
  bool _isAutoSweeping = false;
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _domain = Domain2DExtractor.extract(
      integral: widget.integral,
      solution: widget.solution,
    );
    _sweepOrder = _domain.preferredSweepOrder;

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
      value: _sweepProgress,
    )..addListener(() {
        if (_isAutoSweeping && mounted) {
          setState(() {
            _sweepProgress = 0.15 + 0.70 * _sweepController.value;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant Native2DDomainViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.integral != widget.integral ||
        oldWidget.solution != widget.solution) {
      _domain = Domain2DExtractor.extract(
        integral: widget.integral,
        solution: widget.solution,
      );
      _sweepOrder = _domain.preferredSweepOrder;
      _zoom = 1.0;
      _pan = Offset.zero;
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  void _toggleAutoSweep() {
    setState(() {
      _isAutoSweeping = !_isAutoSweeping;
      if (_isAutoSweeping) {
        _sweepController.repeat(reverse: true);
      } else {
        _sweepController.stop();
      }
    });
  }

  void _resetView() {
    setState(() {
      _zoom = 1.0;
      _baseZoom = 1.0;
      _pan = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeIntegralLatex = _sweepOrder == SweepOrderType.typeI
        ? _domain.typeIIntegralLatex
        : _domain.typeIIIntegralLatex;

    final canvasWidget = Container(
      constraints: widget.minCanvasHeight != null
          ? BoxConstraints(minHeight: widget.minCanvasHeight!)
          : null,
      decoration: BoxDecoration(
        color: AppColors.deepVoid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                setState(() {
                  final delta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
                  _zoom = (_zoom * delta).clamp(0.35, 8.0);
                });
              }
            },
            child: GestureDetector(
              onScaleStart: (_) => _baseZoom = _zoom,
              onScaleUpdate: (details) {
                setState(() {
                  if (details.pointerCount == 1) {
                    _pan += details.focalPointDelta;
                  } else {
                    _pan += details.focalPointDelta;
                    final factor = 1.0 + (details.scale - 1.0) * 0.6;
                    _zoom = (_baseZoom * factor).clamp(0.35, 8.0);
                  }
                });
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: Domain2DCanvasPainter(
                  domain: _domain,
                  sweepOrder: _sweepOrder,
                  sweepProgress: _sweepProgress,
                  zoom: _zoom,
                  pan: _pan,
                ),
              ),
            ),
          ),

          // Top-left Legend Pill
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.slateDark.withAlpha(225),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _domain.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pureWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _legendDot(AppColors.cyberEmerald, 'Región R'),
                      const SizedBox(width: 8),
                      _legendDot(AppColors.amberGlow, 'Cortes / Barrido'),
                    ],
                  ),
                  if (_domain.parameterNote != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _domain.parameterNote!,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.electricCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom HUD Controls
          Positioned(
            bottom: 10,
            right: 10,
            left: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sweep Slider Mini Control
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.slateDark.withAlpha(215),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _toggleAutoSweep,
                          child: Icon(
                            _isAutoSweeping
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            size: 18,
                            color: AppColors.amberGlow,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2.5,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            ),
                            child: Slider(
                              value: _sweepProgress.clamp(0.12, 0.88),
                              min: 0.12,
                              max: 0.88,
                              activeColor: AppColors.amberGlow,
                              inactiveColor: AppColors.borderSubtle,
                              onChanged: (v) {
                                if (_isAutoSweeping) {
                                  _isAutoSweeping = false;
                                  _sweepController.stop();
                                }
                                setState(() => _sweepProgress = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _hudBtn(
                      icon: Icons.add_rounded,
                      tooltip: 'Acercar',
                      onTap: () => setState(() => _zoom = (_zoom * 1.25).clamp(0.35, 8.0)),
                    ),
                    const SizedBox(width: 4),
                    _hudBtn(
                      icon: Icons.remove_rounded,
                      tooltip: 'Alejar',
                      onTap: () => setState(() => _zoom = (_zoom * 0.8).clamp(0.35, 8.0)),
                    ),
                    const SizedBox(width: 4),
                    _hudBtn(
                      icon: Icons.center_focus_strong_rounded,
                      tooltip: 'Centrar 2D',
                      onTap: _resetView,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Orden de Barrido Interactive Switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.slateDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_calls_rounded, size: 16, color: AppColors.amberGlow),
              const SizedBox(width: 6),
              const Text(
                'Orden de Barrido:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.pureWhite,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<SweepOrderType>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppColors.deepVoid,
                    selectedBackgroundColor: AppColors.cyberEmerald.withAlpha(45),
                    selectedForegroundColor: AppColors.cyberEmerald,
                    foregroundColor: AppColors.mutedGray,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: SweepOrderType.typeI,
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text('Tipo I (dy dx)')),
                    ),
                    ButtonSegment(
                      value: SweepOrderType.typeII,
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text('Tipo II (dx dy)')),
                    ),
                  ],
                  selected: {_sweepOrder},
                  onSelectionChanged: (sel) {
                    setState(() => _sweepOrder = sel.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 2D Interactive Canvas
        if (widget.minCanvasHeight != null)
          SizedBox(height: widget.minCanvasHeight, child: canvasWidget)
        else
          Expanded(child: canvasWidget),

        const SizedBox(height: 8),

        // Integral Armada con los Límites Deducidos
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.slateDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cyberEmerald.withAlpha(110)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _sweepOrder == SweepOrderType.typeI
                          ? 'Integral Armada Tipo I (Barrido Vertical ↑):'
                          : 'Integral Armada Tipo II (Barrido Horizontal →):',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyberEmerald,
                      ),
                    ),
                  ),
                  if (_domain.intersectionPoints.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${_domain.intersectionPoints.length} cortes',
                      style: const TextStyle(fontSize: 10, color: AppColors.amberGlow),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math.tex(
                  LatexSanitizer.sanitize(activeIntegralLatex),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.pureWhite,
                  ),
                  onErrorFallback: (_) => Text(
                    LatexSanitizer.toReadableUnicode(activeIntegralLatex),
                    style: const TextStyle(fontSize: 13, color: AppColors.pureWhite),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color c, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 9.5, color: c, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _hudBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.slateDark.withAlpha(225),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Icon(icon, size: 16, color: AppColors.pureWhite),
          ),
        ),
      ),
    );
  }
}
