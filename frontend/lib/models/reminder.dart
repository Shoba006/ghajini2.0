class Reminder {
  final int id;
  final int patientId;
  final String title;
  final String? message;
  final String scheduledTime;
  final String frequency;
  final String? rrule;
  final bool isCritical;
  final int escalateAfterMin;
  final String status;
  final int retryCount;
  final DateTime? lastTriggeredAt;
  final DateTime? nextRunAt;
  final DateTime createdAt;
  final bool? active;

  Reminder({
    required this.id,
    required this.patientId,
    required this.title,
    this.message,
    required this.scheduledTime,
    required this.frequency,
    this.rrule,
    this.isCritical = false,
    this.escalateAfterMin = 10,
    this.status = 'pending',
    this.retryCount = 0,
    this.lastTriggeredAt,
    this.nextRunAt,
    DateTime? createdAt,
    this.active,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: (json['id'] as num).toInt(),
      patientId: ((json['patient_id'] ?? 1) as num).toInt(),
      title: json['title'] as String? ?? 'Reminder',
      message: json['message'] as String?,
      scheduledTime: json['scheduled_time'] as String? ?? '09:00',
      frequency: json['frequency'] as String? ?? 'daily',
      rrule: json['rrule'] as String?,
      isCritical: json['is_critical'] as bool? ?? false,
      escalateAfterMin: (json['escalate_after_min'] as num?)?.toInt() ?? 10,
      status: json['status'] as String? ?? 'pending',
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      lastTriggeredAt: json['last_triggered_at'] != null
          ? DateTime.tryParse(json['last_triggered_at'] as String)
          : null,
      nextRunAt: json['next_run_at'] != null
          ? DateTime.tryParse(json['next_run_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isTriggered => status == 'triggered' || status == 'repeated';
  bool get isAcknowledged => status == 'acknowledged';
  bool get isEscalated => status == 'escalated';
}
