import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/models/call_attempt.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/widgets/call_session_card.dart';

void main() {
  group('CallSessionCard & Attempt Timeline Widget Tests', () {
    testWidgets('Renders recipient, reason, status chip and attempt count', (tester) async {
      final callData = {
        'id': 'call_live_01',
        'call_session_id': 'padma_live_no_answer_test_01',
        'attempt_number': 3,
        'patient_id': 1,
        'recipient': {'name': 'Shobamalika', 'phone': '+919123507478'},
        'provider': 'omnidim',
        'provider_call_id': 'bd4183f1-aac9-4470-9e99-4cd2062a980c',
        'status': 'no_answer',
        'reason': 'Controlled 3-attempt no-answer escalation test',
        'source': 'routine',
        'reminder_id': 3,
        'is_technical_failure': false,
        'created_at': '2026-10-30T22:55:45.065071',
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: GhajiniTheme.lightTheme,
          home: Scaffold(
            body: ProviderScope(
              child: SingleChildScrollView(
                child: CallSessionCard(callData: callData),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check recipient name & phone
      expect(find.text('Shobamalika'), findsOneWidget);
      expect(find.text('+919123507478'), findsOneWidget);

      // Check reason and escalation status
      expect(find.text('Controlled 3-attempt no-answer escalation test'), findsOneWidget);
      expect(find.text('ESCALATED'), findsOneWidget);
      expect(find.text('3 of 3 Attempts (Escalated)'), findsOneWidget);

      // Check timeline toggle button
      expect(find.text('View Attempt Timeline (1 → 2 → 3)'), findsOneWidget);
    });

    testWidgets('Tapping View Attempt Timeline expands 3-attempt stepped sequence', (tester) async {
      final callData = {
        'id': 'call_live_01',
        'call_session_id': 'padma_live_no_answer_test_01',
        'attempt_number': 3,
        'patient_id': 1,
        'recipient': {'name': 'Shobamalika', 'phone': '+919123507478'},
        'status': 'no_answer',
        'reason': 'Controlled 3-attempt no-answer escalation test',
        'created_at': '2026-10-30T22:55:45.065071',
      };

      final mockAttempts = [
        CallAttempt(
          id: 4,
          callSessionId: 'padma_live_no_answer_test_01',
          attemptNumber: 1,
          provider: 'omnidim',
          providerCallId: 'b587c540-52ac-4319-9bed-2fe92860f03e',
          recipientName: 'Shobamalika',
          recipientPhone: '+919123507478',
          status: 'no_answer',
          createdAt: DateTime.parse('2026-10-30T22:55:45.065071'),
        ),
        CallAttempt(
          id: 5,
          callSessionId: 'padma_live_no_answer_test_01',
          attemptNumber: 2,
          provider: 'omnidim',
          providerCallId: '3bea9b13-8743-422b-a695-d456b7851739',
          recipientName: 'Shobamalika',
          recipientPhone: '+919123507478',
          status: 'no_answer',
          createdAt: DateTime.parse('2026-10-30T22:56:39.792714'),
        ),
        CallAttempt(
          id: 6,
          callSessionId: 'padma_live_no_answer_test_01',
          attemptNumber: 3,
          provider: 'omnidim',
          providerCallId: 'bd4183f1-aac9-4470-9e99-4cd2062a980c',
          recipientName: 'Shobamalika',
          recipientPhone: '+919123507478',
          status: 'no_answer',
          createdAt: DateTime.parse('2026-10-30T22:57:34.978655'),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: GhajiniTheme.lightTheme,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                callSessionAttemptsProvider('padma_live_no_answer_test_01')
                    .overrideWith((ref) => Future.value(mockAttempts)),
              ],
              child: SingleChildScrollView(
                child: CallSessionCard(callData: callData),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap toggle button to expand timeline
      await tester.tap(find.text('View Attempt Timeline (1 → 2 → 3)'));
      await tester.pumpAndSettle();

      // Verify toggle button label changes to Hide
      expect(find.text('Hide Attempt Timeline'), findsOneWidget);

      // Verify timeline sequence header
      expect(find.text('Call Attempt Sequence (3 of 3)'), findsOneWidget);

      // Verify all 3 attempts appear with step indicators
      expect(find.text('Attempt 1'), findsOneWidget);
      expect(find.text('Attempt 2'), findsOneWidget);
      expect(find.text('Attempt 3'), findsOneWidget);

      // Verify Attempt 1 and 2 show No Answer
      expect(find.text('No Answer'), findsNWidgets(2));

      // Verify Attempt 3 shows Escalated (No Answer)
      expect(find.text('Escalated (No Answer)'), findsOneWidget);

      // Verify escalation warning message is displayed
      expect(
        find.text('Calling halted after 3 unanswered attempts. Caretaker escalation alert generated.'),
        findsOneWidget,
      );
    });

    testWidgets('Renders Completed status chip when call is answered', (tester) async {
      final callData = {
        'id': 'call_answered_01',
        'call_session_id': 'sess_answered_01',
        'attempt_number': 1,
        'patient_id': 1,
        'recipient': {'name': 'Padma', 'phone': '+919123507478'},
        'status': 'completed',
        'reason': 'Morning Medication Reminder',
        'created_at': '2026-10-30T09:00:00.000000',
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: GhajiniTheme.lightTheme,
          home: Scaffold(
            body: ProviderScope(
              child: SingleChildScrollView(
                child: CallSessionCard(callData: callData),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('Attempt 1 of 3'), findsOneWidget);
    });
  });
}

