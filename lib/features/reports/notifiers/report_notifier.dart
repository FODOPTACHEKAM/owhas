import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../core/mixins/loading_mixin.dart';
import '../../../models/session.dart';
import '../../../models/attendance_record.dart';
import '../../../services/pdf_service.dart';
import '../../../services/file_service.dart';
import '../../../services/api_service.dart';
import '../../../services/signature_service.dart';

/// Handles PDF generation, sharing, and server-side PDF download.
///
/// All methods receive the session and records as parameters so this
/// notifier stays independent of [SessionStateNotifier] and
/// [AttendanceRecordNotifier].
class ReportNotifier extends ChangeNotifier with LoadingMixin {
  ReportNotifier({
    required FileService fileService,
    required ApiService  apiService,
  })  : _fileService = fileService,
        _apiService  = apiService;

  final FileService _fileService;
  final ApiService  _apiService;

  // ── PDF generation ────────────────────────────────────────────────────────────

  Future<Uint8List?> generatePDFReport({
    required AttendanceSession     session,
    required List<AttendanceRecord> records,
    required Map<String, int>      previousAttendance,
    required int                   sessionNumber,
  }) async {
    if (records.isEmpty) {
      setError('No records to include in the report.');
      return null;
    }

    Uint8List? bytes;
    await runWithLoading(() async {
      final signatureBytes = await SignatureService.loadSignature();
      final lecturerName   = await SignatureService.loadLecturerName();

      bytes = await PdfService.generateAttendancePDF(
        session:            session,
        records:            records,
        previousAttendance: previousAttendance,
        signatureBytes:     signatureBytes,
        lecturerName:       lecturerName,
        sessionNumber:      sessionNumber,
      );
    });
    return bytes;
  }

  // ── Share ─────────────────────────────────────────────────────────────────────

  Future<bool> generateAndSharePDFReport({
    required AttendanceSession     session,
    required List<AttendanceRecord> records,
    required Map<String, int>      previousAttendance,
    required int                   sessionNumber,
  }) async {
    final bytes = await generatePDFReport(
      session:            session,
      records:            records,
      previousAttendance: previousAttendance,
      sessionNumber:      sessionNumber,
    );
    if (bytes == null) return false;

    try {
      final name = _pdfFileName(session);
      await _fileService.saveAndSharePdf(bytes, fileName: name);
      return true;
    } catch (e) {
      setError('Failed to share PDF: $e');
      return false;
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────────

  Future<String?> downloadPDFReport({
    required AttendanceSession     session,
    required List<AttendanceRecord> records,
    required Map<String, int>      previousAttendance,
    required int                   sessionNumber,
  }) async {
    final bytes = await generatePDFReport(
      session:            session,
      records:            records,
      previousAttendance: previousAttendance,
      sessionNumber:      sessionNumber,
    );
    if (bytes == null) return null;

    try {
      return await _fileService.savePdfToDevice(bytes, fileName: _pdfFileName(session));
    } catch (e) {
      setError('Failed to download PDF: $e');
      return null;
    }
  }

  /// Fetch the server-generated PDF and open the native share dialog.
  Future<bool> downloadAndShareServerPdf() async {
    bool success = false;
    await runWithLoading(() async {
      final bytes = await _apiService.fetchServerPdf();
      if (bytes != null) {
        await _fileService.saveAndSharePdf(bytes);
        success = true;
      } else {
        throw Exception('Server returned an empty PDF.');
      }
    });
    return success;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _pdfFileName(AttendanceSession session) {
    final date = DateFormat('yyyy-MM-dd').format(session.startTime);
    return '${session.courseName.replaceAll(' ', '_')}_$date.pdf';
  }

}
