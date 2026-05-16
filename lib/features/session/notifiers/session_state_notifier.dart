import 'package:flutter/foundation.dart';
import '../../../core/mixins/loading_mixin.dart';
import '../../../models/session.dart';
import '../../../models/attendance_record.dart';
import '../../../services/session_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/api_service.dart';
import '../../../services/excel_service.dart';
import '../../../services/face_recognition_service.dart';
import '../../../services/server_config.dart';

/// Owns the session lifecycle: create → configure → end.
///
/// Consumers that need attendance records or reports should read
/// [AttendanceRecordNotifier] and [ReportNotifier] respectively.
class SessionStateNotifier extends ChangeNotifier with LoadingMixin {
  SessionStateNotifier({
    required SessionService sessionService,
    required StorageService storage,
    required ApiService apiService,
    required ExcelService excelService,
    required FaceRecognitionService faceService,
  })  : _sessionService  = sessionService,
        _storage         = storage,
        _apiService      = apiService,
        _excelService    = excelService,
        _faceService     = faceService;

  final SessionService        _sessionService;
  final StorageService        _storage;
  final ApiService            _apiService;
  final ExcelService          _excelService;
  final FaceRecognitionService _faceService;

  AttendanceSession?   _activeSession;
  int                  _sessionNumber = 1;
  String?              _serverWarning;
  Map<String, int>     _previousAttendance = {};

  AttendanceSession? get activeSession      => _activeSession;
  int                get sessionNumber      => _sessionNumber;
  String?            get serverWarning      => _serverWarning;
  Map<String, int>   get previousAttendance => _previousAttendance;
  bool               get hasActiveSession   => _activeSession != null;

  // ── Startup ───────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await runWithLoading(() async {
      _activeSession = await _storage.getActiveSession();
      if (_activeSession != null) {
        final expiry = _activeSession!.startTime
            .add(Duration(minutes: _activeSession!.durationMinutes));
        if (DateTime.now().isAfter(expiry)) {
          await _sessionService.endSession(_activeSession!.id);
          _apiService.clearSession();
          _activeSession = null;
        } else {
          _syncApiServiceSession();
        }
      }
    });
  }

  // ── Session creation ──────────────────────────────────────────────────────────

  Future<void> createSession({
    required String courseName,
    String? courseCode,
    required String lecturerName,
    required int gracePeriodMinutes,
    required int requiredConnectionMinutes,
    required int maxAttendanceCount,
    required int durationMinutes,
  }) async {
    await runWithLoading(() async {
      _activeSession = await _sessionService.createSession(
        courseName:               courseName,
        courseCode:               courseCode,
        lecturerId:               lecturerName,
        gracePeriodMinutes:       gracePeriodMinutes,
        requiredConnectionMinutes: requiredConnectionMinutes,
        maxAttendanceCount:       maxAttendanceCount,
        durationMinutes:          durationMinutes,
        sessionNumber:            _sessionNumber,
      );
      _serverWarning = null;
      _syncApiServiceSession();

      try {
        await _apiService.pushSessionConfig(
          requiredConnectionMinutes: requiredConnectionMinutes,
          gracePeriodMinutes:        gracePeriodMinutes,
        );
      } catch (e) {
        debugPrint('Session config push failed (offline?): $e');
        _serverWarning =
            'Server not reachable — web registration (hotspot.html) is unavailable. '
            'Start node server.js and connect phones to the same Wi-Fi. '
            'Use the Retry button in the dashboard to reconnect.';
      }
    });
  }

  // ── Pre-session setup ─────────────────────────────────────────────────────────

  /// Pick a previous Excel/PDF, parse student list, and advance [sessionNumber].
  Future<bool> uploadPreviousSession() async {
    bool success = false;
    await runWithLoading(() async {
      try {
        await _apiService.pingServer();
      } catch (_) {
        throw Exception(
          'Server not reachable. Ensure node server.js is running '
          'and the phone is on the same Wi-Fi.',
        );
      }

      final result = await _excelService.uploadPreviousSession();
      if (result == null) {
        throw Exception('No file selected or file could not be read.');
      }
      _previousAttendance = {
        for (final s in result.students) s.matricule: s.totalPresence
      };
      _sessionNumber = result.sessionNumber + 1;
      success = true;
    });
    return success;
  }

  // ── Session end ───────────────────────────────────────────────────────────────

  /// Generate an Excel report (best-effort) then tear down the session.
  ///
  /// [records] and [previousAttendance] come from [AttendanceRecordNotifier].
  /// Returns the saved file path, or null if report generation failed.
  Future<String?> endSessionAndGenerateReport(
    List<AttendanceRecord> records,
    Map<String, int> previousAttendance,
  ) async {
    if (_activeSession == null) return null;
    String? filePath;

    await runWithLoading(() async {
      try {
        filePath = await _excelService.generateReport(
          courseName:            _activeSession!.courseName,
          sessionDate:           _activeSession!.startTime,
          currentSessionRecords: records,
          previousAttendance:    previousAttendance,
          maxAttendanceCount:    _activeSession!.maxAttendanceCount,
        );
      } catch (e) {
        debugPrint('Excel report failed (session will still end): $e');
      }
      await _teardown();
    });

    return filePath;
  }

  /// Tear down the session immediately — used for auto-expiry (no report).
  Future<void> forceEndSession() async {
    if (_activeSession == null) return;
    await runWithLoading(() => _teardown());
  }

  Future<void> _teardown() async {
    final id = _activeSession!.id;
    try { await _sessionService.endSession(id); } catch (e) { debugPrint('endSession: $e'); }
    try { await _storage.clearSessionData(id);  } catch (e) { debugPrint('clearData: $e');  }
    _faceService.clearSession(id);
    _apiService.clearSession();
    _activeSession      = null;
    _previousAttendance = {};
    _serverWarning      = null;
    _sessionNumber      = 1;
  }

  // ── Network recovery ──────────────────────────────────────────────────────────

  Future<void> retryServerConnection() async {
    _serverWarning = null;
    notifyListeners();
    try {
      ServerConfig().reset();
      await ServerConfig().detect();
      _syncApiServiceSession();
      await _apiService.pushSessionConfig(
        requiredConnectionMinutes: _activeSession?.requiredConnectionMinutes ?? 0,
        gracePeriodMinutes:        _activeSession?.gracePeriodMinutes        ?? 0,
      );
      await _sessionService.resyncToServer();
    } catch (_) {
      _serverWarning =
          'Server still not reachable — ensure node server.js is running '
          'and the phone is on the same Wi-Fi.';
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _syncApiServiceSession() {
    final pin   = _activeSession?.sessionPin;
    final token = _activeSession?.sessionToken;
    if (pin   != null) _apiService.setSessionPin(pin);
    if (token != null) _apiService.setSessionToken(token);
  }

}
