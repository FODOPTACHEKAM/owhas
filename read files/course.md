# OwHAS — Course Catalogue System

Design document for adding institution-level semester and course management so
lecturers can select their course from a pre-loaded list instead of typing it
every time.

---

## 1. What Exists Today

`CourseService` (`lib/services/course_service.dart`) saves a flat list of
`{ name, code }` pairs to SharedPreferences under the key `'saved_courses'`.
The lecturer adds courses manually one by one through a small dialog on the
Session Setup page.

**Problems with the current approach:**
- No semester grouping — all courses from all years are mixed together
- Each lecturer types their own courses from scratch — no shared catalogue
- No department filtering — a university with 50+ courses shows all at once
- Courses have no additional metadata (credits, level, department)
- If the lecturer switches phone or reinstalls the app, all saved courses vanish

---

## 2. Target Design

```
Institution
 └── Semester  (e.g. "Semester 1 — 2025/2026")
      └── Course  (e.g. "Database Systems  •  IFT3025  •  Dept: Computer Science")
```

A one-time setup screen lets an administrator (department head or IT officer)
enter all semesters and their courses.  From that point, every lecturer simply:

1. Opens the app → taps **Select Course**
2. Picks their active semester from a dropdown
3. Picks their course from the filtered list
4. Hits **Start Session** — name, code, and semester are pre-filled

---

## 3. Data Models

### 3.1 `Semester`

```dart
// lib/models/semester.dart

class Semester {
  final String id;          // UUID, e.g. "sem_2025_1"
  final String label;       // Display name: "Semester 1 — 2025/2026"
  final String academicYear; // "2025/2026"
  final int    number;       // 1 or 2 (or 3 for trimester systems)
  final bool   isActive;     // true = currently running semester
  final DateTime createdAt;

  const Semester({
    required this.id,
    required this.label,
    required this.academicYear,
    required this.number,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id':           id,
    'label':        label,
    'academicYear': academicYear,
    'number':       number,
    'isActive':     isActive,
    'createdAt':    createdAt.toIso8601String(),
  };

  factory Semester.fromJson(Map<String, dynamic> j) => Semester(
    id:           j['id'],
    label:        j['label'],
    academicYear: j['academicYear'],
    number:       j['number'],
    isActive:     j['isActive'] ?? false,
    createdAt:    DateTime.parse(j['createdAt']),
  );
}
```

### 3.2 `CatalogueCourse`

```dart
// lib/models/catalogue_course.dart

class CatalogueCourse {
  final String  id;           // UUID
  final String  semesterId;   // FK → Semester.id
  final String  name;         // "Database Systems"
  final String  code;         // "IFT3025"
  final String? department;   // "Computer Science" (optional)
  final int?    credits;      // 3 (optional)
  final DateTime createdAt;

  const CatalogueCourse({
    required this.id,
    required this.semesterId,
    required this.name,
    required this.code,
    this.department,
    this.credits,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id':         id,
    'semesterId': semesterId,
    'name':       name,
    'code':       code,
    'department': department,
    'credits':    credits,
    'createdAt':  createdAt.toIso8601String(),
  };

  factory CatalogueCourse.fromJson(Map<String, dynamic> j) => CatalogueCourse(
    id:         j['id'],
    semesterId: j['semesterId'],
    name:       j['name'],
    code:       j['code'],
    department: j['department'],
    credits:    j['credits'],
    createdAt:  DateTime.parse(j['createdAt']),
  );
}
```

---

## 4. Updated `CourseService`

Replace the current flat `CourseService` with one that manages both semesters
and courses.  Keep the old `saved_courses` key loading as a migration fallback
so existing data is not lost on first upgrade.

