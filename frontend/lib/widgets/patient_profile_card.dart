import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/widgets/edit_patient_profile_dialog.dart';
import 'package:ghajini_app/widgets/section_card.dart';
import 'package:ghajini_app/widgets/status_chip.dart';

/// Caretaker App: Patient Profile & Care Information Card.
/// Displays patient identity, medical condition, emergency notes,
/// escalation contact, and daily companion preferences.
class PatientProfileCard extends ConsumerWidget {
  const PatientProfileCard({super.key});

  static String _formatLanguage(String? langCode) {
    switch (langCode?.toLowerCase()) {
      case 'hi':
        return 'Hindi (हिन्दी)';
      case 'pa':
        return 'Punjabi (ਪੰਜਾਬੀ)';
      case 'en':
      default:
        return 'English (en)';
    }
  }

  static String _formatTone(String? tone) {
    if (tone == null || tone.isEmpty) return 'Calm';
    return tone[0].toUpperCase() + tone.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientId = ref.watch(currentPatientIdProvider);
    final settingsAsync = ref.watch(patientSettingsProvider);

    return SectionCard(
      title: 'Patient Profile & Care Record',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: GhajiniTheme.primaryOrange),
            tooltip: 'Edit Patient Profile',
            onPressed: () {
              final settings = settingsAsync.value ?? <String, dynamic>{};
              _showEditProfileDialog(context, ref, patientId, settings);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: GhajiniTheme.primaryOrange),
            tooltip: 'Refresh Patient Record',
            onPressed: () => ref.refresh(patientSettingsProvider),
          ),
          const StatusChip(
            label: 'Active Care',
            icon: Icons.verified_user_outlined,
            type: StatusType.success,
          ),
        ],
      ),
      child: settingsAsync.when(
        data: (settings) => _buildProfileContent(context, ref, patientId, settings),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: GhajiniTheme.primaryOrange),
                SizedBox(height: 12),
                Text(
                  'Loading patient record...',
                  style: TextStyle(color: GhajiniTheme.mutedBrown, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: GhajiniTheme.emergencyRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Could not load patient record: $err',
                      style: const TextStyle(color: GhajiniTheme.emergencyRed, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.refresh(patientSettingsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    int patientId,
    Map<String, dynamic> settings,
  ) {
    final patientName = settings['patient_name'] as String? ?? 'Padma';
    final preferredLang = settings['preferred_language'] as String? ?? 'hi';
    final emergencyPhone = settings['emergency_contact'] as String? ?? '+919876543210';
    final wakeTime = settings['wake_time'] as String? ?? '08:00';
    final quietStart = settings['quiet_hours_start']?.toString() ?? '22';
    final quietEnd = settings['quiet_hours_end']?.toString() ?? '6';
    final checkInFreq = settings['check_in_frequency_hours']?.toString() ?? '3';
    final tone = settings['tone'] as String? ?? 'calm';

    // Fields that may not exist in backend schema: display recorded value or transparent fallback
    final ageDisplay = settings['age'] != null ? '${settings['age']} years' : 'Not recorded in database';
    final conditionDisplay = settings['condition'] as String? ?? 'Alzheimer\'s / Cognitive Care (Care Protocol)';
    final emergencyNotesDisplay = settings['emergency_notes'] as String? ??
        'Speak in calm, short sentences; verify patient safety during escalation alerts.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Patient Header Row (Avatar, Name, ID badge)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GhajiniTheme.softCream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GhajiniTheme.borderLight),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: GhajiniTheme.primaryOrange,
                child: Text(
                  patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            patientName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: GhajiniTheme.darkBrown,
                              fontFamily: 'serif',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: GhajiniTheme.borderLight.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ID: #$patientId',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: GhajiniTheme.darkBrown,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Primary Patient • Monitored via Ghajini Caretaker Phone',
                      style: TextStyle(
                        fontSize: 14,
                        color: GhajiniTheme.mutedBrown,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Clinical & Medical Care Details
        const Text(
          'Clinical & Care Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: GhajiniTheme.darkBrown,
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoGrid([
          _InfoItem(
            label: 'Condition / Diagnosis',
            value: conditionDisplay,
            icon: Icons.medical_services_outlined,
            highlight: true,
          ),
          _InfoItem(
            label: 'Age',
            value: ageDisplay,
            icon: Icons.cake_outlined,
          ),
          _InfoItem(
            label: 'Emergency Care Notes',
            value: emergencyNotesDisplay,
            icon: Icons.note_alt_outlined,
            isFullWidth: true,
          ),
        ]),
        const SizedBox(height: 20),

        // 3. Emergency Escalation Contact
        const Text(
          'Emergency Escalation Contact',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: GhajiniTheme.darkBrown,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: GhajiniTheme.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GhajiniTheme.borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GhajiniTheme.emergencyBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.phone_in_talk,
                  color: GhajiniTheme.emergencyRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Designated Caretaker Emergency Phone',
                      style: TextStyle(
                        fontSize: 13,
                        color: GhajiniTheme.mutedBrown,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      emergencyPhone,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: GhajiniTheme.darkBrown,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusChip(
                label: 'Auto-Escalation',
                type: StatusType.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. Routine & AI Companion Preferences
        const Text(
          'Routine & Companion Preferences',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: GhajiniTheme.darkBrown,
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoGrid([
          _InfoItem(
            label: 'Preferred Language',
            value: _formatLanguage(preferredLang),
            icon: Icons.language,
          ),
          _InfoItem(
            label: 'Daily Wake-Up Time',
            value: '$wakeTime hrs',
            icon: Icons.wb_sunny_outlined,
          ),
          _InfoItem(
            label: 'Quiet Hours',
            value: '$quietStart:00 – $quietEnd:00',
            icon: Icons.bedtime_outlined,
          ),
          _InfoItem(
            label: 'Automated Check-in',
            value: 'Every $checkInFreq hours',
            icon: Icons.timelapse_outlined,
          ),
          _InfoItem(
            label: 'Companion Voice Tone',
            value: '${_formatTone(tone)} & Reassuring',
            icon: Icons.record_voice_over_outlined,
          ),
        ]),
        const SizedBox(height: 16),

        // 5. Edit Settings Action Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: GhajiniTheme.primaryOrange, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.edit_outlined, color: GhajiniTheme.primaryOrange, size: 20),
            label: const Text(
              'Edit Profile & Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: GhajiniTheme.darkBrown,
              ),
            ),
            onPressed: () => _showEditProfileDialog(context, ref, patientId, settings),
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    int patientId,
    Map<String, dynamic> settings,
  ) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => EditPatientProfileDialog(
        patientId: patientId,
        initialSettings: settings,
      ),
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: item.highlight ? GhajiniTheme.softCream : GhajiniTheme.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.highlight ? GhajiniTheme.borderOrange : GhajiniTheme.borderLight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 20, color: GhajiniTheme.primaryOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GhajiniTheme.mutedBrown,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: GhajiniTheme.darkBrown,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  final bool isFullWidth;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.isFullWidth = false,
  });
}
