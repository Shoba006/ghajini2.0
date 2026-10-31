import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghajini_app/core/responsive.dart';
import 'package:ghajini_app/core/user_theme.dart';
import 'package:ghajini_app/models/reminder.dart';
import 'package:ghajini_app/providers/app_providers.dart';

/// Elderly-friendly screen showing today's important reminders and medication schedule.
/// Uses crisp white + green theme with large typography and clear "I Took This" actions.
class UserRemindersScreen extends ConsumerWidget {
  const UserRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(upcomingRemindersProvider);

    return Scaffold(
      backgroundColor: UserTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: UserTheme.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: UserTheme.primaryGreen, size: 28),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Today's Reminders",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: UserTheme.textTitle,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsivePatientContainer(
          child: RefreshIndicator(
            color: UserTheme.primaryGreen,
            onRefresh: () async => ref.refresh(upcomingRemindersProvider.future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Friendly Header Note
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: UserTheme.primaryLight,
                      borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                      border: Border.all(color: UserTheme.primaryBorder, width: 1.5),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: UserTheme.primaryGreen, size: 32),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            "Here is your daily medicine and routine schedule.",
                            style: TextStyle(
                              fontSize: UserTheme.bodySize,
                              fontWeight: FontWeight.w700,
                              color: UserTheme.primaryGreenDark,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Reminders List
                  remindersAsync.when(
                    data: (reminders) {
                      if (reminders.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                            border: Border.all(color: UserTheme.cardBorder, width: 1.5),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: UserTheme.primaryGreen, size: 60),
                              SizedBox(height: 16),
                              Text(
                                "All Caught Up!",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: UserTheme.textTitle,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "No pending reminders or medications for today.",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: UserTheme.textMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: reminders.map((rem) => _ReminderItemCard(reminder: rem)).toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: UserTheme.primaryGreen),
                      ),
                    ),
                    error: (err, _) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: UserTheme.emergencyRed, size: 30),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Could not load reminders. Please pull down to refresh.",
                              style: TextStyle(fontSize: 17, color: UserTheme.textTitle),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: UserTheme.primaryGreen),
                            onPressed: () => ref.refresh(upcomingRemindersProvider.future),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderItemCard extends ConsumerStatefulWidget {
  final Reminder reminder;
  const _ReminderItemCard({required this.reminder});

  @override
  ConsumerState<_ReminderItemCard> createState() => _ReminderItemCardState();
}

class _ReminderItemCardState extends ConsumerState<_ReminderItemCard> {
  bool _isMarkingDone = false;
  bool _isSnoozing = false;

  Future<void> _markAcknowledged() async {
    setState(() => _isMarkingDone = true);
    try {
      await ref.read(apiServiceProvider).respondToReminder(
        reminderId: widget.reminder.id,
        response: 'acknowledged',
      );
      ref.invalidate(upcomingRemindersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: UserTheme.primaryGreen,
            content: Text(
              'Marked as taken. Good job!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UserTheme.emergencyRed,
            content: Text('Could not update: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingDone = false);
    }
  }

  Future<void> _markSnoozed() async {
    setState(() => _isSnoozing = true);
    try {
      await ref.read(apiServiceProvider).respondToReminder(
        reminderId: widget.reminder.id,
        response: 'snoozed',
      );
      ref.invalidate(upcomingRemindersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: UserTheme.primaryGreenDark,
            content: Text(
              'Reminder snoozed for 5 minutes.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UserTheme.emergencyRed,
            content: Text('Could not snooze: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSnoozing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rem = widget.reminder;
    final isDone = rem.status == 'acknowledged';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF8FAFC) : UserTheme.cardWhite,
        borderRadius: BorderRadius.circular(UserTheme.cardRadius),
        border: Border.all(
          color: rem.isCritical && !isDone
              ? UserTheme.emergencyBorder
              : (isDone ? UserTheme.cardBorder : UserTheme.primaryBorder),
          width: rem.isCritical && !isDone ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Scheduled Time & Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFFE2E8F0) : UserTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 20,
                      color: isDone ? UserTheme.textMuted : UserTheme.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      rem.scheduledTime,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDone ? UserTheme.textMuted : UserTheme.primaryGreenDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (rem.isCritical && !isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: UserTheme.emergencyBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: UserTheme.emergencyBorder),
                  ),
                  child: const Text(
                    "IMPORTANT",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: UserTheme.emergencyRed,
                    ),
                  ),
                ),
              if (isDone)
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: UserTheme.primaryGreen, size: 20),
                    SizedBox(width: 4),
                    Text(
                      "Taken",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: UserTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            rem.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDone ? UserTheme.textMuted : UserTheme.textTitle,
              decoration: isDone ? TextDecoration.lineThrough : null,
            ),
          ),
          if (rem.message != null && rem.message!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              rem.message!,
              style: const TextStyle(
                fontSize: 17,
                color: UserTheme.textBody,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Action Buttons
          if (!isDone) ...[
            ElevatedButton.icon(
              onPressed: _isMarkingDone || _isSnoozing ? null : _markAcknowledged,
              icon: _isMarkingDone
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 24),
              label: const Text(
                "I Have Taken This",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: UserTheme.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UserTheme.buttonRadius),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isMarkingDone || _isSnoozing ? null : _markSnoozed,
              icon: _isSnoozing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: UserTheme.primaryGreenDark, strokeWidth: 2),
                    )
                  : const Icon(Icons.snooze_rounded, size: 22, color: UserTheme.primaryGreenDark),
              label: const Text(
                "Remind Me in 5 Min",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: UserTheme.primaryGreenDark),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: UserTheme.primaryBorder, width: 1.5),
                backgroundColor: UserTheme.primaryLight,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UserTheme.buttonRadius),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