```dart
// lib/services/course_service.dart  (full replacement)

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/semester.dart';
import '../models/catalogue_course.dart';

class CourseService {
  static const _semesterKey = 'catalogue_semesters';
  static const _courseKey   = 'catalogue_courses';
  static const _legacyKey   = 'saved_courses';       // migration only
  static const _uuid = Uuid();

  // ── Semesters ────────────────────────────────────────────────────────────────

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
    final list  = await loadSemesters();
    final idx   = list.indexWhere((s) => s.id == semester.id);
    if (idx != -1) list[idx] = semester; else list.add(semester);
    await prefs.setString(_semesterKey, jsonEncode(list.map((s) => s.toJson()).toList()));
  }

  static Future<void> deleteSemester(String semesterId) async {
    final prefs = await SharedPreferences.getInstance();
    // Remove semester
    final semesters = await loadSemesters();
    semesters.removeWhere((s) => s.id == semesterId);
    await prefs.setString(_semesterKey, jsonEncode(semesters.map((s) => s.toJson()).toList()));
    // Remove all courses that belonged to it
    final courses = await loadCourses();
    courses.removeWhere((c) => c.semesterId == semesterId);
    await prefs.setString(_courseKey, jsonEncode(courses.map((c) => c.toJson()).toList()));
  }

  /// Mark one semester active, all others inactive.
  static Future<void> setActiveSemester(String semesterId) async {
    final list = await loadSemesters();
    final updated = list.map((s) => Semester(
      id:           s.id,
      label:        s.label,
      academicYear: s.academicYear,
      number:       s.number,
      isActive:     s.id == semesterId,
      createdAt:    s.createdAt,
    )).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_semesterKey, jsonEncode(updated.map((s) => s.toJson()).toList()));
  }

  // ── Courses ──────────────────────────────────────────────────────────────────

  static Future<List<CatalogueCourse>> loadCourses({String? semesterId}) async {
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
      // One-time migration from legacy flat list
      all = await _migrateLegacyCourses(prefs);
    }

    return semesterId == null ? all : all.where((c) => c.semesterId == semesterId).toList();
  }

  static Future<void> saveCourse(CatalogueCourse course) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = await loadCourses();
    final idx   = list.indexWhere((c) => c.id == course.id);
    if (idx != -1) list[idx] = course; else list.add(course);
    await prefs.setString(_courseKey, jsonEncode(list.map((c) => c.toJson()).toList()));
  }

  static Future<void> deleteCourse(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = await loadCourses();
    list.removeWhere((c) => c.id == courseId);
    await prefs.setString(_courseKey, jsonEncode(list.map((c) => c.toJson()).toList()));
  }

  /// Convenience factory — generates ID and timestamps automatically.
  static CatalogueCourse createCourse({
    required String semesterId,
    required String name,
    required String code,
    String? department,
    int? credits,
  }) =>
      CatalogueCourse(
        id:         _uuid.v4(),
        semesterId: semesterId,
        name:       name.trim(),
        code:       code.trim().toUpperCase(),
        department: department?.trim(),
        credits:    credits,
        createdAt:  DateTime.now(),
      );

  static Semester createSemester({
    required String academicYear,
    required int number,
  }) {
    final label = 'Semester $number — $academicYear';
    return Semester(
      id:           _uuid.v4(),
      label:        label,
      academicYear: academicYear,
      number:       number,
      isActive:     false,
      createdAt:    DateTime.now(),
    );
  }

  // ── Legacy migration ─────────────────────────────────────────────────────────

  /// Reads the old `saved_courses` flat list and imports each entry into a
  /// placeholder semester called "Imported Courses".  Runs once.
  static Future<List<CatalogueCourse>> _migrateLegacyCourses(
      SharedPreferences prefs) async {
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final legacy = (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
      if (legacy.isEmpty) return [];

      // Create a placeholder semester
      final importSem = createSemester(academicYear: 'Imported', number: 0);
      final importSemWithLabel = Semester(
        id: importSem.id, label: 'Imported Courses',
        academicYear: 'Imported', number: 0,
        isActive: false, createdAt: importSem.createdAt,
      );
      await saveSemester(importSemWithLabel);

      // Convert each legacy entry to CatalogueCourse
      final courses = legacy.map((e) => createCourse(
        semesterId: importSem.id,
        name: e['name'] ?? '',
        code: e['code'] ?? '',
      )).toList();

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
```

---

## 5. New Pages

### 5.1 Course Catalogue Page (`lib/pages/course_catalogue_page.dart`)

This is the administration screen.  Accessed from the Home page via a
**Manage Catalogue** button (shown only on the lecturer role card).

**Layout:**

