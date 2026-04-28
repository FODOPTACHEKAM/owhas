import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../models/attendance_record.dart';
import '../models/student.dart';
import 'storage_service.dart';
import 'device_service.dart';

/// Service for managing attendance sessions
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final StorageService _storage = StorageService();
  final DeviceService _deviceService = DeviceService();
  final Uuid _uuid = const Uuid();

  Timer? _connectionTracker;
  final Map<String, DateTime> _studentJoinTimes = {};

  /// Create a new session
  Future<AttendanceSession> createSession({
    required String courseName,
    String? courseCode,
    required String lecturerId,
    required int gracePeriodMinutes,
    required int requiredConnectionMinutes,
    required int maxAttendanceCount,
    int sessionNumber = 1,
  }) async {
    // End any existing active session
    final activeSession = await _storage.getActiveSession();
    if (activeSession != null) {
      await endSession(activeSession.id);
    }

    final now = DateTime.now();
    final session = AttendanceSession(
      id: _uuid.v4(),
      courseName: courseName,
      courseCode: courseCode,
      lecturerId: lecturerId,
      startTime: now,
      gracePeriodMinutes: gracePeriodMinutes,
      requiredConnectionMinutes: requiredConnectionMinutes,
      maxAttendanceCount: maxAttendanceCount,
      sessionNumber: sessionNumber,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    await _storage.saveSession(session);
    _startConnectionTracking(session.id);
    return session;
  }

  /// Register a student for the active session
  Future<AttendanceRecord?> registerStudent({
    required String matricule,
    required String studentName,
    String? email,
  }) async {
    final session = await _storage.getActiveSession();
    if (session == null) {
      throw Exception('No active session');
    }

    // Get or create student
    final deviceFingerprint = await _deviceService.getDeviceFingerprint();
    
    // Check for device reuse
    final existingRecords = await _storage.getAttendanceRecords(session.id);
    final deviceAlreadyUsed = existingRecords.any(
      (r) => r.deviceFingerprint == deviceFingerprint,
    );
    
    if (deviceAlreadyUsed) {
      throw Exception('This device has already been used for registration');
    }

    Student? student = await _storage.getStudentByMatricule(matricule);
    if (student == null) {
      student = Student(
        id: _uuid.v4(),
        matricule: matricule,
        name: studentName,
        email: email,
        deviceFingerprint: deviceFingerprint,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _storage.saveStudent(student);
    } else if (email != null && student.email != email) {
      // Update email if changed
      student = student.copyWith(email: email, updatedAt: DateTime.now());
      await _storage.saveStudent(student);
    }

    final now = DateTime.now();
    final record = AttendanceRecord(
      id: _uuid.v4(),
      sessionId: session.id,
      studentId: student.id,
      matricule: matricule,
      studentName: studentName,
      email: email,
      joinedAt: now,
      connectionDurationMinutes: 0,
      isVerified: false,
      deviceFingerprint: deviceFingerprint,
      createdAt: now,
      updatedAt: now,
    );

    await _storage.saveAttendanceRecord(record);
    _studentJoinTimes[record.id] = now;

    return record;
  }

  /// Register a student manually (for discharged phones).
  /// Bypasses device fingerprint checks and marks as manual entry.
  Future<AttendanceRecord?> registerManualStudent({
    required String matricule,
    required String studentName,
    String? email,
  }) async {
    final session = await _storage.getActiveSession();
    if (session == null) {
      throw Exception('No active session');
    }

    Student? student = await _storage.getStudentByMatricule(matricule);
    if (student == null) {
      student = Student(
        id: _uuid.v4(),
        matricule: matricule,
        name: studentName,
        email: email,
        deviceFingerprint: 'manual_${_uuid.v4()}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _storage.saveStudent(student);
    } else if (email != null && student.email != email) {
      student = student.copyWith(email: email, updatedAt: DateTime.now());
      await _storage.saveStudent(student);
    }

    final now = DateTime.now();
    final record = AttendanceRecord(
      id: _uuid.v4(),
      sessionId: session.id,
      studentId: student.id,
      matricule: matricule,
      studentName: studentName,
      email: email,
      joinedAt: now,
      connectionDurationMinutes: 0,
      isVerified: false,
      isManual: true,
      deviceFingerprint: 'manual_${_uuid.v4()}',
      createdAt: now,
      updatedAt: now,
    );

    await _storage.saveAttendanceRecord(record);

    return record;
  }

  /// End a session
  Future<void> endSession(String sessionId) async {
    final sessions = await _storage.getSessions();
    final session = sessions.where((s) => s.id == sessionId).firstOrNull;
    
    if (session != null) {
      final updatedSession = session.copyWith(
        isActive: false,
        endTime: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _storage.saveSession(updatedSession);
    }

    _connectionTracker?.cancel();
    _studentJoinTimes.clear();
  }

  /// Start tracking connection durations
  void _startConnectionTracking(String sessionId) {
    _connectionTracker?.cancel();
    _connectionTracker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateConnectionDurations(sessionId),
    );
  }

  /// Update connection durations and verify attendance
  Future<void> _updateConnectionDurations(String sessionId) async {
    final session = await _storage.getSessions();
    final currentSession = session.where((s) => s.id == sessionId).firstOrNull;
    
    if (currentSession == null || !currentSession.isActive) {
      _connectionTracker?.cancel();
      return;
    }

    final records = await _storage.getAttendanceRecords(sessionId);
    final now = DateTime.now();

    for (final record in records) {
      final joinTime = _studentJoinTimes[record.id] ?? record.joinedAt;
      final connectionMinutes = now.difference(joinTime).inMinutes;

      final isVerified =
          connectionMinutes >= currentSession.requiredConnectionMinutes;

      final updatedRecord = record.copyWith(
        connectionDurationMinutes: connectionMinutes,
        isVerified: isVerified,
        verifiedAt: isVerified && record.verifiedAt == null ? now : record.verifiedAt,
        updatedAt: now,
      );

      await _storage.saveAttendanceRecord(updatedRecord);
    }
  }

  /// Get current session statistics
  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    final records = await _storage.getAttendanceRecords(sessionId);
    final verified = records.where((r) => r.isVerified).length;
    final pending = records.where((r) => !r.isVerified).length;

    return {
      'total': records.length,
      'verified': verified,
      'pending': pending,
    };
  }

  /// Remove a student from the session by record ID.
  /// Also deletes the associated student entity and cleans up join-time tracking.
  Future<void> removeStudent(String sessionId, String recordId) async {
    // 1. Fetch the record to obtain the linked student ID
    final records = await _storage.getAttendanceRecords(sessionId);
    final record = records.firstWhere(
      (r) => r.id == recordId,
      orElse: () => throw Exception('Attendance record not found'),
    );

    // 2. Delete the attendance record
    await _storage.deleteAttendanceRecord(sessionId, recordId);

    // 3. Delete the student entity completely
    await _storage.deleteStudent(record.studentId);

    // 4. Clean up in-memory join-time tracking
    _studentJoinTimes.remove(recordId);
  }
}
