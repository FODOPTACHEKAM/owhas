# TODO: Session Auto-End, PIN-Only QR, Lecturer Name

## Steps
- [x] 1. Update `lib/models/session.dart` — add `durationMinutes` and `lecturerName`
- [x] 2. Update `server.js` — accept `durationMinutes` & `lecturerName`, dynamic expiry
- [x] 3. Update `public/hotspot.html` — display `lecturerName` from validate-pin
- [x] 4. Update `lib/services/session_service.dart` — accept new fields, auto-end Timer
- [x] 5. Update `lib/providers/attendance_provider.dart` — pass new fields, auto-end on init
- [x] 6. Update `lib/pages/session_setup_page.dart` — add lecturer name & duration inputs
- [x] 7. Update `lib/pages/lecturer_dashboard_page.dart` — remove token QR, show lecturer name & end time


