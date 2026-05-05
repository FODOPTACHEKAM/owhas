# TODO: Allow PDF Upload for Previous Session — ROLLED BACK TO EXCEL-ONLY

## Context
`pdf_text` plugin depends on `com.tom_roush:pdfbox-android:1.8.10.1` which is hosted on JCenter (shutdown). This caused unresolvable Android build failures. Decision: remove PDF upload support, keep Excel upload.

## Steps Completed

- [x] Step 1: Removed `pdf_text: ^0.5.0` from `pubspec.yaml`
- [x] Step 2: Cleaned up `excel_service.dart` — removed PDF parsing methods (`_parsePdf()`, `_parseMasterRosterLine()`), kept Excel-only upload
- [x] Step 3: Updated `session_setup_page.dart` button back to "Choose Excel File" (clearer UX)
- [x] Step 4: `flutter pub get` succeeded
- [x] Step 5: `flutter analyze` passed (only 2 pre-existing avoid_print info warnings)
- [x] Step 6: `flutter build apk --debug` — **SUCCESS** ✓ (`app-debug.apk` built in 42.9s)
