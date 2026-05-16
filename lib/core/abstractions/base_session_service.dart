import '../../models/session.dart';
import '../../models/attendance_record.dart';

/// Contract for session lifecycle management.
///
/// Implementations coordinate local storage, server registration,
/// and cloud sync. No caller above this layer should touch any of
/// those systems directly.
abstract class BaseSessionService {
  // ── Session lifecycle ─────────────────────────────────────────────────────────
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
  });

  Future<void> endSession(String sessionId);

  /// Re-registers the active session PIN on the server after a reconnect.
  /// Returns true if the session is confirmed live on the server.
  Future<bool> resyncToServer();

  // ── Student registration ──────────────────────────────────────────────────────
  Future<AttendanceRecord?> registerStudent({
    required String matricule,
    required String studentName,
    String? email,
    bool collectLocation = true,
  });

  /// Manual entry for discharged phones — bypasses device fingerprint check.
  Future<AttendanceRecord?> registerManualStudent({
    required String matricule,
    required String studentName,
    String? email,
  });

  Future<void> removeStudent(String sessionId, String recordId);

  // ── Stats ─────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSessionStats(String sessionId);
}
