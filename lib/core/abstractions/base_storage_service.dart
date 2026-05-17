import '../../models/session.dart';
import '../../models/attendance_record.dart';
import '../../models/student.dart';

/// Contract for all local persistence operations.
///
/// Only [StorageService] (in shared/services/) may implement this interface.
/// No other class should read or write SharedPreferences directly.
abstract class BaseStorageService {
  // ── Sessions ──────────────────────────────────────────────────────────────────
  Future<AttendanceSession?> getActiveSession();
  Future<void> saveSession(AttendanceSession session);
  Future<List<AttendanceSession>> getSessions();

  // ── Attendance records ────────────────────────────────────────────────────────
  Future<List<AttendanceRecord>> getAttendanceRecords(String sessionId);
  Future<void> saveAttendanceRecord(AttendanceRecord record);
  Future<void> deleteAttendanceRecord(String sessionId, String recordId);

  // ── Students ──────────────────────────────────────────────────────────────────
  Future<Student?> getStudentByMatricule(String matricule, String sessionId);
  Future<void> saveStudent(Student student, String sessionId);
  Future<void> deleteStudent(String studentId, String sessionId);

  // ── Bulk cleanup ──────────────────────────────────────────────────────────────
  /// Wipe all persisted data (records + students) for a completed session.
  Future<void> clearSessionData(String sessionId);
}
