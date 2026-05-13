import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/semester.dart';
import '../models/catalogue_course.dart';
import '../course_management.dart';

class CourseService {
  static const _semesterKey = 'catalogue_semesters';
  static const _courseKey = 'catalogue_courses';
  static const _legacyKey = 'saved_courses';
  static const _seedVersionKey = 'catalogue_seed_version';
  static const _uuid = Uuid();

  // ── Seeding from course_management.dart ───────────────────────────────────

  /// Called once on app startup (in main.dart).
  /// If the stored seed version differs from CourseManagement.version,
  /// the device catalogue is wiped and rebuilt from the static data — meaning
  /// any update to course_management.dart + APK rebuild automatically
  /// refreshes all lecturer devices on next launch.
  static Future<void> seedFromManagement() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_seedVersionKey);
    if (stored == CourseManagement.version) return; // already up to date

    // Clear old catalogue before re-seeding
    await prefs.remove(_semesterKey);
    await prefs.remove(_courseKey);

    final List<Semester> semesters = [];
    final List<CatalogueCourse> courses = [];

    for (final sd in CourseManagement.semesters) {
      final semester = Semester(
        id: sd.id,
        label: sd.label,
        academicYear: sd.academicYear,
        number: sd.number,
        isActive: sd.isActive,
        createdAt: DateTime.now(),
      );
      semesters.add(semester);

      for (final cd in sd.courses) {
        courses.add(CatalogueCourse(
          id: _uuid.v4(),
          semesterId: sd.id,
          name: cd.name.trim(),
          code: cd.code.trim().toUpperCase(),
          department: cd.department,
          credits: cd.credits,
          createdAt: DateTime.now(),
        ));
      }
    }

    await prefs.setString(
      _semesterKey,
      jsonEncode(semesters.map((s) => s.toJson()).toList()),
    );
    await prefs.setString(
      _courseKey,
      jsonEncode(courses.map((c) => c.toJson()).toList()),
    );
    await prefs.setString(_seedVersionKey, CourseManagement.version);
  }

  // ── Semesters ──────────────────────────────────────────────────────────────

  static Future<List<Semester>> loadSemesters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_semesterKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Semester.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSemester(Semester semester) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadSemesters();
    final idx = list.indexWhere((s) => s.id == semester.id);
    if (idx != -1) {
      list[idx] = semester;
    } else {
      list.add(semester);
    }
    await prefs.setString(
      _semesterKey,
      jsonEncode(list.map((s) => s.toJson()).toList()),
    );
  }

  static Future<void> deleteSemester(String semesterId) async {
    final prefs = await SharedPreferences.getInstance();
    final semesters = await loadSemesters();
    semesters.removeWhere((s) => s.id == semesterId);
    await prefs.setString(
      _semesterKey,
      jsonEncode(semesters.map((s) => s.toJson()).toList()),
    );
    final courses = await loadCourses();
    courses.removeWhere((c) => c.semesterId == semesterId);
    await prefs.setString(
      _courseKey,
      jsonEncode(courses.map((c) => c.toJson()).toList()),
    );
  }

  /// Makes one semester active and all others inactive.
  static Future<void> setActiveSemester(String semesterId) async {
    final list = await loadSemesters();
    final updated = list
        .map((s) => s.copyWith(isActive: s.id == semesterId))
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _semesterKey,
      jsonEncode(updated.map((s) => s.toJson()).toList()),
    );
  }

  // ── Courses ────────────────────────────────────────────────────────────────

  static Future<List<CatalogueCourse>> loadCourses({
    String? semesterId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_courseKey);
    List<CatalogueCourse> all = [];

    if (raw != null && raw.isNotEmpty) {
      try {
        all = (jsonDecode(raw) as List)
            .map((e) => CatalogueCourse.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    } else {
      all = await _migrateLegacyCourses(prefs);
    }

    return semesterId == null
        ? all
        : all.where((c) => c.semesterId == semesterId).toList();
  }

  static Future<void> saveCourse(CatalogueCourse course) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadCourses();
    final idx = list.indexWhere((c) => c.id == course.id);
    if (idx != -1) {
      list[idx] = course;
    } else {
      list.add(course);
    }
    await prefs.setString(
      _courseKey,
      jsonEncode(list.map((c) => c.toJson()).toList()),
    );
  }

  static Future<void> deleteCourse(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadCourses();
    list.removeWhere((c) => c.id == courseId);
    await prefs.setString(
      _courseKey,
      jsonEncode(list.map((c) => c.toJson()).toList()),
    );
  }

  // ── Factories ──────────────────────────────────────────────────────────────

  static CatalogueCourse buildCourse({
    required String semesterId,
    required String name,
    required String code,
    String? department,
    int? credits,
  }) =>
      CatalogueCourse(
        id: _uuid.v4(),
        semesterId: semesterId,
        name: name.trim(),
        code: code.trim().toUpperCase(),
        department: department?.trim().isEmpty == true ? null : department?.trim(),
        credits: credits,
        createdAt: DateTime.now(),
      );

  static Semester buildSemester({
    required String academicYear,
    required int number,
  }) {
    final label = 'Semester $number — $academicYear';
    return Semester(
      id: _uuid.v4(),
      label: label,
      academicYear: academicYear.trim(),
      number: number,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  // ── Legacy migration ───────────────────────────────────────────────────────

  static Future<List<CatalogueCourse>> _migrateLegacyCourses(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final legacy = (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .where((e) => e['name'] != null && e['code'] != null)
          .toList();
      if (legacy.isEmpty) return [];

      final importSem = Semester(
        id: _uuid.v4(),
        label: 'Imported Courses',
        academicYear: 'Imported',
        number: 0,
        isActive: false,
        createdAt: DateTime.now(),
      );
      await saveSemester(importSem);

      final courses = legacy
          .map(
            (e) => buildCourse(
              semesterId: importSem.id,
              name: e['name']!,
              code: e['code']!,
            ),
          )
          .toList();

      await prefs.setString(
        _courseKey,
        jsonEncode(courses.map((c) => c.toJson()).toList()),
      );
      return courses;
    } catch (_) {
      return [];
    }
  }
}
