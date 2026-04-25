/// Session data model representing a lecture session
class AttendanceSession {
  final String id;
  final String courseName;
  final String lecturerId;
  final DateTime startTime;
  final DateTime? endTime;
  final int gracePeriodMinutes;
  final int requiredConnectionMinutes;
  final int maxAttendanceCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  AttendanceSession({
    required this.id,
    required this.courseName,
    required this.lecturerId,
    required this.startTime,
    this.endTime,
    required this.gracePeriodMinutes,
    required this.requiredConnectionMinutes,
    required this.maxAttendanceCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseName': courseName,
        'lecturerId': lecturerId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'gracePeriodMinutes': gracePeriodMinutes,
        'requiredConnectionMinutes': requiredConnectionMinutes,
        'maxAttendanceCount': maxAttendanceCount,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AttendanceSession.fromJson(Map<String, dynamic> json) =>
      AttendanceSession(
        id: json['id'] as String,
        courseName: json['courseName'] as String,
        lecturerId: json['lecturerId'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        gracePeriodMinutes: json['gracePeriodMinutes'] as int,
        requiredConnectionMinutes: json['requiredConnectionMinutes'] as int,
        maxAttendanceCount: json['maxAttendanceCount'] as int,
        isActive: json['isActive'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  AttendanceSession copyWith({
    String? id,
    String? courseName,
    String? lecturerId,
    DateTime? startTime,
    DateTime? endTime,
    int? gracePeriodMinutes,
    int? requiredConnectionMinutes,
    int? maxAttendanceCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      AttendanceSession(
        id: id ?? this.id,
        courseName: courseName ?? this.courseName,
        lecturerId: lecturerId ?? this.lecturerId,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
        requiredConnectionMinutes:
            requiredConnectionMinutes ?? this.requiredConnectionMinutes,
        maxAttendanceCount: maxAttendanceCount ?? this.maxAttendanceCount,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
