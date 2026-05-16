# OwHAS — File Modification Guide

Organized by customer preference. Each section names the exact files to open, what to change, and nothing else.

---

## 1. Branding & Visual Identity

### Change institution name
**`lib/course_management.dart`**
```dart
static const String institutionName = 'Your University Name';
```

### Change app colors / theme
**`lib/theme.dart`**
- `LightModeColors` — change `primary`, `secondary`, `surface` hex values for light mode
- `DarkModeColors` — same for dark mode
- `AppSpacing` — adjust spacing scale (xs/sm/md/lg/xl/xxl in pixels)
- `AppRadius` — adjust corner radius scale

### Change font family
**`lib/theme.dart`** → `_buildTextTheme()` — replace `GoogleFonts.inter(...)` with any Google Fonts name

### Change app name (title bar / launcher)
- **`lib/main.dart`** → `title: 'Your App Name'`
- **`android/app/src/main/AndroidManifest.xml`** → `android:label`
- **`ios/Runner/Info.plist`** → `CFBundleName`

### Change app icon
Replace **`OHAS2.png`** (root folder) then run:
```
flutter pub run flutter_launcher_icons
```

### Change home screen headline and badge pills
**`lib/features/home/widgets/home_ui_components.dart`**
Look for the `Text(...)` with `'Offline Hotspot Attendance'` and the `BadgePill` widgets.

---

## 2. Course Catalogue (Semesters & Courses)

### Pre-load semesters and courses before distributing the APK
**`lib/course_management.dart`** — this is the only file to edit.

```dart
// Change version every time you update this file so devices re-seed
static const String version = '2026_v2';

// Set isActive: true on exactly one semester
static final List<SemesterData> semesters = [
  SemesterData(id: 'sem1', label: 'Semester 1 2025/26', isActive: true, ...),
];

// Add courses under each semester using its id
static final List<CourseData> courses = [
  CourseData(semesterId: 'sem1', name: 'Mathematics', code: 'MAT101'),
];
```

> Bump `version` on every change — this forces all devices to refresh their local catalogue.

---

## 3. Session Defaults (Grace Period, Duration, Max Students)

### Change default values in the session creation form
**`lib/features/session/screens/session_setup_screen.dart`** — top of the State class:

```dart
final _gracePeriodController     = TextEditingController(text: '5');   // minutes
final _connectionTimeController  = TextEditingController(text: '10');  // minutes
final _maxAttendanceController   = TextEditingController(text: '200'); // students
final _durationController        = TextEditingController(text: '60');  // minutes
```

Change the string inside `text: '...'` for each field.

---

## 4. Student Registration Flow

### Change which fields students fill in (name, matricule, email)
**`lib/features/attendance/widgets/registration_steps.dart`** — `DetailsStep` widget contains the form fields.
**`lib/features/attendance/widgets/registration_widgets.dart`** — individual field widgets.

### Change PIN length or validation rules
**`lib/features/attendance/widgets/registration_steps.dart`** — `PinStep` widget; look for the `validator` on the PIN field.

### Change the success message after registration
**`lib/features/attendance/widgets/success_dialog.dart`**

### Enable or disable face capture step
**`lib/features/attendance/screens/student_registration_screen.dart`** — `_submitDetails()` method.
- To skip face capture: change `_currentStep = 2` to jump directly to `_registerDirect(...)`.

### Change face similarity threshold (how strict duplicate detection is)
**`lib/services/face_recognition_service.dart`**
```dart
static const double _threshold = 0.82; // lower = stricter, higher = more lenient
```

---

## 5. PDF Attendance Report

### Change PDF layout, columns, header, footer
**`lib/services/pdf_service.dart`** — entire PDF structure lives here.
Key methods:
- `_buildHeader()` — institution name, session info at the top
- `_buildTable()` — column headers and row data
- `_buildSignatureSection()` — lecturer signature placement

### Change what data appears on the PDF
**`lib/features/reports/notifiers/report_notifier.dart`** — `generateAndSharePDFReport()` and `downloadPDFReport()` control what gets passed to `pdf_service.dart`.

### Change how previous session data is read (Excel / PDF upload)
**`lib/services/excel_service.dart`** — parsing logic for `.xlsx`, `.xls`, and `.pdf` files.

---

## 6. Lecturer Dashboard

