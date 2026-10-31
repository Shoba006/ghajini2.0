import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghajini_app/core/user_theme.dart';
import 'package:ghajini_app/models/person.dart';
import 'package:ghajini_app/models/reminder.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/screens/user_call_screen.dart';
import 'package:ghajini_app/screens/user_reminders_screen.dart';

void main() {
  group('UserRemindersScreen Tests', () {
    testWidgets('Renders empty state when no reminders', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            upcomingRemindersProvider.overrideWith((ref) => Future.value(<Reminder>[])),
          ],
          child: MaterialApp(
            theme: UserTheme.theme,
            home: const UserRemindersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Today's Reminders"), findsOneWidget);
      expect(find.text("All Caught Up!"), findsOneWidget);
    });

    testWidgets('Renders reminders list with time and I Have Taken This button', (tester) async {
      final rem = Reminder(
        id: 1,
        patientId: 1,
        title: 'Morning Medicine',
        message: 'Take with food',
        scheduledTime: '08:00 AM',
        frequency: 'daily',
        status: 'pending',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            upcomingRemindersProvider.overrideWith((ref) => Future.value([rem])),
          ],
          child: MaterialApp(
            theme: UserTheme.theme,
            home: const UserRemindersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Morning Medicine'), findsOneWidget);
      expect(find.text('08:00 AM'), findsOneWidget);
      expect(find.text('I Have Taken This'), findsOneWidget);
    });
  });

  group('UserCallScreen Tests', () {
    testWidgets('Renders Call Family button and contact cards', (tester) async {
      final person = Person(
        id: 1,
        patientId: 1,
        name: 'Shobamalika',
        relationship: 'Daughter',
        phone: '+919876543210',
        isEmergencyContact: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            peopleListProvider.overrideWith((ref) => Future.value([person])),
          ],
          child: MaterialApp(
            theme: UserTheme.theme,
            home: const UserCallScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Call Someone'), findsOneWidget);
      expect(find.text('Call Family'), findsOneWidget);
      expect(find.text('Shobamalika'), findsOneWidget);
      expect(find.text('Daughter'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
    });
  });
}
