import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghajini_app/core/responsive.dart';

void main() {
  group('Responsive Breakpoint Tests', () {
    testWidgets('Compact phone breakpoint (<600 px)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ScreenType? detected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                detected = Responsive.getScreenType(context);
                return Text('Type: ${detected?.name}');
              },
            ),
          ),
        ),
      );

      expect(detected, equals(ScreenType.compact));
      expect(find.text('Type: compact'), findsOneWidget);
    });

    testWidgets('Medium tablet breakpoint (600-1024 px)', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ScreenType? detected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                detected = Responsive.getScreenType(context);
                return Text('Type: ${detected?.name}');
              },
            ),
          ),
        ),
      );

      expect(detected, equals(ScreenType.medium));
      expect(find.text('Type: medium'), findsOneWidget);
    });

    testWidgets('Expanded desktop web breakpoint (>1024 px)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ScreenType? detected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                detected = Responsive.getScreenType(context);
                return Text('Type: ${detected?.name}');
              },
            ),
          ),
        ),
      );

      expect(detected, equals(ScreenType.expanded));
      expect(find.text('Type: expanded'), findsOneWidget);
    });

    testWidgets('ResponsivePatientContainer constrains width to 720 on wide screens', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsivePatientContainer(
              maxWidth: 720,
              child: SizedBox(
                key: Key('patient-content'),
                height: 200,
              ),
            ),
          ),
        ),
      );

      final containerSize = tester.getSize(find.byKey(const Key('patient-content')));
      expect(containerSize.width, lessThanOrEqualTo(720.0));
    });

    testWidgets('ResponsiveCaregiverContainer constrains width to 1100 on desktop web', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveCaregiverContainer(
              maxWidth: 1100,
              child: SizedBox(
                key: Key('caregiver-content'),
                height: 200,
              ),
            ),
          ),
        ),
      );

      final containerSize = tester.getSize(find.byKey(const Key('caregiver-content')));
      expect(containerSize.width, lessThanOrEqualTo(1100.0));
    });
  });
}