```
┌─────────────────────────────────────────────┐
│  ←  Course Catalogue               [+ Semester] │
├─────────────────────────────────────────────┤
│                                             │
│  ▼  Semester 1 — 2025/2026  ● Active  [✎] [🗑] │
│  ┌──────────────────────────────────────┐   │
│  │  Database Systems     IFT3025  [✎][🗑]│   │
│  │  Web Development      IFT3060  [✎][🗑]│   │
│  │  Algorithms           IFT2010  [✎][🗑]│   │
│  │                    [+ Add Course]     │   │
│  └──────────────────────────────────────┘   │
│                                             │
│  ▶  Semester 2 — 2025/2026         [✎] [🗑] │
│                                             │
│  ▶  Imported Courses               [✎] [🗑] │
└─────────────────────────────────────────────┘
```

**Key behaviours:**
- Each semester row is an `ExpansionTile` that expands to show its courses
- "● Active" chip next to the currently active semester — tap another
  semester's row to set it as active (radio behaviour)
- "Add Course" button inside each semester's expanded panel opens the
  Add Course dialog
- Swipe-to-delete or trash icon removes a course with a confirmation dialog
- Delete semester also deletes all its courses (warning shown in dialog)

**Add/Edit Semester dialog fields:**

| Field | Type | Example |
|-------|------|---------|
| Academic Year | Text | 2025/2026 |
| Semester Number | Dropdown (1, 2, 3) | 1 |

The `label` is auto-generated: `"Semester 1 — 2025/2026"`.

**Add/Edit Course dialog fields:**

| Field | Required | Example |
|-------|----------|---------|
| Course Name | Yes | Database Systems |
| Course Code | Yes | IFT3025 |
| Department | No | Computer Science |
| Credits | No | 3 |

---

### 5.2 Updated Session Setup Page

Replace the current "Select Saved Course" dropdown with a two-step picker:

```
┌──────────────────────────────────────────────┐
│  Semester                                    │
│  ┌──────────────────────────────────────┐   │
│  │  Semester 1 — 2025/2026            ▼ │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  Course                                      │
│  ┌──────────────────────────────────────┐   │
│  │  Database Systems (IFT3025)         ▼ │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  Course Name  [Database Systems         ]    │
│  Course Code  [IFT3025                  ]    │
└──────────────────────────────────────────────┘
```

1. Lecturer selects semester → course dropdown filters to that semester's list
2. Lecturer selects course → Course Name and Course Code fields auto-fill
   (fields remain editable in case of one-off override)
3. If the catalogue is empty, a banner shows: "No courses configured.
   Go to Manage Catalogue to add your institution's courses."

**Code change in `session_setup_page.dart`:**

```dart
// Replace _savedCourses (flat list) with:
List<Semester> _semesters = [];
List<CatalogueCourse> _allCourses = [];
Semester? _selectedSemester;
CatalogueCourse? _selectedCourse;

// Load on initState
Future<void> _loadCatalogue() async {
  final semesters = await CourseService.loadSemesters();
  final courses   = await CourseService.loadCourses();
  if (!mounted) return;
  setState(() {
    _semesters = semesters;
    _allCourses = courses;
    // Pre-select the active semester
    _selectedSemester = semesters.firstWhereOrNull((s) => s.isActive)
        ?? (semesters.isNotEmpty ? semesters.first : null);
  });
}

// Courses filtered to the chosen semester
List<CatalogueCourse> get _semesterCourses => _selectedSemester == null
    ? []
    : _allCourses.where((c) => c.semesterId == _selectedSemester!.id).toList();

// When course is chosen
void _onCourseSelected(CatalogueCourse? course) {
  if (course == null) return;
  setState(() {
    _selectedCourse = course;
    _courseNameController.text = course.name;
    _courseCodeController.text = course.code;
  });
}
```

---

## 6. Navigation Changes

Add a **Manage Catalogue** entry to the home page, visible in the lecturer card:

```dart
// In home_page.dart, inside the lecturer role card actions:
OutlinedButton.icon(
  onPressed: () => context.go('/catalogue'),
  icon: const Icon(Icons.menu_book_outlined),
  label: const Text('Manage Catalogue'),
),
```

Add the route to your router:

