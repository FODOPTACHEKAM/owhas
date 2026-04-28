# TODO: Digital Signature for PDF Reports

## Steps

- [x] Step 1: Create `lib/services/signature_service.dart` — Save/load signature PNG bytes via SharedPreferences
- [x] Step 2: Create `lib/widgets/signature_pad.dart` — Reusable signature capture widget with CustomPainter
- [x] Step 3: Create `lib/pages/signature_setup_page.dart` — Full-screen signature page
- [x] Step 4: Update `lib/services/pdf_service.dart` — Embed saved signature image in generated PDFs
- [x] Step 5: Update `lib/providers/attendance_provider.dart` — Load signature before PDF generation
- [x] Step 6: Update `lib/pages/lecturer_dashboard_page.dart` — Add signature button to AppBar
- [x] Step 7: Update `lib/nav.dart` — Add `/signature` route
- [x] Step 8: Run `flutter analyze` to verify compilation (clean build confirmed)

## Files Created
- `lib/services/signature_service.dart`
- `lib/widgets/signature_pad.dart`
- `lib/pages/signature_setup_page.dart`

## Files Modified
- `lib/services/pdf_service.dart`
- `lib/providers/attendance_provider.dart`
- `lib/pages/lecturer_dashboard_page.dart`
- `lib/nav.dart`

## Notes
- No new dependencies needed (`shared_preferences` already in `pubspec.yaml`)
- Signature is stored as base64-encoded PNG in SharedPreferences
- PDF embeds signature right-aligned above the footer with a horizontal rule and "Lecturer Signature" label
- If no signature is saved, PDF generates normally without the signature section

