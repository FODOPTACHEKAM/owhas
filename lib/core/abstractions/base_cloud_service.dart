import '../../models/session.dart';
import '../../models/attendance_record.dart';

/// Contract for optional Firebase cloud synchronisation.
///
/// All callers must check [isSignedIn] before calling any sync method.
/// Cloud operations are always best-effort — callers must never let a
/// cloud failure block core attendance functionality.
abstract class BaseCloudService {
  bool get isSignedIn;

  Future<void> syncSession(AttendanceSession session);

  Future<void> syncAttendanceRecord(
    String sessionId,
    AttendanceRecord record,
  );

  /// Full sync at session end: pushes both the session metadata and every
  /// attendance record in a single batch.
  Future<void> fullSessionSync(
    AttendanceSession session,
    List<AttendanceRecord> records,
  );
}
