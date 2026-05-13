// =============================================================================
//  INSTITUTION COURSE CATALOGUE CONFIGURATION
//  File: lib/course_management.dart
// =============================================================================
//
//  WHO EDITS THIS FILE
//  -------------------
//  The IT administrator or department coordinator edits this file ONCE
//  before the app is built and distributed to lecturers.
//  Lecturers never need to touch this — they only select from the list.
//
//  HOW TO ADD YOUR INSTITUTION'S COURSES
//  --------------------------------------
//  1. Set `institutionName` to your university / college name.
//  2. Add your semesters inside the `semesters` list below.
//  3. Inside each semester, add all its courses in the `courses` list.
//  4. Mark the currently running semester with  isActive: true
//     (only ONE semester should be active at a time).
//  5. IMPORTANT: change the `version` string to any new value every time
//     you update this file (e.g. '2025_v1' → '2025_v2').
//     This tells the app to refresh the course list on lecturer devices.
//  6. Rebuild the APK and redistribute it to lecturers.
//
//  SEMESTER FIELDS
//  ---------------
//  id           Unique short string, e.g. 'sem_2025_1'.
//               WARNING: do NOT change an id after distributing the APK —
//               changing it creates a duplicate semester on lecturer devices.
//  label        What lecturers see in the dropdown.
//  academicYear e.g. '2025/2026'
//  number       1, 2, or 3
//  isActive     true = pre-selected when the lecturer opens session setup.
//               Set exactly ONE semester to true; all others to false.
//
//  COURSE FIELDS
//  -------------
//  name         Full course name,   e.g. 'Database Systems'
//  code         Official course code (uppercased automatically), e.g. 'IFT3025'
//  department   Optional — faculty or department name
//  credits      Optional — number of credit hours
//
//  EXAMPLE — adding a new course
//  --------------------------------
//    CourseData(
//      name:       'Advanced Networking',
//      code:       'NET402',
//      department: 'Computer Networks',
//      credits:    3,
//    ),
//
// =============================================================================

class CourseManagement {
  // ── Institution name ────────────────────────────────────────────────────────
  static const String institutionName = 'My University';

  // ── Version ─────────────────────────────────────────────────────────────────
  // Change this EVERY TIME you update the semesters or courses list.
  // Suggested format: 'YEAR_vNUMBER'  e.g. '2025_v1', '2025_v2', '2026_v1'
  static const String version = '2025_v1';

  // ── Semesters and Courses ───────────────────────────────────────────────────
  static const List<SemesterData> semesters = [

    // ── SEMESTER 1 ────────────────────────────────────────────────────────────
    SemesterData(
      id: 'sem_2025_1',
      label: 'Semester 1 — 2025/2026',
      academicYear: '2025/2026',
      number: 1,
      isActive: true, // <-- pre-selected for lecturers
      courses: [
        CourseData(name: 'Database Systems',              code: 'IFT3025', department: 'Computer Science',  credits: 3),
        CourseData(name: 'Web Development',               code: 'IFT3060', department: 'Computer Science',  credits: 3),
        CourseData(name: 'Algorithms and Data Structures',code: 'IFT2010', department: 'Computer Science',  credits: 4),
        CourseData(name: 'Introduction to Programming',   code: 'IFT1005', department: 'Computer Science',  credits: 3),
        // ↑ Add more Semester 1 courses here ↑
      ],
    ),

    // ── SEMESTER 2 ────────────────────────────────────────────────────────────
    SemesterData(
      id: 'sem_2025_2',
      label: 'Semester 2 — 2025/2026',
      academicYear: '2025/2026',
      number: 2,
      isActive: false,
      courses: [
        CourseData(name: 'Operating Systems',  code: 'IFT3150', department: 'Computer Science',    credits: 3),
        CourseData(name: 'Computer Networks',  code: 'IFT3200', department: 'Computer Networks',   credits: 3),
        CourseData(name: 'Software Engineering',code: 'IFT3010', department: 'Computer Science',   credits: 3),
        // ↑ Add more Semester 2 courses here ↑
      ],
    ),

    // ── ADD MORE SEMESTERS BELOW ──────────────────────────────────────────────
    // Copy and paste a SemesterData block above and fill in your details.

  ];
}

// =============================================================================
//  DATA CLASSES — DO NOT MODIFY BELOW THIS LINE
// =============================================================================

class SemesterData {
  final String id;
  final String label;
  final String academicYear;
  final int number;
  final bool isActive;
  final List<CourseData> courses;

  const SemesterData({
    required this.id,
    required this.label,
    required this.academicYear,
    required this.number,
    required this.isActive,
    required this.courses,
  });
}

class CourseData {
  final String name;
  final String code;
  final String? department;
  final int? credits;

  const CourseData({
    required this.name,
    required this.code,
    this.department,
    this.credits,
  });
}
