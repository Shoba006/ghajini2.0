import 'package:dio/dio.dart';
import 'package:ghajini_app/core/api_client.dart';
import 'package:ghajini_app/models/alert_model.dart';
import 'package:ghajini_app/models/call_attempt.dart';
import 'package:ghajini_app/models/dashboard_summary.dart';
import 'package:ghajini_app/models/memory.dart';
import 'package:ghajini_app/models/person.dart';
import 'package:ghajini_app/models/recognition_result.dart';
import 'package:ghajini_app/models/reminder.dart';

class ApiService {
  final Dio _dio;

  ApiService({Dio? dio}) : _dio = dio ?? ApiClient.createDio();

  /// Health check
  Future<bool> checkHealth() async {
    try {
      final res = await _dio.get('/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Transcribe voice audio bytes (web & mobile compatible)
  Future<Map<String, dynamic>> transcribeVoiceBytes(List<int> bytes, {String filename = 'voice_input.wav'}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/voice/transcribe', data: formData);
    return res.data as Map<String, dynamic>;
  }

  /// Transcribe voice audio file path (delegates to fromFile on native, or fromBytes on web)
  Future<Map<String, dynamic>> transcribeVoice(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'voice_input.wav'),
    });
    final res = await _dio.post('/voice/transcribe', data: formData);
    return res.data as Map<String, dynamic>;
  }

