class Patient {
  final int id;
  final String name;
  final int? age;
  final String? condition;
  final String? emergencyNotes;
  final DateTime? createdAt;

  Patient({
    required this.id,
    required this.name,
    this.age,
    this.condition,
    this.emergencyNotes,
    this.createdAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Patient',
      age: (json['age'] as num?)?.toInt(),
      condition: json['condition'] as String?,
      emergencyNotes: json['emergency_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

