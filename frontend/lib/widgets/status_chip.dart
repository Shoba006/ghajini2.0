import 'package:flutter/material.dart';
import 'package:ghajini_app/core/theme.dart';

enum StatusType {
  success,
  warning,
  error,
  info,
}

/// Accessible status chip combining icon + text (never color alone).
class StatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final StatusType? type;
  final Color? color;
  final Color? backgroundColor;
  final double? fontSize;

  const StatusChip({
    super.key,
    required this.label,
    this.icon,
    this.type,
    this.color,
    this.backgroundColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    IconData effectiveIcon = icon ?? Icons.info_outline;
    Color effectiveColor = color ?? GhajiniTheme.primaryOrange;
    Color effectiveBg = backgroundColor ?? GhajiniTheme.softCream;

    if (type != null) {
      switch (type!) {
        case StatusType.success:
          effectiveIcon = icon ?? Icons.check_circle;
          effectiveColor = color ?? GhajiniTheme.successGreen;
          effectiveBg = backgroundColor ?? GhajiniTheme.successBg;
          break;
        case StatusType.warning:
          effectiveIcon = icon ?? Icons.warning_amber_rounded;
          effectiveColor = color ?? GhajiniTheme.amberAccent;
          effectiveBg = backgroundColor ?? const Color(0xFFFFFBEB);
          break;
        case StatusType.error:
          effectiveIcon = icon ?? Icons.error_outline;
          effectiveColor = color ?? GhajiniTheme.emergencyRed;
          effectiveBg = backgroundColor ?? const Color(0xFFFEE2E2);
          break;
        case StatusType.info:
          effectiveIcon = icon ?? Icons.info_outline;
          effectiveColor = color ?? const Color(0xFF2563EB);
          effectiveBg = backgroundColor ?? const Color(0xFFEFF6FF);
          break;
      }
    }

    final double effectiveFontSize = fontSize ?? 13.0;
    final double effectiveIconSize = fontSize != null ? (fontSize! * 1.1) : 16.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(effectiveIcon, size: effectiveIconSize, color: effectiveColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: effectiveFontSize,
              fontWeight: FontWeight.w800,
              color: effectiveColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
