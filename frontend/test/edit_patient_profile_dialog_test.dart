import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/services/api_service.dart';
import 'package:ghajini_app/widgets/edit_patient_profile_dialog.dart';
import 'package:ghajini_app/widgets/patient_profile_card.dart';

class FakeApiService extends Fake implements ApiService {
  Map<String, dynamic>? lastUpdatedSettings;
  int? lastPatientId;
  bool shouldThrow = false;

  Map<String, dynamic> currentSettings = {
    'patient_name': 'Padma Devi',
    'preferred_language': 'hi',
    'emergency_contact': '+919876543210',
    'wake_time': '07:30',
    'quiet_hours_start': 22,
    'quiet_hours_end': 6,
    'check_in_frequency_hours': 3,
    'tone': 'calm',
  };

  @override
  Future<Map<String, dynamic>> getCompanionSettings({int patientId = 1}) async {
    if (shouldThrow) throw Exception('Network timeout');
    return Map<String, dynamic>.from(currentSettings);
  }

  @override
  Future<Map<String, dynamic>> updateCompanionSettings({
    required Map<String, dynamic> settings,
    int patientId = 1,
  }) async {
    if (shouldThrow) throw Exception('API connection failure');
    lastUpdatedSettings = settings;
    lastPatientId = patientId;
    currentSettings = Map<String, dynamic>.from(settings);
    return currentSettings;
  }
}

