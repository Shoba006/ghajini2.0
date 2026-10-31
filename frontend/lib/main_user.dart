import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghajini_app/core/user_theme.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/router/user_router.dart';

/// Entrypoint for Phone 2: Elderly User Application.
/// Run via: flutter run -t lib/main_user.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        currentAppModeProvider.overrideWith((ref) => AppMode.user),
      ],
      child: const GhajiniUserApp(),
    ),
  );
}

class GhajiniUserApp extends StatelessWidget {
  const GhajiniUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ghajini User',
      theme: UserTheme.theme,
      debugShowCheckedModeBanner: false,
      routerConfig: userRouter,
    );
  }
}
