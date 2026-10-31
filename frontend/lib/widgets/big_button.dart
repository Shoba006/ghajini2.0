import 'package:flutter/material.dart';
import 'package:ghajini_app/core/theme.dart';

/// Primary action button: minimum 64 dp tall, rounded 20 dp, large icon & text,
/// high contrast, semantics label, accessible focus ring.
class BigButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final double height;
  final bool isOutlined;
  final String? semanticLabel;

  String get text => label;

  BigButton({
    super.key,
    String? label,
    String? text,
    dynamic icon,
    required this.onPressed,
    Color backgroundColor = GhajiniTheme.primaryOrange,
    Color? color,
    Color? foregroundColor,
    Color? textColor,
    this.borderColor,
    this.height = GhajiniTheme.primaryButtonHeight,
    this.isOutlined = false,
    this.semanticLabel,
  })  : label = label ?? text ?? '',
        backgroundColor = color ?? backgroundColor,
        foregroundColor = foregroundColor ?? textColor ?? (borderColor != null && (color ?? backgroundColor) == Colors.white ? GhajiniTheme.darkBrown : Colors.white),
        icon = icon is IconData
            ? Icon(
                icon,
                color: foregroundColor ?? textColor ?? (borderColor != null && (color ?? backgroundColor) == Colors.white ? GhajiniTheme.darkBrown : Colors.white),
                size: 28,
              )
            : (icon as Widget?);

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height < GhajiniTheme.primaryButtonHeight
        ? GhajiniTheme.primaryButtonHeight
        : height;

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          icon!,
          const SizedBox(width: 14),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: GhajiniTheme.buttonSize,
              fontWeight: FontWeight.bold,
              color: foregroundColor,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? label,
      child: Focus(
        child: SizedBox(
          width: double.infinity,
          height: effectiveHeight,
          child: (isOutlined || borderColor != null)
              ? OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: foregroundColor,
                    backgroundColor: backgroundColor,
                    side: BorderSide(color: borderColor ?? foregroundColor, width: 2.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
                    ),
                    elevation: 1,
                  ),
                  child: content,
                )
              : ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: backgroundColor,
                    foregroundColor: foregroundColor,
                    elevation: 4,
                    shadowColor: GhajiniTheme.darkBrown.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
                    ),
                  ),
                  child: content,
                ),
        ),
      ),
    );
  }
}
