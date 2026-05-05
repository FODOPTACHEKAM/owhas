import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../models/attendance_record.dart';
import '../models/student.dart';
import 'storage_service.dart';
import 'device_service.dart';
import 'server_config.dart';
import 'cloud_service.dart';
import 'location_service.dart';

/// Service for managing attendance sessions
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final StorageService _storage = StorageService();
  final DeviceService _deviceService = DeviceService();
  final CloudService _cloudService = CloudService();
  final LocationService _locationService = LocationService();
  final Uuid _uuid = const Uuid();

  Timer? _connectionTracker;
  Timer? _autoEndTimer;
  final Map<String, DateTime> _studentJoinTimes = {};

  String get _serverBaseUrl => ServerConfig().baseUrl;

  /// Generate a 6-digit numeric PIN (100000 - 999999)
  String generateSessionPin() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Generate a secure opaque session token for QR fallback
  String generateSessionToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Initialize the session on the Node.js server with PIN
  Future<void> _initServerSession({
    required String pin,
    required String courseName,
    String? courseCode,
    required String lecturerId,
    String? lecturerName,
    String? sessionToken,
    required int durationMinutes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_serverBaseUrl/api/session-init'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pin': pin,
          'courseName': courseName,
          'courseCode': courseCode,
          'lecturerId': lecturerId,
          'lecturerName': lecturerName,
          'sessionToken': sessionToken,
          'durationMinutes': durationMinutes,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[SessionService] Server session initialized with PIN $pin');
      } else if (response.statusCode == 409) {
        throw Exception('PIN already in use by another active session. Try again.');
      } else {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to initialize server session: $e');
    }
  }

  /// End the session on the Node.js server (deactivates PIN)
  Future<void> _endServerSession(String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$_serverBaseUrl/api/end-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pin': pin}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[SessionService] Server session ended: ${data['message']}');
      }
    } catch (e) {
      print('[SessionService] Failed to end server session (offline?): $e');
    }
  }

  /// Create a new session
  Future<AttendanceSession> createSession({
    required String courseName,
    String? courseCode,
    required String lecturerId,
    String? lecturerName,
    required int gracePeriodMinutes,
    required int requiredConnectionMinutes,
    required int maxAttendanceCount,
    required int durationMinutes,
    int sessionNumber = 1,
  }) async {
    // End any existing active session
    final activeSession = await _storage.getActiveSession();
    if (activeSession != null) {
      await endSession(activeSession.id);
    }

    final pin = generateSessionPin();
    final token = generateSessionToken();

    // Initialize on server first (fails fast if PIN collision or server down)
    await _initServerSession(
      pin: pin,
      courseName: courseName,
      courseCode: courseCode,
      lecturerId: lecturerId,
      lecturerName: lecturerName,
      sessionToken: token,
      durationMinutes: durationMinutes,
    );

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
      durationMinutes: durationMinutes,
      lecturerName: lecturerName,
      sessionPin: pin,
      sessionToken: token,
    );

    await _storage.saveSession(session);

    // Sync to cloud if signed in
    if (_cloudService.isSignedIn) {
      try {
        await _cloudService.syncSession(session);
      } catch (e) {
        print('[SessionService] Cloud sync failed (offline?): $e');
      }
    }

    _startConnectionTracking(session.id);

    // Start auto-end timer
    _autoEndTimer?.cancel();
    _autoEndTimer = Timer(
      Duration(minutes: durationMinutes),
      () => endSession(session.id),
    );

    return session;
  }

  /// Register a student for the active session with location collection
  Future<AttendanceRecord?> registerStudent({
    required String matricule,
    required String studentName,
    String? email,
    bool collectLocation = true,
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

    // Collect location if enabled
    AttendanceLocation? location;
    if (collectLocation) {
      try {
        location = await _locationService.collectLocation();
      } catch (e) {
        print('[SessionService] Location collection failed: $e');
      }
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
      location: location,
      createdAt: now,
      updatedAt: now,
    );

    await _storage.saveAttendanceRecord(record);
    _studentJoinTimes[record.id] = now;

    // Sync to cloud if signed in
    if (_cloudService.isSignedIn) {
      try {
        await _cloudService.syncAttendanceRecord(session.id, record);
      } catch (e) {
        print('[SessionService] Cloud sync failed (offline?): $e');
      }
    }

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

    // Sync to cloud if signed in
    if (_cloudService.isSignedIn) {
      try {
        await _cloudService.syncAttendanceRecord(session.id, record);
      } catch (e) {
        print('[SessionService] Cloud sync failed (offline?): $e');
      }
    }

    return record;
  }

  /// End a session and sync to cloud
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

      // Deactivate PIN on server
      if (session.sessionPin != null) {
        await _endServerSession(session.sessionPin!);
      }

      // Full sync to cloud if signed in
      if (_cloudService.isSignedIn) {
        try {
          final records = await _storage.getAttendanceRecords(sessionId);
          await _cloudService.fullSessionSync(updatedSession, records);
        } catch (e) {
          print('[SessionService] Cloud full sync failed: $e');
        }
      }
    }

    _connectionTracker?.cancel();
    _autoEndTimer?.cancel();
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
