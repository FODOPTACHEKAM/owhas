# TODO: Fix Network Registration to Node Server

## Problem
When a student on the same network clicks **Register** in the Flutter app, the data is only saved locally and never reaches the Node.js server. The server’s `attendees` array (used for PDF export) stays empty, so the lecturer sees no registrations.

## Root Causes
1. Flutter app never POSTs registration data to the server.
2. Android 9+ blocks cleartext HTTP by default.
3. Network discovery scans wrong port (5500 instead of 80).
4. Server does not parse JSON bodies.

## Plan / Checklist
- [x] Step 1: `server.js` – runs on port 5500, has `express.json()` middleware
- [x] Step 2: `lib/services/api_service.dart` – baseUrl includes `:5500`, added `registerStudentOnServer()`
- [x] Step 3: `lib/providers/attendance_provider.dart` – pushes to server after local save
- [x] Step 4: `lib/services/network_discovery_service.dart` – changed port to 5500
- [x] Step 5: `android/app/src/main/AndroidManifest.xml` – added `usesCleartextTraffic="true"`
- [x] Step 6: `lib/pages/lecturer_dashboard_page.dart` – QR URL includes `:5500` port

