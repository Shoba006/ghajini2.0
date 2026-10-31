import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghajini_app/core/user_theme.dart';
import 'package:ghajini_app/models/reminder.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/screens/user_home_screen.dart';
import 'package:ghajini_app/widgets/user_action_card.dart';

void main() {
  group('UserHomeScreen Elderly Accessibility & UI Structure Tests', () {
    testWidgets('Renders all 5 primary user actions with >= 80 dp touch target', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            upcomingRemindersProvider.overrideWith((ref) => Future.value(<Reminder>[])),
            patientSettingsProvider.overrideWith((ref) => Future.value({
              'patient_name': 'Padma',
              'preferred_language': 'en',
            })),
          ],
          child: MaterialApp(
            theme: UserTheme.theme,
            home: const UserHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the 5 visually obvious actions exist
      expect(find.text('Talk to Ghajini'), findsOneWidget);
      expect(find.text('Call Someone'), findsOneWidget);
      expect(find.text('Recognize Person'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('EMERGENCY / SOS'), findsOneWidget);

      // Verify header branding and patient greeting
      expect(find.text('Ghajini'), findsOneWidget);
      expect(find.text('Good Day, Padma!'), findsOneWidget);

      // Find all UserActionCard widgets and verify >= 80 dp height for elderly accessibility
      final actionCardFinders = find.byType(UserActionCard);
      expect(actionCardFinders, findsNWidgets(5));

      for (final element in actionCardFinders.evaluate()) {
        final renderBox = element.renderObject as RenderBox?;
        if (renderBox != null) {
          expect(renderBox.size.height, greaterThanOrEqualTo(80.0));
        }
      }
    });

    testWidgets('Tapping language chip cycles language', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          upcomingRemindersProvider.overrideWith((ref) => Future.value(<Reminder>[])),
          patientSettingsProvider.overrideWith((ref) => Future.value({})),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: UserTheme.theme,
            home: const UserHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial language is English
      expect(find.text('English'), findsOneWidget);

      // Tap language chip -> cycles to Hindi
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('हिंदी'), findsOneWidget);

      // Tap again -> cycles to Punjabi
      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();
      expect(find.text('ਪੰਜਾਬੀ'), findsOneWidget);
    });

    testWidgets('Renders upcoming reminder banner when pending reminder exists', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testReminder = Reminder(
        id: 101,
        patientId: 1,
        title: 'Blood Pressure Pill',
        message: 'Take 1 tablet with warm water',
        scheduledTime: '09:00',
        frequency: 'daily',
        status: 'pending',
        isCritical: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            upcomingRemindersProvider.overrideWith((ref) => Future.value([testReminder])),
            patientSettingsProvider.overrideWith((ref) => Future.value({})),
          ],
          child: MaterialApp(
            theme: UserTheme.theme,
            home: const UserHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NEXT AT 09:00'), findsOneWidget);
      expect(find.text('Blood Pressure Pill'), findsOneWidget);
      expect(find.text('IMPORTANT'), findsOneWidget);
    });
  });
}
