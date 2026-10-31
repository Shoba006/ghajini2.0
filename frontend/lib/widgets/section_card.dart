import 'package:flutter/material.dart';
import 'package:ghajini_app/core/theme.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color? borderColor;

  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(22),
    this.backgroundColor = GhajiniTheme.cardWhite,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
        side: BorderSide(
          color: borderColor ?? GhajiniTheme.borderLight,
          width: 1.5,
        ),
      ),
      elevation: 2,
      shadowColor: GhajiniTheme.darkBrown.withValues(alpha: 0.06),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: GhajiniTheme.darkBrown,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
