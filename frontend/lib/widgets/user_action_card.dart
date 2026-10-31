import 'package:flutter/material.dart';
import 'package:ghajini_app/core/user_theme.dart';

/// Elderly-friendly large action card for Phone 2 (User Mode).
/// Provides high contrast, large touch area (min 80 dp), rounded corners,
/// clear icon badge, readable title (21 sp), and explanatory subtitle (16 sp).
class UserActionCard extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isEmergency;
  final Color? customBorderColor;

  const UserActionCard({
    super.key,
    required this.label,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isEmergency = false,
    this.customBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isEmergency
        ? UserTheme.emergencyBorder
        : (customBorderColor ?? (isPrimary ? UserTheme.primaryBorder : UserTheme.cardBorder));
    
    final backgroundColor = isEmergency
        ? UserTheme.emergencyBg
        : (isPrimary ? const Color(0xFFFAFDFB) : UserTheme.cardWhite);

    final iconBg = isEmergency
        ? const Color(0xFFFEE2E2)
        : (isPrimary ? UserTheme.primaryLight : const Color(0xFFF1F5F9));

    final titleColor = isEmergency ? UserTheme.emergencyRed : UserTheme.textTitle;

    return Semantics(
      button: true,
      label: subtitle != null ? '$label, $subtitle' : label,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(UserTheme.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(UserTheme.cardRadius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 74.0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UserTheme.cardRadius),
              border: Border.all(color: borderColor, width: isPrimary || isEmergency ? 2.0 : 1.5),
              boxShadow: [
                BoxShadow(
                  color: isEmergency
                      ? UserTheme.emergencyRed.withOpacity(0.06)
                      : (isPrimary ? UserTheme.primaryGreen.withOpacity(0.06) : Colors.black.withOpacity(0.02)),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Large Rounded Icon Container (56x56)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isEmergency ? UserTheme.emergencyBorder : UserTheme.primaryBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Center(child: icon),
                ),
                const SizedBox(width: 18),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: UserTheme.buttonLabelSize,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: UserTheme.captionSize,
                            fontWeight: FontWeight.w500,
                            color: UserTheme.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Forward chevron indicator
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 20,
                  color: isEmergency ? UserTheme.emergencyRed : UserTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

