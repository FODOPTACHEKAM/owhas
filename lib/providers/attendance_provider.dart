import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../models/attendance_record.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../services/api_service.dart';
import '../services/file_service.dart';
import '../services/network_discovery_service.dart';
import '../services/signature_service.dart';

/// Provider for attendance system state management
class AttendanceProvider extends ChangeNotifier {
  final SessionService _sessionService = SessionService();
  final StorageService _storage = StorageService();
  final ExcelService _excelService = ExcelService();
  final ApiService _apiService = ApiService();
  final FileService _fileService = FileService();
  final NetworkDiscoveryService _networkDiscovery = NetworkDiscoveryService();

  AttendanceSession? _activeSession;
  List<AttendanceRecord> _currentRecords = [];
  Map<String, int> _previousAttendance = {};
  Map<String, dynamic> _serverStats = {};
  bool _isLoading = false;
  String? _error;
  int _activeWifiDevices = 0;
  List<String> _wifiDeviceIps = [];
  int _sessionNumber = 1;

  AttendanceSession? get activeSession => _activeSession;
  List<AttendanceRecord> get currentRecords => _currentRecords;
  Map<String, int> get previousAttendance => _previousAttendance;
  Map<String, dynamic> get serverStats => _serverStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get activeWifiDevices => _activeWifiDevices;
  List<String> get wifiDeviceIps => _wifiDeviceIps;
  int get sessionNumber => _sessionNumber;

