import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghajini_app/core/call_service.dart';
import 'package:ghajini_app/core/responsive.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/widgets/big_button.dart';

class CardioLifeScreen extends ConsumerStatefulWidget {
  const CardioLifeScreen({super.key});

  @override
  ConsumerState<CardioLifeScreen> createState() => _CardioLifeScreenState();
}

class _CardioLifeScreenState extends ConsumerState<CardioLifeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _beatController;
  late Animation<double> _scaleAnimation;
  Timer? _refreshTimer;
  Timer? _ecgAnimationTimer;
  double _ecgPhase = 0.0;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _beatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 833), // Default ~72 BPM
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(parent: _beatController, curve: Curves.easeInOut),
    );

    // Smooth continuous ECG trace sweep
    _ecgAnimationTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (mounted) {
        setState(() {
          _ecgPhase = (_ecgPhase + 0.035) % 1.0;
        });
      }
    });

    // Refresh telemetry every 8 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      ref.invalidate(currentVitalsProvider);
    });
  }

  @override
  void dispose() {
    _beatController.dispose();
    _refreshTimer?.cancel();
    _ecgAnimationTimer?.cancel();
    super.dispose();
  }

  void _updateBeatPace(int bpm) {
    final effectiveBpm = bpm.clamp(40, 180);
    final msPerBeat = (60000 / effectiveBpm).round();
    if (_beatController.duration?.inMilliseconds != msPerBeat) {
      _beatController.duration = Duration(milliseconds: msPerBeat);
      if (!_beatController.isAnimating) {
        _beatController.repeat(reverse: true);
      }
    }
  }

  Future<void> _runSimulation(String scenario) async {
    setState(() => _isSimulating = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.simulateVitals(scenario);
      ref.invalidate(currentVitalsProvider);
      ref.invalidate(vitalsHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulated condition: ${scenario.replaceAll('_', ' ').toUpperCase()}'),
            backgroundColor: scenario.contains('critical')
                ? GhajiniTheme.emergencyRed
                : GhajiniTheme.primaryOrange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Simulation error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  Future<void> _triggerEmergencyCall() async {
    final lang = ref.read(currentLanguageProvider);
    final reason = lang == 'hi'
        ? 'हृदय गति चेतावनी: असामान्य पल्स दर'
        : (lang == 'pa'
            ? 'ਦਿਲ ਦੀ ਧੜਕਣ ਚੇਤਾਵਨੀ: ਅਸਧਾਰਨ ਪਲਸ ਰੇਟ'
            : 'Cardiac Alert: Abnormal vitals telemetry reading');

    await CallService.instance.initiateCallFlow(
      context: context,
      patientId: 1,
      reason: reason,
      source: 'cardiac_anomaly',
      lang: lang,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(currentLanguageProvider);
    final vitalsAsync = ref.watch(currentVitalsProvider);

    return Scaffold(
      backgroundColor: GhajiniTheme.softCream,
      appBar: AppBar(
        backgroundColor: GhajiniTheme.primaryOrange,
        foregroundColor: Colors.white,
        title: Text(
          currentLang == 'hi'
              ? 'हृदय स्वास्थ्य (CardioLife)'
              : (currentLang == 'pa'
                  ? 'ਦਿਲ ਦੀ ਸਿਹਤ (CardioLife)'
                  : 'CardioLife Care'),
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Language selector pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentLang,
                dropdownColor: GhajiniTheme.darkBrown,
                icon: const Icon(Icons.language, color: Colors.white, size: 20),
                items: const [
                  DropdownMenuItem(
                    value: 'en',
                    child: Text('EN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  DropdownMenuItem(
                    value: 'hi',
                    child: Text('हिंदी', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  DropdownMenuItem(
                    value: 'pa',
                    child: Text('ਪੰਜਾਬੀ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(currentLanguageProvider.notifier).state = val;
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsivePatientContainer(
          child: vitalsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: GhajiniTheme.primaryOrange),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: GhajiniTheme.emergencyRed),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load vitals: $err',
                      style: const TextStyle(fontSize: 18, color: GhajiniTheme.darkBrown),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    BigButton(
                      text: 'Retry / पुनः प्रयास',
                      onPressed: () => ref.invalidate(currentVitalsProvider),
                      height: 56,
                    ),
                  ],
                ),
              ),
            ),
            data: (data) {
              final reading = (data['reading'] as Map<String, dynamic>?) ?? {};
              final bpm = (reading['heart_rate_bpm'] as int?) ?? 72;
              final systolic = (reading['blood_pressure_systolic'] as int?) ?? 120;
              final diastolic = (reading['blood_pressure_diastolic'] as int?) ?? 80;
              final oxygen = (reading['oxygen_saturation'] as int?) ?? 98;
              final hrv = (reading['hrv_ms'] as int?) ?? 45;
              final status = (reading['status'] as String?) ?? 'normal';
              final isCritical = (data['is_critical'] as bool?) ?? false;

              final statusLabels = (data['status_label'] as Map<String, dynamic>?) ?? {};
              final humanSummaries = (data['human_summary'] as Map<String, dynamic>?) ?? {};

              final localizedStatus = (statusLabels[currentLang] as String?) ??
                  (statusLabels['en'] as String?) ??
                  status;
              final localizedSummary = (humanSummaries[currentLang] as String?) ??
                  (humanSummaries['en'] as String?) ??
                  "Your heart rhythm is being monitored continuously.";

              _updateBeatPace(bpm);

              final Color statusColor = isCritical
                  ? GhajiniTheme.emergencyRed
                  : (status == 'elevated' ? GhajiniTheme.amberAccent : GhajiniTheme.successGreen);

              final Color orbBgColor = isCritical
                  ? GhajiniTheme.emergencyBg
                  : (status == 'elevated' ? const Color(0xFFFFFBEB) : GhajiniTheme.successBg);

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Heart Rate Pulse Orb Card
                    Card(
                      color: GhajiniTheme.cardWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
                        side: BorderSide(color: statusColor.withOpacity(0.5), width: 2),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Status Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor, width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isCritical ? Icons.warning_rounded : Icons.check_circle_rounded,
                                    size: 20,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    localizedStatus.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Animated Pulsing Heart Rate Circle
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: orbBgColor,
                                  border: Border.all(color: statusColor, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withOpacity(0.25),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.favorite_rounded,
                                        size: 40,
                                        color: statusColor,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$bpm',
                                        style: TextStyle(
                                          fontSize: 54,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                          height: 1.0,
                                          fontFamily: 'serif',
                                        ),
                                      ),
                                      Text(
                                        currentLang == 'hi'
                                            ? 'धड़कन / BPM'
                                            : (currentLang == 'pa' ? 'ਧੜਕਣ / BPM' : 'BPM'),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: GhajiniTheme.mutedBrown,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Multilingual Plain-Language Explanation
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: GhajiniTheme.softCream,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                localizedSummary,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: GhajiniTheme.darkBrown,
                                  height: 1.35,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. Real-Time ECG Waveform Canvas
                    Card(
                      color: const Color(0xFF0F172A), // Dark slate medical monitor
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
                        side: const BorderSide(color: Color(0xFF334155), width: 1.5),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.show_chart, color: Color(0xFF38BDF8), size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      currentLang == 'hi'
                                          ? 'लाइव ईसीजी तरंग (Lead II)'
                                          : (currentLang == 'pa'
                                              ? 'ਲਾਈਵ ਈਸੀਜੀ ਵੇਵਫਾਰਮ'
                                              : 'Live ECG Waveform (Lead II)'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '25 mm/s • 10 mm/mV',
                                    style: TextStyle(
                                      color: Color(0xFF4ADE80),
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 130,
                                width: double.infinity,
                                child: CustomPaint(
                                  painter: EcgWaveformPainter(
                                    phase: _ecgPhase,
                                    bpm: bpm,
                                    isCritical: isCritical,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 3. Vitals Telemetry Grid
                    Row(
                      children: [
                        // Blood Pressure Card
                        Expanded(
                          child: _buildTelemetryMetricCard(
                            icon: Icons.speed_rounded,
                            label: currentLang == 'hi'
                                ? 'रक्तचाप'
                                : (currentLang == 'pa' ? 'ਬਲੱਡ ਪ੍ਰੈਸ਼ਰ' : 'Blood Pressure'),
                            value: '$systolic/$diastolic',
                            unit: 'mmHg',
                            color: systolic >= 140 ? GhajiniTheme.emergencyRed : GhajiniTheme.darkBrown,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Oxygen SpO2 Card
                        Expanded(
                          child: _buildTelemetryMetricCard(
                            icon: Icons.air_rounded,
                            label: currentLang == 'hi'
                                ? 'ऑक्सीजन'
                                : (currentLang == 'pa' ? 'ਆਕਸੀਜਨ' : 'Oxygen (SpO2)'),
                            value: '$oxygen%',
                            unit: '95-100% ideal',
                            color: oxygen < 92 ? GhajiniTheme.emergencyRed : GhajiniTheme.darkBrown,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // HRV Card
                        Expanded(
                          child: _buildTelemetryMetricCard(
                            icon: Icons.timeline_rounded,
                            label: currentLang == 'hi'
                                ? 'एचआरवी'
                                : (currentLang == 'pa' ? 'ਐਚਆਰਵੀ' : 'HRV'),
                            value: '$hrv',
                            unit: 'ms',
                            color: GhajiniTheme.darkBrown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // 4. Action Button: Emergency Family Call
                    BigButton(
                      text: currentLang == 'hi'
                          ? 'परिवार को आपातकालीन कॉल करें'
                          : (currentLang == 'pa'
                              ? 'ਪਰਿਵਾਰ ਨੂੰ ਐਮਰਜੈਂਸੀ ਕਾਲ ਕਰੋ'
                              : 'Call Caregiver / Family'),
                      icon: Icons.phone_in_talk,
                      color: isCritical ? GhajiniTheme.emergencyRed : GhajiniTheme.primaryOrange,
                      height: 64,
                      onPressed: _triggerEmergencyCall,
                    ),
                    const SizedBox(height: 20),

                    // 5. Simulation / Demo Scenarios (Doctor / Presentation Tools)
                    Card(
                      color: GhajiniTheme.cardWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
                        side: const BorderSide(color: GhajiniTheme.borderLight),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.science_outlined, color: GhajiniTheme.primaryOrange, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  currentLang == 'hi'
                                      ? 'सिमुलेशन और डेमो टूल्स'
                                      : (currentLang == 'pa'
                                          ? 'ਸਿਮੂਲੇਸ਼ਨ ਅਤੇ ਡੈਮੋ ਟੂਲ'
                                          : 'Telemetry Demo Scenarios'),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: GhajiniTheme.darkBrown,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildScenarioChip('normal', 'Normal (74 BPM)', Colors.green),
                                _buildScenarioChip('elevated', 'Elevated (106 BPM)', Colors.amber.shade800),
                                _buildScenarioChip('critical_tachycardia', 'Tachycardia Spike (144 BPM)', Colors.red),
                                _buildScenarioChip('bradycardia', 'Bradycardia (42 BPM)', Colors.purple),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Card(
      color: GhajiniTheme.cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GhajiniTheme.borderLight, width: 1.2),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Icon(icon, size: 24, color: GhajiniTheme.primaryOrange),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: GhajiniTheme.mutedBrown,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'serif',
              ),
            ),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 11,
                color: GhajiniTheme.mutedBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioChip(String scenario, String label, Color color) {
    return ActionChip(
      avatar: CircleAvatar(
        radius: 6,
        backgroundColor: color,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.4)),
      onPressed: _isSimulating ? null : () => _runSimulation(scenario),
    );
  }
}

/// Custom painter rendering continuous mathematical P-Q-R-S-T electrocardiogram
class EcgWaveformPainter extends CustomPainter {
  final double phase;
  final int bpm;
  final bool isCritical;

  EcgWaveformPainter({
    required this.phase,
    required this.bpm,
    required this.isCritical,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Grid Background
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 0.8;

    const gridSpacing = 20.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Baseline center
    final centerY = size.height * 0.55;

    // 2. ECG Trace Path
    final tracePaint = Paint()
      ..color = isCritical ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final effectiveBpm = bpm.clamp(40, 180);
    // Frequency of cycles across canvas
    final cyclesAcross = (effectiveBpm / 72.0) * 3.2;

    double? lastX;
    double? lastY;

    for (double x = 0; x <= size.width; x += 2.0) {
      final normalizedX = x / size.width;
      final t = (normalizedX * cyclesAcross + phase * 2.0) % 1.0;

      // Mathematical P-Q-R-S-T voltage model
      double v = 0.0;
      if (t >= 0.10 && t < 0.20) {
        // P-wave
        v += 0.16 * math.sin(math.pi * (t - 0.10) / 0.10);
      } else if (t >= 0.22 && t < 0.25) {
        // Q-dip
        v -= 0.18 * math.sin(math.pi * (t - 0.22) / 0.03);
      } else if (t >= 0.25 && t < 0.29) {
        // R-peak (large spike)
        v += 1.40 * math.sin(math.pi * (t - 0.25) / 0.04);
      } else if (t >= 0.29 && t < 0.33) {
        // S-dip
        v -= 0.38 * math.sin(math.pi * (t - 0.29) / 0.04);
      } else if (t >= 0.40 && t < 0.55) {
        // T-wave
        v += 0.28 * math.sin(math.pi * (t - 0.40) / 0.15);
      }

      // Small natural baseline fluctuation
      v += 0.02 * math.sin(normalizedX * 18.0 + phase * 6.0);

      final y = centerY - (v * 45.0);

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      lastX = x;
      lastY = y;
    }

    canvas.drawPath(path, tracePaint);

    // Glowing leading dot at the end
    if (lastX != null && lastY != null) {
      final glowPaint = Paint()
        ..color = (isCritical ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)).withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(lastX, lastY), 5.0, glowPaint);

      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lastX, lastY), 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant EcgWaveformPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.bpm != bpm ||
        oldDelegate.isCritical != isCritical;
  }
}
