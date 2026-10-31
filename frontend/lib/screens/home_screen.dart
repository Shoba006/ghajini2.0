import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ghajini_app/core/responsive.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/models/reminder.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/screens/calling_screen.dart';
import 'package:ghajini_app/widgets/big_button.dart';
import 'package:ghajini_app/widgets/reminder_popup.dart';
import 'package:ghajini_app/widgets/sos_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _duePollTimer;
  final Set<int> _activePromptReminderIds = {};
  FlutterLocalNotificationsPlugin? _notificationsPlugin;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initLocalNotifications();
    }
    // Poll /v1/reminders/due every 15 seconds across both mobile and web
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

  Future<void> _scheduleOfflineNotifications(List<Reminder> reminders) async {
    if (kIsWeb || _notificationsPlugin == null) return;
    try {
      for (final rem in reminders) {
        final parts = rem.scheduledTime.split(':');
        if (parts.length >= 2) {
          const androidDetails = AndroidNotificationDetails(
            'ghajini_reminders_channel',
            'Medication & Reminders',
            channelDescription: 'Caregiver and patient reminders for Ghajini 2.0',
            importance: Importance.max,
            priority: Priority.high,
          );
          const details = NotificationDetails(android: androidDetails);
          await _notificationsPlugin?.show(
            rem.id,
            rem.title,
            rem.message ?? 'Time for your daily scheduled reminder.',
            details,
          );
        }
      }
    } catch (e) {
      debugPrint('Schedule notifications note: $e');
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
            _showSOSConfirmedDialog();
          } catch (_) {}
        },
      ),
    );
  }

  Future<void> _handleSOS() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CallingScreen(
          reason: "SOS Button pressed on Home Screen",
          source: "sos",
        ),
      ),
    );
  }

  void _showSOSConfirmedDialog() {
    final tts = ref.read(ttsServiceProvider);
    tts.speak("Help is coming. Your family has been told.");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GhajiniTheme.cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
          side: const BorderSide(color: GhajiniTheme.emergencyRed, width: 2.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: GhajiniTheme.emergencyRed, size: 36),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Help is coming',
                style: TextStyle(fontFamily: 'serif', fontSize: 24, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your family has been told.\nSomeone will contact or visit you right away.',
          style: TextStyle(fontSize: 20, color: GhajiniTheme.darkBrown, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GhajiniTheme.emergencyRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _callFamily() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CallingScreen(
          reason: "Patient asked to call family",
          source: "call_family",
        ),
      ),
    );
  }

  void _showDemoToolsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Demo Tools', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore, color: GhajiniTheme.primaryOrange),
              title: const Text('Reset Demo Data', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref.read(apiServiceProvider).resetDemoData();
                  ref.invalidate(upcomingRemindersProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demo data reset to pristine state.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset failed: $e')));
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.alarm, color: GhajiniTheme.successGreen),
              title: const Text('Trigger Reminder Now', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref.read(apiServiceProvider).triggerReminderNow();
                  await _checkDueReminders();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trigger failed: $e')));
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: GhajiniTheme.primaryOrange),
              title: const Text('Open CardioLife Care (Vitals Monitor)', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('/cardiolife');
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: GhajiniTheme.emergencyRed),
              title: const Text('Trigger SOS Alert', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.of(ctx).pop();
                _handleSOS();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(upcomingRemindersProvider);
    final isWide = Responsive.isWide(context);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM y').format(now);
    final timeStr = DateFormat('h:mm a').format(now);

    return Scaffold(
      backgroundColor: GhajiniTheme.softCream,
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: _showDemoToolsDialog,
          child: const Text(
            'Ghajini 2.0',
            style: TextStyle(fontFamily: 'serif', fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          // On wide screens, put SOS right in the header for instant access
          if (isWide) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: CompactSosButton(onPressed: _handleSOS),
            ),
            const SizedBox(width: 8),
          ],
          if (ref.watch(currentAppModeProvider) != AppMode.user) ...[
            IconButton(
              icon: const Icon(Icons.analytics_outlined, size: 28),
              tooltip: 'Caregiver Dashboard',
              onPressed: () => context.push('/dashboard'),
            ),
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 28),
              tooltip: 'Caregiver Portal',
              onPressed: () => context.push('/caregiver'),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: ResponsivePatientContainer(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Warm Greeting Card with Date & Time
                Card(
                  color: GhajiniTheme.cardWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
                    side: const BorderSide(color: GhajiniTheme.borderLight, width: 1.5),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: GhajiniTheme.softCream,
                          ),
                          child: const Icon(Icons.wb_sunny_rounded, color: GhajiniTheme.primaryOrange, size: 40),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Good Day!",
                                style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: GhajiniTheme.darkBrown,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$dateStr • $timeStr",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: GhajiniTheme.primaryOrange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "I am here to help you remember everything.",
                                style: TextStyle(
                                  fontSize: 17,
                                  color: GhajiniTheme.mutedBrown,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. SOS Button (Compact full width; on wide it's also in the header)
                if (!isWide) ...[
                  FullWidthSosButton(onPressed: _handleSOS),
                  const SizedBox(height: 16),
                ],

                // 3. Next Due Reminder Card
                remindersAsync.when(
                  data: (reminders) {
                    _scheduleOfflineNotifications(reminders);
                    final active = reminders.where((r) => r.status != 'acknowledged').toList();
                    if (active.isEmpty) {
                      return Card(
                        color: GhajiniTheme.cardWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
                          side: const BorderSide(color: GhajiniTheme.borderLight, width: 1.5),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: GhajiniTheme.successGreen, size: 36),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'All caught up! No pending reminders today.',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: GhajiniTheme.successGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final nextRem = active.first;
                    return Card(
                      color: GhajiniTheme.cardWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
                        side: BorderSide(
                          color: nextRem.isCritical ? GhajiniTheme.emergencyRed : GhajiniTheme.primaryOrange,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_filled, color: GhajiniTheme.primaryOrange, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      "NEXT REMINDER: ${nextRem.scheduledTime}",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: GhajiniTheme.primaryOrange,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                if (nextRem.isCritical)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: GhajiniTheme.emergencyBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text("CRITICAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GhajiniTheme.emergencyRed)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              nextRem.title,
                              style: const TextStyle(
                                fontFamily: 'serif',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: GhajiniTheme.darkBrown,
                              ),
                            ),
                            if (nextRem.message != null && nextRem.message!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                nextRem.message!,
                                style: const TextStyle(fontSize: 17, color: GhajiniTheme.mutedBrown),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // 4. Action Buttons (Responsive: Stack on compact, 2-column grid on wide)
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (isWide) {
                      // 2-column grid on tablets and desktop
                      return GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.8,
                        children: [
                          BigButton(
                            label: "Talk to Ghajini",
                            icon: const Text('🤖', style: TextStyle(fontSize: 28)),
                            onPressed: () => context.push('/companion'),
                            backgroundColor: GhajiniTheme.primaryOrange,
                          ),
                          BigButton(
                            label: "Who is this?",
                            icon: const Icon(Icons.face_retouching_natural, size: 30, color: Colors.white),
                            onPressed: () => context.push('/recognize'),
                            backgroundColor: GhajiniTheme.darkBrown,
                          ),
                          BigButton(
                            label: "Ask memory",
                            icon: const Icon(Icons.mic, size: 30, color: Colors.white),
                            onPressed: () => context.push('/ask'),
                            backgroundColor: const Color(0xFF9A3412),
                          ),
                          BigButton(
                            label: "Call family",
                            icon: const Icon(Icons.phone, size: 30, color: Colors.white),
                            onPressed: _callFamily,
                            backgroundColor: const Color(0xFF0F172A),
                          ),
                        ],
                      );
                    } else {
                      // Single column stacked buttons on mobile phones
                      return Column(
                        children: [
                          BigButton(
                            label: "Talk to Ghajini (Companion)",
                            icon: const Text('🤖', style: TextStyle(fontSize: 28)),
                            onPressed: () => context.push('/companion'),
                            backgroundColor: GhajiniTheme.primaryOrange,
                          ),
                          const SizedBox(height: 14),
                          BigButton(
                            label: "Who is this?",
                            icon: const Icon(Icons.face_retouching_natural, size: 30, color: Colors.white),
                            onPressed: () => context.push('/recognize'),
                            backgroundColor: GhajiniTheme.darkBrown,
                          ),
                          const SizedBox(height: 14),
                          BigButton(
                            label: "Ask me anything",
                            icon: const Icon(Icons.mic, size: 30, color: Colors.white),
                            onPressed: () => context.push('/ask'),
                            backgroundColor: const Color(0xFF9A3412),
                          ),
                          const SizedBox(height: 14),
                          BigButton(
                            label: "Call family",
                            icon: const Icon(Icons.phone, size: 30, color: Colors.white),
                            onPressed: _callFamily,
                            backgroundColor: const Color(0xFF0F172A),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
