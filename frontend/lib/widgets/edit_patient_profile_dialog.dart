import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/providers/app_providers.dart';

/// Caretaker dialog for editing patient companion settings and profile.
/// Reuses existing POST /v1/companion/settings endpoint.
class EditPatientProfileDialog extends ConsumerStatefulWidget {
  final int patientId;
  final Map<String, dynamic> initialSettings;

  const EditPatientProfileDialog({
    super.key,
    required this.patientId,
    required this.initialSettings,
  });

  @override
  ConsumerState<EditPatientProfileDialog> createState() => _EditPatientProfileDialogState();
}

class _EditPatientProfileDialogState extends ConsumerState<EditPatientProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _wakeTimeController;
  late TextEditingController _quietStartController;
  late TextEditingController _quietEndController;
  late TextEditingController _checkInFreqController;
  late TextEditingController _emergencyContactController;

  late String _selectedLanguage;
  late String _selectedTone;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSettings;
    _nameController = TextEditingController(text: s['patient_name'] as String? ?? 'Padma');
    _wakeTimeController = TextEditingController(text: s['wake_time'] as String? ?? '08:00');
    _quietStartController = TextEditingController(text: s['quiet_hours_start']?.toString() ?? '22');
    _quietEndController = TextEditingController(text: s['quiet_hours_end']?.toString() ?? '6');
    _checkInFreqController = TextEditingController(text: s['check_in_frequency_hours']?.toString() ?? '3');
    _emergencyContactController = TextEditingController(text: s['emergency_contact'] as String? ?? '+919876543210');

    _selectedLanguage = (s['preferred_language'] as String?)?.toLowerCase() ?? 'hi';
    if (!['hi', 'en', 'pa'].contains(_selectedLanguage)) {
      _selectedLanguage = 'hi';
    }

    _selectedTone = (s['tone'] as String?)?.toLowerCase() ?? 'calm';
    if (!['calm', 'warm', 'cheerful'].contains(_selectedTone)) {
      _selectedTone = 'calm';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wakeTimeController.dispose();
    _quietStartController.dispose();
    _quietEndController.dispose();
    _checkInFreqController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final payload = <String, dynamic>{
      'patient_name': _nameController.text.trim(),
      'preferred_language': _selectedLanguage,
      'tone': _selectedTone,
      'wake_time': _wakeTimeController.text.trim(),
      'check_in_frequency_hours': int.parse(_checkInFreqController.text.trim()),
      'quiet_hours_start': int.parse(_quietStartController.text.trim()),
      'quiet_hours_end': int.parse(_quietEndController.text.trim()),
      'emergency_contact': _emergencyContactController.text.trim(),
    };

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateCompanionSettings(
        settings: payload,
        patientId: widget.patientId,
      );

      // Invalidate provider so all listening UI updates immediately
      ref.invalidate(patientSettingsProvider);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Patient profile updated successfully'),
            backgroundColor: GhajiniTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save settings: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: GhajiniTheme.emergencyRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: GhajiniTheme.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Edit Patient Profile & Settings',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: GhajiniTheme.darkBrown,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: GhajiniTheme.mutedBrown),
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Update monitored patient identification, emergency phone, and AI companion preferences.',
                  style: TextStyle(fontSize: 14, color: GhajiniTheme.mutedBrown),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: GhajiniTheme.borderLight),
                const SizedBox(height: 12),

                // Scrollable Form Fields
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error message banner if any
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: GhajiniTheme.emergencyBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: GhajiniTheme.emergencyRed),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: GhajiniTheme.emergencyRed, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: GhajiniTheme.emergencyRed, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 1. Patient Name
                        const Text('Patient Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('patient_name_field'),
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Padma',
                            prefixIcon: const Icon(Icons.person, color: GhajiniTheme.primaryOrange),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Patient name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 2. Emergency Contact Phone
                        const Text('Emergency Contact Phone *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('emergency_phone_field'),
                          controller: _emergencyContactController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'e.g. +919876543210',
                            prefixIcon: const Icon(Icons.phone, color: GhajiniTheme.primaryOrange),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Emergency contact is required';
                            }
                            if (val.trim().length < 6) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 3. Preferred Language & Voice Tone (Row)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Language *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    key: const Key('language_dropdown'),
                                    value: _selectedLanguage,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.language, color: GhajiniTheme.primaryOrange),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'hi', child: Text('Hindi (हिन्दी)')),
                                      DropdownMenuItem(value: 'en', child: Text('English (en)')),
                                      DropdownMenuItem(value: 'pa', child: Text('Punjabi (ਪੰਜਾਬੀ)')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedLanguage = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Voice Tone *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    key: const Key('tone_dropdown'),
                                    value: _selectedTone,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.record_voice_over, color: GhajiniTheme.primaryOrange),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'calm', child: Text('Calm')),
                                      DropdownMenuItem(value: 'warm', child: Text('Warm')),
                                      DropdownMenuItem(value: 'cheerful', child: Text('Cheerful')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedTone = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 4. Wake-up Time & Check-in Frequency (Row)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Wake-Up Time *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    key: const Key('wake_time_field'),
                                    controller: _wakeTimeController,
                                    decoration: InputDecoration(
                                      hintText: '08:00',
                                      prefixIcon: const Icon(Icons.wb_sunny_outlined, color: GhajiniTheme.primaryOrange),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.access_time, color: GhajiniTheme.primaryOrange),
                                        tooltip: 'Select Time',
                                        onPressed: () async {
                                          final parts = _wakeTimeController.text.split(':');
                                          final initial = TimeOfDay(
                                            hour: int.tryParse(parts.first) ?? 8,
                                            minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
                                          );
                                          final picked = await showTimePicker(context: context, initialTime: initial);
                                          if (picked != null) {
                                            final h = picked.hour.toString().padLeft(2, '0');
                                            final m = picked.minute.toString().padLeft(2, '0');
                                            _wakeTimeController.text = '$h:$m';
                                          }
                                        },
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      final parts = val.trim().split(':');
                                      if (parts.length != 2) return 'HH:MM';
                                      final h = int.tryParse(parts[0]);
                                      final m = int.tryParse(parts[1]);
                                      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
                                        return '00:00 - 23:59';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Check-in Every *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    key: const Key('check_in_freq_field'),
                                    controller: _checkInFreqController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: '3',
                                      suffixText: 'hrs',
                                      prefixIcon: const Icon(Icons.timelapse_outlined, color: GhajiniTheme.primaryOrange),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      final n = int.tryParse(val.trim());
                                      if (n == null || n < 1 || n > 24) {
                                        return '1 - 24 hrs';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 5. Quiet Hours Start & End (Row)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Quiet Hours Start *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    key: const Key('quiet_start_field'),
                                    controller: _quietStartController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: '22',
                                      suffixText: ':00',
                                      prefixIcon: const Icon(Icons.bedtime_outlined, color: GhajiniTheme.primaryOrange),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      final n = int.tryParse(val.trim());
                                      if (n == null || n < 0 || n > 23) return '0 - 23';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Quiet Hours End *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    key: const Key('quiet_end_field'),
                                    controller: _quietEndController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: '6',
                                      suffixText: ':00',
                                      prefixIcon: const Icon(Icons.wb_twilight_outlined, color: GhajiniTheme.primaryOrange),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      final n = int.tryParse(val.trim());
                                      if (n == null || n < 0 || n > 23) return '0 - 23';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Informational banner about read-only clinical fields
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: GhajiniTheme.softCream,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: GhajiniTheme.borderLight),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: GhajiniTheme.mutedBrown, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Note: Age and Clinical Diagnosis (Alzheimer\'s Care Protocol) are managed by clinical supervision and remain display-only.',
                                  style: TextStyle(fontSize: 12, color: GhajiniTheme.mutedBrown),
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

                // Dialog Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const Key('cancel_button'),
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16, color: GhajiniTheme.mutedBrown),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      key: const Key('save_settings_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GhajiniTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Settings',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