  /// Get registered people
  Future<List<Person>> getPeople({int patientId = 1}) async {
    final res = await _dio.get('/people', queryParameters: {'patient_id': patientId});
    final list = res.data as List<dynamic>;
    return list.map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Create person (consent is mandatory)
  Future<Person> createPerson({
    required String name,
    required String relationship,
    String? notes,
    required bool consent,
    int patientId = 1,
  }) async {
    final res = await _dio.post(
      '/people',
      data: {
        'name': name,
        'relationship': relationship,
        'notes': notes,
        'consent': consent,
        'patient_id': patientId,
      },
    );
    return Person.fromJson(res.data as Map<String, dynamic>);
  }

  /// Upload face photo bytes for person (Web and mobile compatible)
  Future<Map<String, dynamic>> uploadPersonFaceBytes({
    required int personId,
    required List<int> bytes,
    String filename = 'face.jpg',
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/people/$personId/faces', data: formData);
    return res.data as Map<String, dynamic>;
  }

  /// Upload face photo for person
  Future<Map<String, dynamic>> uploadPersonFace({
    required int personId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post('/people/$personId/faces', data: formData);
    return res.data as Map<String, dynamic>;
  }

  /// Delete person
  Future<bool> deletePerson(int personId) async {
    final res = await _dio.delete('/people/$personId');
    return res.statusCode == 200;
  }

  /// Recognize face from bytes (Web and mobile compatible)
  Future<RecognitionResult> recognizeFaceBytes(List<int> bytes, {String filename = 'recognition.jpg'}) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/recognize', data: formData);
    return RecognitionResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// Recognize face from photo
  Future<RecognitionResult> recognizeFace(String imagePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imagePath),
    });
    final res = await _dio.post('/recognize', data: formData);
    return RecognitionResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// Ask memory a question
  Future<AskResponseModel> askQuestion({
    required String text,
    String lang = 'en',
    int patientId = 1,
  }) async {
    final res = await _dio.post(
      '/ask',
      data: {
        'text': text,
        'lang': lang,
        'patient_id': patientId,
      },
    );
    return AskResponseModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Add memory
  Future<Memory> createMemory({
    required String text,
    String category = 'general',
    int patientId = 1,
  }) async {
    final res = await _dio.post(
      '/memories',
      data: {
        'text': text,
        'category': category,
        'patient_id': patientId,
      },
    );
    return Memory.fromJson(res.data as Map<String, dynamic>);
  }

  /// Get upcoming reminders
  Future<List<Reminder>> getUpcomingReminders({int patientId = 1}) async {
    final res = await _dio.get(
      '/reminders/upcoming',
      queryParameters: {'patient_id': patientId},
    );
    final list = res.data as List<dynamic>;
    return list.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get currently due/triggered reminders (polled every 15s)
  Future<List<Reminder>> getDueReminders({int patientId = 1}) async {
    final res = await _dio.get(
      '/reminders/due',
      queryParameters: {'patient_id': patientId},
    );
    final list = res.data as List<dynamic>;
    return list.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Create reminder
  Future<Reminder> createReminder({
    required String title,
    String? message,
    required String scheduledTime,
    String frequency = 'daily',
    String? rrule,
    bool isCritical = false,
    int escalateAfterMin = 10,
    int patientId = 1,
  }) async {
    final res = await _dio.post(
      '/reminders',
      data: {
        'title': title,
        'message': message,
        'scheduled_time': scheduledTime,
        'frequency': frequency,
        'rrule': rrule,
        'is_critical': isCritical,
        'escalate_after_min': escalateAfterMin,
        'patient_id': patientId,
      },
    );
    return Reminder.fromJson(res.data as Map<String, dynamic>);
  }

  /// Update reminder
  Future<Reminder> updateReminder(
    int reminderId, {
    String? title,
    String? message,
    String? scheduledTime,
    String? frequency,
    String? rrule,
    bool? isCritical,
    int? escalateAfterMin,
  }) async {
    final res = await _dio.put(
      '/reminders/$reminderId',
      data: {
        if (title != null) 'title': title,
        if (message != null) 'message': message,
        if (scheduledTime != null) 'scheduled_time': scheduledTime,
        if (frequency != null) 'frequency': frequency,
        if (rrule != null) 'rrule': rrule,
        if (isCritical != null) 'is_critical': isCritical,
        if (escalateAfterMin != null) 'escalate_after_min': escalateAfterMin,
      },
    );
    return Reminder.fromJson(res.data as Map<String, dynamic>);
  }

  /// Delete reminder
  Future<bool> deleteReminder(int reminderId) async {
    final res = await _dio.delete('/reminders/$reminderId');
    return res.statusCode == 200;
  }

  /// Respond to reminder: "acknowledged" | "snoozed" | "distressed"
  Future<Reminder> respondToReminder({
    required int reminderId,
    required String response,
  }) async {
    final res = await _dio.post(
      '/reminders/$reminderId/respond',
      data: {'response': response},
    );
    return Reminder.fromJson(res.data as Map<String, dynamic>);
  }

  /// Trigger emergency SOS alert
  Future<Map<String, dynamic>> triggerSOSHelp({int patientId = 1, String? note}) async {
    final res = await _dio.post(
      '/alerts/help',
      data: {
        'patient_id': patientId,
        'note': note ?? 'SOS button tapped by patient.',
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// Get recent alerts for caregiver
  Future<List<AlertModel>> getRecentAlerts({int patientId = 1}) async {
    final res = await _dio.get(
      '/alerts',
      queryParameters: {'patient_id': patientId},
    );
    final list = res.data as List<dynamic>;
    return list.map((e) => AlertModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get Caregiver Dashboard summary metrics
  Future<DashboardSummary> getDashboardSummary({int patientId = 1}) async {
    final res = await _dio.get(
      '/dashboard/summary',
      queryParameters: {'patient_id': patientId},
    );
    return DashboardSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// Get plain-English daily summary
  Future<DailySummary> getDailySummary({int patientId = 1}) async {
    final res = await _dio.get(
      '/dashboard/daily-summary',
      queryParameters: {'patient_id': patientId},
    );
    return DailySummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// Reset demo data to initial pristine demo state
  Future<Map<String, dynamic>> resetDemoData({int patientId = 1}) async {
    final res = await _dio.post(
      '/demo/reset',
      queryParameters: {'patient_id': patientId},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Force-trigger a reminder immediately for live demonstration
  Future<Map<String, dynamic>> triggerReminderNow({int patientId = 1}) async {
    final res = await _dio.post(
      '/demo/trigger-reminder',
      queryParameters: {'patient_id': patientId},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Export all patient personal data as ZIP
  Future<List<int>> exportData({int patientId = 1}) async {
    final res = await _dio.get(
      '/privacy/export',
      queryParameters: {'patient_id': patientId},
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data as List<int>;
  }

  /// Wipe all patient records, faces, reminders and audit logs
  Future<bool> wipeAllData({int patientId = 1}) async {
    final res = await _dio.delete(
      '/privacy/all',
      queryParameters: {'patient_id': patientId},
    );
    return res.statusCode == 200;
  }

  /// Alias for wipeAllData
  Future<bool> wipePatientData({int patientId = 1}) => wipeAllData(patientId: patientId);

  /// Patient AI Companion: Send message
  Future<Map<String, dynamic>> sendCompanionMessage({
    required String text,
    String? lang,
    String source = 'text',
    int patientId = 1,
  }) async {
    final res = await _dio.post(
      '/companion/message',
      data: {
        'patient_id': patientId,
        'text': text,
        'lang': lang,
        'source': source,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// Patient AI Companion: Poll proactive message
  Future<Map<String, dynamic>> getCompanionProactive({int patientId = 1}) async {
    final res = await _dio.get(
      '/companion/proactive',
      queryParameters: {'patient_id': patientId},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Patient AI Companion: Respond to gentle check-in
  Future<void> respondCompanionCheckin({
    required String status,
    String? checkinId,
    int patientId = 1,
  }) async {
    await _dio.post(
      '/companion/check-in/respond',
      data: {
        'patient_id': patientId,
        'checkin_id': checkinId,
        'status': status,
      },
    );
  }

  /// Patient AI Companion: Teach a new memory
  Future<Map<String, dynamic>> teachCompanion({
    required String text,
    String category = 'personal',
    int patientId = 1,
  }) async {
    final res = await _dio.post(
      '/companion/teach',
      data: {
        'patient_id': patientId,
        'text': text,
        'category': category,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// Patient AI Companion: Get settings
  Future<Map<String, dynamic>> getCompanionSettings({int patientId = 1}) async {
    final res = await _dio.get(
      '/companion/settings',
      queryParameters: {'patient_id': patientId},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Patient AI Companion: Update settings
  Future<Map<String, dynamic>> updateCompanionSettings({
    required Map<String, dynamic> settings,
    int patientId = 1,
  }) async {
    final res = await _dio.post(
      '/companion/settings',
      queryParameters: {'patient_id': patientId},
      data: settings,
    );
    return res.data as Map<String, dynamic>;
  }

  /// Patient AI Companion: List conversation logs
  Future<List<dynamic>> listCompanionConversations({
    int patientId = 1,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/companion/conversations',
      queryParameters: {'patient_id': patientId, 'limit': limit},
    );
    return res.data as List<dynamic>;
  }

  /// Patient AI Companion: Mark reply as wrong
  Future<void> markConversationWrong({
    required String conversationId,
    String? reason,
  }) async {
    await _dio.post(
      '/companion/conversations/$conversationId/feedback',
      data: {
        'marked_wrong': true,
        'reason': reason ?? 'Flagged by caregiver as inaccurate',
      },
    );
  }

  /// Calling Agent: Request a call from patient's phone
  Future<Map<String, dynamic>> requestCall({
    required String reason,
    required String source,
    int patientId = 1,
    String lang = 'en',
    int contactIndex = 0,
  }) async {
    final res = await _dio.post(
      '/calls/request',
      data: {
        'patient_id': patientId,
        'reason': reason,
        'source': source,
        'lang': lang,
        'contact_index': contactIndex,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// Calling Agent: Report call result (answered / not_answered / cancelled)
  Future<Map<String, dynamic>> reportCallResult({
    required String callId,
    required String status,
    String? note,
  }) async {
    final res = await _dio.post(
      '/calls/$callId/result',
      data: {
        'status': status,
        'note': note,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// Calling Agent: Send test alert
  Future<Map<String, dynamic>> sendTestAlert({
    int patientId = 1,
    String? botToken,
    String? chatId,
    String lang = 'en',
  }) async {
    final res = await _dio.post(
      '/calls/test-alert',
      data: {
        'patient_id': patientId,
        'bot_token': botToken,
        'chat_id': chatId,
        'lang': lang,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// Calling Agent: Fetch call history
  Future<List<dynamic>> getCallHistory({
    int patientId = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/calls/history',
      queryParameters: {'patient_id': patientId, 'limit': limit},
    );
    return res.data as List<dynamic>;
  }

  /// Update person emergency contact status
  Future<Map<String, dynamic>> updatePersonEmergency({
    required int personId,
    required bool isEmergencyContact,
    String? phone,
    int priority = 1,
  }) async {
    final res = await _dio.put(
      '/people/$personId/emergency',
      data: {
        'is_emergency_contact': isEmergencyContact,
        'phone': phone,
        'priority': priority,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// CardioLife: Fetch current vitals summary with multilingual descriptions
  Future<Map<String, dynamic>> getCurrentVitals({int patientId = 1}) async {
    final res = await _dio.get(
      '/cardiolife/current',
      queryParameters: {'patient_id': patientId},
    );
    return res.data as Map<String, dynamic>;
  }

  /// CardioLife: Fetch historical vitals readings
  Future<List<dynamic>> getVitalsHistory({
    int patientId = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/cardiolife/history',
      queryParameters: {'patient_id': patientId, 'limit': limit},
    );
    return res.data as List<dynamic>;
  }

  /// CardioLife: Fetch live mathematical ECG waveform data points
  Future<Map<String, dynamic>> getLiveEcg({
    int bpm = 72,
    int samples = 120,
  }) async {
    final res = await _dio.get(
      '/cardiolife/ecg-live',
      queryParameters: {'bpm': bpm, 'samples': samples},
    );
    return res.data as Map<String, dynamic>;
  }

  /// CardioLife: Record a telemetry vitals reading
  Future<Map<String, dynamic>> recordVitals({
    required int bpm,
    int? systolic,
    int? diastolic,
    int? oxygen,
    int? hrv,
    String? notes,
    int patientId = 1,
  }) async {
    final res = await _dio.post(
      '/cardiolife/readings',
      data: {
        'patient_id': patientId,
        'heart_rate_bpm': bpm,
        'blood_pressure_systolic': systolic ?? 120,
        'blood_pressure_diastolic': diastolic ?? 80,
        'oxygen_saturation': oxygen ?? 98,
        'hrv_ms': hrv ?? 45,
        'notes': notes,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// CardioLife: Simulate a cardiac condition scenario for demo
  Future<Map<String, dynamic>> simulateVitals(
    String scenario, {
    int patientId = 1,
  }) async {
    final res = await _dio.post(
      '/cardiolife/simulate',
      queryParameters: {
        'scenario': scenario,
        'patient_id': patientId,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// OmniDimension Orchestrated Calling:
  /// Initiates an outbound phone call managed by the backend 3-attempt orchestrator.
  Future<Map<String, dynamic>> initiateOrchestratedCall({
    required String reason,
    int patientId = 1,
    String source = 'routine',
    String? callSessionId,
    int? reminderId,
    int? contactId,
  }) async {
    final res = await _dio.post(
      '/calls/orchestrated/initiate',
      data: {
        'patient_id': patientId,
        'reason': reason,
        'source': source,
        if (callSessionId != null) 'call_session_id': callSessionId,
        if (reminderId != null) 'reminder_id': reminderId,
        if (contactId != null) 'contact_id': contactId,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// OmniDimension Orchestrated Calling:
  /// Returns all call attempts for a call session ID.
  Future<List<CallAttempt>> getCallAttempts(String callSessionId) async {
    final res = await _dio.get('/calls/attempts/$callSessionId');
    final list = res.data as List<dynamic>;
    return list.map((e) => CallAttempt.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Calling Agent: Clear active cooldown and throttle locks
  Future<Map<String, dynamic>> resetCallCooldown({int patientId = 1}) async {
    final res = await _dio.post(
      '/calls/reset-cooldown',
      queryParameters: {'patient_id': patientId},
    );
    return res.data as Map<String, dynamic>;
  }
}
