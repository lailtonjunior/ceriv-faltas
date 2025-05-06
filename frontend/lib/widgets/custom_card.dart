import 'package:flutter/material.dart';
import 'package:ceriv_app/theme.dart';

class CustomCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? titleColor;
  final double borderRadius;
  final double elevation;
  final bool hasShadow;
  final Widget? trailing;

  const CustomCard({
    Key? key,
    this.title,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.titleColor,
    this.borderRadius = 12.0,
    this.elevation = 1.0,
    this.hasShadow = true,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBackgroundColor = backgroundColor ?? theme.cardTheme.color;
    final cardBorderColor = borderColor ?? theme.colorScheme.primary.withOpacity(0.1);
    final cardTitleColor = titleColor ?? theme.textTheme.titleLarge?.color;

    return Container(
      decoration: hasShadow
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            )
          : null,
      child: Material(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        elevation: hasShadow ? 0 : elevation,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: cardBorderColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título, se fornecido
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 16.0,
                      bottom: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cardTitleColor,
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                  ),
                
                // Conteúdo
                Padding(
                  padding: padding ??
                      EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: title != null ? 8.0 : 16.0,
                        bottom: 16.0,
                      ),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}