import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ghajini_app/core/responsive.dart';
import 'package:ghajini_app/core/user_theme.dart';
import 'package:ghajini_app/models/reminder.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/screens/calling_screen.dart';
import 'package:ghajini_app/widgets/reminder_popup.dart';
import 'package:ghajini_app/widgets/user_action_card.dart';

/// Elderly-friendly User Home Screen (Phone 2).
/// Features a crisp white + green visual design matching the main Ghajini web application,
/// large readable typography, 80dp+ touch targets, rounded cards, and zero complex navigation.
class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  Timer? _duePollTimer;
  final Set<int> _activePromptReminderIds = {};
  FlutterLocalNotificationsPlugin? _notificationsPlugin;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initLocalNotifications();
    }
    // Poll /v1/reminders/due every 15 seconds
    _duePollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkDueReminders());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDueReminders());
  }

  @override
  void dispose() {
    _duePollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLocalNotifications() async {
    try {
      _notificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _notificationsPlugin?.initialize(initSettings);
    } catch (e) {
      debugPrint('Local notifications init note (native only): $e');
    }
  }

  Future<void> _checkDueReminders() async {
    if (!mounted) return;
    try {
      final api = ref.read(apiServiceProvider);
      final dueReminders = await api.getDueReminders();

      for (final rem in dueReminders) {
        if (!_activePromptReminderIds.contains(rem.id)) {
          _activePromptReminderIds.add(rem.id);
          _showFullScreenReminderCard(rem);
          break; // Show one at a time
        }
      }
    } catch (_) {}
  }

  void _showFullScreenReminderCard(Reminder reminder) {
    final tts = ref.read(ttsServiceProvider);
    final speakText = "Attention please: It is time for ${reminder.title}. ${reminder.message ?? ''}";
    tts.speak(speakText);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReminderPopupDialog(
        reminder: reminder,
        onDone: () async {
          Navigator.of(ctx).pop();
          _activePromptReminderIds.remove(reminder.id);
          try {
            await ref.read(apiServiceProvider).respondToReminder(reminderId: reminder.id, response: 'acknowledged');
            ref.invalidate(upcomingRemindersProvider);
          } catch (_) {}
        },
        onLater: () async {
          Navigator.of(ctx).pop();
          _activePromptReminderIds.remove(reminder.id);
          try {
            await ref.read(apiServiceProvider).respondToReminder(reminderId: reminder.id, response: 'snoozed');
            ref.invalidate(upcomingRemindersProvider);
          } catch (_) {}
        },
        onNeedHelp: () async {
          Navigator.of(ctx).pop();
          _activePromptReminderIds.remove(reminder.id);
          try {
            await ref.read(apiServiceProvider).respondToReminder(reminderId: reminder.id, response: 'distressed');
            _handleSOS();
          } catch (_) {}
        },
      ),
    );
  }

  void _handleSOS() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CallingScreen(
          reason: "Emergency SOS triggered from User Home Screen",
          source: "sos",
        ),
      ),
    );
  }

  void _toggleLanguage() {
    final current = ref.read(currentLanguageProvider);
    final next = current == 'en' ? 'hi' : (current == 'hi' ? 'pa' : 'en');
    ref.read(currentLanguageProvider.notifier).state = next;
  }

  String _getLanguageLabel(String code) {
    switch (code) {
      case 'hi':
        return 'हिंदी';
      case 'pa':
        return 'ਪੰਜਾਬੀ';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(upcomingRemindersProvider);
    final settingsAsync = ref.watch(patientSettingsProvider);
    final currentLang = ref.watch(currentLanguageProvider);

    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM').format(now);
    final timeStr = DateFormat('h:mm a').format(now);

    final patientName = settingsAsync.when(
      data: (settings) {
        final name = settings['patient_name'] as String?;
        return (name != null && name.isNotEmpty) ? name : null;
      },
      loading: () => null,
      error: (_, __) => null,
    );

    return Scaffold(
      backgroundColor: UserTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: UserTheme.backgroundWhite,
        elevation: 0,
        titleSpacing: 16,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ghajini',
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: UserTheme.primaryGreen,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Language switcher pill button
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ActionChip(
              avatar: const Icon(Icons.language_rounded, size: 18, color: UserTheme.primaryGreen),
              label: Text(
                _getLanguageLabel(currentLang),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: UserTheme.primaryGreenDark,
                ),
              ),
              backgroundColor: UserTheme.primaryLight,
              side: const BorderSide(color: UserTheme.primaryBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: _toggleLanguage,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsivePatientContainer(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Warm Greeting Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: UserTheme.primaryLight,
                    borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                    border: Border.all(color: UserTheme.primaryBorder, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(Icons.wb_sunny_rounded, color: UserTheme.accentOrange, size: 32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentLang == 'hi'
                                  ? (patientName != null ? "नमस्ते, $patientName!" : "नमस्ते!")
                                  : (currentLang == 'pa'
                                      ? (patientName != null ? "ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ, $patientName!" : "ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ!")
                                      : (patientName != null ? "Good Day, $patientName!" : "Good Day!")),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: UserTheme.textTitle,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$dateStr • $timeStr",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: UserTheme.primaryGreenDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentLang == 'hi'
                                  ? "मैं आपको सब कुछ याद रखने में मदद करूंगा।"
                                  : (currentLang == 'pa'
                                      ? "ਮੈਂ ਤੁਹਾਨੂੰ ਸਭ ਕੁਝ ਯਾਦ ਰੱਖਣ ਵਿੱਚ ਮਦਦ ਕਰਾਂਗਾ।"
                                      : "I am here to help you remember everything."),
                              style: const TextStyle(
                                fontSize: 14,
                                color: UserTheme.textBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Next Due Reminder Preview
                remindersAsync.when(
                  data: (reminders) {
                    final active = reminders.where((r) => r.status != 'acknowledged').toList();
                    if (active.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: UserTheme.primaryGreen, size: 26),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "All caught up! No pending reminders today.",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: UserTheme.primaryGreenDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final nextRem = active.first;
                    return InkWell(
                      borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                      onTap: () => context.push('/reminders'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: UserTheme.cardWhite,
                          borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                          border: Border.all(
                            color: nextRem.isCritical ? UserTheme.emergencyBorder : UserTheme.primaryBorder,
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: UserTheme.primaryGreen.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: nextRem.isCritical ? UserTheme.emergencyBg : UserTheme.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.access_time_filled_rounded,
                                color: nextRem.isCritical ? UserTheme.emergencyRed : UserTheme.primaryGreen,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      Text(
                                        "NEXT AT ${nextRem.scheduledTime}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: nextRem.isCritical ? UserTheme.emergencyRed : UserTheme.primaryGreen,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (nextRem.isCritical)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: UserTheme.emergencyBg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            "IMPORTANT",
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UserTheme.emergencyRed),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    nextRem.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: UserTheme.textTitle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: UserTheme.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),

                // 3. Primary Action 1: Talk to Ghajini
                UserActionCard(
                  label: "Talk to Ghajini",
                  subtitle: "Ask anything or talk with me",
                  icon: const Text('🤖', style: TextStyle(fontSize: 28)),
                  isPrimary: true,
                  onTap: () => context.push('/companion'),
                ),
                const SizedBox(height: 10),

                // 4. Primary Action 2: Call Someone
                UserActionCard(
                  label: "Call Someone",
                  subtitle: "Call your loved ones or doctor",
                  icon: const Icon(Icons.phone_rounded, color: UserTheme.primaryGreen, size: 28),
                  onTap: () => context.push('/call'),
                ),
                const SizedBox(height: 10),

                // 5. Primary Action 3: Recognize Person
                UserActionCard(
                  label: "Recognize Person",
                  subtitle: "Who is this person in front of me?",
                  icon: const Icon(Icons.face_retouching_natural_rounded, color: UserTheme.primaryGreen, size: 28),
                  onTap: () => context.push('/recognize'),
                ),
                const SizedBox(height: 10),

                // 6. Primary Action 4: Reminders
                UserActionCard(
                  label: "Reminders",
                  subtitle: "View today's medicine & routine",
                  icon: const Icon(Icons.alarm_rounded, color: UserTheme.primaryGreen, size: 28),
                  onTap: () => context.push('/reminders'),
                ),
                const SizedBox(height: 12),

                // 7. Primary Action 5: Emergency SOS
                UserActionCard(
                  label: "EMERGENCY / SOS",
                  subtitle: "Press if you need urgent help",
                  icon: const Icon(Icons.warning_amber_rounded, color: UserTheme.emergencyRed, size: 30),
                  isEmergency: true,
                  onTap: _handleSOS,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
