import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/widgets/patient_profile_card.dart';

void main() {
  group('PatientProfileCard Widget Tests', () {
    testWidgets('Renders patient name, ID, condition, and emergency contact from settings', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockSettings = <String, dynamic>{
        'patient_name': 'Padma Devi',
        'preferred_language': 'hi',
        'emergency_contact': '+919876543210',
        'wake_time': '07:30',
        'quiet_hours_start': 22,
        'quiet_hours_end': 6,
        'check_in_frequency_hours': 3,
        'tone': 'calm',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPatientIdProvider.overrideWith((ref) => 1),
            patientSettingsProvider.overrideWith((ref) async => mockSettings),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PatientProfileCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card Title & Header
      expect(find.text('Patient Profile & Care Record'), findsOneWidget);
      expect(find.text('Active Care'), findsOneWidget);
      expect(find.text('Padma Devi'), findsOneWidget);
      expect(find.text('ID: #1'), findsOneWidget);

      // Clinical & Medical Details
      expect(find.text('Condition / Diagnosis'), findsOneWidget);
      expect(find.textContaining('Alzheimer\'s'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Not recorded in database'), findsOneWidget);
      expect(find.text('Emergency Care Notes'), findsOneWidget);

      // Emergency Contact
      expect(find.text('+919876543210'), findsOneWidget);
      expect(find.text('Auto-Escalation'), findsOneWidget);

      // Preferences
      expect(find.text('Hindi (हिन्दी)'), findsOneWidget);
      expect(find.text('07:30 hrs'), findsOneWidget);
      expect(find.text('22:00 – 6:00'), findsOneWidget);
      expect(find.text('Every 3 hours'), findsOneWidget);
      expect(find.text('Calm & Reassuring'), findsOneWidget);
    });

    testWidgets('Renders custom recorded age and condition when present', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockSettings = <String, dynamic>{
        'patient_name': 'Ramesh Kumar',
        'preferred_language': 'pa',
        'emergency_contact': '+919811122233',
        'wake_time': '06:00',
        'quiet_hours_start': 21,
        'quiet_hours_end': 5,
        'check_in_frequency_hours': 2,
        'tone': 'warm',
        'age': 76,
        'condition': 'Mild Cognitive Impairment (MCI)',
        'emergency_notes': 'Allergic to penicillin. Requires physical walking assistance.',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPatientIdProvider.overrideWith((ref) => 2),
            patientSettingsProvider.overrideWith((ref) async => mockSettings),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PatientProfileCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('ID: #2'), findsOneWidget);
      expect(find.text('76 years'), findsOneWidget);
      expect(find.text('Mild Cognitive Impairment (MCI)'), findsOneWidget);
      expect(find.text('Allergic to penicillin. Requires physical walking assistance.'), findsOneWidget);
      expect(find.text('+919811122233'), findsOneWidget);
      expect(find.text('Punjabi (ਪੰਜਾਬੀ)'), findsOneWidget);
      expect(find.text('Warm & Reassuring'), findsOneWidget);
    });

    testWidgets('Displays error UI and retry button when settings fetch fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPatientIdProvider.overrideWith((ref) => 1),
            patientSettingsProvider.overrideWith((ref) async => throw Exception('Network timeout')),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PatientProfileCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load patient record'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

