import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghajini_app/core/call_service.dart';
import 'package:ghajini_app/core/theme.dart';

void main() {
  group('CallService & Fallback Dialer Tests', () {
    test('Clean phone numbers removes dashes, spaces and brackets', () {
      expect(CallService.cleanPhoneNumber('+91 98765-43210'), '+919876543210');
      expect(CallService.cleanPhoneNumber('(080) 1234 5678'), '08012345678');
      expect(CallService.cleanPhoneNumber('+1 (800) 555-0199'), '+18005550199');
    });

    testWidgets('Fallback dialer dialog displays number, Copy button and Dialer button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: GhajiniTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CallService.showFallbackDialerDialog(
                    context,
                    phone: '+919876543210',
                    contactName: 'Priya',
                  );
                },
                child: const Text('Open Fallback'),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Open Fallback'));
      await tester.pumpAndSettle();

      // Verify contact name and phone number badge are present
      expect(find.text('Call Priya'), findsOneWidget);
      expect(find.text('+919876543210'), findsOneWidget);

      // Verify Copy and Dialer buttons are present
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Dialer'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Tap Copy button
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      // Verify dialog is closed after copying
      expect(find.text('+919876543210'), findsNothing);
    });
  });
}
