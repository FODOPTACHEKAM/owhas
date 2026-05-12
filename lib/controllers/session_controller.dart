import '../models/session.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

abstract class SessionController {
  Future<AttendanceSession?> createSession({
    required String courseName,
    String? courseCode,
    required String lecturerName,
    required int gracePeriodMinutes,
    required int requiredConnectionMinutes,
    required int maxAttendanceCount,
    required int durationMinutes,
    required int sessionNumber,
  });

  Future<AttendanceSession?> getActiveSession();

  Future<void> endSession(String sessionId);

  Future<bool> uploadPreviousSession();
}

class SessionControllerImpl implements SessionController {
  final SessionService _sessionService;
  final StorageService _storage;
  final ApiService _apiService;

  SessionControllerImpl(this._sessionService, this._storage, this._apiService);

  @override
  Future<AttendanceSession?> createSession({
    required String courseName,
    String? courseCode,
    required String lecturerName,
    required int gracePeriodMinutes,
    required int requiredConnectionMinutes,
    required int maxAttendanceCount,
    required int durationMinutes,
    required int sessionNumber,
  }) async {
    return await _sessionService.createSession(
      courseName: courseName,
      courseCode: courseCode,
      lecturerId: 'lecturer_1', // In a real app, get from auth
      lecturerName: lecturerName,
      gracePeriodMinutes: gracePeriodMinutes,
      requiredConnectionMinutes: requiredConnectionMinutes,
      maxAttendanceCount: maxAttendanceCount,
      durationMinutes: durationMinutes,
      sessionNumber: sessionNumber,
    );
  }

  @override
  Future<AttendanceSession?> getActiveSession() async {
    return await _storage.getActiveSession();
  }

  @override
  Future<void> endSession(String sessionId) async {
    await _sessionService.endSession(sessionId);
  }

  @override
  Future<bool> uploadPreviousSession() async {
    // Implementation would go here
    return false;
  }
}