void main() {
  group('EditPatientProfileDialog & Profile Editing Tests', () {
    testWidgets('1. Existing settings load correctly into the form', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeApi = FakeApiService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(fakeApi),
            currentPatientIdProvider.overrideWith((ref) => 1),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EditPatientProfileDialog(
                patientId: 1,
                initialSettings: fakeApi.currentSettings,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Patient Profile & Settings'), findsOneWidget);

      // Verify TextFormField contents via controllers or widget finding
      final nameField = tester.widget<TextFormField>(find.byKey(const Key('patient_name_field')));
      expect(nameField.controller?.text, 'Padma Devi');

      final phoneField = tester.widget<TextFormField>(find.byKey(const Key('emergency_phone_field')));
      expect(phoneField.controller?.text, '+919876543210');

      final wakeField = tester.widget<TextFormField>(find.byKey(const Key('wake_time_field')));
      expect(wakeField.controller?.text, '07:30');

      final freqField = tester.widget<TextFormField>(find.byKey(const Key('check_in_freq_field')));
      expect(freqField.controller?.text, '3');

      final quietStartField = tester.widget<TextFormField>(find.byKey(const Key('quiet_start_field')));
      expect(quietStartField.controller?.text, '22');

      final quietEndField = tester.widget<TextFormField>(find.byKey(const Key('quiet_end_field')));
      expect(quietEndField.controller?.text, '6');

      expect(find.text('Hindi (हिन्दी)'), findsOneWidget);
      expect(find.text('Calm'), findsOneWidget);
    });

    testWidgets('2. Editing and saving valid values sends correct payload', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeApi = FakeApiService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(fakeApi),
            currentPatientIdProvider.overrideWith((ref) => 1),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EditPatientProfileDialog(
                patientId: 1,
                initialSettings: fakeApi.currentSettings,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter updated values using Keys
      await tester.enterText(find.byKey(const Key('patient_name_field')), 'Padma Sharma');
      await tester.enterText(find.byKey(const Key('emergency_phone_field')), '+919811122233');
      await tester.enterText(find.byKey(const Key('wake_time_field')), '08:15');
      await tester.enterText(find.byKey(const Key('check_in_freq_field')), '4');
      await tester.enterText(find.byKey(const Key('quiet_start_field')), '23');
      await tester.enterText(find.byKey(const Key('quiet_end_field')), '7');

      await tester.tap(find.byKey(const Key('save_settings_button')));
      await tester.pumpAndSettle();

      expect(fakeApi.lastPatientId, 1);
      expect(fakeApi.lastUpdatedSettings, isNotNull);
      expect(fakeApi.lastUpdatedSettings!['patient_name'], 'Padma Sharma');
      expect(fakeApi.lastUpdatedSettings!['emergency_contact'], '+919811122233');
      expect(fakeApi.lastUpdatedSettings!['wake_time'], '08:15');
      expect(fakeApi.lastUpdatedSettings!['check_in_frequency_hours'], 4);
      expect(fakeApi.lastUpdatedSettings!['quiet_hours_start'], 23);
      expect(fakeApi.lastUpdatedSettings!['quiet_hours_end'], 7);
      expect(fakeApi.lastUpdatedSettings!['preferred_language'], 'hi');
      expect(fakeApi.lastUpdatedSettings!['tone'], 'calm');
    });

    testWidgets('3. Successful save refreshes the displayed profile', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeApi = FakeApiService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(fakeApi),
            currentPatientIdProvider.overrideWith((ref) => 1),
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

      // Initial profile display
      expect(find.text('Padma Devi'), findsOneWidget);

      // Tap 'Edit Profile & Settings' button to open dialog
      await tester.tap(find.text('Edit Profile & Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Patient Profile & Settings'), findsOneWidget);

      // Update patient name
      await tester.enterText(find.byKey(const Key('patient_name_field')), 'Padma Sharma');

      // Save
      await tester.tap(find.byKey(const Key('save_settings_button')));
      await tester.pumpAndSettle();

      // Dialog is popped and updated name is displayed in PatientProfileCard
      expect(find.text('Edit Patient Profile & Settings'), findsNothing);
      expect(find.text('Padma Sharma'), findsOneWidget);
    });

    testWidgets('4. API failure is handled correctly with error message', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeApi = FakeApiService();
      fakeApi.shouldThrow = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(fakeApi),
            currentPatientIdProvider.overrideWith((ref) => 1),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EditPatientProfileDialog(
                patientId: 1,
                initialSettings: fakeApi.currentSettings,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Attempt save
      await tester.tap(find.byKey(const Key('save_settings_button')));
      await tester.pumpAndSettle();

      // Error message is displayed in dialog
      expect(find.textContaining('Failed to save settings'), findsOneWidget);
      // Dialog remains open
      expect(find.text('Edit Patient Profile & Settings'), findsOneWidget);
      // Save button remains active for retry
      expect(find.byKey(const Key('save_settings_button')), findsOneWidget);
    });

    testWidgets('5. Invalid input is rejected appropriately', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeApi = FakeApiService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(fakeApi),
            currentPatientIdProvider.overrideWith((ref) => 1),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EditPatientProfileDialog(
                patientId: 1,
                initialSettings: fakeApi.currentSettings,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter invalid inputs
      await tester.enterText(find.byKey(const Key('patient_name_field')), ''); // Empty name
      await tester.enterText(find.byKey(const Key('wake_time_field')), '99:99'); // Invalid time
      await tester.enterText(find.byKey(const Key('quiet_start_field')), '25'); // Invalid hour > 23
      await tester.enterText(find.byKey(const Key('check_in_freq_field')), '0'); // Invalid frequency < 1
      await tester.enterText(find.byKey(const Key('emergency_phone_field')), '12'); // Too short phone

      // Tap save
      await tester.tap(find.byKey(const Key('save_settings_button')));
      await tester.pumpAndSettle();

      // Validation errors shown
      expect(find.text('Patient name is required'), findsOneWidget);
      expect(find.text('00:00 - 23:59'), findsOneWidget);
      expect(find.text('0 - 23'), findsOneWidget);
      expect(find.text('1 - 24 hrs'), findsOneWidget);
      expect(find.text('Enter a valid phone number'), findsOneWidget);

      // Verify API was not called
      expect(fakeApi.lastUpdatedSettings, isNull);
    });
  });
}
