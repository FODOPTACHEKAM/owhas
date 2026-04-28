# TODO: Signature + Lecturer Name + PDF Styling Improvements

## Steps

- [x] Step 1: `signature_service.dart` — add lecturerName save/load/clear methods
- [x] Step 2: `signature_setup_page.dart` — add lecturer name TextFormField + save/clear logic
- [x] Step 3: `pdf_service.dart` — add lecturerName + signaturePngBytes params; blue headers; total count; signature at bottom
- [x] Step 4: `attendance_provider.dart` — load lecturer name/signature; pass to PDF; fix filename to `${courseName}_${yyyy-MM-dd}.pdf`
- [x] Step 5: `lecturer_dashboard_page.dart` — show lecturer name in session info
- [x] Step 6: `flutter analyze` — verify no errors (only 2 pre-existing print warnings)
- [ ] Step 7: `flutter build apk --debug` — verify Android build succeeds
