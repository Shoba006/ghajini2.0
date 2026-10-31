import 'package:go_router/go_router.dart';
import 'package:ghajini_app/screens/add_person_screen.dart';
import 'package:ghajini_app/screens/ask_screen.dart';
import 'package:ghajini_app/screens/cardiolife_screen.dart';
import 'package:ghajini_app/screens/caregiver_screen.dart';
import 'package:ghajini_app/screens/companion_screen.dart';
import 'package:ghajini_app/screens/dashboard_screen.dart';
import 'package:ghajini_app/screens/home_screen.dart';
import 'package:ghajini_app/screens/privacy_screen.dart';
import 'package:ghajini_app/screens/recognize_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/user',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/caretaker',
      builder: (context, state) => const CaregiverScreen(),
    ),
    GoRoute(
      path: '/companion',
      builder: (context, state) => const CompanionScreen(),
    ),
    GoRoute(
      path: '/recognize',
      builder: (context, state) => const RecognizeScreen(),
    ),
    GoRoute(
      path: '/ask',
      builder: (context, state) => const AskScreen(),
    ),
    GoRoute(
      path: '/add-person',
      builder: (context, state) => const AddPersonScreen(),
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
      path: '/privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: '/cardiolife',
      builder: (context, state) => const CardioLifeScreen(),
    ),
  ],
);
