class CallAttempt {
  final int id;
  final String callSessionId;
  final int attemptNumber;
  final String provider;
  final String? providerCallId;
  final String? recipientName;
  final String recipientPhone;
  final String status;
  final bool isTechnicalFailure;
  final String? failureReason;
  final int durationSeconds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CallAttempt({
    required this.id,
    required this.callSessionId,
    required this.attemptNumber,
    required this.provider,
    this.providerCallId,
    this.recipientName,
    required this.recipientPhone,
    required this.status,
    this.isTechnicalFailure = false,
    this.failureReason,
    this.durationSeconds = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory CallAttempt.fromJson(Map<String, dynamic> json) {
    return CallAttempt(
      id: (json['id'] as num).toInt(),
      callSessionId: json['call_session_id'] as String? ?? '',
      attemptNumber: (json['attempt_number'] as num?)?.toInt() ?? 1,
      provider: json['provider'] as String? ?? 'omnidim',
      providerCallId: json['provider_call_id'] as String?,
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String? ?? '',
      status: json['status'] as String? ?? 'initiated',
      isTechnicalFailure: json['is_technical_failure'] as bool? ?? false,
      failureReason: json['failure_reason'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  bool get isCompleted => status == 'completed' || status == 'answered';
  bool get isNoAnswer => status == 'no_answer';
  bool get isInitiated => status == 'initiated';
}

