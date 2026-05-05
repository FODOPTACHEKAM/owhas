# Cloud Integration Implementation Plan

## Steps

- [x] 1. Create TODO-cloud-plan.md (this file)
- [x] 2. Update pubspec.yaml — Add Firebase & geolocator dependencies
- [x] 3. Create cloud.md — Full cloud architecture documentation
- [x] 4. Update AttendanceRecord model — Add location fields (latitude, longitude, accuracy, address)
- [x] 5. Create lib/services/location_service.dart — GPS collection service
- [x] 6. Create lib/services/cloud_service.dart — Firebase CRUD & sync logic
- [x] 7. Modify lib/services/session_service.dart — Integrate cloud sync calls
- [x] 8. Modify lib/pages/student_registration_page.dart — Collect location on registration (via SessionService)
- [x] 9. Create lib/pages/cloud_login_page.dart — Lecturer Firebase Auth login
- [x] 10. Create lib/pages/cloud_sessions_page.dart — Cloud session viewer & downloader
- [x] 11. Update lib/nav.dart — Add cloud routes
- [x] 12. Update lib/main.dart — Initialize Firebase & auth state
- [x] 13. Run flutter pub get & verify

## Summary

All cloud integration components have been implemented. See `cloud.md` for full setup instructions.
