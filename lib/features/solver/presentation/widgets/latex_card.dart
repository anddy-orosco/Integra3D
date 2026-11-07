import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../../core/theme/app_theme.dart';

class LatexCard extends StatelessWidget {
  final String latex;
  final String? title;
  final String? subtitle;
  final TextStyle? mathStyle;
  final bool isHighlight;

  const LatexCard({
    super.key,
    required this.latex,
    this.title,
    this.subtitle,
    this.mathStyle,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (latex.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppTheme.primaryBlue.withAlpha(25)
            : AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight ? AppTheme.primaryBlue.withAlpha(160) : AppTheme.cardBorder,
          width: isHighlight ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isHighlight ? AppTheme.primaryBlueLight : AppTheme.textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: latex));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fórmula copiada en formato LaTeX'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Row(
                        children: const [
                          Icon(Icons.content_copy_rounded, size: 13, color: AppTheme.textMuted),
                          SizedBox(width: 4),
                          Text('LaTeX', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Math.tex(
                    latex,
                    textStyle: mathStyle ??
                        TextStyle(
                          fontSize: isHighlight ? 19 : 16,
                          color: isHighlight ? AppTheme.textLight : AppTheme.textLight,
                          fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                        ),
                    onErrorFallback: (err) => SelectableText(
                      latex,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppTheme.accentGold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
