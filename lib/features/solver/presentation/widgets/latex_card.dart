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

    return Card(
      color: isHighlight
          ? AppTheme.primaryCyan.withAlpha(20)
          : AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHighlight ? AppTheme.primaryCyan : const Color(0x22FFFFFF),
          width: isHighlight ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isHighlight ? AppTheme.primaryCyan : AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.textMuted),
                    tooltip: 'Copiar código LaTeX',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: latex));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código LaTeX copiado al portapapeles'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
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
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Math.tex(
                    latex,
                    textStyle: mathStyle ??
                        TextStyle(
                          fontSize: isHighlight ? 20 : 17,
                          color: isHighlight ? AppTheme.primaryCyan : AppTheme.textLight,
                          fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                        ),
                    onErrorFallback: (err) => SelectableText(
                      latex,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.amber,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
