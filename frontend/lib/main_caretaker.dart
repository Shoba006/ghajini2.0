import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/router/caretaker_router.dart';

/// Entrypoint for Phone 1: Caretaker / Admin Application.
/// Run via: flutter run -t lib/main_caretaker.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        currentAppModeProvider.overrideWith((ref) => AppMode.caretaker),
      ],
      child: const GhajiniCaretakerApp(),
    ),
  );
}

class GhajiniCaretakerApp extends StatelessWidget {
  const GhajiniCaretakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ghajini Caretaker',
      theme: AppTheme.elderlyTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: caretakerRouter,
    );
  }
}

