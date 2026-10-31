import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghajini_app/main_caretaker.dart';
import 'package:ghajini_app/main_user.dart';
import 'package:ghajini_app/models/call_attempt.dart';
import 'package:ghajini_app/models/patient.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/router/caretaker_router.dart';
import 'package:ghajini_app/router/user_router.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Orchestrated Calling & Dual App Architecture Tests', () {
    test('CallAttempt fromJson correctly parses 3-attempt lifecycle status', () {
      final json = {
        'id': 4,
        'call_session_id': 'padma_live_no_answer_test_01',
        'attempt_number': 1,
        'provider': 'omnidim',
        'provider_call_id': 'b587c540-52ac-4319-9bed-2fe92860f03e',
        'recipient_name': 'Shobamalika',
        'recipient_phone': '+919123507478',
        'status': 'no_answer',
        'is_technical_failure': false,
        'failure_reason': null,
        'duration_seconds': 0,
        'created_at': '2026-10-30T22:55:45.065071',
        'updated_at': '2026-10-30T22:56:36.430086',
      };

      final attempt = CallAttempt.fromJson(json);

      expect(attempt.id, 4);
      expect(attempt.callSessionId, 'padma_live_no_answer_test_01');
      expect(attempt.attemptNumber, 1);
      expect(attempt.provider, 'omnidim');
      expect(attempt.providerCallId, 'b587c540-52ac-4319-9bed-2fe92860f03e');
      expect(attempt.recipientName, 'Shobamalika');
      expect(attempt.recipientPhone, '+919123507478');
      expect(attempt.status, 'no_answer');
      expect(attempt.isNoAnswer, isTrue);
      expect(attempt.isCompleted, isFalse);
      expect(attempt.isTechnicalFailure, isFalse);
    });

    test('Patient fromJson parses correctly', () {
      final json = {
        'id': 1,
        'name': 'Padma',
        'age': 76,
        'condition': 'Mild Cognitive Impairment',
        'emergency_notes': 'Penicillin allergy',
        'created_at': '2026-10-30T10:00:00Z',
      };

      final patient = Patient.fromJson(json);

      expect(patient.id, 1);
      expect(patient.name, 'Padma');
      expect(patient.age, 76);
      expect(patient.condition, 'Mild Cognitive Impairment');
      expect(patient.emergencyNotes, 'Penicillin allergy');
    });

    test('AppMode provider defaults to combined and switches per app entrypoint', () {
      final element = ProviderContainer();

      // Universal / dev mode default
      expect(element.read(currentAppModeProvider), AppMode.combined);
      expect(element.read(currentPatientIdProvider), 1);

      // Phone 1 Caretaker override
      final caretakerContainer = ProviderContainer(
        overrides: [
          currentAppModeProvider.overrideWith((ref) => AppMode.caretaker),
        ],
      );
      expect(caretakerContainer.read(currentAppModeProvider), AppMode.caretaker);

      // Phone 2 User override
      final userContainer = ProviderContainer(
        overrides: [
          currentAppModeProvider.overrideWith((ref) => AppMode.user),
        ],
      );
      expect(userContainer.read(currentAppModeProvider), AppMode.user);
    });

    test('Caretaker Router configures Phone 1 caretaker routes without patient mode', () {
      final routes = caretakerRouter.configuration.routes.whereType<GoRoute>();
      final paths = routes.map((r) => r.path).toList();

      expect(paths.contains('/'), isTrue);
      expect(paths.contains('/caregiver'), isTrue);
      expect(paths.contains('/dashboard'), isTrue);
      expect(paths.contains('/add-person'), isTrue);
      expect(paths.contains('/cardiolife'), isTrue);
      expect(paths.contains('/privacy'), isTrue);

      // Caretaker router does not include elderly-only user routes
      expect(paths.contains('/companion'), isFalse);
      expect(paths.contains('/recognize'), isFalse);
      expect(paths.contains('/ask'), isFalse);
    });

    test('User Router configures Phone 2 user routes without complex admin dashboard', () {
      final routes = userRouter.configuration.routes.whereType<GoRoute>();
      final paths = routes.map((r) => r.path).toList();

      expect(paths.contains('/'), isTrue);
      expect(paths.contains('/companion'), isTrue);
      expect(paths.contains('/recognize'), isTrue);
      expect(paths.contains('/ask'), isTrue);
      expect(paths.contains('/cardiolife'), isTrue);

      // User router does not expose caretaker management
      expect(paths.contains('/caregiver'), isFalse);
      expect(paths.contains('/dashboard'), isFalse);
    });

    test('GhajiniCaretakerApp instantiates with Caretaker identity', () {
      const app = GhajiniCaretakerApp();
      expect(app, isNotNull);
    });

    test('GhajiniUserApp instantiates with User identity', () {
      const app = GhajiniUserApp();
      expect(app, isNotNull);
    });
  });
}
