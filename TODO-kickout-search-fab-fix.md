# TODO: Kick Out Students, Search Bar, Coverage Fix, FAB Fix

## Plan
1. ✅ `lib/services/storage_service.dart` - Add `deleteAttendanceRecord` method
2. ✅ `lib/services/session_service.dart` - Add `removeStudent` method
3. ✅ `server.js` - Add `POST /api/remove-attendee` endpoint
4. ✅ `lib/services/api_service.dart` - Add `removeAttendeeOnServer` method
5. ✅ `lib/providers/attendance_provider.dart` - Add `removeStudent` provider method
6. ✅ `lib/pages/lecturer_dashboard_page.dart` - Add search bar, kick-out button, fix coverage %, fix FAB bounds

## Summary of Changes

### 1. Kick Out Students
- **StorageService**: Added `deleteAttendanceRecord(sessionId, recordId)` to remove a record from SharedPreferences.
- **SessionService**: Added `removeStudent(sessionId, recordId)` wrapper.
- **Server (`server.js`)**: Added `POST /api/remove-attendee` endpoint that filters attendees by matricule.
- **ApiService**: Added `removeAttendeeOnServer(matricule)` to call the new endpoint.
- **AttendanceProvider**: Added `removeStudent(recordId)` that removes locally, calls server (best-effort), and updates the UI.
- **LecturerDashboardPage**: Added `_confirmRemoveStudent()` dialog and red "person_remove" icon button on each attendance tile.

### 2. Search Bar
- Added a `TextField` above the attendance list in `LecturerDashboardPage`.
- Filters records by `studentName` or `matricule` in real time.
- Uses `_searchQuery` state variable.

### 3. Coverage % Fix
- Changed from `wifiDevices / total` to `verified / total * 100`.
- Now shows the percentage of verified students out of all registered students.

### 4. FAB Bounds Fix
- Wrapped FAB in `LayoutBuilder` to get screen constraints.
- Clamped FAB position using `.clamp(0.0, maxX/Y)` so it never moves off-screen.

