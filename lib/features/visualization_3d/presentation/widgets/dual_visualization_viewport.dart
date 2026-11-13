import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../calculator/domain/entities/multivariable_integral.dart';
import '../../../solver/domain/entities/integral_solution.dart';
import '../../../visualization_2d/domain/services/domain_2d_extractor.dart';
import '../../../visualization_2d/presentation/widgets/native_2d_domain_viewport.dart';
import '../../../visualization_2d/presentation/widgets/uv_plane_viewport.dart';
import 'native_3d_viewport.dart';

enum DualViewportMode {
  domain2D,
  uvPlane,
  solid3D,
}

class DualVisualizationViewport extends StatefulWidget {
  final MultivariableIntegral integral;
  final IntegralSolution? solution;
  final Map<String, dynamic>? meshData;
  final DualViewportMode initialMode;
  final double? fixedHeight;

  const DualVisualizationViewport({
    super.key,
    required this.integral,
    this.solution,
    this.meshData,
    this.initialMode = DualViewportMode.domain2D,
    this.fixedHeight,
  });

  @override
  State<DualVisualizationViewport> createState() =>
      _DualVisualizationViewportState();
}

class _DualVisualizationViewportState extends State<DualVisualizationViewport> {
  late DualViewportMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    final domain = Domain2DExtractor.extract(
      integral: widget.integral,
      solution: widget.solution,
    );
    final hasUvOrPolar = domain.uvMapping != null;

    final viewportBody = switch (_mode) {
      DualViewportMode.domain2D => Native2DDomainViewport(
          integral: widget.integral,
          solution: widget.solution,
        ),
      DualViewportMode.uvPlane => UvPlaneViewport(
          integral: widget.integral,
          solution: widget.solution,
        ),
      DualViewportMode.solid3D => Native3DViewport(
          meshData: widget.meshData,
          integral: widget.integral,
          solution: widget.solution,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<DualViewportMode>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            backgroundColor: AppColors.slateDark,
            selectedBackgroundColor: AppColors.cyberEmerald.withAlpha(40),
            selectedForegroundColor: AppColors.cyberEmerald,
            foregroundColor: AppColors.mutedGray,
            side: const BorderSide(color: AppColors.borderSubtle),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          segments: [
            const ButtonSegment(
              value: DualViewportMode.domain2D,
              icon: Icon(Icons.grid_on_rounded, size: 15),
              label: FittedBox(fit: BoxFit.scaleDown, child: Text('2D: Dominio R')),
            ),
            ButtonSegment(
              value: DualViewportMode.uvPlane,
              icon: Icon(
                Icons.transform_rounded,
                size: 15,
                color: hasUvOrPolar ? AppColors.violetHeatmap : null,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(hasUvOrPolar ? 'Plano UV ✨' : 'Plano UV'),
              ),
            ),
            const ButtonSegment(
              value: DualViewportMode.solid3D,
              icon: Icon(Icons.view_in_ar_rounded, size: 15),
              label: FittedBox(fit: BoxFit.scaleDown, child: Text('3D: Sólido V')),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) {
            setState(() => _mode = selection.first);
          },
        ),
        const SizedBox(height: 10),
        if (widget.fixedHeight != null)
          SizedBox(height: widget.fixedHeight, child: viewportBody)
        else
          Expanded(child: viewportBody),
      ],
    );
  }
}
