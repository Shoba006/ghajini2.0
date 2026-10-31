import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghajini_app/core/user_theme.dart';
import 'package:ghajini_app/models/person.dart';
import 'package:ghajini_app/models/reminder.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/screens/companion_screen.dart';
import 'package:ghajini_app/screens/recognize_screen.dart';
import 'package:ghajini_app/screens/user_call_screen.dart';
import 'package:ghajini_app/screens/user_reminders_screen.dart';
import 'package:ghajini_app/services/api_service.dart';

class MockApiService extends Fake implements ApiService {
  String? lastReminderStatus;
  int? lastReminderId;
  bool orchestratedCallInitiated = false;

  @override
  Future<Map<String, dynamic>> getCompanionProactive({int patientId = 1}) async {
    return {'has_message': false};
  }

  @override
  Future<Map<String, dynamic>> sendCompanionMessage({
    required String text,
    String? lang,
    String source = 'text',
    int patientId = 1,
  }) async {
    return {
      'reply': 'I heard you say: $text',
      'actions': <dynamic>[],
      'person': null,
    };
  }

  @override
  Future<Reminder> respondToReminder({
    required int reminderId,
    required String response,
  }) async {
    lastReminderId = reminderId;
    lastReminderStatus = response;
    return Reminder(
      id: reminderId,
      patientId: 1,
      title: 'Test Reminder',
      scheduledTime: '10:00 AM',
      frequency: 'daily',
      status: response,
    );
  }

  @override
  Future<Map<String, dynamic>> initiateOrchestratedCall({
    required String reason,
    int patientId = 1,
    String source = 'routine',
    String? callSessionId,
    int? reminderId,
    int? contactId,
  }) async {
    orchestratedCallInitiated = true;
    return {
      'status': 'initiated',
      'call_session_id': 'sess_123',
    };
  }
}

void main() {
  group('Phase 2 User App Integration Tests', () {
    testWidgets('CompanionScreen renders greeting, avatar, and speech controls', (tester) async {
      final mockApi = MockApiService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApi),
            currentLanguageProvider.overrideWith((ref) => 'en'),
          ],
          child: MaterialApp(
            theme: UserTheme.theme,
            home: const CompanionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Companion'), findsOneWidget);
      expect(find.text('🤖'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('Who is this?'), findsOneWidget);
      expect(find.text("What's next?"), findsOneWidget);
      expect(find.text('Call family'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('UserRemindersScreen provides both Taken and Snooze actions', (tester) async {
      final mockApi = MockApiService();
      final rem = Reminder(
        id: 42,
        patientId: 1,
        title: 'Blood Pressure Tablet',
        message: 'Take 1 tablet after breakfast',
        scheduledTime: '09:00 AM',
        frequency: 'daily',
        status: 'pending',
        isCritical: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApi),
            upcomingRemindersProvider.overrideWith((ref) => Future.value([rem])),
          ],
          child: MaterialApp(
            theme: UserTheme.theme,
            home: const UserRemindersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blood Pressure Tablet'), findsOneWidget);
      expect(find.text('IMPORTANT'), findsOneWidget);
      expect(find.text('I Have Taken This'), findsOneWidget);
      expect(find.text('Remind Me in 5 Min'), findsOneWidget);

      // Tap Snooze
      await tester.tap(find.text('Remind Me in 5 Min'));
      await tester.pumpAndSettle();

      expect(mockApi.lastReminderId, equals(42));
      expect(mockApi.lastReminderStatus, equals('snoozed'));
    });

    testWidgets('UserCallScreen provides OmniDimension automated call confirmation dialog', (tester) async {
      final mockApi = MockApiService();
      final person = Person(
        id: 7,
        patientId: 1,
        name: 'Dr. Mehta',
        relationship: 'Cardiologist',
        phone: '+919988776655',
        isEmergencyContact: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApi),
            peopleListProvider.overrideWith((ref) => Future.value([person])),
          ],
          child: MaterialApp(
            theme: UserTheme.theme,
            home: const UserCallScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dr. Mehta'), findsOneWidget);
      expect(find.text('Cardiologist'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);

      // Tap smart toy icon -> opens OmniDimension confirmation dialog
      await tester.tap(find.byIcon(Icons.smart_toy_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Request AI Call to Dr. Mehta?'), findsOneWidget);
      expect(find.text('Request Call'), findsOneWidget);

      // Confirm call
      await tester.tap(find.text('Request Call'));
      await tester.pumpAndSettle();

      expect(mockApi.orchestratedCallInitiated, isTrue);
    });

    testWidgets('RecognizeScreen renders photo capture actions and instruction banner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLanguageProvider.overrideWith((ref) => 'en'),
          ],
          child: MaterialApp(
            theme: UserTheme.theme,
            home: const RecognizeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Who Is This?'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Pick Photo'), findsOneWidget);
      expect(find.text('Show a photo or take a picture to recognize your loved ones.'), findsOneWidget);
    });
  });
}
