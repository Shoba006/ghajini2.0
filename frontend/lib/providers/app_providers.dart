import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghajini_app/models/alert_model.dart';
import 'package:ghajini_app/models/call_attempt.dart';
import 'package:ghajini_app/models/dashboard_summary.dart';
import 'package:ghajini_app/models/person.dart';
import 'package:ghajini_app/models/reminder.dart';
import 'package:ghajini_app/services/api_service.dart';
import 'package:ghajini_app/services/tts_service.dart';

enum AppMode {
  user,
  caretaker,
  combined,
}

final currentAppModeProvider = StateProvider<AppMode>((ref) => AppMode.combined);
final currentPatientIdProvider = StateProvider<int>((ref) => 1);

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

/// Current language selection (en, hi, pa) saved locally in state
final currentLanguageProvider = StateProvider<String>((ref) => 'en');
final languageProvider = currentLanguageProvider;

/// Fetches upcoming reminders
final upcomingRemindersProvider = FutureProvider.autoDispose<List<Reminder>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getUpcomingReminders();
});

/// Fetches currently due reminders (for periodic polling)
final dueRemindersProvider = FutureProvider.autoDispose<List<Reminder>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getDueReminders();
});

/// Fetches recent caregiver alerts
final recentAlertsProvider = FutureProvider.autoDispose<List<AlertModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getRecentAlerts();
});

/// Fetches registered people
final peopleListProvider = FutureProvider.autoDispose<List<Person>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getPeople();
});

/// Fetches Caregiver Dashboard summary metrics
final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getDashboardSummary();
});

/// Fetches plain-English daily summary
final dailySummaryProvider = FutureProvider.autoDispose<DailySummary>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getDailySummary();
});

/// CardioLife: Current heart rate & vitals telemetry summary
final currentVitalsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCurrentVitals();
});

/// CardioLife: Historical vitals recordings
final vitalsHistoryProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getVitalsHistory();
});

/// CardioLife: Live mathematical ECG waveform data points
final liveEcgWaveformProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, bpm) async {
  final api = ref.watch(apiServiceProvider);
  return api.getLiveEcg(bpm: bpm, samples: 100);
});

/// Active orchestrated call session ID being tracked
final activeCallSessionIdProvider = StateProvider<String?>((ref) => null);

/// Fetches all call attempts for an orchestrated call session
final callSessionAttemptsProvider = FutureProvider.autoDispose.family<List<CallAttempt>, String>((ref, sessionId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCallAttempts(sessionId);
});

/// Fetches recent call history records from backend
final callHistoryProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final patientId = ref.watch(currentPatientIdProvider);
  return api.getCallHistory(patientId: patientId);
});

/// Fetches patient companion & profile settings
final patientSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final patientId = ref.watch(currentPatientIdProvider);
  return api.getCompanionSettings(patientId: patientId);
});
