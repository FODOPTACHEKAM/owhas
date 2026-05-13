class CatalogueCourse {
  final String id;
  final String semesterId;
  final String name;
  final String code;
  final String? department;
  final int? credits;
  final DateTime createdAt;

  const CatalogueCourse({
    required this.id,
    required this.semesterId,
    required this.name,
    required this.code,
    this.department,
    this.credits,
    required this.createdAt,
  });

  CatalogueCourse copyWith({
    String? id,
    String? semesterId,
    String? name,
    String? code,
    String? department,
    int? credits,
    DateTime? createdAt,
  }) =>
      CatalogueCourse(
        id: id ?? this.id,
        semesterId: semesterId ?? this.semesterId,
        name: name ?? this.name,
        code: code ?? this.code,
        department: department ?? this.department,
        credits: credits ?? this.credits,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'semesterId': semesterId,
        'name': name,
        'code': code,
        'department': department,
        'credits': credits,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CatalogueCourse.fromJson(Map<String, dynamic> j) => CatalogueCourse(
        id: j['id'] as String,
        semesterId: j['semesterId'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        department: j['department'] as String?,
        credits: j['credits'] as int?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) => other is CatalogueCourse && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
