class AlertModel {
  final int id;
  final int patientId;
  final int? reminderId;
  final String alertType;
  final String message;
  final String status;
  final DateTime createdAt;
  final String? _severity;

  String get severity =>
      _severity ??
      (alertType.toLowerCase().contains('critical') ||
              alertType.toLowerCase().contains('sos')
          ? 'critical'
          : alertType);

  AlertModel({
    required this.id,
    required this.patientId,
    this.reminderId,
    required this.alertType,
    required this.message,
    required this.status,
    required this.createdAt,
    String? severity,
  }) : _severity = severity;

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: (json['id'] as num).toInt(),
      patientId: ((json['patient_id'] ?? 1) as num).toInt(),
      reminderId: (json['reminder_id'] as num?)?.toInt(),
      alertType: json['alert_type'] as String? ?? 'general',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'sent',
      severity: json['severity'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
