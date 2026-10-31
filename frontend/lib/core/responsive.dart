import 'package:flutter/material.dart';

/// Screen Size Breakpoint Classification
enum ScreenType { compact, medium, expanded }

/// Responsive layout helper using LayoutBuilder & MediaQuery.
/// Breakpoints:
/// - Compact: width < 600 px (mobile phone)
/// - Medium: 600 px <= width <= 1024 px (tablets / foldables)
/// - Expanded: width > 1024 px (desktop / wide web)
class Responsive extends StatelessWidget {
  final Widget compact;
  final Widget? medium;
  final Widget? expanded;

  const Responsive({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  static const double compactMaxWidth = 600.0;
  static const double mediumMaxWidth = 1024.0;
  static const double patientContentMaxWidth = 720.0;
  static const double caregiverContentMaxWidth = 1100.0;

  static ScreenType screenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactMaxWidth) {
      return ScreenType.compact;
    } else if (width <= mediumMaxWidth) {
      return ScreenType.medium;
    } else {
      return ScreenType.expanded;
    }
  }

  static ScreenType getScreenType(BuildContext context) => screenType(context);

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactMaxWidth;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compactMaxWidth && width <= mediumMaxWidth;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width > mediumMaxWidth;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= compactMaxWidth;

  static EdgeInsets screenPadding(BuildContext context) {
    final type = screenType(context);
    switch (type) {
      case ScreenType.compact:
        return const EdgeInsets.all(16.0);
      case ScreenType.medium:
        return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0);
      case ScreenType.expanded:
        return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > mediumMaxWidth) {
          return expanded ?? medium ?? compact;
        } else if (constraints.maxWidth >= compactMaxWidth) {
          return medium ?? compact;
        } else {
          return compact;
        }
      },
    );
  }
}

/// Centers content for Patient screens to prevent awkward wide-screen stretching (Max 720px)
class ResponsivePatientContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const ResponsivePatientContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
    this.maxWidth = Responsive.patientContentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Centers content for Caregiver screens (Max 1100px)
class ResponsiveCaregiverContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const ResponsiveCaregiverContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
    this.maxWidth = Responsive.caregiverContentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
