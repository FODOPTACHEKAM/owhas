import 'dart:typed_data';

/// Contract for all HTTP communication with the Node.js server.
///
/// Implementations talk to either the local hotspot server (port 5501)
/// or the cloud server (owhas.org) depending on [ServerConfig.baseUrl].
/// Notifiers must only call this interface — never `http` directly.
abstract class BaseApiService {
  // ── Session identity ──────────────────────────────────────────────────────────
  void setSessionPin(String pin);
  void setSessionToken(String token);
  void clearSession();

  // ── Connectivity ──────────────────────────────────────────────────────────────
  Future<void> pingServer();

  // ── Attendees ─────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchServerAttendees();
  Future<Map<String, dynamic>> fetchServerStats();

  Future<void> registerStudentOnServer({
    required String username,
    required String matricule,
    String? email,
  });

  Future<void> removeAttendeeOnServer(String matricule);

  // ── Session lifecycle ─────────────────────────────────────────────────────────
  Future<void> resetServerSession({
    required String pin,
    String? courseName,
    String? courseCode,
    String? lecturerId,
  });

  Future<void> pushSessionConfig({
    required int requiredConnectionMinutes,
    required int gracePeriodMinutes,
  });

  Future<bool> verifySessionPin(String pin);

  // ── Reports ───────────────────────────────────────────────────────────────────
  Future<Uint8List?> fetchServerPdf();
  Future<Map<String, dynamic>> parsePdfOnServer(Uint8List pdfBytes);
}
