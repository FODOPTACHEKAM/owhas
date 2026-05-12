import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for saving and loading classroom courses and their codes.
class CourseService {
  static const String _savedCoursesKey = 'saved_courses';

  /// Load the saved course list.
  static Future<List<Map<String, String>>> loadCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedCoursesKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Map<String, String>.from(e as Map<dynamic, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save or update a course entry.
  static Future<bool> saveCourse({
    required String courseName,
    required String courseCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadCourses();
    final normalizedCode = courseCode.trim().toUpperCase();
    final normalizedName = courseName.trim();

    final existingIndex = current.indexWhere((c) {
      return c['code']?.toUpperCase() == normalizedCode || c['name'] == normalizedName;
    });

    final updatedCourse = {
      'name': normalizedName,
      'code': normalizedCode,
    };

    if (existingIndex != -1) {
      current[existingIndex] = updatedCourse;
    } else {
      current.add(updatedCourse);
    }

    return await prefs.setString(_savedCoursesKey, jsonEncode(current));
  }

  /// Remove a saved course by its code.
  static Future<bool> deleteCourse(String courseCode) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadCourses();
    current.removeWhere((c) => c['code']?.toUpperCase() == courseCode.trim().toUpperCase());
    return await prefs.setString(_savedCoursesKey, jsonEncode(current));
  }
}
