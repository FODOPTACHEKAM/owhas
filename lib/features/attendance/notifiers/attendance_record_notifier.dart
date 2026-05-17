import 'package:flutter/foundation.dart';
import '../../../core/mixins/loading_mixin.dart';
import '../../../models/session.dart';
import '../../../models/attendance_record.dart';
import '../../../services/session_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/api_service.dart';
import '../../../services/network_discovery_service.dart';
import '../../../services/face_recognition_service.dart';

/// Owns the attendance record list for the active session.
///
/// All methods that need the active session receive it as a parameter so
/// this notifier stays independent of [SessionStateNotifier].
class AttendanceRecordNotifier extends ChangeNotifier with LoadingMixin {
  AttendanceRecordNotifier({
    required StorageService storage,
    required ApiService apiService,
    required SessionService sessionService,
    required NetworkDiscoveryService networkDiscovery,
    required FaceRecognitionService faceService,
  })  : _storage         = storage,
        _apiService      = apiService,
        _sessionService  = sessionService,
        _networkDiscovery = networkDiscovery,
        _faceService     = faceService;

  final StorageService          _storage;
  final ApiService              _apiService;
  final SessionService          _sessionService;
  final NetworkDiscoveryService _networkDiscovery;
  final FaceRecognitionService  _faceService;

  List<AttendanceRecord> _records      = [];
  Map<String, dynamic>   _serverStats  = {};
  int                    _wifiDevices  = 0;
  List<String>           _wifiIps      = [];

  List<AttendanceRecord> get records          => _records;
  Map<String, dynamic>   get serverStats      => _serverStats;
  int                    get activeWifiDevices => _wifiDevices;
  List<String>           get wifiDeviceIps    => _wifiIps;

  // ── Record refresh ────────────────────────────────────────────────────────────

  /// Merge local storage records with live server attendees.
  Future<void> refreshRecords(AttendanceSession session) async {
    try {
      final local = await _storage.getAttendanceRecords(session.id);

      List<AttendanceRecord> serverRecords = [];
      try {
        final raw = await _apiService.fetchServerAttendees();
        serverRecords = _convertServerAttendees(raw, session);
        _serverStats  = await _apiService.fetchServerStats();
      } catch (_) {
        _serverStats = {};
      }

      final merged = <String, AttendanceRecord>{};
      for (final r in local)         { merged[r.matricule] = r; }
      for (final r in serverRecords) { merged[r.matricule] = r; } // server wins

      _records = merged.values.toList()
        ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }

  List<AttendanceRecord> _convertServerAttendees(
    List<Map<String, dynamic>> attendees,
    AttendanceSession session,
  ) {
    final now      = DateTime.now();
    final required = session.requiredConnectionMinutes;

    return attendees.map((a) {
      final matricule  = a['matricule'] as String? ?? 'unknown';
      final username   = a['username']  as String? ?? 'Unknown';
      final joinedAt   = _parseDate(a['connectedAt'] as String?, now);
      final effectiveTime = _parseDate(a['lastSeen'] as String?, now);
      final duration   = effectiveTime.difference(joinedAt).inMinutes;
      final isVerified = duration >= required;

      return AttendanceRecord(
        id:                      'server_${matricule}_${joinedAt.millisecondsSinceEpoch}',
        sessionId:               session.id,
        studentId:               matricule,
        matricule:               matricule,
        studentName:             username,
        joinedAt:                joinedAt,
        verifiedAt:              isVerified ? now : null,
        connectionDurationMinutes: duration,
        isVerified:              isVerified,
        isManual:                false,
        deviceFingerprint:       a['ip'] as String? ?? 'unknown',
        createdAt:               joinedAt,
        updatedAt:               now,
      );
    }).toList();
  }

  DateTime _parseDate(String? raw, DateTime fallback) =>
      raw != null ? DateTime.parse(raw) : fallback;

  // ── Registration ──────────────────────────────────────────────────────────────

  Future<bool> registerStudent({
    required AttendanceSession session,
    required String matricule,
    required String studentName,
    String? email,
  }) async {
    bool success = false;
    await runWithLoading(() async {
      await _sessionService.registerStudent(
        matricule: matricule, studentName: studentName, email: email,
      );
      try {
        await _apiService.registerStudentOnServer(
          username: studentName, matricule: matricule, email: email,
        );
      } catch (e) {
        debugPrint('Server registration failed (offline?): $e');
      }
      await refreshRecords(session);
      success = true;
    });
    return success;
  }

  Future<bool> registerManualStudent({
    required AttendanceSession session,
    required String matricule,
    required String studentName,
    String? email,
  }) async {
    bool success = false;
    await runWithLoading(() async {
      await _sessionService.registerManualStudent(
        matricule: matricule, studentName: studentName, email: email,
      );
      await refreshRecords(session);
      success = true;
    });
    return success;
  }

  // ── Removal ───────────────────────────────────────────────────────────────────

  Future<bool> removeStudent(String recordId, AttendanceSession session) async {
    bool success = false;
    await runWithLoading(() async {
      final record = _records.firstWhere((r) => r.id == recordId);
      await _sessionService.removeStudent(session.id, recordId);
      _faceService.removeFace(session.id, record.matricule);
      try {
        await _apiService.removeAttendeeOnServer(record.matricule);
      } catch (e) {
        debugPrint('Server removal failed (offline?): $e');
      }
      _records.removeWhere((r) => r.id == recordId);
      success = true;
    });
    return success;
  }

  // ── Network scan ──────────────────────────────────────────────────────────────

  Future<void> refreshWifiDeviceCount() async {
    try {
      final result = await _networkDiscovery.scanActiveDevices();
      _wifiDevices = result.activeDeviceCount;
      _wifiIps     = result.deviceIps;
      notifyListeners();
    } catch (_) {
      _wifiDevices = 0;
      _wifiIps     = [];
    }
  }

  // ── Stats & reset ─────────────────────────────────────────────────────────────

  Map<String, int> getStats() {
    if (_serverStats.isNotEmpty) {
      return {
        'total':    (_serverStats['total']    as num?)?.toInt() ?? 0,
        'verified': (_serverStats['verified'] as num?)?.toInt() ?? 0,
        'pending':  (_serverStats['pending']  as num?)?.toInt() ?? 0,
      };
    }
    final verified = _records.where((r) =>  r.isVerified).length;
    final pending  = _records.where((r) => !r.isVerified).length;
    return {'total': _records.length, 'verified': verified, 'pending': pending};
  }

  /// Called by the widget layer after session end to wipe local state.
  void clear() {
    _records     = [];
    _serverStats = {};
    _wifiDevices = 0;
    _wifiIps     = [];
    notifyListeners();
  }

}
