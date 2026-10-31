import 'package:flutter/material.dart';

/// Ghajini 2.0 User App Theme (Elderly Phone 2)
/// Built with a crisp white + green visual design matching the main Ghajini web application,
/// with high-contrast, large touch targets (64-76 dp), large typography (20-32 sp),
/// and rounded cards/buttons designed specifically for elderly accessibility.
class UserTheme {
  // Brand Color Palette (matching main Ghajini web application)
  static const Color primaryGreen = Color(0xFF0F9D7A);      // Teal/Jade green (--primary)
  static const Color primaryGreenDark = Color(0xFF0C8567);  // Darker green hover (--primary-hover)
  static const Color primaryLight = Color(0xFFE8F5EE);      // Soft green container (--primary-light)
  static const Color primaryBorder = Color(0xFFC6E7D2);     // Mint border (--primary-border)
  static const Color accentOrange = Color(0xFFF26B21);      // Accent orange (--accent-orange)
  static const Color emergencyRed = Color(0xFFEF4444);      // Emergency SOS red (--danger-red)
  static const Color emergencyBg = Color(0xFFFEF2F2);       // Emergency light red bg
  static const Color emergencyBorder = Color(0xFFFECACA);   // Emergency border red
  
  // Surfaces and Backgrounds
  static const Color backgroundWhite = Color(0xFFFFFFFF);   // Pure white background
  static const Color pageBackground = Color(0xFFF8FAFC);    // Very soft slate background
  static const Color cardWhite = Color(0xFFFFFFFF);         // Card surface
  static const Color cardBorder = Color(0xFFE5E7EB);        // Neutral card border
  
  // Typography Colors
  static const Color textTitle = Color(0xFF1F2937);         // Dark slate titles (--text-title)
  static const Color textBody = Color(0xFF4B5563);          // Main body text (--text-body)
  static const Color textMuted = Color(0xFF6B7280);         // Sub-labels & captions (--text-muted)
  
  // Sizing & Spacing Constants for Elderly Accessibility
  static const double headingLargeSize = 32.0;
  static const double headingMediumSize = 26.0;
  static const double titleSize = 22.0;
  static const double bodySize = 19.0;
  static const double buttonLabelSize = 21.0;
  static const double captionSize = 16.0;

  static const double minTouchTarget = 56.0;
  static const double primaryButtonHeight = 72.0;
  static const double cardRadius = 22.0;
  static const double buttonRadius = 20.0;

  /// High-contrast, elderly-friendly white + green ThemeData
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        onPrimary: Colors.white,
        secondary: primaryLight,
        onSecondary: primaryGreenDark,
        surface: cardWhite,
        onSurface: textTitle,
        error: emergencyRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundWhite,

      // High-contrast, legible typography
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: headingLargeSize,
          fontWeight: FontWeight.w800,
          color: textTitle,
          height: 1.25,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: headingMediumSize,
          fontWeight: FontWeight.bold,
          color: textTitle,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: titleSize,
          fontWeight: FontWeight.bold,
          color: textTitle,
          height: 1.35,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: bodySize,
          fontWeight: FontWeight.w600,
          color: textBody,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: 17.0,
          fontWeight: FontWeight.normal,
          color: textBody,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: buttonLabelSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // Clean White/Green App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundWhite,
        foregroundColor: textTitle,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryGreen, size: 28),
        titleTextStyle: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          color: textTitle,
        ),
      ),

      // Rounded Card Theme with subtle border
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: cardBorder, width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),

      // Primary Green Elevated Buttons (Min 64 dp tall)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTouchTarget, primaryButtonHeight),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 1.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'sans-serif',
            fontSize: buttonLabelSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Outlined Green Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(minTouchTarget, primaryButtonHeight),
          foregroundColor: primaryGreenDark,
          backgroundColor: backgroundWhite,
          side: const BorderSide(color: primaryGreen, width: 2.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'sans-serif',
            fontSize: buttonLabelSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

