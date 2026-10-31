import 'package:go_router/go_router.dart';
import 'package:ghajini_app/screens/ask_screen.dart';
import 'package:ghajini_app/screens/cardiolife_screen.dart';
import 'package:ghajini_app/screens/companion_screen.dart';
import 'package:ghajini_app/screens/recognize_screen.dart';
import 'package:ghajini_app/screens/user_call_screen.dart';
import 'package:ghajini_app/screens/user_home_screen.dart';
import 'package:ghajini_app/screens/user_reminders_screen.dart';

/// Dedicated router for Phone 2: Elderly User Application.
/// Initial location ('/') launches the simplified elderly User Home experience with
/// white + green theme, large touch targets, voice companion, calling, face recognition,
/// reminders, and SOS emergency assistance.
final userRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const UserHomeScreen(),
    ),
    GoRoute(
      path: '/user',
      builder: (context, state) => const UserHomeScreen(),
    ),
    GoRoute(
      path: '/companion',
      builder: (context, state) => const CompanionScreen(),
    ),
    GoRoute(
      path: '/ask',
      builder: (context, state) => const AskScreen(),
    ),
    GoRoute(
      path: '/recognize',
      builder: (context, state) => const RecognizeScreen(),
    ),
    GoRoute(
      path: '/call',
      builder: (context, state) => const UserCallScreen(),
    ),
    GoRoute(
      path: '/reminders',
      builder: (context, state) => const UserRemindersScreen(),
    ),
    GoRoute(
      path: '/cardiolife',
      builder: (context, state) => const CardioLifeScreen(),
    ),
  ],
);
