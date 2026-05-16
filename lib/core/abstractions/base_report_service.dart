import 'dart:typed_data';
import '../../models/session.dart';
import '../../models/attendance_record.dart';

/// Contract for attendance report generation.
///
/// Both PDF (in-app, Flutter pdf package) and Excel (cumulative tracking)
/// implement this interface so [ReportNotifier] depends on the abstraction,
/// not on the concrete packages.
abstract class BaseReportService {
  Future<Uint8List?> generatePdf({
    required AttendanceSession session,
    required List<AttendanceRecord> records,
    required Map<String, int> previousAttendance,
    Uint8List? signatureBytes,
    String? lecturerName,
    int sessionNumber = 1,
  });

  Future<String?> generateExcel({
    required String courseName,
    required DateTime sessionDate,
    required List<AttendanceRecord> currentSessionRecords,
    required Map<String, int> previousAttendance,
    required int maxAttendanceCount,
  });
}
