import 'package:flutter/material.dart';
import 'package:ghajini_app/core/theme.dart';

class SosButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isHeaderStyle;

  const SosButton({
    super.key,
    required this.onPressed,
    this.isHeaderStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHeaderStyle) {
      return CompactSosButton(onPressed: onPressed);
    }
    return FullWidthSosButton(onPressed: onPressed);
  }
}

class CompactSosButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CompactSosButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.sos_rounded, color: Colors.white, size: 24),
      label: const Text(
        "SOS HELP",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: GhajiniTheme.emergencyRed,
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

class FullWidthSosButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FullWidthSosButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "SOS Emergency Assistance Button",
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.sos_rounded, size: 40, color: Colors.white),
        label: const Text(
          "HELP ME / SOS",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 78),
          backgroundColor: GhajiniTheme.emergencyRed,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
            side: const BorderSide(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }
}
