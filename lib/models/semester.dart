class Semester {
  final String id;
  final String label;
  final String academicYear;
  final int number;
  final bool isActive;
  final DateTime createdAt;

  const Semester({
    required this.id,
    required this.label,
    required this.academicYear,
    required this.number,
    required this.isActive,
    required this.createdAt,
  });

  Semester copyWith({
    String? id,
    String? label,
    String? academicYear,
    int? number,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      Semester(
        id: id ?? this.id,
        label: label ?? this.label,
        academicYear: academicYear ?? this.academicYear,
        number: number ?? this.number,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'academicYear': academicYear,
        'number': number,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Semester.fromJson(Map<String, dynamic> j) => Semester(
        id: j['id'] as String,
        label: j['label'] as String,
        academicYear: j['academicYear'] as String,
        number: j['number'] as int,
        isActive: j['isActive'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) => other is Semester && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
