# Plan: QR-Only Session Dashboard with Server Stats

## User Requirements
1. Session page shows ONLY the QR code for `http://192.168.137.1:5500/public/hotspot.html`
2. Dashboard shows: number of people connected, those verified, those pending
3. No more PIN generation

## Architecture Changes

### 1. Backend (server.js)
- Add `connectedAt` timestamp to attendee records
- Add `GET /api/attendees` endpoint — returns all attendees
- Add `GET /api/stats` endpoint — returns `{ total, verified, pending }` based on connection duration

### 2. Models
- `lib/models/session.dart` — Remove `currentPin` field
- `lib/models/attendance_record.dart` — Simplify (remove `isPinVerified` since no PIN)

### 3. Services
- `lib/services/session_service.dart` — Remove `_generatePin()`, `regeneratePin()`, PIN verification in `registerStudent()`
- `lib/services/api_service.dart` — Add `fetchServerStats()` and `fetchServerAttendees()` methods

### 4. Provider
- `lib/providers/attendance_provider.dart` — Add server stats polling, remove PIN-related methods

### 5. UI
- `lib/pages/lecturer_dashboard_page.dart` —
  - QR code encodes hotspot URL directly
  - Remove PIN display and regenerate button
  - Stats cards pull from server API
  - Attendee list populated from server
- `lib/pages/session_setup_page.dart` — Keep fields (grace period, connection time still used for verification logic)

## Files to Edit
1. `server.js`
2. `lib/models/session.dart`
3. `lib/models/attendance_record.dart`
4. `lib/services/session_service.dart`
5. `lib/services/api_service.dart`
6. `lib/providers/attendance_provider.dart`
7. `lib/pages/lecturer_dashboard_page.dart`

