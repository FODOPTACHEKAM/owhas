/// Student data model with matricule and attendance information
class Student {
  final String id;
  final String matricule;
  final String name;
  final String? email;
  final String deviceFingerprint;
  final DateTime createdAt;
  final DateTime updatedAt;

  Student({
    required this.id,
    required this.matricule,
    required this.name,
    this.email,
    required this.deviceFingerprint,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'matricule': matricule,
        'name': name,
        'email': email,
        'deviceFingerprint': deviceFingerprint,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        matricule: json['matricule'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
        deviceFingerprint: json['deviceFingerprint'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Student copyWith({
    String? id,
    String? matricule,
    String? name,
    String? email,
    String? deviceFingerprint,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Student(
        id: id ?? this.id,
        matricule: matricule ?? this.matricule,
        name: name ?? this.name,
        email: email ?? this.email,
        deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