### Change what statistics are shown in the session header
**`lib/widgets/dashboard/session_header.dart`** — the stats row with total, verified, pending, Wi-Fi device count.

### Change the QR code (size, color, refresh interval)
**`lib/widgets/dashboard/qr_code_section.dart`**

### Change attendance record list (columns, sort order, search)
**`lib/widgets/dashboard/attendance_records_section.dart`** and
**`lib/widgets/dashboard/attendance_record_tile.dart`**

### Add or remove app bar actions (share, download, add manual student)
**`lib/features/session/widgets/dashboard_app_bar.dart`**

---

## 7. Lecturer Signature

### Change how the signature is captured or stored
**`lib/services/signature_service.dart`** — save/load to SharedPreferences.
**`lib/widgets/signature_pad.dart`** — the drawing canvas widget itself.
**`lib/features/signature/widgets/signature_widgets.dart`** — form layout around the pad.

---

## 8. Server / Network Configuration

### Change which IP addresses the app tries when discovering the server
**`lib/services/server_config.dart`** — look for the list of candidate URLs:
```dart
final candidates = [
  'http://192.168.137.1:3000',  // Windows hotspot gateway
  // add university VLAN, cloud fallback, etc.
];
```

### Change server discovery timeout or scan range
**`lib/services/server_config.dart`** — `_tryUrl()` timeout and the subnet range `192.168.137.x`.

### Change Wi-Fi device count scan range
**`lib/services/network_discovery_service.dart`** — subnet and port being scanned.

---

## 9. Cloud / Firebase Sync

### Enable or disable cloud sync entirely
**`lib/services/cloud_service.dart`** — set `_enabled = false` or wrap the sync calls in a flag.

### Change what gets synced to Firestore
**`lib/services/cloud_service.dart`** — `syncSession()` and `syncAttendanceRecord()` methods.

### Change Firebase project (switch institution's Firebase account)
**`lib/firebase_options.dart`** — replace with output from `flutterfire configure`.
**`google-services.json`** (Android) / **`GoogleService-Info.plist`** (iOS) — replace in platform folders.

---

## 10. Navigation & Routing

### Add a new screen / route
1. Create screen in `lib/features/<feature>/screens/`
2. Add route constant in **`lib/core/constants/route_constants.dart`**
3. Add `GoRoute` entry in **`lib/nav.dart`**

### Change which screen opens on launch
**`lib/nav.dart`** — `initialLocation:` parameter on the `GoRouter`.

### Change back-button behavior on a screen
Each screen's `PopScope` or back-button `onTap` handler — open the specific screen file.

---

## 11. Local Storage & Data

### Change what gets saved between app sessions
**`lib/services/storage_service.dart`** — all SharedPreferences keys and read/write methods.

### Clear all local data on first launch / version upgrade
**`lib/services/storage_service.dart`** — add a version-key check in the constructor, similar to how `CourseService.seedFromManagement()` works.

---

## 12. Attendance Verification Rules

### Change how the app decides a student is "verified" vs "pending"
**`lib/services/session_service.dart`** — `_updateVerificationStatuses()` method.
Rules: student must stay connected for `requiredConnectionMinutes` within the grace period.

### Change device fingerprint logic (what counts as a unique device)
**`lib/services/device_service.dart`** — `getFingerprint()` method.

---

## Quick Reference — Files by Frequency of Change

| How often | Files |
|-----------|-------|
| Every deployment | `lib/course_management.dart` |
| Per institution | `lib/theme.dart`, `OHAS2.png`, `lib/main.dart` (title), `lib/firebase_options.dart` |
| Per customer request | `lib/services/server_config.dart`, `lib/services/pdf_service.dart` |
| Per feature toggle | `lib/features/attendance/screens/student_registration_screen.dart` (face step), `lib/services/cloud_service.dart` (sync) |
| Rarely | `lib/services/session_service.dart`, `lib/services/device_service.dart`, `lib/nav.dart` |

---

## Architecture in One Paragraph

Screens live in `lib/features/<feature>/screens/`. They read state from notifiers (`lib/features/*/notifiers/`) via `context.watch<>()` and call service singletons (`lib/services/`) for I/O. Services never touch the UI. Models (`lib/models/`) are plain data classes shared everywhere. The theme, spacing, and typography are all centralized in `lib/theme.dart`. Routes are declared once in `lib/nav.dart` and referenced by name via `lib/core/constants/route_constants.dart`.