```dart
// In lib/router.dart (or wherever GoRouter is configured)
GoRoute(
  path: '/catalogue',
  builder: (_, __) => const CourseCataloguePage(),
),
```

---

## 7. File Changes Summary

| Action | File |
|--------|------|
| **Create** | `lib/models/semester.dart` |
| **Create** | `lib/models/catalogue_course.dart` |
| **Replace** | `lib/services/course_service.dart` |
| **Create** | `lib/pages/course_catalogue_page.dart` |
| **Modify** | `lib/pages/session_setup_page.dart` — swap pickers |
| **Modify** | `lib/pages/home_page.dart` — add catalogue button |
| **Modify** | `lib/router.dart` — add `/catalogue` route |
| **Modify** | `pubspec.yaml` — add `uuid` if not already present |

---

## 8. `pubspec.yaml` — Dependency Check

The `uuid` package is needed for generating `Semester.id` and
`CatalogueCourse.id`.  Check if it is already listed:

```yaml
dependencies:
  uuid: ^4.4.0       # add if missing
```

Run `flutter pub get` after adding.

---

## 9. Implementation Order

Follow this sequence to avoid breaking the existing session setup flow:

### Step 1 — Models (no UI, no breakage)
Create `lib/models/semester.dart` and `lib/models/catalogue_course.dart`.
These are pure data classes with no dependencies on existing code.

### Step 2 — Service (backward compatible)
Replace `lib/services/course_service.dart` with the new version shown in
section 4.  The migration logic in `_migrateLegacyCourses` will automatically
import the lecturer's existing flat course list into an "Imported Courses"
semester the first time the app runs after the update — no data is lost.

### Step 3 — Catalogue page
Create `lib/pages/course_catalogue_page.dart` and add the `/catalogue`
route.  The catalogue page is self-contained — it does not affect anything else.

### Step 4 — Session setup update
Update `lib/pages/session_setup_page.dart` to use the two-dropdown
semester → course picker.  Keep the manual Course Name and Course Code
text fields so the lecturer can still override or type a one-off course.

### Step 5 — Home page button
Add the **Manage Catalogue** button to the lecturer role card on the home page.

---

## 10. Complete Data Flow

```
Admin opens app
  → taps "Manage Catalogue"
      → CourseCataloguePage loads
          → CourseService.loadSemesters()
          → CourseService.loadCourses()
      → Admin taps "+ Semester"
          → enters "2025/2026", picks "Semester 1"
          → CourseService.saveSemester(...)
      → Admin expands semester → taps "+ Add Course"
          → enters name, code, department
          → CourseService.saveCourse(...)
      → Admin marks semester as Active
          → CourseService.setActiveSemester(id)

Lecturer opens app
  → taps "New Session" → SessionSetupPage
      → CourseService.loadSemesters() → shows dropdown
      → Active semester pre-selected
      → Lecturer picks semester → course list filters
      → Lecturer picks course → name + code auto-filled
      → Taps "Start Session" → session launched
```

---

## 11. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| No semesters configured | Session setup shows banner: "Go to Manage Catalogue" |
| Semester has no courses | Course dropdown is empty with hint "Add courses to this semester first" |
| Lecturer wants a course not in the list | They can type directly in the Course Name / Course Code fields |
| App reinstalled | All catalogue data is lost (SharedPreferences cleared). Mitigate with export/import in Step 12 |
| Two semesters marked active | `setActiveSemester` clears all others — only one can be active at a time |
| Legacy courses before update | Auto-migrated into "Imported Courses" semester on first run |

---

## 12. Optional Future Step — Export / Import Catalogue

Because SharedPreferences is device-local, reinstalling the app wipes the
catalogue.  Once the basic feature works, add a JSON export/import so the
admin can back up and restore:

```
Catalogue page → three-dot menu → Export Catalogue → saves catalogue.json
Catalogue page → three-dot menu → Import Catalogue → reads catalogue.json
```

The JSON structure is simply:

```json
{
  "semesters": [ ...Semester.toJson()... ],
  "courses":   [ ...CatalogueCourse.toJson()... ]
}
```

Write it with `file_service.dart`'s existing save logic.  This also allows
copying the catalogue from one lecturer's phone to another via WhatsApp or USB.
