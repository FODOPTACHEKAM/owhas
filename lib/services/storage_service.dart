import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';
import '../models/attendance_record.dart';
import '../models/student.dart';

/// Service for local storage operations
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Session storage
  Future<void> saveSession(AttendanceSession session) async {
    await init();
    final sessions = await getSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
    await _prefs!.setString(
      'sessions',
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<List<AttendanceSession>> getSessions() async {
    await init();
    final data = _prefs!.getString('sessions');
    if (data == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((s) => AttendanceSession.fromJson(s)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<AttendanceSession?> getActiveSession() async {
    final sessions = await getSessions();
    try {
      return sessions.firstWhere((s) => s.isActive);
    } catch (e) {
      return null;
    }
  }

  // Attendance records storage
  Future<void> saveAttendanceRecord(AttendanceRecord record) async {
    await init();
    final records = await getAttendanceRecords(record.sessionId);
    final index = records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      records[index] = record;
    } else {
      records.add(record);
    }
    await _prefs!.setString(
      'attendance_${record.sessionId}',
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  Future<List<AttendanceRecord>> getAttendanceRecords(String sessionId) async {
    await init();
    final data = _prefs!.getString('attendance_$sessionId');
    if (data == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((r) => AttendanceRecord.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  // Student storage
  Future<void> saveStudent(Student student) async {
    await init();
    final students = await getStudents();
    final index = students.indexWhere((s) => s.id == student.id);
    if (index != -1) {
      students[index] = student;
    } else {
      students.add(student);
    }
    await _prefs!.setString(
      'students',
      jsonEncode(students.map((s) => s.toJson()).toList()),
    );
  }

  Future<List<Student>> getStudents() async {
    await init();
    final data = _prefs!.getString('students');
    if (data == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((s) => Student.fromJson(s)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Student?> getStudentByMatricule(String matricule) async {
    final students = await getStudents();
    try {
      return students.firstWhere((s) => s.matricule == matricule);
    } catch (e) {
      return null;
    }
  }

  // Clear all data
  Future<void> clearAll() async {
    await init();
    await _prefs!.clear();
  }
}
