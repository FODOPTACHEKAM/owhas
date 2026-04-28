# TODO: Fix PDF Layout & Restore PDF Previous Session Loading

## Steps

- [x] Step 1: Add `pdf_text: ^0.5.0` back to `pubspec.yaml`
- [x] Step 2: Fix cached `pdf_text` build.gradle — replace `jcenter()` with `mavenCentral()`
- [x] Step 3: Update `lib/services/pdf_service.dart` — status circles, email fitting, row spacing
- [x] Step 4: Update `lib/pages/session_setup_page.dart` — button text to "Choose File (Excel or PDF)"
- [x] Step 5: Update `lib/services/excel_service.dart` — robust PDF parsing error handling
- [ ] Step 6: Run `flutter pub get` and verify build

