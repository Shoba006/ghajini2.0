import 'package:flutter/material.dart';

/// Ghajini 2.0 Design System & Elderly-Friendly Responsive Theme
/// Built for WCAG AA compliance, high contrast, and cross-platform readability.
class GhajiniTheme {
  // Brand Color Palette
  static const Color primaryOrange = Color(0xFFE8650A);
  static const Color softCream = Color(0xFFFFF4E8);
  static const Color darkBrown = Color(0xFF2B1608);
  static const Color borderLight = Color(0xFFF0C9A4);
  static const Color borderOrange = Color(0xFFE8650A);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color mutedBrown = Color(0xFF7C5D44);
  static const Color successGreen = Color(0xFF166534);
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color emergencyBg = Color(0xFFFEF2F2);
  static const Color amberAccent = Color(0xFFD97706);
  static const Color focusRing = Color(0xFFB45309);

  // Backward-compatible aliases for legacy imports
  static const Color primaryDark = darkBrown;
  static const Color accentAmber = primaryOrange;
  static const Color softBackground = softCream;
  static const Color cardBackground = cardWhite;
  static const Color highContrastText = darkBrown;
  static const Color gentleGreen = successGreen;
  static const Color distressRed = emergencyRed;

  // Typography Constants (Elderly friendly 20sp+ body, 28sp+ headings)
  static const double headingLargeSize = 34.0;
  static const double headingMediumSize = 28.0;
  static const double bodySize = 20.0;
  static const double buttonSize = 22.0;
  static const double labelSize = 16.0;

  // Target Sizing
  static const double minTouchTarget = 48.0;
  static const double primaryButtonHeight = 64.0;
  static const double cardRadius = 20.0;

  static ThemeData get elderlyTheme => lightTheme;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        onPrimary: Colors.white,
        secondary: borderLight,
        onSecondary: darkBrown,
        surface: cardWhite,
        onSurface: darkBrown,
        error: emergencyRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: softCream,

      // High-contrast, scalable typography
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'serif',
          fontSize: headingLargeSize,
          fontWeight: FontWeight.bold,
          color: darkBrown,
          height: 1.25,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'serif',
          fontSize: headingMediumSize,
          fontWeight: FontWeight.bold,
          color: darkBrown,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          color: darkBrown,
          height: 1.35,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: bodySize,
          fontWeight: FontWeight.w600,
          color: darkBrown,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: 18.0,
          fontWeight: FontWeight.normal,
          color: darkBrown,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: buttonSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBrown,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'serif',
          fontSize: 24.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // Card Theme with 20dp corners and warm border
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 2,
        shadowColor: darkBrown.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: borderLight, width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),

      // Buttons (Min 64 dp tall)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTouchTarget, primaryButtonHeight),
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          elevation: 3.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'sans-serif',
            fontSize: buttonSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, primaryButtonHeight),
          foregroundColor: darkBrown,
          backgroundColor: cardWhite,
          side: const BorderSide(color: primaryOrange, width: 2.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'sans-serif',
            fontSize: buttonSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: borderLight, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: borderLight, width: 2.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: primaryOrange, width: 2.5),
        ),
        hintStyle: const TextStyle(
          fontSize: 18.0,
          color: mutedBrown,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }
}

// Global Alias for seamless backward compatibility
typedef AppTheme = GhajiniTheme;
