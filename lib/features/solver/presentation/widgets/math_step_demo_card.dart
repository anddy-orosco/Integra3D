import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../../core/theme/math_colors.dart';

/// Componente de Demostración del Sistema de Diseño Integra3D.
/// Muestra una tarjeta paso a paso con renderizado LaTeX de alta precisión
/// e indicadores visuales de los tres ejes canónicos (X, Y, Z) obtenidos
/// directamente de `ThemeExtension<MathColors>`.
class MathStepDemoCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String explanation;
  final String latexFormula;
  final String integrationVariable;

  const MathStepDemoCard({
    super.key,
    this.stepNumber = 1,
    this.title = 'Integración Parcial Iterada',
    this.explanation =
        'Se integra respecto a la variable interior manteniendo fijas las variables del plano base.',
    this.latexFormula =
        r'\int_{z_1(x,y)}^{z_2(x,y)} f(x, y, z) \, dz = \left[ F(x, y, z) \right]_{z_1}^{z_2}',
    this.integrationVariable = 'z',
  });

  @override
  Widget build(BuildContext context) {
    // Acceso directo tipado mediante la ThemeExtension
    final mathColors = context.mathColors;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // #161B22 (Slate Dark)
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline, width: 1), // #30363D
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera con número de paso y título
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: mathColors.primaryAction, // #10B981 (Cyber Emerald)
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$stepNumber',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D1117), // Deep Void contrast
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: mathColors.formulaText, // #F0F6FC (Pure White)
                    ),
                  ),
                ],
              ),

              // Badge de variable de integración (Electric Cyan)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mathColors.secondaryAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: mathColors.secondaryAccent.withAlpha(100)),
                ),
                child: Text(
                  'd$integrationVariable',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: mathColors.secondaryAccent, // #06B6D4 (Electric Cyan)
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Indicadores de los Tres Ejes de Coordenadas 3D (ThemeExtension)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117), // #0D1117 (Deep Void)
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAxisBadge(
                  label: r'Eje X (î)',
                  color: mathColors.axisX, // #FF5757 (Coral Flame)
                  sublabel: 'Abscisas',
                ),
                Container(width: 1, height: 22, color: theme.colorScheme.outline),
                _buildAxisBadge(
                  label: r'Eje Y (ĵ)',
                  color: mathColors.axisY, // #22C55E (Lime Phosphor)
                  sublabel: 'Ordenadas',
                ),
                Container(width: 1, height: 22, color: theme.colorScheme.outline),
                _buildAxisBadge(
                  label: r'Eje Z (k̂)',
                  color: mathColors.axisZ, // #3B82F6 (Neon Sky)
                  sublabel: 'Cotas',
                  isTarget: integrationVariable == 'z',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. Explicación didáctica (Muted Gray)
          Text(
            explanation,
            style: TextStyle(
              fontSize: 12,
              color: mathColors.metadataText, // #8B949E (Muted Gray)
              height: 1.45,
            ),
          ),

          const SizedBox(height: 12),

          // 4. Fórmula Matemática en LaTeX (Pure White)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117), // Deep Void
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: mathColors.secondaryAccent.withAlpha(60), // Cyan border
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Math.tex(
                  latexFormula,
                  textStyle: TextStyle(
                    fontSize: 16,
                    color: mathColors.formulaText, // #F0F6FC (Pure White)
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAxisBadge({
    required String label,
    required Color color,
    required String sublabel,
    bool isTarget = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isTarget
                ? [BoxShadow(color: color.withAlpha(180), blurRadius: 6, spreadRadius: 1)]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              sublabel,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF8B949E), // Muted Gray
              ),
            ),
          ],
        ),
      ],
    );
  }
}
