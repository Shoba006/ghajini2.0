import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ghajini_app/core/responsive.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/models/dashboard_summary.dart';
import 'package:ghajini_app/models/person.dart';
import 'package:ghajini_app/models/reminder.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/screens/calling_screen.dart';
import 'package:ghajini_app/widgets/big_button.dart';
import 'package:ghajini_app/widgets/call_session_card.dart';
import 'package:ghajini_app/widgets/patient_profile_card.dart';
import 'package:ghajini_app/widgets/person_card.dart';
import 'package:ghajini_app/widgets/reminder_card.dart';
import 'package:ghajini_app/widgets/section_card.dart';
import 'package:ghajini_app/widgets/status_chip.dart';

/// Caregiver Portal with Responsive Navigation:
/// - Compact (<600 px): BottomNavigationBar (People, Reminders, Dashboard, Alerts, Settings)
/// - Medium (600-1024 px): NavigationRail on the left
/// - Expanded (>1024 px): Permanent Side Drawer + 2-column Dashboard & max-width 1100 px content
class CaregiverScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const CaregiverScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends ConsumerState<CaregiverScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  void _showAddEditReminderDialog([Reminder? existing]) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final messageController = TextEditingController(text: existing?.message ?? '');
    final timeController = TextEditingController(text: existing?.scheduledTime ?? '09:00');
    bool isCritical = existing?.isCritical ?? false;
    String repeatOption = existing?.rrule?.contains('WEEKLY') == true ? 'weekly' : 'daily';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: GhajiniTheme.softCream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? 'Create Reminder' : 'Edit Reminder',
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: GhajiniTheme.darkBrown,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(fontSize: 20, color: GhajiniTheme.darkBrown),
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g., Blood Pressure Pill',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: messageController,
                  style: const TextStyle(fontSize: 18, color: GhajiniTheme.darkBrown),
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    hintText: 'e.g., Take with a full glass of water',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: timeController,
                  style: const TextStyle(fontSize: 20, color: GhajiniTheme.darkBrown),
                  decoration: const InputDecoration(
                    labelText: 'Time (HH:MM 24h) *',
                    hintText: '09:00',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: repeatOption,
                  decoration: const InputDecoration(labelText: 'Repeat Schedule'),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily (Every Day)', style: TextStyle(fontSize: 18))),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly', style: TextStyle(fontSize: 18))),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => repeatOption = val);
                  },
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  value: isCritical,
                  activeColor: GhajiniTheme.primaryOrange,
                  title: const Text(
                    'Critical Medication',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
                  ),
                  subtitle: const Text('Fires alert even during quiet hours (10 PM - 6 AM)'),
                  onChanged: (val) => setDialogState(() => isCritical = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(fontSize: 18, color: GhajiniTheme.mutedBrown)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GhajiniTheme.primaryOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final api = ref.read(apiServiceProvider);
                final rrule = repeatOption == 'weekly' ? 'FREQ=WEEKLY' : 'FREQ=DAILY';

                if (existing == null) {
                  await api.createReminder(
                    title: titleController.text.trim(),
                    message: messageController.text.trim().isNotEmpty ? messageController.text.trim() : null,
                    scheduledTime: timeController.text.trim(),
                    frequency: repeatOption,
                    rrule: rrule,
                    isCritical: isCritical,
                  );
                } else {
                  await api.updateReminder(
                    existing.id,
                    title: titleController.text.trim(),
                    message: messageController.text.trim().isNotEmpty ? messageController.text.trim() : null,
                    scheduledTime: timeController.text.trim(),
                    frequency: repeatOption,
                    rrule: rrule,
                    isCritical: isCritical,
                  );
                }

                ref.invalidate(upcomingRemindersProvider);
                if (mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save Reminder', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenType = Responsive.getScreenType(context);

    return Scaffold(
      backgroundColor: GhajiniTheme.softCream,
      appBar: AppBar(
        title: Text(
          _getTitleForTab(_currentIndex),
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: GhajiniTheme.primaryOrange,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (ref.watch(currentAppModeProvider) != AppMode.caretaker)
            IconButton(
              tooltip: 'Switch to Patient Mode',
              icon: const Icon(Icons.person_pin, size: 28),
              onPressed: () => context.go('/'),
            ),
        ],
      ),
      body: SafeArea(
        child: _buildLayout(context, screenType),
      ),
      bottomNavigationBar: screenType == ScreenType.compact
          ? NavigationBar(
              selectedIndex: _currentIndex,
              backgroundColor: Colors.white,
              indicatorColor: GhajiniTheme.borderLight,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people, color: GhajiniTheme.primaryOrange),
                  label: 'People',
                ),
                NavigationDestination(
                  icon: Icon(Icons.alarm_outlined),
                  selectedIcon: Icon(Icons.alarm, color: GhajiniTheme.primaryOrange),
                  label: 'Reminders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.phone_callback_outlined),
                  selectedIcon: Icon(Icons.phone_callback, color: GhajiniTheme.primaryOrange),
                  label: 'Calls',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights, color: GhajiniTheme.primaryOrange),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications_active, color: GhajiniTheme.emergencyRed),
                  label: 'Alerts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings, color: GhajiniTheme.primaryOrange),
                  label: 'Settings',
                ),
              ],
            )
          : null,
    );
  }

  String _getTitleForTab(int index) {
    switch (index) {
      case 0:
        return 'Caregiver: Family & Contacts';
      case 1:
        return 'Caregiver: Reminders';
      case 2:
        return 'Caregiver: Call Schedule & Status';
      case 3:
        return 'Caregiver: Activity Dashboard';
      case 4:
        return 'Caregiver: Distress Alerts';
      case 5:
      default:
        return 'Caregiver: Patient Profile & Settings';
    }
  }

  Widget _buildLayout(BuildContext context, ScreenType screenType) {
    if (screenType == ScreenType.compact) {
      return SingleChildScrollView(
        padding: Responsive.screenPadding(context),
        child: ResponsiveCaregiverContainer(
          child: _buildCurrentTabContent(context, screenType),
        ),
      );
    }

    if (screenType == ScreenType.medium) {
      return Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.white,
            selectedIconTheme: const IconThemeData(color: GhajiniTheme.primaryOrange, size: 28),
            unselectedIconTheme: const IconThemeData(color: GhajiniTheme.mutedBrown, size: 24),
            selectedLabelTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: GhajiniTheme.primaryOrange,
            ),
            unselectedLabelTextStyle: const TextStyle(color: GhajiniTheme.mutedBrown),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.people_outline), label: Text('People')),
              NavigationRailDestination(icon: Icon(Icons.alarm_outlined), label: Text('Reminders')),
              NavigationRailDestination(icon: Icon(Icons.phone_callback_outlined), label: Text('Calls')),
              NavigationRailDestination(icon: Icon(Icons.insights_outlined), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.notifications_outlined), label: Text('Alerts')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('Settings')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: GhajiniTheme.borderLight),
          Expanded(
            child: SingleChildScrollView(
              padding: Responsive.screenPadding(context),
              child: ResponsiveCaregiverContainer(
                child: _buildCurrentTabContent(context, screenType),
              ),
            ),
          ),
        ],
      );
    }

    // Expanded Layout (>1024 px) with permanent side drawer
    return Row(
      children: [
        SizedBox(
          width: 250,
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  color: GhajiniTheme.softCream,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ghajini 2.0',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: GhajiniTheme.darkBrown,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Caregiver Control Suite',
                        style: TextStyle(fontSize: 16, color: GhajiniTheme.primaryOrange, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: GhajiniTheme.borderLight),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      _buildDrawerItem(0, Icons.people, 'Family & Contacts'),
                      _buildDrawerItem(1, Icons.alarm, 'Daily Reminders'),
                      _buildDrawerItem(2, Icons.phone_callback, 'Call Schedule & Status'),
                      _buildDrawerItem(3, Icons.insights, 'Dashboard & Metrics'),
                      _buildDrawerItem(4, Icons.notifications_active, 'Safety Alerts'),
                      _buildDrawerItem(5, Icons.account_circle, 'Patient & Settings'),
                    ],
                  ),
                ),
                if (ref.watch(currentAppModeProvider) != AppMode.caretaker)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: BigButton(
                      text: 'Patient Mode',
                      icon: Icons.person_pin,
                      backgroundColor: GhajiniTheme.softCream,
                      textColor: GhajiniTheme.darkBrown,
                      borderColor: GhajiniTheme.borderLight,
                      onPressed: () => context.go('/'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const VerticalDivider(thickness: 1, width: 1, color: GhajiniTheme.borderLight),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ResponsiveCaregiverContainer(
              child: _buildCurrentTabContent(context, screenType),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: GhajiniTheme.borderLight) : null,
      ),
      child: Material(
        color: isSelected ? GhajiniTheme.softCream : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon, color: isSelected ? GhajiniTheme.primaryOrange : GhajiniTheme.mutedBrown),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? GhajiniTheme.primaryOrange : GhajiniTheme.darkBrown,
            ),
          ),
          onTap: () => setState(() => _currentIndex = index),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent(BuildContext context, ScreenType screenType) {
    switch (_currentIndex) {
      case 0:
        return _buildPeopleTab(context);
      case 1:
        return _buildRemindersTab(context);
      case 2:
        return _buildCallsTab(context);
      case 3:
        return _buildDashboardTab(context, screenType);
      case 4:
        return _buildAlertsTab(context);
      case 5:
      default:
        return _buildSettingsTab(context);
    }
  }

  // 1. People Tab
  Widget _buildPeopleTab(BuildContext context) {
    final peopleAsync = ref.watch(peopleListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recognized People',
              style: TextStyle(fontFamily: 'serif', fontSize: 26, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GhajiniTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onPressed: () => context.push('/add-person'),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Person', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        peopleAsync.when(
          data: (people) {
            if (people.isEmpty) {
              return SectionCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 54, color: GhajiniTheme.mutedBrown),
                      const SizedBox(height: 12),
                      const Text(
                        'No family or friends added yet.',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add contacts and photo references so Ghajini can recognize and introduce them to the patient.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, color: GhajiniTheme.mutedBrown),
                      ),
                      const SizedBox(height: 16),
                      BigButton(
                        text: 'Add First Person',
                        icon: Icons.person_add,
                        backgroundColor: GhajiniTheme.primaryOrange,
                        textColor: Colors.white,
                        onPressed: () => context.push('/add-person'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: people.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final person = people[i];
                return PersonCard(
                  name: person.name,
                  relationship: person.relationship,
                  notes: person.notes,
                  onDelete: () => _handleDeletePerson(person),
                );
              },
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          error: (err, _) => SectionCard(child: Text('Error loading contacts: $err', style: const TextStyle(fontSize: 18))),
        ),
      ],
    );
  }

  Future<void> _handleDeletePerson(Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GhajiniTheme.softCream,
        title: Text('Delete ${person.name}?', style: const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold)),
        content: Text('This will delete ${person.name}\'s profile and face vectors completely from recognition memory.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GhajiniTheme.emergencyRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(apiServiceProvider).deletePerson(person.id);
      ref.invalidate(peopleListProvider);
    }
  }

  // 2. Reminders Tab
  Widget _buildRemindersTab(BuildContext context) {
    final remindersAsync = ref.watch(upcomingRemindersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Scheduled Reminders',
              style: TextStyle(fontFamily: 'serif', fontSize: 26, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GhajiniTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onPressed: () => _showAddEditReminderDialog(),
              icon: const Icon(Icons.add_alarm),
              label: const Text('New Reminder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        remindersAsync.when(
          data: (reminders) {
            if (reminders.isEmpty) {
              return SectionCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.alarm_on, size: 54, color: GhajiniTheme.mutedBrown),
                      const SizedBox(height: 12),
                      const Text(
                        'No upcoming reminders scheduled.',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Schedule medication, meals, or daily activities for automated reminders.',
                        style: TextStyle(fontSize: 17, color: GhajiniTheme.mutedBrown),
                      ),
                      const SizedBox(height: 16),
                      BigButton(
                        text: 'Create First Reminder',
                        icon: Icons.add_alarm,
                        backgroundColor: GhajiniTheme.primaryOrange,
                        textColor: Colors.white,
                        onPressed: () => _showAddEditReminderDialog(),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reminders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final r = reminders[i];
                return ReminderCard(
                  title: r.title,
                  scheduledTime: r.scheduledTime,
                  message: r.message,
                  isCritical: r.isCritical,
                  frequency: r.frequency,
                  onEdit: () => _showAddEditReminderDialog(r),
                  onDelete: () async {
                    await ref.read(apiServiceProvider).deleteReminder(r.id);
                    ref.invalidate(upcomingRemindersProvider);
                  },
                );
              },
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          error: (err, _) => SectionCard(child: Text('Error loading reminders: $err', style: const TextStyle(fontSize: 18))),
        ),
      ],
    );
  }

  // 3. Calls & 3-Attempt Status Tab
  Widget _buildCallsTab(BuildContext context) {
    final callsAsync = ref.watch(callHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab Header & Refresh
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Call Schedule & Status',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: GhajiniTheme.darkBrown,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Recent reminder calls, 3-attempt escalation status, and recipient timeline.',
                    style: TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: GhajiniTheme.primaryOrange, size: 28),
              tooltip: 'Refresh Call History',
              onPressed: () => ref.invalidate(callHistoryProvider),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Live status stream
        callsAsync.when(
          data: (calls) {
            if (calls.isEmpty) {
              return SectionCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: GhajiniTheme.softCream,
                        ),
                        child: const Icon(Icons.phone_missed_outlined, size: 36, color: GhajiniTheme.mutedBrown),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No recent call records found',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: GhajiniTheme.darkBrown,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Scheduled reminder calls and automated caretaker escalations will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Summary metrics
            final int totalCalls = calls.length;
            final int completedCalls = calls.where((c) {
              final s = (c['status'] as String? ?? '').toLowerCase();
              return s == 'completed' || s == 'answered';
            }).length;
            final int escalatedCalls = calls.where((c) {
              final s = (c['status'] as String? ?? '').toLowerCase();
              final att = (c['attempt_number'] as num?)?.toInt() ?? 1;
              return s == 'escalated' || (s == 'no_answer' && att >= 3);
            }).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick Summary Metric Pills
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: GhajiniTheme.cardWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GhajiniTheme.borderLight),
                        ),
                        child: Column(
                          children: [
                            Text('$totalCalls', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown)),
                            const SizedBox(height: 2),
                            const Text('Total Calls', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GhajiniTheme.mutedBrown)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: GhajiniTheme.cardWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GhajiniTheme.successGreen.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text('$completedCalls', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: GhajiniTheme.successGreen)),
                            const SizedBox(height: 2),
                            const Text('Completed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GhajiniTheme.successGreen)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: GhajiniTheme.cardWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GhajiniTheme.emergencyRed.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text('$escalatedCalls', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: GhajiniTheme.emergencyRed)),
                            const SizedBox(height: 2),
                            const Text('Escalated (3x)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GhajiniTheme.emergencyRed)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Call Cards List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: calls.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (ctx, index) {
                    final call = calls[index] as Map<String, dynamic>;
                    return CallSessionCard(callData: call);
                  },
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => SectionCard(
            child: Text(
              'Error loading call records: $err',
              style: const TextStyle(fontSize: 18, color: GhajiniTheme.emergencyRed),
            ),
          ),
        ),
      ],
    );
  }

  // 4. Dashboard Tab (2-column on wide screens)
  Widget _buildDashboardTab(BuildContext context, ScreenType screenType) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final dailyAsync = ref.watch(dailySummaryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Daily Activity Summary Card
        dailyAsync.when(
          data: (daily) => _buildDailySummaryCard(daily),
          loading: () => const SectionCard(child: Center(child: CircularProgressIndicator())),
          error: (_, __) => _buildDailySummaryCard(
            DailySummary(
              summary: 'Today Mother took her scheduled morning care, met family, and had no distress events.',
              source: 'template',
              details: {},
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Summary Metrics & Bar Chart
        summaryAsync.when(
          data: (summary) {
            if (screenType == ScreenType.expanded) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildAdherenceCard(summary),
                        const SizedBox(height: 20),
                        _buildRecognitionsCard(summary),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildWeeklyBarChart(summary.weeklyHistory),
                        const SizedBox(height: 20),
                        _buildTopQuestionsCard(summary.topQuestions),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _buildAdherenceCard(summary),
                const SizedBox(height: 20),
                _buildWeeklyBarChart(summary.weeklyHistory),
                const SizedBox(height: 20),
                _buildTopQuestionsCard(summary.topQuestions),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SectionCard(child: Text('Dashboard data is loading or offline.')),
        ),
      ],
    );
  }

  Widget _buildDailySummaryCard(DailySummary daily) {
    return SectionCard(
      borderColor: GhajiniTheme.successGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, color: GhajiniTheme.primaryOrange, size: 30),
              const SizedBox(width: 10),
              const Text(
                "Today's Overview",
                style: TextStyle(fontFamily: 'serif', fontSize: 22, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
              ),
              const Spacer(),
              StatusChip(label: daily.source.toUpperCase(), type: StatusType.success),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            daily.summary,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4, color: GhajiniTheme.darkBrown),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceCard(DashboardSummary summary) {
    final pctColor = summary.adherencePct >= 80 ? GhajiniTheme.successGreen : GhajiniTheme.amberAccent;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.medication_rounded, color: GhajiniTheme.primaryOrange, size: 28),
              SizedBox(width: 8),
              Text('Medication Adherence', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${summary.adherencePct.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: pctColor),
              ),
              const SizedBox(width: 10),
              const Text('(Past 7 Days)', style: TextStyle(fontSize: 18, color: GhajiniTheme.mutedBrown)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (summary.adherencePct / 100.0).clamp(0.0, 1.0),
              minHeight: 14,
              backgroundColor: GhajiniTheme.borderLight.withOpacity(0.4),
              color: pctColor,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${summary.doneCount} taken', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: GhajiniTheme.successGreen)),
              Text('${summary.missedCount} missed', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: GhajiniTheme.emergencyRed)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionsCard(DashboardSummary summary) {
    return SectionCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text('Recognitions Today', style: TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown)),
              const SizedBox(height: 6),
              Text('${summary.recognitionsToday}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: GhajiniTheme.primaryOrange)),
            ],
          ),
          Column(
            children: [
              const Text('Active Alerts', style: TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown)),
              const SizedBox(height: 6),
              Text('${summary.alertsCount}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: GhajiniTheme.emergencyRed)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBarChart(List<WeeklyDayHistory> history) {
    final maxTotal = history.fold<int>(1, (max, item) {
      final t = item.done + item.missed;
      return t > max ? t : max;
    });

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Medication Pattern', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildLegend(GhajiniTheme.successGreen, 'Taken'),
              const SizedBox(width: 14),
              _buildLegend(GhajiniTheme.emergencyRed, 'Missed'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 130,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: history.map((day) {
                final double doneH = ((day.done / maxTotal) * 85).clamp(6.0, 85.0);
                final double missedH = ((day.missed / maxTotal) * 85).clamp(0.0, 85.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 16,
                          height: day.done > 0 ? doneH : 6,
                          decoration: BoxDecoration(
                            color: day.done > 0 ? GhajiniTheme.successGreen : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        if (day.missed > 0) ...[
                          const SizedBox(width: 3),
                          Container(
                            width: 16,
                            height: missedH,
                            decoration: BoxDecoration(
                              color: GhajiniTheme.emergencyRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(day.day, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTopQuestionsCard(List<TopQuestion> topQuestions) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.help_outline_rounded, color: GhajiniTheme.primaryOrange, size: 26),
              SizedBox(width: 8),
              Text('Top Repeated Questions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (topQuestions.isEmpty)
            const Text('No repeated patient inquiries recorded today.', style: TextStyle(fontSize: 18, color: GhajiniTheme.mutedBrown))
          else
            ...topQuestions.map(
              (q) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: GhajiniTheme.softCream, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: Text(q.question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: GhajiniTheme.primaryOrange, borderRadius: BorderRadius.circular(12)),
                      child: Text('${q.count}x', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 4. Alerts Tab
  Widget _buildAlertsTab(BuildContext context) {
    final alertsAsync = ref.watch(recentAlertsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Caregiver Distress & Escalation Logs',
          style: TextStyle(fontFamily: 'serif', fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        alertsAsync.when(
          data: (alerts) {
            if (alerts.isEmpty) {
              return SectionCard(
                borderColor: GhajiniTheme.successGreen,
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 54, color: GhajiniTheme.successGreen),
                      SizedBox(height: 12),
                      Text('All Quiet & Safe', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: GhajiniTheme.successGreen)),
                      SizedBox(height: 8),
                      Text('No emergency phrases, missed critical doses, or distress alerts logged.', style: TextStyle(fontSize: 18, color: GhajiniTheme.mutedBrown)),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final alert = alerts[i];
                return SectionCard(
                  borderColor: alert.severity == 'critical' ? GhajiniTheme.emergencyRed : GhajiniTheme.amberAccent,
                  child: Row(
                    children: [
                      StatusChip(
                        label: alert.severity.toUpperCase(),
                        type: alert.severity == 'critical' ? StatusType.error : StatusType.warning,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(alert.message, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown)),
                            const SizedBox(height: 4),
                            Text('Time: ${alert.createdAt}', style: const TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          error: (err, _) => SectionCard(child: Text('Error loading alerts: $err', style: const TextStyle(fontSize: 18))),
        ),
      ],
    );
  }

  // 5. Settings / Patient Profile & Privacy Tab
  Widget _buildSettingsTab(BuildContext context) {
    final peopleAsync = ref.watch(peopleListProvider);
    final selectedLang = ref.watch(languageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          const Text(
            'Patient Profile & Settings',
            style: TextStyle(fontFamily: 'serif', fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Patient medical identification, emergency contacts, companion preferences, and safety controls.',
            style: TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown),
          ),
          const SizedBox(height: 16),

          // 0. Dedicated Patient Profile & Care Information
          const PatientProfileCard(),
          const SizedBox(height: 20),

          // 1. Emergency Contacts Priority List
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Emergency Contacts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    StatusChip(label: 'SIM Calling Active', color: GhajiniTheme.successGreen),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'When an emergency trigger or escalation occurs, Ghajini calls Contact #1. If not answered, it seamlessly offers Contact #2.',
                  style: TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown),
                ),
                const SizedBox(height: 16),
                peopleAsync.when(
                  data: (people) {
                    final emergencies = people.where((p) => p.isEmergencyContact).toList()
                      ..sort((a, b) => a.priority.compareTo(b.priority));
                    if (emergencies.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'No emergency contacts configured yet. Click "Manage Contacts" below to set priorities.',
                          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: GhajiniTheme.mutedBrown),
                        ),
                      );
                    }
                    return Column(
                      children: emergencies.map((p) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: GhajiniTheme.softCream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GhajiniTheme.borderOrange),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: GhajiniTheme.primaryOrange,
                                radius: 18,
                                child: Text('#${p.priority}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text('${p.relationship} • ${p.phone ?? "+919876543210"}', style: const TextStyle(fontSize: 15, color: GhajiniTheme.mutedBrown)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: GhajiniTheme.darkBrown),
                                onPressed: () => _showEditEmergencyDialog(p),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error loading contacts: $e'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          side: const BorderSide(color: GhajiniTheme.primaryOrange),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.contacts, color: GhajiniTheme.primaryOrange),
                        label: const Text('Manage Contacts', style: TextStyle(fontSize: 16, color: GhajiniTheme.darkBrown, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final people = peopleAsync.value ?? [];
                          if (people.isNotEmpty) {
                            _showEditEmergencyDialog(people.first);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GhajiniTheme.successGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.phone_in_talk, size: 20),
                        label: const Text('Test Call Flow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CallingScreen(
                                reason: 'Caregiver settings call test',
                                source: 'manual',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Telegram Caregiver Briefing Channel
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Telegram Caregiver Alerts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    StatusChip(label: 'Free Channel', color: GhajiniTheme.primaryOrange),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sends immediate 3-line incident briefings to the caregiver on Telegram using the free Bot API. Never blocks the phone call.',
                  style: TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Briefing Language:', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: selectedLang,
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English (en)')),
                        DropdownMenuItem(value: 'hi', child: Text('Hindi (हिन्दी)')),
                        DropdownMenuItem(value: 'pa', child: Text('Punjabi (ਪੰਜਾਬੀ)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(languageProvider.notifier).state = val;
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                BigButton(
                  text: 'Send Test Alert (No Phone Call)',
                  icon: Icons.send_rounded,
                  backgroundColor: GhajiniTheme.primaryOrange,
                  textColor: Colors.white,
                  onPressed: () async {
                    try {
                      final res = await ref.read(apiServiceProvider).sendTestAlert(lang: selectedLang);
                      if (!context.mounted) return;
                      final detail = res['detail'] ?? 'Sent';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Test alert: $detail'),
                          backgroundColor: res['success'] == true ? GhajiniTheme.successGreen : GhajiniTheme.darkBrown,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Test alert error: $e'), backgroundColor: GhajiniTheme.emergencyRed),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Privacy & Data Export
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data Export & Portability', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Download all stored memories, contacts, reminder adherence, and conversation logs in a structured ZIP archive.',
                  style: TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown),
                ),
                const SizedBox(height: 16),
                BigButton(
                  text: 'Export All Patient Data',
                  icon: Icons.download_rounded,
                  backgroundColor: GhajiniTheme.darkBrown,
                  textColor: Colors.white,
                  onPressed: () async {
                    try {
                      final bytes = await ref.read(apiServiceProvider).exportData();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Exported ${bytes.length} bytes archive successfully!'),
                          backgroundColor: GhajiniTheme.successGreen,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not export data.'), backgroundColor: GhajiniTheme.emergencyRed),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Wipe Data
          SectionCard(
            borderColor: GhajiniTheme.emergencyRed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Right to be Forgotten', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: GhajiniTheme.emergencyRed)),
                const SizedBox(height: 8),
                const Text(
                  'Wipes all face vectors, personal memories, logs, and audio transcripts permanently for this patient.',
                  style: TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown),
                ),
                const SizedBox(height: 16),
                BigButton(
                  text: 'Wipe Patient Data',
                  icon: Icons.delete_forever,
                  backgroundColor: GhajiniTheme.emergencyRed,
                  textColor: Colors.white,
                  onPressed: () => _handleWipeData(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      );
  }

  void _showEditEmergencyDialog(Person person) {
    final phoneController = TextEditingController(text: person.phone ?? '+919876543210');
    bool isEmergency = person.isEmergencyContact;
    int priority = person.priority;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: GhajiniTheme.softCream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Emergency Settings: ${person.name}',
            style: const TextStyle(fontFamily: 'serif', fontSize: 22, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                title: const Text('Designate as Emergency Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Eligible for automated SIM calling & alerts'),
                value: isEmergency,
                activeColor: GhajiniTheme.successGreen,
                onChanged: (val) {
                  setDialogState(() => isEmergency = val ?? false);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number (with Country Code)',
                  hintText: '+919876543210',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Calling Priority: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: priority,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Priority #1 (First call)')),
                      DropdownMenuItem(value: 2, child: Text('Priority #2 (Fallback call)')),
                      DropdownMenuItem(value: 3, child: Text('Priority #3')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => priority = val);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GhajiniTheme.primaryOrange, foregroundColor: Colors.white),
              onPressed: () async {
                await ref.read(apiServiceProvider).updatePersonEmergency(
                  personId: person.id,
                  isEmergencyContact: isEmergency,
                  phone: phoneController.text.trim(),
                  priority: priority,
                );
                ref.invalidate(peopleListProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWipeData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GhajiniTheme.softCream,
        title: const Text('Wipe All Patient Data?', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold)),
        content: const Text('This will delete all enrolled faces, memories, reminders, and alerts. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GhajiniTheme.emergencyRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Wipe Completely', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(apiServiceProvider).wipePatientData();
      ref.invalidate(peopleListProvider);
      ref.invalidate(upcomingRemindersProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All patient data wiped.'), backgroundColor: GhajiniTheme.emergencyRed),
      );
    }
  }
}
