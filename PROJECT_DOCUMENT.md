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
8. [Application Screens and User Flows](#8-application-screens-and-user-flows)
9. [Session Modes](#9-session-modes)
10. [Data Models](#10-data-models)
11. [Security Design](#11-security-design)
12. [Face Recognition and Anti-Proxy System](#12-face-recognition-and-anti-proxy-system)
13. [Auto-Open Mechanism (Captive Portal)](#13-auto-open-mechanism-captive-portal)
14. [Server Auto-Detection](#14-server-auto-detection)
15. [Cloud Integration](#15-cloud-integration)
16. [Report Generation](#16-report-generation)
17. [Navigation and Routing](#17-navigation-and-routing)
18. [Deployment Options](#18-deployment-options)
19. [Limitations and Difficulties](#19-limitations-and-difficulties)
20. [Future Work](#20-future-work)
21. [Conclusion](#21-conclusion)

---

## 1. Abstract

OwHAS (Offline Wi-Fi Hotspot Attendance System) is a cross-platform mobile
application built with Flutter that enables lecturers to manage student
attendance digitally without requiring a permanent internet connection.
The system uses the lecturer's laptop as both the Wi-Fi hotspot and the
server, creating a self-contained local area network (LAN) over which a
Node.js backend runs and hosts a web registration page (`hotspot.html`).
Students connect to this hotspot and register their attendance through a
mobile browser — no app installation required on the student side.

The system supports three operational modes: fully offline (LAN hotspot),
fully online (cloud server at `owhas.org`), and hybrid (both simultaneously
under the same session PIN). It incorporates browser-based face recognition
for anti-proxy detection, a 4-digit PIN for session authentication, GPS
geolocation with periodic heartbeat confirmation for online sessions, a
captive portal for automatic page display upon Wi-Fi connection, digital
signature capture, Firebase cloud backup, cumulative attendance tracking
across multiple sessions, and automated PDF and Excel report generation.

---

## 2. Introduction

Traditional attendance management in educational institutions relies on
paper-based sign-in sheets, manual roll calls, or centralised software
systems that depend on institutional internet infrastructure. These methods
suffer from a common set of problems: they are slow, prone to proxy
attendance, easily forged, difficult to archive, and non-functional when
internet access is unavailable.

OwHAS addresses all of these issues with a self-contained, offline-first
design. The system runs its own local server on the lecturer's PC — the
same PC whose mobile hotspot students are required to join. This design means:

- No institutional Wi-Fi or internet is needed for offline mode.
- Joining the hotspot proves physical proximity to the classroom.
- Registration, verification, and reporting are completed within the
  lecturer's controlled local network.
- If internet is available, the same system extends to cloud deployment
  for remote or hybrid learning scenarios.
- Students never need to install any application — the entire registration
  interface is delivered as a single web page from the server.

---

## 3. Problem Statement

Attendance management in higher education faces several persistent challenges:

**Proxy Attendance:** Students signing in on behalf of absent classmates is
a widespread problem that paper sheets and simple digital forms cannot
prevent. A student can share their credentials or physically sign in for
someone who is not present.

**Infrastructure Dependency:** Web-based attendance systems require reliable
internet or intranet access. Many lecture halls and fieldwork locations lack
stable connectivity. A system that requires cloud access fails the moment
that access is lost.

**Data Loss:** Paper sheets are easily lost or damaged. Locally stored
digital data is lost if the device fails without a backup.

**Manual Processing:** Converting raw sign-in data into meaningful attendance
reports — presence percentages, cumulative totals across sessions — requires
significant manual effort and introduces transcription errors.

**Scalability:** A system that works for 20 students must also work for 200
without performance degradation or changes to the lecturer's workflow.

OwHAS directly addresses each of these problems:
- LAN proximity enforcement replaces trust-based sign-in.
- Face recognition with duplicate detection prevents proxy attendance.
- Offline-first design removes infrastructure dependency.
- Firebase cloud backup prevents data loss.
- Automated PDF and Excel generation eliminates manual report work.

---

## 4. Objectives

### Primary Objectives

1. Design and implement a mobile attendance system that operates without
   internet connectivity, using the lecturer's device hotspot as the network.
2. Prevent proxy attendance through device fingerprinting and facial
   recognition at the point of registration.
3. Generate complete, formatted attendance reports (PDF and Excel)
   immediately at the end of each session.
4. Maintain cumulative attendance records across multiple sessions for
   the same course.

### Secondary Objectives

5. Extend the offline system to cloud deployment for online and hybrid
   classroom scenarios.
6. Integrate GPS geolocation and periodic heartbeat verification for
   online sessions to replace the physical proximity that the hotspot
   provides offline.
7. Automatically display the registration page on students' phones the
   moment they connect to the hotspot, without any typing required.
8. Provide a digital signature mechanism for formal record authentication.
9. Allow lecturers to manage their course catalogue and auto-fill session
   details without re-entering them each time.
10. Persist the lecturer's identity across sessions to avoid repeated
    manual entry.

---

## 5. System Architecture

### 5a. High-Level Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        OFFLINE MODE                              │
│                                                                  │
│  Lecturer's Phone (Flutter App)                                  │
│  ┌──────────────────────┐   HTTP    ┌────────────────────────┐  │
│  │ SessionStateNotifier │ ────────► │ Node.js Server         │  │
│  │ AttendanceRecordNtfr │ ◄──────── │ Lecturer's PC :5501    │  │
│  │ StorageService       │           └──────────┬─────────────┘  │
│  └──────────────────────┘                      │                │
│                                     ┌──────────▼─────────────┐  │
│                                     │ hotspot.html           │  │
│                                     │ Student browser page   │  │
│                                     │ Served over LAN        │  │
│                                     └────────────────────────┘  │
│                        Students join lecturer's Wi-Fi hotspot    │
│            Phone shows "Sign in to network" popup automatically  │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                        ONLINE MODE                               │
│                                                                  │
│  Lecturer's Phone (Flutter App)                                  │
│  ┌──────────────────────┐  HTTPS    ┌────────────────────────┐  │
│  │ SessionStateNotifier │ ────────► │ Cloud Server           │  │
│  │ AttendanceRecordNtfr │ ◄──────── │ owhas.org              │  │
│  └──────────────────────┘           └──────────┬─────────────┘  │
│                                                 │                │
│                                     ┌───────────▼────────────┐  │
│                                     │ hotspot.html (cloud)   │  │
│                                     │ GPS + heartbeat check  │  │
│                                     │ Any internet connection│  │
│                                     └────────────────────────┘  │
│                    Students connect via any internet             │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│          INSTITUTIONAL VLAN MODE (IT-managed infrastructure)     │
│                                                                  │
│   ICTU_ATD (open)          ICTU_ATD_STAFF (password)            │
│   Students — no internet   Lecturers — server + internet         │
│         │                          │                             │
│         └──────────┬───────────────┘                            │
│                VLAN 10.50.1.x                                    │
│                    ▼                                             │
│         ┌──────────────────────┐   Internet (infrastructure)    │
│         │ OwHAS Server         │ ─────────────────────────────► │
│         │ 10.50.1.5 (static)   │                  owhas.org     │
│         │ DHCP + DNS for VLAN  │ ◄─── remote student records ── │
│         │ TCP 80, 5501         │                                 │
│         │ UDP 53, 5353         │                                 │
│         └──────────────────────┘                                │
│   In-class students → server  ·  Remote students → owhas.org    │
│   Records from both merged at session end into one PDF/Excel     │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                  CLOUD BACKUP (ALL MODES)                        │
│                                                                  │
│  SessionStateNotifier ─► Firebase Firestore (sessions, records) │
│  CloudService         ─► Firebase Auth (lecturer accounts)      │
└──────────────────────────────────────────────────────────────────┘
```

### 5b. Component Separation

| Component | Platform | Role |
|---|---|---|
| Flutter mobile app | Android / iOS | Lecturer-side UI, local state, reporting |
| Node.js server | Lecturer's PC / Cloud | Receives student registrations, serves hotspot.html |
| hotspot.html | Browser (any device) | Student-facing registration page — no app needed |
| Firebase Firestore | Cloud | Session backup and cross-device sync |
| Firebase Auth | Cloud | Lecturer account authentication |

---

## 6. Technology Stack

### Mobile Application (Flutter)

| Package | Version | Purpose |
|---|---|---|
| Flutter SDK | ^3.6.0 | Cross-platform UI framework |
| Dart | ^3.6.0 | Programming language |
| provider | ^6.1.2 | State management (ChangeNotifier) |
| go_router | ^16.2.0 | Declarative navigation |
| shared_preferences | ^2.5.3 | Local persistent storage (sessions, records, settings) |
| http | ^0.13.0 | HTTP client for Node.js server and cloud communication |
| qr_flutter | ^4.1.0 | QR code generation for the session URL |
| pdf | ^3.10.8 | PDF attendance report generation (Dart-native) |
| printing | ^5.13.3 | PDF share and print dialog |
| excel | ^4.0.6 | Excel report generation |
| file_picker | ^10.3.10 | Import previous session PDF or Excel files |
| share_plus | ^10.0.0 | Native file share dialog |
| path_provider | ^2.1.5 | Device file-system access |
| camera | ^0.11.0 | Face capture via device camera |
| google_mlkit_face_detection | ^0.11.0 | On-device face detection (Flutter app side) |
| image | ^4.2.0 | Image processing for face descriptor extraction |
| geolocator | ^13.0.0 | GPS positioning (online mode) |
| geocoding | ^3.0.0 | Reverse geocoding for location labels |
| network_discovery | ^1.0.0 | LAN subnet scan for active device count |
| device_info_plus | ^12.3.0 | Device fingerprinting for duplicate detection |
| firebase_core | ^3.0.0 | Firebase SDK initialisation |
| cloud_firestore | ^5.0.0 | Cloud session and record storage |
| firebase_auth | ^5.0.0 | Lecturer account authentication |
| firebase_storage | ^12.0.0 | Cloud file and signature storage |
| google_fonts | ^4.0.4 | Typography |
| uuid | ^4.5.3 | UUID generation for session and record IDs |
| intl | ^0.20.2 | Date and number formatting |

### Backend Server (Node.js)

| Technology | Purpose |
|---|---|
| Node.js ≥ 18 | Server runtime |
| Express.js ^4 | HTTP server framework |
| multer | Multipart file upload (PDF import) |
| pdf-parse | Extract text from uploaded PDFs |
| express-rate-limit | PIN brute-force protection (10 attempts / 5 min) |
| dgram (built-in) | Raw UDP sockets for mDNS responder and LAN DNS |
| crypto (built-in) | UUID generation for one-time tokens |

### Student Side (hotspot.html)

| Technology | Purpose |
|---|---|
| Vanilla HTML / CSS / JS | Student registration UI — no frameworks needed |
| face-api.js 0.22.2 | TinyFaceDetector + FaceLandmark68Net + FaceRecognitionNet |
| navigator.geolocation | GPS position (online mode registration and heartbeats) |
| Fetch API | POST registration and periodic GPS heartbeats to server |
| setInterval | GPS heartbeat loop (fires every `HEARTBEAT_INTERVAL_MINUTES`) |

### Cloud Services

| Service | Purpose |
|---|---|
| Firebase Firestore | Session metadata and attendance record storage |
| Firebase Authentication | Email/password login for lecturers |
| Firebase Storage | Signature and file backup |

---

## 7. System Components

### 7a. Flutter Application — Directory Structure

```
lib/
├── main.dart                   Entry point; MultiProvider wires SessionStateNotifier,
│                               AttendanceRecordNotifier, ReportNotifier; runs
│                               ServerConfig.detect(), CloudService.initialize(),
│                               CourseService.seedFromManagement()
├── nav.dart                    GoRouter with 8 routes, all using NoTransitionPage
├── theme.dart                  Light/dark Material 3 themes, spacing and radius constants
├── course_management.dart      IT-admin editable: institution name, semesters, courses
│
├── models/
│   ├── session.dart            AttendanceSession — all session metadata and configuration
│   ├── attendance_record.dart  AttendanceRecord — one student's single-session record
│   ├── student.dart            Student entity (matricule, name, device fingerprint)
│   ├── semester.dart           Semester with equality for picker widgets
│   └── catalogue_course.dart   Course linked to a semester
│
├── services/
│   ├── session_service.dart            PIN generation, session lifecycle, server init, resync
│   ├── storage_service.dart            SharedPreferences CRUD for sessions, records, students
│   ├── api_service.dart                HTTP calls to Node.js server endpoints
│   ├── server_config.dart              Auto-detect LAN / cloud server, isOnline flag, reset/retry
│   ├── course_service.dart             Load and save semesters and courses (catalogue)
│   ├── signature_service.dart          Save and load lecturer signature PNG and name
│   ├── face_recognition_service.dart   Session-scoped in-memory face descriptor store
│   ├── pdf_service.dart                Generate formatted PDF attendance report
│   ├── excel_service.dart              Generate Excel report; parse uploaded files
│   ├── file_service.dart               Save and share files via native dialogs
│   ├── network_discovery_service.dart  Subnet scan to count active hotspot devices
│   ├── cloud_service.dart              Firebase Auth + Firestore sync
│   ├── location_service.dart           GPS collection wrapper (geolocator)
│   └── device_service.dart             Device fingerprint generation (device_info_plus)
│
├── features/
│   ├── home/
│   │   ├── screens/home_screen.dart              Role selection — Lecturer or Student
│   │   └── widgets/                              Animations, role card, badge pills
│   │
│   ├── session/
│   │   ├── screens/session_setup_screen.dart     Create and configure a new session
│   │   ├── screens/lecturer_dashboard_screen.dart  Live session; QR, records, reports
│   │   ├── notifiers/session_state_notifier.dart Session lifecycle ChangeNotifier
│   │   └── widgets/                              Course picker, timing fields, form fields
│   │
│   ├── attendance/
│   │   ├── screens/student_registration_screen.dart  3-step PIN → Details → Face (app)
│   │   ├── notifiers/attendance_record_notifier.dart Record list ChangeNotifier
│   │   └── widgets/                              Registration card, steps, success dialog
│   │
│   ├── reports/
│   │   └── notifiers/report_notifier.dart        PDF generation and sharing ChangeNotifier
│   │
│   ├── catalogue/
│   │   ├── screens/course_catalogue_screen.dart  Manage semesters and courses
│   │   └── widgets/                              Dialogs, tiles, empty state
│   │
│   ├── cloud/
│   │   ├── screens/cloud_login_screen.dart       Firebase email/password sign-in
│   │   ├── screens/cloud_sessions_screen.dart    Historical sessions from Firestore
│   │   └── widgets/                              Login form, session cards, placeholders
│   │
│   └── signature/
│       ├── screens/signature_setup_screen.dart   Draw and save digital signature
│       └── widgets/                              Signature pad form, preview
│
├── pages/
│   └── face_capture_page.dart          Full-screen camera; ML Kit face detection;
│                                       returns FaceCaptureResult with descriptor
│
├── core/
│   ├── abstractions/                   Interfaces: BaseApiService, BaseSessionService,
│   │                                   BaseCloudService, BaseStorageService,
│   │                                   BaseFaceRecognitionService, BaseReportService
│   ├── constants/route_constants.dart  8 route path constants (RouteConstants)
│   ├── extensions/                     context_extensions, datetime_extensions
│   └── mixins/                         LoadingMixin, SnackbarMixin
│
├── widgets/
│   ├── signature_pad.dart              Custom-painter drawing canvas
│   └── dashboard/                     SessionHeader, QrCodeSection,
│                                       AttendanceRecordsSection, CompactStatChip
│
└── utils/
    └── dialog_helpers.dart             Add-manual-student and confirm dialogs
```

### 7b. Node.js Backend — API Endpoints

| Method | Endpoint | Purpose | Notes |
|---|---|---|---|
| GET | `/ping` | Health check — returns `{"status":"ok"}` | Used by server detection |
| GET | `/` | Root redirect | Redirects to `/public/hotspot.html` |
| GET | `/public/hotspot.html` | Student registration page | Served from `backend/public/` |
| GET | `/api/qr-url` | Dynamic QR URL based on server IP | Used by Flutter QR widget |
| POST | `/api/session-init` | Create session with PIN, GPS, and token | Called by Flutter at session start |
| GET | `/api/session-info?token=` | Fetch session details for QR token path | Used by hotspot.html |
| POST | `/api/validate-pin` | Validate a 4-digit PIN | Rate-limited: 10/5 min per IP |
| POST | `/api/end-session` | Deactivate PIN and close session | Called by Flutter at session end |
| POST | `/api/verify-face` | Check face descriptor uniqueness, issue one-time faceId | Step 1 of 2 for browser registration |
| POST | `/api/biometric-connect` | Commit student registration, return heartbeatToken | Step 2 of 2; rate-limited |
| POST | `/connect` | Alternative registration (Flutter app path, no face) | Used by `AttendanceProvider` |
| POST | `/api/heartbeat` | GPS keep-alive from browser — updates `lastSeen` | Online sessions only |
| GET | `/api/attendees?pin=` | List all session attendees (heartbeatToken stripped) | Polled every 5 seconds by dashboard |
| GET | `/api/stats?pin=` | Total / verified / pending counts | Dashboard stats |
| POST | `/api/session-config` | Push required connection time and grace period | Called after session creation |
| POST | `/api/reset` | Clear session attendee list | Internal |
| POST | `/api/remove-attendee` | Remove a single student by matricule | Called from dashboard long-press |
| GET | `/export?pin=` | Download attendance PDF from server | Optional alternative export |
| POST | `/api/parse-pdf` | Extract student data from uploaded PDF file | Cumulative tracking import |
| GET | `/api/version` | Server version and feature flags | Internal |

### 7c. hotspot.html — Student Registration Page

`hotspot.html` is a single HTML file (approximately 900 lines) served by the
Node.js server. It requires no installation and runs in any modern mobile
browser. It implements a 3-step card-based flow with animated stepper pills.

**Step 0 — PIN Entry:**
The student enters the 4-digit PIN displayed on the lecturer's dashboard.
The PIN is validated via `POST /api/validate-pin`. On success, the session
name and lecturer are shown and the student advances to the face step.

**Step 1 — Face Verification:**
The page uses `<input type="file" capture="user">` to open the native
Android/iOS camera without requiring HTTPS or `getUserMedia`. After the
student takes a selfie, `face-api.js` runs three models (TinyFaceDetector,
FaceLandmark68Net, FaceRecognitionNet) locally in the browser to extract
a 128-dimension descriptor. The descriptor is sent to `POST /api/verify-face`,
which checks it against all descriptors already registered in the session
(Euclidean distance threshold 0.6). If a match is found, registration is
blocked and the matched student's name is shown. If unique, a one-time
`faceId` token is issued (valid 5 minutes).

**Step 2 — Personal Details:**
The student fills in: Full Name, Matricule (Student ID), and Email.

**Submission:**
On "Register for Attendance", the page:
1. Acquires current GPS (online sessions only).
2. POSTs all fields plus the `faceId` token to `POST /api/biometric-connect`.
3. Server validates GPS distance (Haversine, ≤ 50 m for online sessions).
4. On success, server returns `{ ok, message, heartbeatToken, heartbeatIntervalMs }`.
5. If `heartbeatToken` is present (online session), the browser starts a
   GPS heartbeat loop and shows the "Keep this page open" status panel.
6. For offline sessions, the page resets to step 0 after 2.5 seconds to
   allow the next student to register.

---

## 8. Application Screens and User Flows

### 8a. Home Page (`/`)

The app opens on a role selection screen with two role cards:
- **Lecturer:** If no active session exists, navigates to Session Setup.
  If an active session is found in storage, a dialog asks whether to
  resume the existing session or discard it and create a new one.
- **Student:** Navigates directly to Student Registration.

A "View Course Catalogue" link gives quick access to course management
without entering the lecturer flow.

### 8b. Session Setup Page (`/setup`)

The lecturer configures all session parameters before starting a class:

1. **Upload Previous Session (optional):** Import a prior session's PDF
   or Excel. The server parses cumulative totals; the session number is
   auto-incremented. Requires the Node.js server to be running (PDF parsing
   uses the `/api/parse-pdf` endpoint).
2. **Lecturer Name:** Pre-filled from SharedPreferences (saved from the
   last session via `SignatureService.saveLecturerName`). Saved automatically
   when the lecturer taps away from the field (on focus-out). A ✕ icon
   clears the saved name. The "Manage Catalogue" button was intentionally
   removed from this page; catalogue management is accessed from the home
   screen.
3. **Semester Picker:** Opens a `SimpleDialog` listing configured semesters.
4. **Course Picker:** After selecting a semester, lists its courses.
   Selecting a course auto-fills Course Name and Code.
5. **Session Duration:** Total time (minutes) the session stays open.
6. **Grace Period:** Late-arrival window (minutes). Must be less than
   Session Duration.
7. **Required Connection Time:** Minimum minutes connected for Verified status.
8. **Maximum Attendance Count:** Total session count for presence percentage.

On **Start Session**, the app:
- Validates all fields.
- Generates a 4-digit PIN: `(1000 + Random.secure().nextInt(9000)).toString()`
- Generates a 32-byte base64url session token for the QR fallback path.
- Captures GPS coordinates if in online mode (passed to server for geofencing).
- Calls `POST /api/session-init` to register the session on the server.
- Saves the session locally to SharedPreferences.
- Navigates to the Lecturer Dashboard.

### 8c. Lecturer Dashboard (`/dashboard`)

The live session control centre. `Timer.periodic` polls the server every
5 seconds via `GET /api/attendees`.

**Session Header:**
- Course name and code, session end time, countdown chip.
- PIN displayed in a large bold card with a "Tap to copy" shortcut.
- Three `CompactStatChip` badges: Total / Verified / Pending.

**Server Warning Banner:**
An orange strip shown when `ServerConfig.detect()` found no server or
when `pushSessionConfig` failed. Contains the error message and a
**Retry** button that calls `ServerConfig().reset()` then `detect()` again.
In hybrid mode (local server found first), this banner does not appear.

**QR Code Section:**
The QR code encodes `<baseUrl>/public/hotspot.html?s=<token>`. Directly
below the QR code, a hint reads:
> For ONLINE type OWHAS.ORG

**Attendance Records:**
A scrollable list of all students showing name, matricule, join time,
connection duration, and verification status (Verified / Pending / Manual).
Long-pressing a tile shows a removal confirmation dialog.

**App Bar Actions:**
- Refresh
- Share Report (generates PDF, opens native share dialog)
- Download PDF (saves to device Downloads folder)
- More menu (⋮): Digital Signature, Add Manual Student, End Session

### 8d. Student Registration Page (`/register`) — App-Side Flow

This page is for students using the OwHAS Flutter app directly, as an
alternative to the browser-based `hotspot.html` flow.

**Step 1 — Enter Session PIN:**
4-digit numeric field with `LengthLimitingTextInputFormatter(4)`. Tapping
"Verify PIN" contacts the server and checks the local active session PIN.
Animated badge shows Verifying → PIN Verified ✓ (green) or Invalid PIN (red).
Auto-advances to step 2 after 700 ms on success.

**Step 2 — Personal Details:**
Matricule, Full Name, Email. All required. Email format validated.

**Step 3 — Face Verification:**
Opens `FaceCapturePage` using `google_mlkit_face_detection`. On return,
the 128-dimension descriptor is checked against all registered faces in
the session. If a duplicate is found, the matched student's name is shown
and registration is blocked. On success, the student is registered locally
and pushed to the server via `POST /connect`.

### 8e. Course Catalogue Page (`/catalogue`)

Manage the institution's course catalogue:
- **Semesters:** Add, rename, mark as active.
- **Courses:** Add, edit, delete. Each course has: Name, Code, Department,
  Credits. Courses are linked to a semester.
- Back navigation: `context.canPop() ? pop() : go('/')` so it correctly
  returns to whichever page opened it.

### 8f. Signature Setup Page (`/signature`)

A `SignaturePad` drawing canvas where the lecturer draws their signature
with a stylus or finger. Saved as PNG bytes in SharedPreferences
(base64-encoded) via `SignatureService`. Loaded automatically and embedded
in every generated PDF report. The lecturer's name is also saved here and
read by the PDF generator for the report header.

### 8g. Cloud Pages

**Cloud Login Page (`/cloud-login`):**
Firebase email/password sign-in and new account registration.

**Cloud Sessions Page (`/cloud-sessions`):**
Lists all historically synced sessions. Sessions display date, course, and
attendance totals. Export as PDF or Excel available per session.

---

## 9. Session Modes

### 9a. Offline Mode (LAN Hotspot)

- The lecturer runs `start-server.bat` on their PC (self-elevates to
  Administrator automatically). This starts `node server.js` on port 5501.
- The PC's Windows Mobile Hotspot is enabled. Students join it.
- `ServerConfig.detect()` scans 767 LAN addresses in parallel with an
  800 ms timeout. It finds the server at `192.168.137.1:5501` (Windows
  hotspot) within milliseconds.
- `ServerConfig.isOnline = false`.
- Physical presence is enforced by the LAN: only devices joined to the
  hotspot can reach the server. No GPS required.
- When a student connects to the hotspot, the server's captive portal
  (port 80) intercepts the OS connectivity probe and returns a 302 redirect,
  triggering a "Sign in to network" popup that opens `hotspot.html`
  automatically in the device's browser.
- QR code URL: `http://192.168.137.1:5501/public/hotspot.html?s=<token>`

### 9b. Online Mode (Cloud Server)

- No local server is running. `ServerConfig.detect()` finds no LAN server
  and proceeds to try `https://owhas.org` with a 2-second timeout.
- `ServerConfig.isOnline = true`.
- Students connect from any internet connection from anywhere.
- GPS geolocation is mandatory:
  - Lecturer's GPS captured at session creation; sent to the server in
    `POST /api/session-init`.
  - Student's browser prompts for GPS permission before the form appears.
  - Haversine distance checked server-side; distance > 50 m → rejected.
  - GPS coordinates are used only for this check and are not stored in any
    attendance record or exported file.
- After registration, the browser starts a **GPS heartbeat loop** sending
  a GPS ping to `POST /api/heartbeat` every `HEARTBEAT_INTERVAL_MINUTES`
  (default: 2 minutes). The server checks distance on each heartbeat.
  If the student leaves the area or closes the browser tab, the server
  freezes their `lastSeen` timestamp. The Flutter dashboard uses
  `lastSeen - connectedAt` as the student's confirmed duration instead of
  wall-clock elapsed time.
- QR code URL: `https://owhas.org/public/hotspot.html?s=<token>`

### 9c. Hybrid Mode (Both Simultaneously)

- Both local server and cloud are running under the same session PIN.
- `ServerConfig.detect()` picks the local server first (faster LAN response).
- Hotspot students register on the LAN server; remote students register
  on the cloud.
- At "End Session," the Flutter app queries both servers, merges records
  by matricule (online record wins ties — it carries GPS validation), and
  exports a single unified PDF/Excel with a `Source` column (offline /
  online). No GPS coordinates appear in any export.

### 9d. Institutional VLAN Mode (IT-Managed Infrastructure)

This is the production deployment model for universities that assign a
dedicated VLAN to OwHAS, managed entirely by the IT department.

**Network layout:**
- A VLAN is provisioned on subnet `10.50.1.x`, spanning all equipped
  classrooms. Two SSIDs are broadcast on this VLAN:
  - `ICTU_ATD` — open (no password), reserved for students. Traffic is
    restricted to the OwHAS server only (`10.50.1.5`); no internet breakout.
  - `ICTU_ATD_STAFF` — password-protected, reserved for lecturers.
    Traffic reaches both the OwHAS server and the open internet.

**Server role:**
- A dedicated machine holds the static IP `10.50.1.5`.
- It acts as DHCP server and DNS resolver for the VLAN (not for the
  university's main network).
- Required open ports (inbound, within the VLAN):
  - `TCP 80` — captive portal redirect
  - `TCP 5501` — main OwHAS attendance server
  - `UDP 53` — LAN DNS hostname (`owhas.lan`)
  - `UDP 5353` — mDNS hostname (`owhas.local`)
- The server also requires outbound internet access (via the university's
  uplink) to synchronise completed sessions to `owhas.org` at session end.

**Registration flow:**
- Students connect to `ICTU_ATD`. The server's captive portal (port 80)
  intercepts the OS connectivity probe and redirects to `hotspot.html`
  automatically — identical to the personal-hotspot experience but on
  university-managed infrastructure.
- Lecturers connect to `ICTU_ATD_STAFF`. The Flutter app communicates
  with the server at `10.50.1.5:5501` for session management, and
  simultaneously with `owhas.org` for remote students.
- Remote students (not physically present) register directly on
  `owhas.org` using the same 4-digit session PIN.
- At session end, both the local server (`10.50.1.5`) and the cloud
  (`owhas.org`) are queried; records are merged by matricule and exported
  as a single unified attendance list.

**Server auto-detection:**
`ServerConfig.detect()` will find `10.50.1.5:5501` during the LAN subnet
scan if the phone is connected to either SSID. No configuration change is
needed in the Flutter app — detection is automatic.

**Advantages over the personal-hotspot model:**
- No limit on concurrent connected devices (replaces Windows Mobile
  Hotspot's ~8-device cap).
- Persistent server (always on, no laptop required to host the hotspot).
- Controlled network separation — students cannot access the internet or
  any other university resource while on `ICTU_ATD`.
- Clean institutional ownership of attendance infrastructure.

---

## 10. Data Models

### AttendanceSession

| Field | Type | Description |
|---|---|---|
| id | String (UUID v4) | Unique session identifier |
| courseName | String | Full course name |
| courseCode | String? | Course code, e.g. CS2560 |
| lecturerId | String | Device identifier of the lecturer |
| lecturerName | String? | Lecturer display name (persisted across sessions) |
| sessionPin | String? | 4-digit numeric PIN (1000–9999) |
| sessionToken | String? | 32-byte base64url token for QR fallback path |
| startTime | DateTime | Session creation timestamp |
| endTime | DateTime? | Session end timestamp |
| durationMinutes | int | Total session length in minutes |
| gracePeriodMinutes | int | Late-arrival tolerance in minutes |
| requiredConnectionMinutes | int | Minimum stay to be marked Verified |
| maxAttendanceCount | int | Total sessions for presence % calculation |
| sessionNumber | int | Sequential session number for this course |
| isActive | bool | Whether the session is still open |
| createdAt | DateTime | Record creation timestamp |
| updatedAt | DateTime | Last modification timestamp |

### AttendanceRecord

| Field | Type | Description |
|---|---|---|
| id | String (UUID v4) | Unique record identifier |
| sessionId | String | Links to AttendanceSession.id |
| studentId | String | Links to Student.id |
| matricule | String | Student matricule number |
| studentName | String | Student full name |
| email | String? | Student email |
| joinedAt | DateTime | Timestamp of registration |
| verifiedAt | DateTime? | When connection time threshold was met |
| connectionDurationMinutes | int | Confirmed presence minutes |
| isVerified | bool | Whether required connection time was met |
| isManual | bool | True if added by lecturer manually |
| deviceFingerprint | String | Device identifier (or `manual_<uuid>`) |
| location | AttendanceLocation? | GPS coords at registration (if collected) |
| createdAt | DateTime | — |
| updatedAt | DateTime | — |

### Server-Side Attendee Object (Node.js)

| Field | Type | Description |
|---|---|---|
| username | String | Student full name |
| matricule | String | Student ID |
| email | String | Email address |
| ip | String | Student device IP (used as fingerprint offline) |
| faceId | String | UUID of the verified face token |
| faceVerified | bool | Whether face check was performed |
| connectedAt | ISO String | Registration timestamp |
| lastSeen | ISO String? | Last confirmed GPS heartbeat (online only) |
| leftEarly | bool? | True if GPS check failed on a heartbeat |
| time | String | Human-readable registration time |

### Student

| Field | Type | Description |
|---|---|---|
| id | String (UUID v4) | Unique student identifier |
| matricule | String | Student matricule (unique per session) |
| name | String | Full name |
| email | String? | Email address |
| deviceFingerprint | String | Hardware device identifier |
| createdAt | DateTime | — |
| updatedAt | DateTime | — |

### Semester

| Field | Type | Description |
|---|---|---|
| id | String | Unique semester identifier |
| label | String | Display name, e.g. "SEMESTER 1 – 2025/26" |
| isActive | bool | Whether this is the current semester |

### CatalogueCourse

| Field | Type | Description |
|---|---|---|
| id | String | Unique course identifier |
| semesterId | String | Links to Semester.id |
| name | String | Course full name |
| code | String | Course code |
| department | String? | Department name |
| credits | int? | Credit hours |

---

## 11. Security Design

### 11a. PIN Authentication

- 4-digit numeric PIN, range 1000–9999.
- Generated with `Random.secure()` — cryptographically unpredictable.
- Server-side validation: regex `^\d{4}$` before any session lookup.
- Rate-limited: maximum 10 attempts per IP per 5-minute window via
  `express-rate-limit` on `/api/validate-pin` and `/api/biometric-connect`.
- Session deactivated immediately when the lecturer ends the session via
  `POST /api/end-session`.
- Sessions also expire automatically after `durationMinutes`; expired
  sessions are evicted on the next lookup.
- PIN is displayed only on the lecturer's device screen and the QR code;
  never transmitted to students in plain text.

### 11b. Face Recognition — Proxy Prevention (Browser Side)

- When registering via `hotspot.html`, the student's selfie is processed
  entirely in the browser by `face-api.js`.
- A 128-dimension descriptor is extracted and sent to `POST /api/verify-face`.
- The server computes Euclidean distance against every descriptor stored
  in the session. Distance < 0.6 = same person → registration blocked.
- A one-time `faceId` UUID is issued (5-minute TTL) and consumed on the
  final `POST /api/biometric-connect` call.
- A race-condition guard re-checks descriptor uniqueness at commit time
  to prevent simultaneous duplicate submissions.

### 11c. Face Recognition — Proxy Prevention (App Side)

- For students registering via the Flutter app (`StudentRegistrationPage`),
  Google ML Kit detects the face from the device camera.
- The same 128-dimension descriptor + Euclidean distance check is applied
  against all faces in `FaceRecognitionService`.
- Face descriptors are held in memory for the session duration only.
  They are never written to disk or uploaded to any server.

### 11d. Device Fingerprinting

- Each student's device generates a fingerprint from hardware identifiers
  (via `device_info_plus`).
- A fingerprint already present in the session blocks a second registration
  from the same device — preventing one device from registering two people.
- Server-side: student IP address is used as an equivalent fingerprint
  for browser-based registrations on the LAN.

### 11e. GPS Geolocation (Online Mode — Registration)

- The lecturer's GPS coordinates are captured once at session creation
  and stored in the server's `activeSessions` map as `targetLocation`.
- When a student submits `hotspot.html`, GPS is checked server-side via
  the Haversine formula. Distance > 50 m → 403 Geofence Error.
- GPS coordinates are validated and immediately discarded. They are not
  stored in any attendance record and do not appear in any export.

### 11f. GPS Heartbeat Presence Enforcement (Online Mode)

The one-time GPS check at registration only proves the student was present
at the moment of submission. The heartbeat system enforces continued presence
for the full required duration.

After successful `POST /api/biometric-connect` for an online session, the
server issues a `heartbeatToken` (UUID) and returns it along with
`heartbeatIntervalMs` in the JSON response. The browser then:

1. Starts a `setInterval` loop at the given interval.
2. Each tick: acquires current GPS, POSTs `{ token, matricule, pin, lat, lng }`
   to `POST /api/heartbeat`.
3. The server re-validates the Haversine distance.
   - In range → updates `attendee.lastSeen` to current time.
   - Out of range → sets `attendee.leftEarly = true`, returns 403, browser
     stops the loop and shows a warning.
4. If the student closes the browser tab, heartbeats stop. A background
   `setInterval` in Node.js checks every `HEARTBEAT_INTERVAL_MINUTES` for
   students whose `lastSeen` is older than
   `HEARTBEAT_INTERVAL_MINUTES × (HEARTBEAT_GRACE_PERIODS + 1)` and
   marks them `leftEarly = true`.

The Flutter dashboard reads `lastSeen` from `GET /api/attendees` and computes:
```
duration = lastSeen - connectedAt   (online students)
duration = now - connectedAt         (offline students, no lastSeen field)
```
When `lastSeen` freezes, the duration shown in the dashboard freezes too.
Verification status is calculated from this frozen duration.

**Configuration** (top of `backend/server.js`):
```javascript
const HEARTBEAT_INTERVAL_MINUTES = 2;   // ← edit to change check frequency
const HEARTBEAT_GRACE_PERIODS    = 1;   // ← edit to change missed-beat tolerance
```

The browser also keeps a matching fallback constant `HEARTBEAT_INTERVAL_MINUTES`
at the top of the `<script>` block in `backend/public/hotspot.html`. Editing
the value in `server.js` is sufficient — the server returns the authoritative
interval to the browser in `heartbeatIntervalMs` at registration time.

### 11g. LAN Proximity (Offline Mode)

The lecturer controls the Wi-Fi hotspot. Only devices physically connected
to the hotspot can reach the server. Being on the network proves physical
presence without any additional check. There is no mechanism to connect to
`192.168.137.1:5501` from outside the hotspot range.

### 11h. Payload and Input Validation

- JSON body size limited to 10 KB to prevent large-payload attacks.
- PIN format validated server-side: regex `^\d{4}$`.
- Student name: maximum 100 characters.
- Matricule: maximum 30 characters.
- Email: maximum 150 characters.
- Session persistence: written to `sessions.json` after every change
  (safe crash recovery). Sessions are restored on server restart if not yet
  expired.

---

## 12. Face Recognition and Anti-Proxy System

### 12a. Models Used

**Browser-side (hotspot.html):**
- `TinyFaceDetector` — lightweight model optimised for mobile browsers.
  Input size: 320, score threshold: 0.45.
- `FaceLandmark68Net` — detects 68 facial landmarks.
- `FaceRecognitionNet` — produces the 128-dimension descriptor vector.
- All three models are served locally from `backend/public/models/`,
  downloaded once by running `node setup.js`.

**App-side (FaceCapturePage):**
- `google_mlkit_face_detection` — Google's on-device ML Kit.
- Face region is cropped and processed by the `image` package to extract
  the descriptor.

### 12b. Duplicate Detection Algorithm

```
For each new descriptor D_new submitted at registration:
  For each D_existing already in session.faceDescriptors:
    dist = sqrt( Σ (D_new[i] − D_existing[i])² )   [Euclidean distance]
    if dist < 0.6:
      return { unique: false, matchedName: D_existing.name }
  If no match:
    issue one-time faceId token
    return { unique: true, faceId }
```

The 0.6 threshold is the standard value for face-api.js. Values below 0.6
are considered the same person.

### 12c. Two-Step Commit Protocol

Registration uses a two-step protocol to close a race-condition window:

1. `POST /api/verify-face` — checks uniqueness, issues `faceId` (5 min TTL).
2. `POST /api/biometric-connect` — re-checks uniqueness at commit time
   using the same descriptor stored with the token, consumes the `faceId`
   (single-use), and writes the record.

This prevents two simultaneous identical requests from both passing the
initial check and both committing.

### 12d. Known Limitations

- Identical twins produce descriptors with distance < 0.6 and will fail
  each other's registration.
- Extreme lighting, head coverings, or heavy sunglasses reduce accuracy.
- Photo spoofing (holding a printed photo) bypasses face capture — liveness
  detection is not implemented.
- Face data is session-scoped and in-memory only; no cross-session face
  database is maintained.
- Low-quality front cameras (< 2 MP) may produce noisy descriptors,
  increasing false positive rates.

---

## 13. Auto-Open Mechanism (Captive Portal)

When a student connects their phone to the lecturer's hotspot, `hotspot.html`
can appear automatically in their browser without any typing. This is
achieved through three layered mechanisms, all started by `server.js`.

### 13a. Captive Portal (Port 80) — Automatic Popup

Every phone OS probes for internet connectivity the moment it joins a new
Wi-Fi. It sends an HTTP request to a well-known URL and expects a specific
response. If it receives anything else — such as a 302 redirect — it
concludes "captive portal" and shows a "Sign in to network" notification.
Tapping the notification opens the phone's mini browser directly on the
redirected page.

The server starts a second Express server on port 80 that intercepts all
of these probe paths:

| OS | Probe URL | Expected |
|---|---|---|
| Android (Chrome) | `/generate_204` | HTTP 204 |
| Android (alt) | `/gen_204` | HTTP 204 |
| iOS / macOS | `/hotspot-detect.html` | HTTP 200 |
| iOS (older) | `/library/test/success.html` | HTTP 200 |
| Windows | `/connecttest.txt` | HTTP 200 |
| Windows NCSI | `/ncsi.txt` | HTTP 200 |
| Firefox | `/success.txt` | HTTP 200 |

Every path returns `302 → http://192.168.137.1:5501/public/hotspot.html`.
All other URLs on port 80 also redirect to the attendance page.

Port 80 requires Administrator rights. The server logs a clear error and
falls back gracefully if not elevated. **Always start the server using
`start-server.bat`**, which self-elevates to Administrator automatically.

### 13b. mDNS Hostname: `http://owhas.local`

A raw UDP socket joins the mDNS multicast group `224.0.0.251:5353` and
answers any query for `owhas.local` with the detected hotspot IP. Students
can type `http://owhas.local` in Chrome or Safari without knowing the IP.
Works on Android 8+, iOS, and Windows 10+ natively. Does not require
Administrator rights (port 5353 is above 1024).

### 13c. LAN DNS Hostname: `http://owhas.lan`

A UDP DNS server binds to port 53 on the hotspot IP only
(not `0.0.0.0`, so the PC's own DNS is not affected). It resolves every
A-record query to the hotspot IP, making `owhas.lan` resolve for all hotspot
clients. Requires Administrator rights and port 53 to be free (Windows
`Dnscache` service may hold it; run `net stop Dnscache` in Admin PowerShell
if needed).

### 13d. How `start-server.bat` Orchestrates Everything

`backend/start-server.bat` is the correct launch method for class use:
1. Self-elevates to Administrator via a UAC prompt if not already elevated.
2. Adds Windows Firewall inbound rules for TCP 5501 and node.exe.
3. Downloads `face-api.js` and model files via `node setup.js`
   (one-time, skipped if already present).
4. Runs `node server.js`, which then starts all four services:
   the main attendance server (5501), the captive portal (80), the mDNS
   responder (5353 UDP), and the LAN DNS (53 UDP).

---

## 14. Server Auto-Detection

### 14a. How `ServerConfig.detect()` Works

`detect()` is called once in `main.dart` before the first screen is shown.
It runs in a background isolate (`compute()`) to avoid UI jank.

It scans in four sequential blocks, stopping at the first success:

| Block | Addresses | Timeout | Sets |
|---|---|---|---|
| 1+2 — Local subnet scan | 767 IPs (5 fixed + 3 × 254 subnet) | 800 ms | `isOnline = false` |
| 3 — Emulator loopback | `10.0.2.2:5501` | 800 ms | `isOnline = false` |
| 4 — Cloud server | `https://owhas.org/ping` | 2000 ms | `isOnline = true` |
| Fallback | — | — | `baseUrl = 192.168.137.1:5501, isOnline = false` |

The fixed candidates in block 1 include:
- `192.168.137.1:5501` — Windows Mobile Hotspot gateway (default)
- `10.50.1.5:5501` — Institutional VLAN server (university-managed)

Both are tried in the same parallel scan pass; whichever responds first is
used. No configuration change is needed when switching between a personal
hotspot and the institutional VLAN deployment.

Total worst-case time if nothing is found: 800 + 800 + 2000 = 3600 ms.

### 14b. The `_hasDetected` Cache

After the first `detect()` call completes, `_hasDetected = true` is set.
Every subsequent call returns immediately without re-scanning. This means:
if the app was launched while offline, it stays in offline mode even after
the internet becomes available — until a re-detection is triggered.

### 14c. Re-Detection (Retry Button)

The orange warning banner in the Lecturer Dashboard includes a **Retry**
button that calls:
```dart
ServerConfig().reset();          // clears _hasDetected = false
await ServerConfig().detect();   // full re-scan from scratch
```
Use this if the app was launched before connecting to the internet, or
if the local server was started after the app.

---

## 15. Cloud Integration

### 15a. Firebase Services

- **Firebase Authentication:** Email/password accounts for lecturers.
- **Cloud Firestore:** Stores session metadata and attendance records.
- **Firebase Storage:** Stores lecturer signatures and large attachments.

### 15b. Sync Behaviour

Cloud sync is entirely optional. The app works completely offline without
a Firebase account.

If the lecturer is signed in (`CloudService.isSignedIn = true`):
- A new session is synced to Firestore when created.
- Each student registration is synced immediately.
- A full session sync runs at session end.

If sync fails (internet unavailable), it is silently ignored. Local
SharedPreferences data is always the source of truth.

### 15c. Cloud Sessions Page

Signed-in lecturers can view all historical sessions from any device. Each
session shows date, course, and attendance totals with PDF/Excel export.

---

## 16. Report Generation

### 16a. PDF Report

Generated in Dart by the `pdf` package (no external service required).

**Contents:**
- Institution and course header
- Lecturer name and embedded digital signature
- Session date, duration, and sequential session number
- Table: #, Name, Matricule, Join Time, Duration, Status (Verified / Pending / Manual)
- Cumulative attendance column (if previous session was uploaded)
- Presence percentage per student
- Session summary statistics

**Two export paths:**
1. `generateAndSharePDFReport()` — generates in-memory and opens the
   native share dialog (WhatsApp, email, Drive, etc.)
2. `downloadPDFReport()` — saves to the device's Downloads folder and
   shows the file path in a SnackBar.

### 16b. Excel Report

Generated by the `excel` package. Contains the same data in spreadsheet
format, suitable for import into institutional LMS systems.

### 16c. Cumulative Attendance Tracking

1. Before a new session, the lecturer uploads the PDF or Excel from the
   previous session via the Session Setup page.
2. For PDF files: the file is sent to `POST /api/parse-pdf`, which extracts
   student names, matricules, and cumulative totals from the Master Roster
   section using regex-based parsing.
3. For Excel files: parsed directly in Dart.
4. Extracted totals are stored in `_previousAttendance (Map<String, int>)`
   keyed by matricule.
5. The session number is auto-incremented from the parsed previous number.
6. The new report adds the current session to each student's cumulative count.

---

## 17. Navigation and Routing

GoRouter (version ^16.2.0) with `NoTransitionPage` on every route for
instant, animation-free navigation.

| Route | Screen | Description |
|---|---|---|
| `/` | `HomeScreen` | Role selection — Lecturer or Student |
| `/setup` | `SessionSetupScreen` | Configure and start a new session |
| `/dashboard` | `LecturerDashboardScreen` | Live session control centre |
| `/register` | `StudentRegistrationScreen` | 3-step student attendance registration |
| `/signature` | `SignatureSetupScreen` | Draw and save digital signature |
| `/catalogue` | `CourseCatalogueScreen` | Manage semesters and courses |
| `/cloud-login` | `CloudLoginScreen` | Firebase sign-in / registration |
| `/cloud-sessions` | `CloudSessionsScreen` | Historical cloud sessions |

**Navigation rules:**
- `context.go(path)` — replaces the navigation stack (main-level screens).
- `context.push(path)` — stacks on top (Catalogue, so back returns correctly).
- `context.canPop() ? pop() : go('/')` — safe back with fallback to home.
- `LecturerDashboardPage` has `PopScope(canPop: false)` to prevent
  accidental back-press from exiting a live session.

---

## 18. Deployment Options

### Option 1 — Offline Only (Default, No Setup)

The lecturer:
1. Runs `backend/start-server.bat` on their PC (self-elevates to Admin).
2. Enables the PC's Windows Mobile Hotspot.
3. Opens the Flutter app on their phone.
4. The app auto-detects the server within 1–2 seconds.

No additional configuration. Works in a classroom with no internet at all.

### Option 2 — Cloudflare Tunnel (5 Minutes, Free)

Keep the local server but expose it to the internet through Cloudflare's
HTTPS tunnel. Useful for occasional remote students during hybrid sessions.

```bat
cloudflared tunnel --url http://localhost:5501
```

Cloudflare prints a temporary HTTPS URL. The tunnel closes when the
terminal is closed.

### Option 3 — Render.com (Permanent Free Cloud)

Deploy the `backend/` folder to Render.com for a permanent cloud deployment.

Configuration:
- Root Directory: `backend`
- Build Command: `npm install && node setup.js`
- Start Command: `node server.js`
- Environment Variable: `NODE_ENV=production`

Note: On the free tier, the server sleeps after 15 minutes of inactivity
and the ephemeral filesystem resets between restarts. For production use,
add a persistent database.

### Option 4 — VPS with HTTPS (Full Control, ~$5/month)

DigitalOcean, Hetzner, or Linode with Caddy as a reverse proxy:

```
owhas.yourdomain.com {
    reverse_proxy localhost:5501
}
```

Caddy auto-provisions a Let's Encrypt SSL certificate. Use PM2 to keep
the server alive after SSH logout.

### Option 5 — Institutional VLAN (IT Department Setup)

The production deployment model for universities. Requires a one-time
network configuration request addressed to the IT department.

**What the IT department must provision:**

1. A dedicated VLAN on subnet `10.50.1.x`, broadcast across all
   classroom access points under two SSIDs:
   - `ICTU_ATD` — open, students only
   - `ICTU_ATD_STAFF` — password-protected, lecturers only

2. Differentiated traffic policy:
   - `ICTU_ATD` → OwHAS server (`10.50.1.5`) only; internet blocked
   - `ICTU_ATD_STAFF` → OwHAS server + full internet

3. The OwHAS server (`10.50.1.5`) to serve as DHCP and DNS within
   this VLAN only — not affecting the university's main DNS.

4. The following ports open inbound within the VLAN:
   - `TCP 80` — captive portal (auto-opens `hotspot.html` on connect)
   - `TCP 5501` — OwHAS attendance server
   - `UDP 53` — LAN DNS (`owhas.lan`)
   - `UDP 5353` — mDNS (`owhas.local`)

5. A static IP (`10.50.1.5`) assigned to the OwHAS server machine,
   with outbound internet access so it can sync completed sessions
   to `owhas.org` at session end.

**What stays the same for the lecturer:**
- Open the Flutter app — server detected automatically at `10.50.1.5`.
- Start the session, share the PIN, monitor the dashboard as normal.
- Students connect to `ICTU_ATD` (no password) and are redirected to
  `hotspot.html` automatically via the captive portal.
- Remote students use `owhas.org` with the same PIN.
- End the session — records from both sources merge into one report.

**Advantages:**
- No device limit (replaces the ~8-device cap of Windows Mobile Hotspot).
- Server is always on — no laptop needs to run the hotspot.
- Clean network isolation: students cannot reach the internet or other
  university systems while on `ICTU_ATD`.
- Zero configuration difference from the lecturer's perspective.

---

## 19. Limitations and Difficulties

### Network and Connectivity

- Windows Mobile Hotspot supports approximately 8 simultaneous connected
  devices. For large classes a dedicated Wi-Fi access point is recommended.
- Some institutional IT policies block personal hotspots.
- The subnet scan covers 767 IPs in parallel; on very slow networks this
  may take the full 800 ms window.
- iOS uses a different hotspot gateway IP (`172.20.10.1`) which requires
  dedicated handling in the scan.
- Port 80 and port 53 require Administrator rights. If `start-server.bat`
  is not used, the captive portal and DNS hostname features are unavailable
  (students must type the full IP or use `http://owhas.local` via mDNS).

### Face Recognition Accuracy

- Photo-based spoofing (holding a printed photograph) bypasses face
  recognition; liveness detection is not implemented.
- Identical twins may produce descriptors with Euclidean distance < 0.6
  and block each other's registration.
- Low-quality front cameras (< 2 MP) produce noisy descriptors.
- Indoor GPS accuracy is 10–50 metres; the 50 m geofence radius may need
  to be widened for large classroom buildings.

### GPS and Heartbeat

- `HEARTBEAT_INTERVAL_MINUTES = 2` means a student could leave the
  classroom for up to 2 minutes before the next heartbeat triggers the
  out-of-range check. Reducing the interval increases battery drain.
- GPS may be unavailable inside concrete buildings; a missed heartbeat is
  tolerated up to `HEARTBEAT_GRACE_PERIODS` times before the clock freezes.

### PIN Security

- A 4-digit PIN has only 9,000 possible values (1000–9999).
- Rate-limiting (10 attempts / 5 min) reduces brute-force risk but does
  not eliminate it completely.
- The PIN should never be shared outside the classroom.

### Data Persistence

- The Node.js server holds sessions in-memory with a `sessions.json` file
  for crash recovery. On cloud free tiers the ephemeral filesystem resets
  between restarts, requiring an external database for production reliability.

### Privacy and Legal

- Face recognition data constitutes biometric data (GDPR Article 9 —
  sensitive personal data). Explicit informed consent is required from each
  student before their face is captured.
- GPS coordinates are a validation gate only and are not stored.
- Institutions must inform students about face and device data collection.

---

## 20. Future Work

1. **Liveness Detection:** Require a blink or head-turn challenge during
   face capture to defeat photo-based spoofing.
2. **NFC Check-in:** Use NFC-enabled student ID cards as an alternative to
   face capture for institutions that issue them.
3. **Multi-Lecturer Support:** Allow multiple lecturers to share a cloud
   session with distinct roles (moderator / observer).
4. **Automated Report Delivery:** Email the PDF report to the department
   automatically at session end via a configured SMTP server.
5. **Dashboard Analytics:** Charts showing attendance trends across all
   sessions for a course — weekly presence percentage line graphs.
6. **Database Migration:** Replace the `sessions.json` file with SQLite for
   the local server and PostgreSQL for the cloud server.
7. **API Key Authentication:** Protect lecturer-only server endpoints with
   a secret header to prevent unauthorised session creation from the internet.
8. **SMS Confirmation:** Send students a confirmation SMS when their
   attendance is verified (Twilio or equivalent).
9. **Tablet Layout:** Two-column dashboard layout for tablet screen sizes.
10. **Windows / macOS Desktop App:** Package the Flutter app as a desktop
    application so the lecturer can run both the server and the app from
    the same machine without two separate tools.
11. **Variable GPS Radius per Session:** Allow the lecturer to set a custom
    geofence radius at session creation instead of the fixed 50 m default,
    to accommodate large outdoor classrooms or fieldwork.

---

## 21. Conclusion

OwHAS demonstrates that a production-quality attendance management system
can be built without dependency on institutional infrastructure. The
offline-first design — where the lecturer's own Wi-Fi hotspot serves as
both the network and the proximity enforcement mechanism — solves the
internet dependency problem at its root rather than working around it.

The three-mode architecture (offline, online, hybrid) and the merge-at-end
strategy allow the same codebase and workflow to serve rural classrooms with
no connectivity, urban lecture halls with stable internet, and blended
learning scenarios where some students are remote.

The anti-proxy layer — device fingerprinting, browser-side face recognition
via face-api.js, app-side face recognition via Google ML Kit, and (in online
mode) GPS geolocation with periodic heartbeat confirmation — addresses the
most persistent challenge in digital attendance systems: verifying that the
person who registered is the person who was actually present and remained
present for the required duration.

The captive portal mechanism (port-80 redirect, mDNS `owhas.local`, DNS
`owhas.lan`) removes all friction from the student side: connecting to the
Wi-Fi is the only action required to reach the registration page, with no
URL typing necessary.

The project was built entirely with open-source and free-tier tools, making
it immediately deployable by any educational institution at zero
infrastructure cost.

---

*Document prepared for Final Year Project submission.*
*System name: OwHAS — Offline Wi-Fi Hotspot Attendance System*
*Developer: FODOPTACHEKAM*
*Platform: Flutter (Android / iOS) + Node.js*
*Version: 1.0.0*
*Date: May 2026*
