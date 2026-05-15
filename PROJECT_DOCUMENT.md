# OwHAS — Offline Wi-Fi Hotspot Attendance System
## Final Year Project — Full Technical Documentation

---

## Table of Contents

1. [Abstract](#1-abstract)
2. [Introduction](#2-introduction)
3. [Problem Statement](#3-problem-statement)
4. [Objectives](#4-objectives)
5. [System Architecture](#5-system-architecture)
6. [Technology Stack](#6-technology-stack)
7. [System Components](#7-system-components)
8. [Application Screens & User Flows](#8-application-screens--user-flows)
9. [Session Modes](#9-session-modes)
10. [Data Models](#10-data-models)
11. [Security Design](#11-security-design)
12. [Face Recognition & Anti-Proxy System](#12-face-recognition--anti-proxy-system)
13. [Cloud Integration](#13-cloud-integration)
14. [Report Generation](#14-report-generation)
15. [Navigation & Routing](#15-navigation--routing)
16. [Deployment Options](#16-deployment-options)
17. [Limitations & Difficulties](#17-limitations--difficulties)
18. [Future Work](#18-future-work)
19. [Conclusion](#19-conclusion)

---

## 1. Abstract

OwHAS (Offline Wi-Fi Hotspot Attendance System) is a cross-platform mobile
application built with Flutter that enables lecturers to manage student
attendance digitally without requiring a permanent internet connection.
The system leverages the lecturer's device as a Wi-Fi hotspot, creating a
local area network (LAN) over which a Node.js server runs and hosts a web
registration page. Students connect to this hotspot and submit their
attendance through a browser — no app installation required on the student
side.

The system supports three operational modes: fully offline (hotspot), fully
online (cloud server), and hybrid (both simultaneously). It incorporates
face recognition for anti-proxy detection, a 4-digit PIN for session
authentication, GPS-based geolocation verification for online sessions,
digital signature capture, Firebase cloud backup, cumulative attendance
tracking across multiple sessions, and automated PDF and Excel report
generation.

---

## 2. Introduction

Traditional attendance management in educational institutions relies on
paper-based sign-in sheets, manual roll calls, or centralized software
systems that depend on institutional internet infrastructure. These methods
suffer from a common set of problems: they are slow, prone to proxy
attendance (one student signing in for another), easily forged, difficult to
archive, and completely non-functional when internet access is unavailable.

OwHAS addresses all of these issues with a self-contained, offline-first
design. The system runs its own local server on the lecturer's PC — the same
PC whose mobile hotspot the students are required to join. This approach
means:

- No institutional Wi-Fi or internet is needed.
- Being on the hotspot proves physical proximity to the classroom.
- The entire session, including registration, verification, and reporting,
  is completed within the lecturer's controlled local network.
- If internet is available, the same system extends to cloud deployment for
  remote or hybrid learning scenarios.

---

## 3. Problem Statement

Attendance management in higher education faces several persistent challenges:

**Proxy Attendance:** Students signing in on behalf of absent classmates is
a widespread issue that paper sheets and simple digital forms cannot prevent.

**Infrastructure Dependency:** Web-based attendance systems require reliable
internet or intranet access. Many lecture halls and fieldwork locations lack
stable connectivity.

**Data Loss:** Paper sheets are easily lost or damaged. Locally stored digital
data is lost if the device fails without a backup.

**Manual Processing:** Converting raw sign-in data into meaningful attendance
reports (presence percentages, cumulative totals across sessions) requires
significant manual effort.

**Scalability:** A system that works for 20 students must also work for 200
without performance degradation.

OwHAS directly addresses each of these problems through its architecture:
LAN proximity enforcement replaces trust-based sign-in, face recognition
prevents proxy attendance, offline-first design removes infrastructure
dependency, Firebase cloud backup prevents data loss, and automated PDF/Excel
generation eliminates manual report work.

---

## 4. Objectives

### Primary Objectives

1. Design and implement a mobile attendance system that operates without
   internet connectivity, using the lecturer's device hotspot as the network.
2. Prevent proxy attendance through device fingerprinting and facial
   recognition at the point of registration.
3. Generate complete, formatted attendance reports (PDF and Excel) immediately
   at the end of each session.
4. Maintain cumulative attendance records across multiple sessions for the
   same course.

### Secondary Objectives

5. Extend the offline system to cloud deployment for online and hybrid
   classroom scenarios.
6. Integrate GPS geolocation verification for online sessions to replace the
   physical proximity enforcement that the hotspot provides offline.
7. Provide a digital signature mechanism for formal record authentication.
8. Allow lecturers to manage their course catalogue and auto-fill session
   details without re-entering them each time.
9. Persist the lecturer's identity (name) across sessions to avoid repeated
   manual entry.

---

## 5. System Architecture

### 5a. High-Level Overview

```
┌────────────────────────────────────────────────────────────────────┐
│                        OFFLINE MODE                                │
│                                                                    │
│   Lecturer's Phone (Flutter App)                                   │
│   ┌────────────────────┐    HTTP      ┌────────────────────────┐  │
│   │  AttendanceProvider│ ──────────►  │  Node.js Server        │  │
│   │  SessionService    │ ◄──────────  │  (Lecturer's PC)       │  │
│   │  StorageService    │             │  Port 5501             │  │
│   └────────────────────┘             └──────────┬─────────────┘  │
│                                                  │                 │
│                                     ┌────────────▼──────────────┐ │
│                                     │  hotspot.html             │ │
│                                     │  (Student browser page)   │ │
│                                     │  Served over LAN          │ │
│                                     └───────────────────────────┘ │
│                            STUDENTS CONNECT TO HOTSPOT            │
└────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│                        ONLINE MODE                                 │
│                                                                    │
│   Lecturer's Phone (Flutter App)                                   │
│   ┌────────────────────┐   HTTPS     ┌────────────────────────┐   │
│   │  AttendanceProvider│ ──────────► │  Cloud Server          │   │
│   │  SessionService    │ ◄────────── │  (owhas.org)           │   │
│   └────────────────────┘            └──────────┬─────────────┘   │
│                                                 │                  │
│                                    ┌────────────▼──────────────┐  │
│                                    │  hotspot.html (cloud)     │  │
│                                    │  + GPS validation         │  │
│                                    │  Any internet connection  │  │
│                                    └───────────────────────────┘  │
│                    STUDENTS CONNECT VIA ANY INTERNET              │
└────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│                    CLOUD BACKUP (BOTH MODES)                       │
│                                                                    │
│   SessionService ──────► Firebase Firestore (sessions, records)   │
│   (on session end)                                                 │
│   CloudService   ──────► Firebase Auth (lecturer accounts)        │
│   (if signed in)                                                   │
└────────────────────────────────────────────────────────────────────┘
```

### 5b. Component Separation

| Component | Platform | Role |
|---|---|---|
| Flutter mobile app | Android / iOS | Lecturer-side UI, local state, reporting |
| Node.js server | Windows PC (local) / Cloud | Receives student registrations, serves hotspot.html |
| hotspot.html | Browser (any device) | Student-facing registration page — no app needed |
| Firebase Firestore | Cloud | Session backup and cross-device sync |
| Firebase Auth | Cloud | Lecturer account authentication |

---

## 6. Technology Stack

### Mobile Application

| Technology | Version | Purpose |
|---|---|---|
| Flutter | SDK ^3.6.0 | Cross-platform UI framework |
| Dart | ^3.6.0 | Programming language |
| Provider | ^6.1.2 | State management |
| GoRouter | ^16.2.0 | Declarative navigation |
| SharedPreferences | ^2.5.3 | Local persistent storage (sessions, students) |
| http | ^0.13.0 | HTTP client for server communication |
| qr_flutter | ^4.1.0 | QR code generation |
| pdf | ^3.10.8 | PDF report generation |
| printing | ^5.13.3 | PDF share and print |
| excel | ^4.0.6 | Excel report generation |
| file_picker | ^10.3.10 | Import previous session PDF/Excel |
| share_plus | ^10.0.0 | Native file share dialog |
| path_provider | ^2.1.5 | Device file system access |
| camera | ^0.11.0 | Face capture |
| google_mlkit_face_detection | ^0.11.0 | On-device face detection |
| image | ^4.2.0 | Image processing for face descriptors |
| geolocator | ^13.0.0 | GPS positioning (online mode) |
| geocoding | ^3.0.0 | Reverse geocoding |
| network_discovery | ^1.0.0 | LAN subnet scan for server detection |
| device_info_plus | ^12.3.0 | Device fingerprinting |
| firebase_core | ^3.0.0 | Firebase initialization |
| cloud_firestore | ^5.0.0 | Cloud database |
| firebase_auth | ^5.0.0 | Cloud authentication |
| firebase_storage | ^12.0.0 | Cloud file storage |
| google_fonts | ^4.0.4 | Typography |
| uuid | ^4.5.3 | Unique ID generation |
| intl | ^0.20.2 | Date and number formatting |
| crypto | (transitive) | Signature hashing |

### Backend Server

| Technology | Version | Purpose |
|---|---|---|
| Node.js | ≥18 | Server runtime |
| Express.js | ^4 | HTTP server framework |
| multer | — | Multipart file upload (PDF import) |
| pdf-parse | — | Extract text from uploaded PDFs |
| express-rate-limit | — | PIN brute-force protection |
| face-api.js | 0.22.2 | Face recognition in the browser (hotspot.html) |

### Student Side (hotspot.html)

| Technology | Purpose |
|---|---|
| Vanilla HTML/CSS/JS | Student registration UI |
| face-api.js (TinyFaceDetector) | Face capture and descriptor extraction |
| navigator.geolocation | GPS position for online mode |
| Fetch API | Submit registration to server |

### Cloud

| Service | Purpose |
|---|---|
| Firebase Firestore | Session and attendance record storage |
| Firebase Authentication | Email/password login for lecturers |
| Firebase Storage | Signature and file backup |

---

## 7. System Components

### 7a. Flutter Application — Layer Structure

```
lib/
├── main.dart              Entry point — initialises ServerConfig, CloudService, CourseService
├── nav.dart               GoRouter configuration, all route paths
├── theme.dart             Light/dark theme, spacing constants, text style extensions
│
├── models/                Pure data classes
│   ├── session.dart       AttendanceSession — all session metadata
│   ├── attendance_record.dart  AttendanceRecord — one student's attendance
│   ├── student.dart       Student entity
│   ├── semester.dart      Semester with == / hashCode for picker
│   └── catalogue_course.dart  CatalogueCourse with == / hashCode
│
├── providers/
│   └── attendance_provider.dart  Central ChangeNotifier — all UI-facing state
│
├── controllers/           Thin orchestration layer over services
│   ├── session_controller.dart
│   ├── report_controller.dart
│   └── network_controller.dart
│
├── services/              Business logic and I/O
│   ├── session_service.dart      PIN generation, session lifecycle, server init
│   ├── storage_service.dart      SharedPreferences CRUD for sessions, records, students
│   ├── api_service.dart          HTTP calls to the Node.js server
│   ├── server_config.dart        Auto-detect LAN/online server, isOnline flag
│   ├── course_service.dart       Load/save semesters and courses (catalogue)
│   ├── signature_service.dart    Save/load lecturer signature and name
│   ├── face_recognition_service.dart  Face descriptor storage, duplicate detection
│   ├── pdf_service.dart          Generate PDF attendance report
│   ├── excel_service.dart        Generate Excel report, parse uploaded files
│   ├── file_service.dart         Save and share files via native dialogs
│   ├── network_discovery_service.dart  Subnet scan for active hotspot devices
│   ├── cloud_service.dart        Firebase Auth + Firestore sync
│   ├── location_service.dart     GPS collection wrapper
│   └── device_service.dart       Device fingerprint generation
│
├── pages/                 Full-screen views
│   ├── home_page.dart             Role selection (Lecturer / Student)
│   ├── session_setup_page.dart    Create session form
│   ├── lecturer_dashboard_page.dart  Live session view, QR, attendee list
│   ├── student_registration_page.dart  3-step PIN → details → face flow
│   ├── course_catalogue_page.dart  Manage semesters and courses
│   ├── signature_setup_page.dart  Draw and save digital signature
│   ├── cloud_login_page.dart      Firebase email/password sign-in
│   ├── cloud_sessions_page.dart   View synced sessions from cloud
│   └── face_capture_page.dart     Camera view for face capture
│
├── widgets/dashboard/     Reusable dashboard sub-widgets
│   ├── session_header.dart        PIN card, timer, stats chips
│   ├── qr_code_section.dart       QR code + online hint
│   ├── attendance_records_section.dart  Attendee list
│   ├── attendance_record_tile.dart  Individual student tile
│   └── compact_stat_chip.dart     Stat badge (total / verified / pending)
│
└── utils/
    └── dialog_helpers.dart    Shared dialog builders
```

### 7b. Node.js Backend — Key Endpoints

| Method | Endpoint | Purpose | Auth |
|---|---|---|---|
| GET | `/ping` | Health check | None |
| GET | `/public/hotspot.html` | Student registration page | None |
| POST | `/api/session-init` | Create session with PIN | (internal) |
| POST | `/api/end-session` | Deactivate PIN | (internal) |
| GET | `/api/attendees?pin=` | List all attendees | PIN |
| GET | `/api/stats?pin=` | Total / verified / pending counts | PIN |
| POST | `/api/validate-pin` | Check PIN validity | Rate-limited |
| POST | `/api/biometric-connect` | Student registration + GPS check | PIN + Rate-limited |
| POST | `/connect` | Alternative student connect endpoint | PIN |
| GET | `/export?pin=` | Download attendance PDF | PIN |
| POST | `/api/reset` | Clear session attendee list | (internal) |
| POST | `/api/session-config` | Push grace period and connection time | (internal) |
| POST | `/api/remove-attendee` | Remove a student from session | PIN |
| GET | `/api/qr-url` | Get dynamic QR URL for current IP | None |
| POST | `/api/parse-pdf` | Extract student data from uploaded PDF | None |
| POST | `/api/generate-pdf` | Generate formatted attendance PDF | PIN |
| POST | `/api/merge-session` | Merge offline + online records (hybrid) | PIN |

### 7c. hotspot.html — Student Registration Page

The student-facing page is a single HTML file served by the Node.js server.
It requires no installation and works in any modern mobile browser.

**Offline mode flow:**
1. Student joins the lecturer's Wi-Fi hotspot.
2. Opens a browser and scans the QR code (or types the server IP).
3. Enters the 4-digit PIN displayed on the lecturer's dashboard.
4. The server validates the PIN and loads the session details.
5. Student fills in: Matricule, Full Name, Email.
6. Camera opens for face capture (face-api.js TinyFaceDetector).
7. A 128-dimension face descriptor is computed and sent to the server.
8. The server checks the descriptor against all previously submitted faces
   (Euclidean distance < 0.6 = duplicate → rejected).
9. On success, the attendance record is created on the server and the page
   shows a confirmation.

**Online mode flow (additional step):**
- Before showing the form, the page requests GPS from the browser.
- The form is hidden until GPS permission is granted.
- GPS coordinates are submitted with the registration.
- The server computes the Haversine distance from the lecturer's location.
- If the student is outside the configured radius, the request is rejected
  with a distance error message.
- GPS coordinates are validated and then discarded — they are never stored
  in the attendance record.

---

## 8. Application Screens & User Flows

### 8a. Home Page (`/`)

The app opens on a role selection screen with an animated Wi-Fi radar icon
and two role cards:

- **Lecturer** → If no active session: go to Session Setup.
  If active session exists: dialog asks whether to resume or create new.
- **Student** → Go to Student Registration page.

A "View Course Catalogue" link provides quick access to course management
without entering the lecturer flow.

### 8b. Session Setup Page (`/setup`)

The lecturer configures all session parameters here:

1. **Upload Previous Session (optional):** Import a previous session's PDF or
   Excel file. The system parses student cumulative totals and automatically
   increments the session number.
2. **Lecturer Name:** Pre-filled from the last session (saved in
   SharedPreferences). Changes are saved when the lecturer taps away from
   the field. A clear (✕) button removes the saved name.
3. **Semester Picker:** Tap-to-open `SimpleDialog` listing all configured
   semesters. Active semester is highlighted.
4. **Course Picker:** After selecting a semester, courses for that semester
   are listed. Selecting a course auto-fills Course Name and Course Code.
5. **Course Name and Course Code:** Editable overrides — populated
   automatically from the catalogue but can be changed manually.
6. **Session Duration:** Total time (minutes) the session stays open.
7. **Grace Period:** Late-arrival window (minutes). Must be less than
   Session Duration.
8. **Required Connection Time:** Minimum minutes a student must stay
   connected to be marked Verified.
9. **Maximum Attendance Count:** Total number of sessions used to compute
   presence percentage.

On "Start Session," the app:
- Validates all fields.
- Checks that Grace Period < Session Duration.
- Generates a 4-digit PIN (`1000 + secureRandom.nextInt(9000)`).
- Generates a 32-byte base64url session token for QR fallback.
- Captures GPS if in online mode.
- Calls `POST /api/session-init` to register the session on the server.
- Saves the session to SharedPreferences.
- Navigates to the Lecturer Dashboard.

### 8c. Lecturer Dashboard (`/dashboard`)

The live session control centre. Updates every 5 seconds via `Timer.periodic`.

**Session Header:** Displays the course name, course code, session end time,
a countdown chip, the PIN in a large bold card with a "Tap to copy" shortcut,
and three stats chips (Total / Verified / Pending).

**Server Warning Banner:** Orange strip shown when the server is unreachable.
Contains the specific error message and a Retry button.

**QR Code Section:** The QR code encodes the full URL to `hotspot.html`
including the session token. Below the QR image, a hint reads
"For ONLINE type OWHAS.ORG".

**Attendance Records:** A scrollable list of all registered students with
their name, matricule, join time, connection duration, and verified status.
The lecturer can remove any student by long-pressing their tile.

**App Bar Actions:**
- Refresh
- Share Report (generates PDF and opens native share dialog)
- Download PDF (saves to device storage)
- More menu (⋮): Digital Signature, Add Manual Student, End Session

### 8d. Student Registration Page (`/register`)

A 3-step glassmorphism card with animated step indicators:

**Step 1 — Enter Session PIN:**
- 4-digit numeric field with `LengthLimitingTextInputFormatter(4)`.
- Tapping "Verify PIN" checks the PIN against both the cloud/LAN server and
  the local session PIN stored in the provider.
- Animated status badge shows: Verifying → PIN Verified! (green) or
  Invalid PIN (red).
- After 700 ms success delay, automatically advances to Step 2.

**Step 2 — Personal Details:**
- Matricule, Full Name, Email (all required, email format validated).
- Back button returns to PIN step.

**Step 3 — Face Verification:**
- Opens the device camera via `FaceCapturePage`.
- On return, checks the face descriptor against all previously registered
  faces in this session (proxy detection).
- If duplicate face detected: shows the existing student's name and blocks
  registration.
- If no duplicate: registers student locally and on the server.
- On success: animated green success dialog auto-dismisses after 2 seconds
  and resets the form for the next student.

### 8e. Course Catalogue Page (`/catalogue`)

Manage the institution's course catalogue:
- **Semesters:** Add, edit, mark as active.
- **Courses:** Add, edit, delete courses. Each course has a Name, Code,
  Department, and Credits. Courses are linked to a semester.
- Back button uses `context.canPop() ? pop() : go('/')` so it correctly
  returns to the page that opened it (Session Setup or Home).

### 8f. Signature Setup Page (`/signature`)

- A drawing canvas (`SignaturePad` widget) where the lecturer draws their
  signature with a stylus or finger.
- The signature is saved as PNG bytes in SharedPreferences (base64-encoded).
- Loaded automatically and embedded in every generated PDF report.
- The lecturer's name is also saved here and used as the report header.

### 8g. Cloud Login Page (`/cloud-login`)

- Firebase email/password sign-in and registration.
- After signing in, sessions are automatically synced to Firestore.
- Cloud Sessions page (`/cloud-sessions`) shows all historically synced
  sessions with download and export options.

---

## 9. Session Modes

### 9a. Offline Mode (Hotspot)

- The lecturer's PC runs `node server.js` on port 5501.
- The phone connects to the PC's Mobile Hotspot.
- `ServerConfig.detect()` finds the server at `192.168.137.1:5501`
  (Windows) or `192.168.43.1:5501` (Android) within 800 ms.
- `ServerConfig.isOnline = false`.
- Students must join the same hotspot — physical presence enforced by LAN.
- No GPS required.
- QR code URL: `http://192.168.137.1:5501/public/hotspot.html?s=<token>`

### 9b. Online Mode (Cloud)

- No local server is running.
- `ServerConfig.detect()` finds no local IP; falls through to `owhas.org`.
- `ServerConfig.isOnline = true`.
- Students can join from any internet connection anywhere.
- GPS geolocation is mandatory:
  - Lecturer's GPS captured once at session creation.
  - Student's GPS captured in the browser before the form is shown.
  - Haversine distance checked server-side; if > `maxRadiusMeters`, rejected.
  - GPS coordinates discarded after validation.
- QR code URL: `https://owhas.org/hotspot.html?pin=XXXX`
- Requires HTTPS (enforced by cloud platform) for camera and GPS APIs.

### 9c. Hybrid Mode (Both Simultaneously)

- Both local server and cloud are running under the same PIN.
- `ServerConfig.detect()` picks the local server first (faster response).
- Hotspot students register locally; remote students register on the cloud.
- At "End Session":
  1. App queries LAN server for offline attendees.
  2. App queries cloud for online attendees.
  3. Merges by matricule (online record wins ties — it has GPS validation).
  4. Pushes merged list to cloud as canonical record.
  5. Closes both servers.
  6. Exports a single unified PDF/Excel with a `Source` column
     (offline / online). No GPS data appears in the export.

---

## 10. Data Models

### AttendanceSession

| Field | Type | Description |
|---|---|---|
| id | String (UUID) | Unique session identifier |
| courseName | String | Full course name |
| courseCode | String? | Course code (e.g., CS2560) |
| lecturerId | String | Device identifier of the lecturer |
| lecturerName | String? | Lecturer's display name |
| sessionPin | String? | 4-digit PIN for web registration |
| sessionToken | String? | 32-byte base64url QR token |
| startTime | DateTime | Session creation timestamp |
| endTime | DateTime? | Session end timestamp |
| durationMinutes | int | Total session length |
| gracePeriodMinutes | int | Late-arrival tolerance |
| requiredConnectionMinutes | int | Minimum stay for Verified status |
| maxAttendanceCount | int | Total sessions (for % calculation) |
| sessionNumber | int | This session's sequential number |
| isActive | bool | Whether the session is still open |
| createdAt | DateTime | — |
| updatedAt | DateTime | — |

### AttendanceRecord

| Field | Type | Description |
|---|---|---|
| id | String (UUID) | Unique record identifier |
| sessionId | String | Links to AttendanceSession.id |
| studentId | String | Links to Student.id |
| matricule | String | Student matricule number |
| studentName | String | Student full name |
| email | String? | Student email |
| joinedAt | DateTime | Timestamp of registration |
| verifiedAt | DateTime? | When connection time threshold was met |
| connectionDurationMinutes | int | Minutes since joining |
| isVerified | bool | Whether required connection time was met |
| isManual | bool | True if added by lecturer manually |
| deviceFingerprint | String | Device identifier for duplicate detection |
| location | AttendanceLocation? | GPS coords at registration time |
| createdAt | DateTime | — |
| updatedAt | DateTime | — |

### Student

| Field | Type | Description |
|---|---|---|
| id | String (UUID) | Unique student identifier |
| matricule | String | Student matricule (unique per session) |
| name | String | Full name |
| email | String? | Email address |
| deviceFingerprint | String | Device identifier |
| createdAt | DateTime | — |
| updatedAt | DateTime | — |

### Semester

| Field | Type | Description |
|---|---|---|
| id | String | Unique semester identifier |
| label | String | Display name (e.g., "SUMMER – 2025/26") |
| isActive | bool | Whether this is the current semester |

### CatalogueCourse

| Field | Type | Description |
|---|---|---|
| id | String | Unique course identifier |
| semesterId | String | Links to Semester.id |
| name | String | Course full name |
| code | String | Course code (e.g., CS2560) |
| department | String? | Department name |
| credits | int? | Credit hours |

---

## 11. Security Design

### 11a. PIN Authentication

- Sessions are identified by a 4-digit numeric PIN (1000–9999).
- Generated using `Random.secure()` — cryptographically random.
- Rate-limited: maximum 10 attempts per IP per 5-minute window
  (enforced by `express-rate-limit` on `/api/validate-pin` and
  `/api/biometric-connect`).
- The PIN is displayed only on the lecturer's device screen and optionally
  printed on a poster QR code.
- After session ends, the PIN is deactivated on the server immediately.

### 11b. Device Fingerprinting

- Each attending student's device generates a fingerprint from hardware
  identifiers (via `device_info_plus`).
- A fingerprint already present in the session's attendance records blocks
  a second registration from the same device.
- This prevents a single student from submitting twice and prevents sharing
  a device to register multiple people.

### 11c. Face Recognition (Anti-Proxy)

- When registering on the lecturer's device (app-side flow), the student's
  face is captured using the device camera.
- Google ML Kit detects the face and extracts a 128-dimension descriptor
  vector.
- The descriptor is compared against all faces already stored in the
  current session using Euclidean distance.
- Distance < 0.6 = duplicate face detected → registration blocked with the
  existing student's name shown.
- Face descriptors are stored in-memory only for the session duration.
  They are cleared when the session ends and are never written to disk or
  uploaded.

### 11d. GPS Geolocation (Online Mode)

- Used only in online mode as a substitute for the hotspot proximity
  requirement.
- The lecturer's GPS coordinates are captured once at session creation and
  sent to the cloud server.
- Students must grant GPS permission in their browser before the form
  appears.
- The server computes the Haversine distance between lecturer and student.
- Students outside the configured radius (default 200 m) are rejected.
- GPS coordinates are used for validation only and are discarded after
  the check — they do not appear in any stored record or exported file.

### 11e. LAN Proximity (Offline Mode)

- The lecturer controls the Wi-Fi hotspot.
- Only devices physically connected to the hotspot can reach the server.
- Being on the network proves physical presence without any additional check.

### 11f. Payload and Input Validation

- JSON body size limited to 10 KB on the server to prevent large-payload
  attacks.
- PIN format validated server-side with regex `^\d{4}$`.
- All student input is sanitised before storage.
- CORS is open (`*`) on the local server (acceptable for a closed LAN);
  should be restricted to the specific origin in cloud deployment.

---

## 12. Face Recognition & Anti-Proxy System

### 12a. Technology

The browser-side face recognition uses **face-api.js** (version 0.22.2):
- `TinyFaceDetector` — a lightweight model optimised for mobile browsers.
- `FaceLandmark68Net` — detects 68 facial landmarks.
- `FaceRecognitionNet` — produces the 128-dimension descriptor vector.

The app-side (Flutter) face detection uses **Google ML Kit Face Detection**:
- Processes the camera frame and extracts facial geometry.
- The descriptor is computed from the cropped face region using the `image`
  package.

### 12b. Duplicate Detection Algorithm

```
For each new student face descriptor D_new:
  For each stored descriptor D_existing in session:
    distance = sqrt( sum( (D_new[i] - D_existing[i])^2 ) )  [Euclidean]
    if distance < 0.6:
      → Reject: "This face is already registered under [name]"
  If no match found:
    → Accept and store D_new
```

The threshold 0.6 is the standard value recommended by face-api.js.
Values below 0.6 are considered the same person.

### 12c. Known Limitations

- Identical twins may not be distinguished (faces too similar).
- Extreme lighting conditions, head-covering (hijab, cap), or glasses can
  reduce accuracy.
- Photo spoofing (holding a printed photo in front of the camera) is a
  risk — liveness detection is not yet implemented.
- Face descriptors are session-scoped in-memory — no cross-session face
  database is maintained.

---

## 13. Cloud Integration

### 13a. Firebase Services Used

- **Firebase Authentication:** Email/password accounts for lecturers.
- **Cloud Firestore:** Stores session metadata and attendance records in a
  structured document database.
- **Firebase Storage:** Stores lecturer signatures and large file attachments.

### 13b. Sync Behaviour

- Cloud sync is **optional** — the app works fully offline without a
  Firebase account.
- If the lecturer is signed in (`CloudService.isSignedIn = true`), sessions
  and records are synced to Firestore automatically:
  - When a new session is created.
  - When a student registers.
  - At the end of a session (full sync).
- If the sync fails (e.g., internet is off), it is silently ignored —
  the local data is the source of truth.

### 13c. Cloud Sessions Page

Lecturers who are signed in can view all their historical sessions from any
device via the Cloud Sessions page. Sessions are listed with their date,
course, and attendance totals, and can be exported as PDF or Excel.

---

## 14. Report Generation

### 14a. PDF Report

Generated using the `pdf` package (Dart-native, no external service needed).

**Report contents:**
- Institution / course header
- Lecturer name and digital signature
- Session date, duration, and session number
- Table with: #, Name, Matricule, Join Time, Connection Duration, Status
  (Verified / Pending / Manual)
- Cumulative attendance column (if previous session data was uploaded)
- Presence percentage per student
- Session statistics summary

**Two export methods:**
1. `generateAndSharePDFReport()` — generates in-memory and opens the
   native share dialog (WhatsApp, email, Drive, etc.)
2. `downloadPDFReport()` — saves to the device's Downloads folder and
   shows the file path in a SnackBar.

### 14b. Excel Report

Generated using the `excel` package. Contains the same data as the PDF in
a machine-readable spreadsheet format, suitable for import into institutional
systems.

### 14c. Cumulative Tracking

- When setting up a new session, the lecturer can upload the PDF or Excel
  from the previous session.
- The app parses the file (via the Node.js `/api/parse-pdf` endpoint for
  PDFs, or directly in Dart for Excel).
- Cumulative presence totals are extracted and stored in `_previousAttendance`
  (a `Map<String, int>` keyed by matricule).
- The session number is auto-incremented from the parsed previous number.
- The new report adds the current session to each student's cumulative count.

---

## 15. Navigation & Routing

The app uses **GoRouter** (version ^16.2.0) with `NoTransitionPage` on all
routes for instant navigation without slide animations.

| Route | Page | Who uses it |
|---|---|---|
| `/` | HomePage | Everyone — role selection |
| `/setup` | SessionSetupPage | Lecturer — configure and start session |
| `/dashboard` | LecturerDashboardPage | Lecturer — live session management |
| `/register` | StudentRegistrationPage | Student — 3-step attendance registration |
| `/signature` | SignatureSetupPage | Lecturer — draw and save digital signature |
| `/catalogue` | CourseCataloguePage | Lecturer — manage semesters and courses |
| `/cloud-login` | CloudLoginPage | Lecturer — Firebase sign in/register |
| `/cloud-sessions` | CloudSessionsPage | Lecturer — view historical cloud sessions |

**Navigation rules:**
- `context.go(path)` — replaces the stack (used for main-level navigation).
- `context.push(path)` — adds to the stack (used for Catalogue so back works).
- `context.canPop() ? pop() : go('/')` — safe back navigation with fallback.
- The dashboard has `PopScope(canPop: false)` — prevents accidental back-press
  from ending a live session.

---

## 16. Deployment Options

### Option 1 — Offline Only (Default)

No deployment needed. The lecturer:
1. Runs `node server.js` on their PC.
2. Enables the PC's Mobile Hotspot.
3. Opens the Flutter app on their phone.
4. The app auto-detects the server and is ready in < 2 seconds.

### Option 2 — Cloudflare Tunnel (5 minutes, free)

Keep the local server but expose it to the internet through a Cloudflare
HTTPS tunnel. Useful for occasional remote students.

```bat
cloudflared tunnel --url http://localhost:5501
```

Cloudflare prints a temporary HTTPS URL. Use it as the student URL. The
tunnel dies when the terminal is closed.

### Option 3 — Render.com (Permanent Free Cloud)

Deploy the `backend/` folder to Render.com. Students can connect from anywhere
without any hotspot setup.

Configuration:
- Root Directory: `backend`
- Build Command: `npm install`
- Start Command: `node server.js`
- Environment Variable: `NODE_ENV=production`

**Changes required for cloud deployment:**
- Load face-api.js models from CDN instead of local disk.
- Wrap local-network-only code (DNS server, mDNS, HTTP-80 redirect) in
  `if (process.env.NODE_ENV !== 'production')`.

### Option 4 — VPS with HTTPS (Full Control, ~$5/month)

DigitalOcean, Linode, or Hetzner with Caddy as a reverse proxy:
```
owhas.yourdomain.com {
    reverse_proxy localhost:5501
}
```
Caddy automatically provisions a Let's Encrypt SSL certificate.
Use PM2 to keep the server running after logout.

---

## 17. Limitations & Difficulties

### Network & Connectivity

- The Windows Mobile Hotspot has a limit of approximately 8 simultaneous
  connected devices. For large classes (> 100 students), a dedicated Wi-Fi
  router is strongly recommended.
- Some institutional IT policies block personal hotspots or restrict device
  association with unofficial access points.
- The app scans 762 IP addresses in parallel to find the server.  On slow
  networks this can take up to 3 seconds.
- iOS devices use a different hotspot gateway IP (`172.20.10.1`) which
  requires special handling.

### Face Recognition Accuracy

- Indoor GPS accuracy varies from 10 to 50 metres; `maxRadiusMeters` should
  be set to at least 150 m for classroom buildings.
- Photo-based spoofing (holding a photograph) bypasses face recognition
  without liveness detection.
- Twins and students with very similar facial structure may register as
  duplicates or bypass the proxy check.
- Low-quality front cameras (< 2 MP) produce noisy descriptors, increasing
  false positive rates.

### PIN Security

- A 4-digit PIN has only 9,000 possible values (1000–9999).
- Rate-limiting (10 attempts / 5 min) reduces practical brute-force
  probability but does not eliminate it entirely.
- The PIN should never be shared publicly; it is meant to be displayed
  only to students present in the room.

### Data Persistence

- The Node.js server uses an in-memory `Map` for sessions; sessions are
  written to `sessions.json` after each change for crash recovery.
- On Render.com free tier, the server sleeps after 15 minutes of inactivity
  and the ephemeral filesystem does not persist between restarts. A database
  solution (SQLite or PostgreSQL) is required for production reliability.

### Privacy & Legal

- Face recognition data constitutes biometric data under GDPR Article 9
  (sensitive personal data). Processing requires explicit informed consent
  from each student.
- GPS coordinates are used only as a validation gate and are not stored —
  this design choice was deliberately made to minimise privacy risk.
- Lecturers must inform students that the app collects facial and device
  data at the point of registration.

---

## 18. Future Work

1. **Liveness Detection:** Add blink or head-turn challenge to prevent
   photo spoofing during face capture.
2. **NFC Check-in:** Use NFC student ID cards as an alternative to face
   capture for institutions that issue NFC-enabled cards.
3. **Multi-Lecturer Support:** Allow multiple lecturers to share a cloud
   session with different roles (moderator / observer).
4. **Automated Report Delivery:** Email the PDF report to the department
   automatically at session end using a configured SMTP server.
5. **Dashboard Analytics:** Add charts showing attendance trends across
   all sessions for a course (line graph of weekly presence %).
6. **Database Migration:** Replace `sessions.json` with SQLite for the
   local server and PostgreSQL for the cloud server.
7. **API Key Authentication:** Protect lecturer-only server endpoints
   with a secret header to prevent unauthorised session creation from
   the internet.
8. **SMS Notification:** Send students a confirmation SMS when their
   attendance is verified using Twilio or an equivalent gateway.
9. **Tablet Layout:** Optimise the UI for tablet screen sizes with a
   two-column dashboard layout.
10. **Windows/macOS Desktop App:** Package the Flutter app as a desktop
    application so the lecturer can run both the server and the app from
    the same machine.

---

## 19. Conclusion

OwHAS demonstrates that a production-quality attendance management system
can be built without dependency on institutional infrastructure. The
offline-first design, where the lecturer's own Wi-Fi hotspot serves as both
the network and the proximity enforcement mechanism, solves the internet
dependency problem at its root rather than working around it.

The three-mode architecture (offline, online, hybrid) and the merge-at-end
strategy allow the same codebase and workflow to serve rural classrooms with
no connectivity, urban lecture halls with stable internet, and blended
learning scenarios where some students are remote.

The anti-proxy layer — combining device fingerprinting, face recognition,
and (in online mode) GPS geolocation — addresses the most persistent
challenge in digital attendance systems: verifying that the person who
registered is the person who was present.

The project was built entirely with open-source and free-tier tools,
making it immediately deployable by any educational institution at zero
infrastructure cost.

---

*Document prepared for Final Year Project submission.*
*System name: OwHAS — Offline Wi-Fi Hotspot Attendance System*
*Developer: FODOPTACHEKAM*
*Platform: Flutter (Android / iOS) + Node.js*
*Version: 1.0.0*
