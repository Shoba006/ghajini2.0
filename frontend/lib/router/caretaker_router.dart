import 'package:go_router/go_router.dart';
import 'package:ghajini_app/screens/add_person_screen.dart';
import 'package:ghajini_app/screens/cardiolife_screen.dart';
import 'package:ghajini_app/screens/caregiver_screen.dart';
import 'package:ghajini_app/screens/dashboard_screen.dart';
import 'package:ghajini_app/screens/privacy_screen.dart';

/// Dedicated router for Phone 1: Caretaker / Admin Application.
/// Initial location ('/') launches directly into the Caregiver Portal so that
/// the caretaker never encounters the elderly User Mode interface.
final caretakerRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const CaregiverScreen(),
    ),
    GoRoute(
      path: '/caregiver',
      builder: (context, state) => const CaregiverScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/add-person',
      builder: (context, state) => const AddPersonScreen(),
    ),
    GoRoute(
      path: '/cardiolife',
      builder: (context, state) => const CardioLifeScreen(),
    ),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),
  ],
);

