# TODO: Fix PDF Upload + Add T.P Table

## Steps

- [x] Step 1: Fix server-side PDF parsing (`server.js`)
  - [x] Flexible matricule regex
  - [x] Improved name extraction
  - [x] Better number/total extraction
  - [x] Extract session/T.P number from PDF
  - [x] Add debug logging
- [x] Step 2: Add `sessionNumber` to `AttendanceSession` model (`lib/models/session.dart`)
- [x] Step 3: Track session number in Provider (`lib/providers/attendance_provider.dart`)
- [x] Step 4: Update Excel Service to handle session number (`lib/services/excel_service.dart`)
- [x] Step 5: Update API Service response parsing (`lib/services/api_service.dart`)
- [x] Step 6: Add T.P table to PDF generation (`lib/services/pdf_service.dart`)
- [x] Step 7: Update Session Service to accept sessionNumber (`lib/services/session_service.dart`)
- [ ] Step 8: Test and verify

