# Attendance App Usage Guide

## Overview
This app helps lecturers manage classroom attendance with both offline and online support. Students register attendance using a QR code and digital verification, while lecturers can view session stats, add manual students, and generate reports.

## Getting Started
1. Install the app on the lecturer device.
2. Open the app and allow required permissions:
   - Location access
   - Storage access (for saving reports)
3. Set up the lecturer signature if prompted in the digital signature setup page.

## Creating a Session
1. From the home screen, tap **Create Session**.
2. Enter the session details:
   - Course Name
   - Course Code (optional)
   - Lecturer Name
   - Session Duration
   - Grace Period
   - Required Connection Minutes
   - Maximum Attendance Count
3. Tap **Start Session**.
4. The session dashboard opens with the session PIN, QR code, and live attendance stats.

## Student Registration
1. Students scan the QR code displayed on the lecturer dashboard.
2. The QR code directs them to the registration page.
3. Students enter their Matricule, Full Name, and Email, then tap **Register Attendance**.
4. The camera opens automatically — students position their face inside the oval guide and tap the capture button.
5. The app verifies that exactly one face is visible, checks it against all faces already registered in the session, and rejects registration if a match is found (proxy detection).
6. If the face is unique, attendance is saved and location is collected for verification.

## Monitoring Attendance
- The **session dashboard** shows:
  - Total registered students
  - Verified attendees
  - Pending attendees
  - Wi-Fi device count
  - Attendance coverage percentage
- Use the search field to find a student by name or matricule.
- Tap the remove icon to remove a student from the current session.

## Manual Student Entry
1. Open the dashboard menu.
2. Choose **Add Manual Student**.
3. Enter the student name, matricule, and optional email.
4. Manual entries are included in reports but marked separately.

## Ending a Session
1. Open the dashboard menu.
2. Select **End Session**.
3. Confirm the action.
4. The app generates a session report and saves it to device storage.

## Generating Reports
- Use the **Share PDF Report** button to share the attendance report.
- Use **Download PDF to Device** to save it locally.
- In online mode, attendance data is also stored in the cloud for lecturer analysis.

## Offline vs Online Mode
- **Offline Mode** uses local hotspot and stores attendance data locally.
- **Online Mode** syncs attendance data to the cloud and enables remote reporting.
- The app requires geolocation in both modes for accurate validation.

## Security Features
- **Facial recognition** prevents proxy registration: one physical face can only appear once per session. If a student tries to register under a second name with the same face, the app blocks it and shows who is already registered with that face.
- Face photos are processed on-device and immediately deleted; only a compact mathematical descriptor is held in memory for the duration of the session and cleared when the session ends.
- Signature verification prevents students from using multiple devices to sign in for others.
- Location verification ensures attendance is recorded only from valid locations.
- Device fingerprinting blocks the same phone from being used twice in one session.
- QR code registration links directly to the root attendance page.

## Troubleshooting
- If the QR code does not open, verify the hotspot server is running and the device is on the same network.
- If location access is denied, enable location services in device settings and relaunch the app.
- If report generation fails, ensure storage permission is granted.
- If the camera does not open during registration, grant Camera permission in the device Settings app and try again.
- If face detection returns "No face detected", ensure the student's face is well-lit and centred in the oval guide before tapping capture.
- If a legitimate student is incorrectly flagged as a duplicate, the lecturer can remove the existing record from the dashboard and ask the student to re-register.

## Tips for Lecturers
- Start the session before students arrive.
- Make sure the QR code is visible to all students.
- Encourage students to keep location services enabled during registration.
- Download or share the report immediately after ending the session.
