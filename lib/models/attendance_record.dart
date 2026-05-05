/// Location data captured during student registration
class AttendanceLocation {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? address;
  final DateTime? timestamp;

  const AttendanceLocation({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.address,
    this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'address': address,
        'timestamp': timestamp?.toIso8601String(),
      };

  factory AttendanceLocation.fromJson(Map<String, dynamic> json) =>
      AttendanceLocation(
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
        accuracy: json['accuracy'] as double?,
        address: json['address'] as String?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
      );

  AttendanceLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? address,
    DateTime? timestamp,
  }) =>
      AttendanceLocation(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        accuracy: accuracy ?? this.accuracy,
        address: address ?? this.address,
        timestamp: timestamp ?? this.timestamp,
      );
}

/// Attendance record tracking student presence in a session
class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final String matricule;
  final String studentName;
  final String? email;
  final DateTime joinedAt;
  final DateTime? verifiedAt;
  final int connectionDurationMinutes;
  final bool isVerified;
  final bool isManual;
  final String deviceFingerprint;
  final AttendanceLocation? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.matricule,
    required this.studentName,
    this.email,
    required this.joinedAt,
    this.verifiedAt,
    required this.connectionDurationMinutes,
    required this.isVerified,
    this.isManual = false,
    required this.deviceFingerprint,
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'studentId': studentId,
        'matricule': matricule,
        'studentName': studentName,
        'email': email,
        'joinedAt': joinedAt.toIso8601String(),
        'verifiedAt': verifiedAt?.toIso8601String(),
        'connectionDurationMinutes': connectionDurationMinutes,
        'isVerified': isVerified,
        'isManual': isManual,
        'deviceFingerprint': deviceFingerprint,
        'location': location?.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        studentId: json['studentId'] as String,
        matricule: json['matricule'] as String,
        studentName: json['studentName'] as String,
        email: json['email'] as String?,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        verifiedAt: json['verifiedAt'] != null
            ? DateTime.parse(json['verifiedAt'] as String)
            : null,
        connectionDurationMinutes: json['connectionDurationMinutes'] as int,
        isVerified: json['isVerified'] as bool,
        isManual: json['isManual'] as bool? ?? false,
        deviceFingerprint: json['deviceFingerprint'] as String,
        location: json['location'] != null
            ? AttendanceLocation.fromJson(json['location'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  AttendanceRecord copyWith({
    String? id,
    String? sessionId,
    String? studentId,
    String? matricule,
    String? studentName,
    String? email,
    DateTime? joinedAt,
    DateTime? verifiedAt,
    int? connectionDurationMinutes,
    bool? isVerified,
    bool? isManual,
    String? deviceFingerprint,
    AttendanceLocation? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      AttendanceRecord(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        studentId: studentId ?? this.studentId,
        matricule: matricule ?? this.matricule,
        studentName: studentName ?? this.studentName,
        email: email ?? this.email,
        joinedAt: joinedAt ?? this.joinedAt,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        connectionDurationMinutes:
            connectionDurationMinutes ?? this.connectionDurationMinutes,
        isVerified: isVerified ?? this.isVerified,
        isManual: isManual ?? this.isManual,
        deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
        location: location ?? this.location,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

