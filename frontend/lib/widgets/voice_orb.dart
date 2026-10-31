import 'package:flutter/material.dart';
import 'package:ghajini_app/core/theme.dart';

class VoiceOrb extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  final double size;
  final String label;
  final Color? activeColor;
  final Color? baseColor;

  const VoiceOrb({
    super.key,
    required this.isListening,
    required this.onTap,
    this.size = 80.0,
    this.label = "Press to speak",
    this.activeColor,
    this.baseColor,
  });

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.16).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isListening) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.isListening ? "Listening to voice" : widget.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isListening ? _scaleAnimation.value : 1.0,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isListening
                          ? (widget.activeColor ?? GhajiniTheme.emergencyRed)
                          : (widget.baseColor ?? GhajiniTheme.primaryOrange),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isListening
                                  ? (widget.activeColor ?? GhajiniTheme.emergencyRed)
                                  : (widget.baseColor ?? GhajiniTheme.primaryOrange))
                              .withOpacity(0.35),
                          blurRadius: widget.isListening ? 26 : 14,
                          spreadRadius: widget.isListening ? 4 : 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: widget.size * 0.52,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            widget.isListening ? "Listening..." : widget.label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: GhajiniTheme.darkBrown,
            ),
          ),
        ],
      ),
    );
  }
}