  /// Initialize the provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _activeSession = await _storage.getActiveSession();
      if (_activeSession != null) {
        _syncApiServiceSession();
        await refreshRecords();
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Sync the API service with the current session's PIN/token
  void _syncApiServiceSession() {
    if (_activeSession?.sessionPin != null) {
      _apiService.setSessionPin(_activeSession!.sessionPin!);
    }
    if (_activeSession?.sessionToken != null) {
      _apiService.setSessionToken(_activeSession!.sessionToken!);
    }
  }

  /// Create a new session
  Future<void> createSession({
    required String courseName,
    String? courseCode,
    required int gracePeriodMinutes,
    required int requiredConnectionMinutes,
    required int maxAttendanceCount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _activeSession = await _sessionService.createSession(
        courseName: courseName,
        courseCode: courseCode,
        lecturerId: 'lecturer_1', // In a real app, get from auth
        gracePeriodMinutes: gracePeriodMinutes,
        requiredConnectionMinutes: requiredConnectionMinutes,
        maxAttendanceCount: maxAttendanceCount,
        sessionNumber: _sessionNumber,
      );
      _currentRecords = [];
      _error = null;

      // Sync PIN/token to API service
      _syncApiServiceSession();

      // Push session config to server (best-effort; don't fail if offline)
      try {
        await _apiService.pushSessionConfig(
          requiredConnectionMinutes: requiredConnectionMinutes,
          gracePeriodMinutes: gracePeriodMinutes,
        );
      } catch (e) {
        debugPrint('Server config push failed (offline?): $e');
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Upload previous session data
  Future<bool> uploadPreviousSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      // First check if server is reachable (for PDF parsing)
      try {
        await _apiService.pingServer();
      } catch (e) {
        _error = 'Server is not reachable. Ensure the Node.js server is running on your PC and your phone is connected to the same Wi-Fi/hotspot.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final result = await _excelService.uploadPreviousSession();
      if (result != null) {
        _previousAttendance = {
          for (var student in result.students) student.matricule: student.totalPresence
        };
        // Increment session number from previous PDF: new = old + 1
        _sessionNumber = result.sessionNumber + 1;
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = 'No file was selected or the file could not be read.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register a student
  Future<bool> registerStudent({
    required String matricule,
    required String studentName,
    String? email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Save locally first
      await _sessionService.registerStudent(
        matricule: matricule,
        studentName: studentName,
        email: email,
      );

      // 2. Push to Node.js server so the lecturer's PDF includes this student
      try {
        await _apiService.registerStudentOnServer(
          username: studentName,
          matricule: matricule,
          email: email,
        );
      } catch (serverErr) {
        // Server might be offline; registration is still valid locally
        debugPrint('Server registration failed (offline?): $serverErr');
      }

      await refreshRecords();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register a student manually (for discharged phones).
  /// Bypasses device checks and marks as manual entry with no status.
  Future<bool> registerManualStudent({
    required String matricule,
    required String studentName,
    String? email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _sessionService.registerManualStudent(
        matricule: matricule,
        studentName: studentName,
        email: email,
      );

      await refreshRecords();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh attendance records from both local storage and the Node server
  Future<void> refreshRecords() async {
    if (_activeSession == null) return;

    try {
      // 1. Load locally registered students
      final localRecords =
          await _storage.getAttendanceRecords(_activeSession!.id);

      // 2. Fetch students who connected via WiFi hotspot from the Node server
      List<AttendanceRecord> serverRecords = [];
      try {
        final serverAttendees = await _apiService.fetchServerAttendees();
        serverRecords = _convertServerAttendees(serverAttendees);

        // Also fetch server stats
        _serverStats = await _apiService.fetchServerStats();
      } catch (e) {
        // Server might be offline; silently fall back to local only
        _serverStats = {};
      }

      // 3. Merge local and server records (deduplicate by matricule)
      final merged = <String, AttendanceRecord>{};
      for (final record in localRecords) {
        merged[record.matricule] = record;
      }
      for (final record in serverRecords) {
        // Server record takes precedence if same matricule exists
        merged[record.matricule] = record;
      }

      _currentRecords = merged.values.toList()
        ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Convert raw server attendee JSON into AttendanceRecord objects
  List<AttendanceRecord> _convertServerAttendees(
      List<Map<String, dynamic>> attendees) {
    if (_activeSession == null) return [];

    final now = DateTime.now();
    final requiredMinutes = _activeSession!.requiredConnectionMinutes;

    return attendees.map((a) {
      final matricule = a['matricule'] as String? ?? 'unknown';
      final username = a['username'] as String? ?? 'Unknown';
      final connectedAtStr = a['connectedAt'] as String?;
      final joinedAt =
          connectedAtStr != null ? DateTime.parse(connectedAtStr) : now;
      final durationMinutes = now.difference(joinedAt).inMinutes;
      final isVerified = durationMinutes >= requiredMinutes;

      return AttendanceRecord(
        id: 'server_${matricule}_${joinedAt.millisecondsSinceEpoch}',
        sessionId: _activeSession!.id,
        studentId: matricule,
        matricule: matricule,
        studentName: username,
        joinedAt: joinedAt,
        verifiedAt: isVerified ? now : null,
        connectionDurationMinutes: durationMinutes,
        isVerified: isVerified,
        isManual: false,
        deviceFingerprint: a['ip'] as String? ?? 'unknown',
        createdAt: joinedAt,
        updatedAt: now,
      );
    }).toList();
  }

  /// End session and generate report
  Future<String?> endSessionAndGenerateReport() async {
    if (_activeSession == null) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final filePath = await _excelService.generateReport(
        courseName: _activeSession!.courseName,
        sessionDate: _activeSession!.startTime,
        currentSessionRecords: _currentRecords,
        previousAttendance: _previousAttendance,
        maxAttendanceCount: _activeSession!.maxAttendanceCount,
      );

      await _sessionService.endSession(_activeSession!.id);
      _apiService.clearSession();
      _activeSession = null;
      _currentRecords = [];
      _serverStats = {};
      _error = null;

      _isLoading = false;
      notifyListeners();

      return filePath;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Get session statistics
  /// Generate PDF report for current session (without ending)
  Future<Uint8List?> generatePDFReport() async {
    if (_activeSession == null || _currentRecords.isEmpty) {
      _error = 'No active session or records to report';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load saved signature and lecturer name if available
      final signatureBytes = await SignatureService.loadSignature();
      final lecturerName = await SignatureService.loadLecturerName();

      final pdfBytes = await PdfService.generateAttendancePDF(
        session: _activeSession!,
        records: _currentRecords,
        previousAttendance: _previousAttendance,
        signatureBytes: signatureBytes,
        lecturerName: lecturerName,
        sessionNumber: _sessionNumber,
      );

      _isLoading = false;
      notifyListeners();

      return pdfBytes;
    } catch (e) {
      _error = 'PDF generation failed: \$e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Generate PDF and share via native share dialog
  Future<bool> generateAndSharePDFReport() async {
    final pdfBytes = await generatePDFReport();
    if (pdfBytes == null) return false;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_activeSession!.startTime);
      final fileName =
          '${_activeSession!.courseName.replaceAll(' ', '_')}_$dateStr.pdf';
      await _fileService.saveAndSharePdf(pdfBytes, fileName: fileName);
      return true;
    } catch (e) {
      _error = 'Failed to share PDF: \$e';
      notifyListeners();
      return false;
    }
  }

  /// Download PDF from Node.js server and trigger native share dialog
  Future<bool> downloadAndShareServerPdf() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final pdfBytes = await _apiService.fetchServerPdf();
      if (pdfBytes != null) {
        await _fileService.saveAndSharePdf(pdfBytes);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Server returned empty PDF';
      }
    } catch (e) {
      _error = 'Download failed: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Map<String, int> getStats() {
    // Prefer server stats if available (they reflect real-time WiFi connections)
    if (_serverStats.isNotEmpty) {
      return {
        'total': (_serverStats['total'] as num?)?.toInt() ?? 0,
        'verified': (_serverStats['verified'] as num?)?.toInt() ?? 0,
        'pending': (_serverStats['pending'] as num?)?.toInt() ?? 0,
      };
    }

    // Fallback to local records
    final verified = _currentRecords.where((r) => r.isVerified).length;
    final pending = _currentRecords.where((r) => !r.isVerified).length;

    return {
      'total': _currentRecords.length,
      'verified': verified,
      'pending': pending,
    };
  }

  /// Scan the Wi-Fi subnet to count active devices (phones connected to hotspot).
  /// This is a best-effort scan; results depend on network permissions and firewall rules.
  Future<void> refreshWifiDeviceCount() async {
    try {
      final result = await _networkDiscovery.scanActiveDevices();
      _activeWifiDevices = result.activeDeviceCount;
      _wifiDeviceIps = result.deviceIps;
      notifyListeners();
    } catch (e) {
      // Silently ignore scan failures (e.g., no Wi-Fi, permissions denied)
      _activeWifiDevices = 0;
      _wifiDeviceIps = [];
    }
  }

  /// Remove a student from the current session (both local and server)
  Future<bool> removeStudent(String recordId) async {
    if (_activeSession == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final record = _currentRecords.firstWhere((r) => r.id == recordId);

      // 1. Remove from local storage
      await _sessionService.removeStudent(_activeSession!.id, recordId);

      // 2. Remove from server (best-effort)
      try {
        await _apiService.removeAttendeeOnServer(record.matricule);
      } catch (serverErr) {
        debugPrint('Server removal failed (offline?): $serverErr');
      }

      // 3. Update local list
      _currentRecords.removeWhere((r) => r.id == recordId);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

