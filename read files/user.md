# Hotspot Attendance System — Complete User & Technical Guide

> **Version:** 1.0  
> **Platform:** Flutter (Android / iOS / Web) + Node.js Server + Firebase Cloud  
> **Purpose:** Offline-first classroom attendance tracking using Wi-Fi hotspots, with optional cloud backup and GPS verification.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Who Uses This System](#2-who-uses-this-system)
3. [How It Works (The Big Picture)](#3-how-it-works-the-big-picture)
4. [Key Concepts](#4-key-concepts)
5. [For Lecturers — Step-by-Step](#5-for-lecturers--step-by-step)
6. [For Students — Step-by-Step](#6-for-students--step-by-step)
7. [Feature Deep-Dives](#7-feature-deep-dives)
8. [Architecture & Data Flow](#8-architecture--data-flow)
9. [Technology Stack](#9-technology-stack)
10. [File & Folder Guide](#10-file--folder-guide)
11. [Troubleshooting](#11-troubleshooting)
12. [Security & Privacy](#12-security--privacy)

---

## 1. System Overview

The **Hotspot Attendance System** is a cross-platform Flutter application designed for university and classroom environments where lecturers need a fast, reliable, and privacy-focused way to take attendance without relying on the public internet.

### Core Idea
1. The lecturer starts a **Wi-Fi hotspot** on their Windows PC.
2. The PC runs a small **Node.js server** that hosts a student registration web page.
3. Students connect to the hotspot and either:
   - Scan a **QR code** on the lecturer's phone, **or**
   - Type a **6-digit PIN** displayed by the lecturer.
4. Students fill in their details on the web page.
5. The lecturer's Flutter app sees the registrations in real time, tracks who stayed long enough to be "verified," and exports attendance reports as **PDF** or **Excel**.
6. Everything can optionally sync to **Firebase Cloud** for backup, multi-device access, and GPS location collection.

### Why It Exists
- **No internet required** — works entirely on a local hotspot.
- **No paper** — digital registers with cumulative tracking across multiple class sessions.
- **Fraud resistant** — device fingerprinting prevents one student from registering multiple friends.
- **Cloud optional** — works fully offline; cloud is only for backup and advanced features.

---

## 2. Who Uses This System

| Role | What They Do | Primary Screens |
|------|--------------|-----------------|
| **Lecturer** | Creates sessions, monitors attendance, exports reports, manages signatures | Home → Setup → Dashboard → Cloud Login |
| **Student** | Connects to hotspot, scans QR or enters PIN, fills web form to register | Any phone browser (no app install needed) |
| **Administrator / Developer** | Sets up Firebase, configures IPs, manages server | Server terminal, Firebase Console |

---

## 3. How It Works (The Big Picture)

### Scenario: A Typical Class Session

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Lecturer's PC  │────▶│  Node.js Server  │◀────│ Student Phones  │
│ (Windows + WiFi)│     │  Port 5501       │     │ (Web Browser)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                        ▲                        │
         │                        │ POST /connect          │
         │                        │                        │
         ▼                        │                        ▼
┌─────────────────┐               │               ┌─────────────────┐
│  Lecturer Phone │───────────────┘               │  Scan QR or     │
│  (Flutter App)  │   GET /api/attendees          │  Enter PIN      │
│                 │                               │  on web form    │
└─────────────────┘                               └─────────────────┘
         │
         ▼
┌─────────────────┐
│  Export PDF/    │
│  Excel Report   │
└─────────────────┘
```

### Step-by-Step Flow

1. **Lecturer opens the Flutter app** and taps **"Create Session."**
2. The app generates a **6-digit PIN** (e.g., `558219`) and a secure **session token**.
3. The app tells the Node.js server to start a new session bucket associated with that PIN.
4. The lecturer writes the PIN on the whiteboard (or shows a QR code).
5. **Students** connect to the lecturer's Wi-Fi hotspot, open their browser, and go to the web page.
6. They enter the PIN, see the course name, and fill in their **Name, Matricule, and Email**.
7. Their data is sent to the Node.js server and stored in the **PIN-scoped session bucket**.
8. The lecturer refreshes the Flutter dashboard and sees the updated student list.
9. After class, the lecturer ends the session and generates a **PDF or Excel report** with cumulative attendance statistics.

---

## 4. Key Concepts

### Session
A single class or lecture. Every session has:
- **Course Name & Code** (e.g., "Computer Science 101", "CS101")
- **6-digit PIN** — students type this to join
- **Session Token** — a secure fallback for QR-code-based joining
- **Grace Period** — extra minutes allowed after the official start
- **Required Connection Time** — minimum minutes a student must stay to be "verified"
- **Max Attendance Count** — the total number of possible attendance marks (for percentage calculations)
- **Duration** — how long the session stays active before auto-ending

### PIN vs. QR Code
The system supports **two ways** for students to join:

| Method | How It Works | Best For |
|--------|--------------|----------|
| **PIN** | Lecturer writes a 6-digit number on the board. Students type it into the web form. | Fixed classrooms with printed posters |
| **QR Code** | The Flutter app displays a QR code. Students scan it with their camera. | Ad-hoc sessions, no poster available |

Both methods ultimately lead to the same web page; the difference is how the session is identified.

### Verified vs. Pending
- **Verified** ✅ — The student has been connected for at least the `requiredConnectionMinutes`.
- **Pending** ⏳ — The student registered but has not yet met the minimum time requirement.
- **Manual** ✋ — The lecturer added the student by hand (e.g., phone battery died).

### Cumulative Attendance (Master Roster)
The system can track attendance across **multiple sessions** (T.P. 1, T.P. 2, T.P. 3, etc.).
- Lecturers upload a previous session's PDF or Excel file.
- The app parses the old data and increments each verified student's total by +1.
- Unverified students keep their old total (freeze rule).
- Reports show both the daily snapshot and the cumulative master roster.

### Device Fingerprinting
To prevent one student from registering multiple classmates on their phone, the Flutter app captures a **device fingerprint** using `device_info_plus`. The same device cannot register twice in the same session.

### GPS Location Collection
When students register through the **Flutter app** (not the web form), the app can optionally collect their GPS coordinates using `geolocator` and `geocoding`. This helps verify that students are physically in the classroom. Location data is stored in Firebase Cloud if cloud sync is enabled.

---

## 5. For Lecturers — Step-by-Step

### Before Class

#### 1. Start the Node.js Server (on your PC)
Open Command Prompt or PowerShell **as Administrator** and run:
```cmd
cd "c:\Users\Lenovo\Desktop\Android App\Att_App ui\attendance_app-first"
node server.js
```
Or simply double-click `start-server.bat`.

You should see output like:
```
========================================
Attendance Server running on port 5501
Static folder: C:\...\public
----------------------------------------
Available on these addresses:
  http://192.168.137.1:5501/public/hotspot.html  (Wi-Fi)
Test endpoint: http://localhost:5501/ping
========================================
```

> **Leave this terminal open.** Closing it stops the server.

#### 2. Enable Windows Mobile Hotspot
1. Press **Windows + I** → **Network & Internet → Mobile Hotspot**
2. Turn **ON** "Share my Internet connection with other devices"
3. Note the **Network name** and **Password** you set

#### 3. Open the Flutter App on Your Phone
- Install the app via USB debugging (`flutter run`) or transfer the APK.
- Make sure your phone is connected to the **same network** as the PC (either the PC's hotspot or the same Wi-Fi router).

### During Class

#### 4. Create a Session
1. Tap **"Create Session"** on the home screen.
2. Fill in:
   - **Course Name** (e.g., "Data Structures")
   - **Course Code** (optional, e.g., "CS201")
   - **Lecturer Name**
   - **Grace Period** (minutes)
   - **Required Connection Time** (minutes)
   - **Max Attendance Count** (for percentage calculations)
   - **Session Duration** (minutes until auto-end)
3. Tap **"Start Session"**.

The app will show a large **6-digit PIN** and a QR code.

#### 5. Display the PIN or QR Code
- **PIN Method:** Write the PIN on the whiteboard or project it.
- **QR Method:** Hold up your phone so students can scan the QR code.

#### 6. Monitor Attendance
- The **Dashboard** shows:
  - Total registered students
  - Verified count
  - Pending count
  - Wi-Fi device count (approximate)
- Tap the **refresh icon ↻** to update the list.
- Students appear as they register via the web form.

#### 7. Manage Students
- **Remove a student:** Swipe or tap delete on their record.
- **Add manually:** If a student's phone died, tap "Add Manual Entry" and type their details.
- **Upload previous session:** Tap the upload button to load a previous PDF/Excel so cumulative attendance is calculated.

### After Class

#### 8. End Session & Generate Report
1. Tap **"End Session"**.
2. Choose to generate a **PDF** or **Excel** report.
3. The report includes:
   - Daily snapshot (who attended today)
   - Master roster (cumulative attendance across all sessions)
   - T.P table (total presence count and percentage)
   - Lecturer signature (if configured)

#### 9. Cloud Backup (Optional)
- Log in to **Firebase** via the Cloud Login page.
- Your sessions and records will sync automatically.
- Access them from any device by signing in with the same account.

---

## 6. For Students — Step-by-Step

### Method A: PIN Entry (Recommended)

1. **Connect to Wi-Fi**
   - Open your phone's Wi-Fi settings.
   - Connect to the lecturer's hotspot (e.g., "LecturerHotspot").
   - Enter the password if asked.

2. **Open Browser**
   - Open Chrome, Safari, or any browser.
   - Go to: `http://192.168.137.1:5501/public/hotspot.html`
   - *(Or scan the permanent poster QR code if one is posted in the classroom.)*

3. **Enter the PIN**
   - Type the 6-digit PIN the lecturer wrote on the board.
   - The page will verify the PIN and show the **course name** and **lecturer name**.

4. **Fill the Form**
   - **Username:** Your full name
   - **Matricule:** Your student ID number
   - **Email:** Your school email

5. **Tap "Validate & Register"**
   - You should see: **"✅ Successfully Registered!"**

### Method B: QR Code Scan

1. Connect to the lecturer's Wi-Fi hotspot.
2. Open your **camera app** or a QR scanner.
3. Point it at the QR code on the lecturer's phone.
4. Tap the link that appears.
5. Fill in the form (same as Method A).

### Troubleshooting for Students

| Problem | Solution |
|---------|----------|
| "Cannot reach server" | Make sure Wi-Fi is on and connected to the lecturer's hotspot. Turn off mobile data temporarily. |
| "Invalid PIN" | Double-check the 6 digits with the lecturer. PINs expire when the session ends. |
| "This device is already registered" | Only one registration per phone per session is allowed. |
| Page won't load | Try typing the URL manually instead of scanning. Reload the page. |

---

## 7. Feature Deep-Dives

### 7.1 Session Differentiation (PIN System)

When multiple lecturers run sessions in the same building, the system prevents data from mixing by using **PIN-scoped session buckets** on the server.

```
Lecturer A (PIN: 123456) ──▶ server.js ──▶ attendees[123456]
Lecturer B (PIN: 987654) ──▶ server.js ──▶ attendees[987654]
```

Each lecturer's dashboard only fetches attendees for their own PIN.

### 7.2 Cumulative Attendance (T.P. Tracking)

The system tracks attendance across multiple class sessions:

1. **Upload previous report** — Select a previous PDF or Excel file.
2. The app parses the "Master Roster" section to extract each student's current total.
3. During the new session, verified students get **+1** added to their total.
4. Unverified students keep their old total (freeze rule).
5. The new report shows:
   - **Previous Total**
   - **New Total**
   - **Change (+/-)**
   - **Percentage** (New Total / Max Attendance Count)

### 7.3 Digital Signature

Lecturers can save a digital signature in the app:
1. Go to **Signature Setup**.
2. Draw your signature on the pad.
3. Save it.

The signature is embedded at the bottom of every generated PDF report, along with the lecturer's name.

### 7.4 Cloud Integration (Firebase)

When signed in, the app syncs to Firebase:

| Feature | Description |
|---------|-------------|
| **Authentication** | Lecturers sign in with email/password |
| **Firestore** | Sessions and attendance records stored in real-time database |
| **Storage** | PDF/Excel exports uploaded for download from any device |
| **Location Data** | GPS coordinates of student registrations stored per record |
| **Offline Support** | Data is saved locally first; syncs to cloud when online |

**Firestore Data Path:**
```
lecturers/{lecturerUid}/sessions/{sessionId}/records/{recordId}
```

### 7.5 PDF Parsing (Previous Session Upload)

The Node.js server can parse previously generated PDF reports to extract student data:
- Upload a PDF via the Flutter app.
- The server extracts text using `pdf-parse`.
- It looks for the **MASTER ROSTER** section and parses matricules, names, and total presence counts.
- This data is used as the baseline for cumulative attendance in the new session.

### 7.6 Auto-End Sessions

Sessions automatically end after the configured `durationMinutes` to prevent forgotten sessions from running forever. The app also checks for expired sessions on startup.

### 7.7 Network Discovery (Wi-Fi Device Count)

The app can scan the Wi-Fi subnet (e.g., `192.168.137.x`) to estimate how many devices are connected to the hotspot. This is a best-effort count and may differ from actual registered students.

---

## 8. Architecture & Data Flow

### 8.1 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              LECTURER PHONE                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ Flutter UI   │  │ Provider     │  │ SessionSvc   │  │ CloudSvc     │    │
│  │ (Pages)      │──│ (State Mgmt) │──│ (Business)   │──│ (Firebase)   │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
│         │                                   │                               │
│         └───────────────────────────────────┘                               │
│                     Local Storage (SharedPreferences)                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                   HTTP (WiFi LAN)  │  HTTP
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              LECTURER PC                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Node.js Express Server (server.js)                                 │   │
│  │  ├─ Serves public/hotspot.html (student web form)                  │   │
│  │  ├─ POST /connect (student registration)                           │   │
│  │  ├─ GET  /api/attendees?pin=XXXXXX (fetch list)                    │   │
│  │  ├─ GET  /export?pin=XXXXXX (generate PDF)                         │   │
│  │  ├─ POST /api/parse-pdf (extract previous session data)            │   │
│  │  └─ In-memory PIN-scoped session storage (Map)                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ▲
                   WiFi Hotspot     │     HTTP
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                              STUDENT PHONES                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Web Browser → hotspot.html                                         │   │
│  │  ├─ Enter PIN → validate-pin                                        │   │
│  │  ├─ Fill form → POST /connect                                       │   │
│  │  └─ Shows course info & confirmation                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Data Models

#### `AttendanceSession`
Represents a single lecture session.
```dart
id, courseName, courseCode, lecturerId, startTime, endTime,
gracePeriodMinutes, requiredConnectionMinutes, maxAttendanceCount,
sessionNumber, isActive, durationMinutes, lecturerName,
sessionPin (6-digit), sessionToken (secure)
```

#### `AttendanceRecord`
Represents one student's attendance in one session.
```dart
id, sessionId, studentId, matricule, studentName, email,
joinedAt, verifiedAt, connectionDurationMinutes, isVerified,
isManual, deviceFingerprint, location (GPS), createdAt, updatedAt
```

#### `Student`
Represents a registered student entity.
```dart
id, matricule, name, email, deviceFingerprint, createdAt, updatedAt
```

### 8.3 State Management Flow

```
UI (Pages) → Provider (AttendanceProvider) → Services → Storage / Server / Cloud
                ↑______________________________________________|
                         (notifyListeners updates UI)
```

The `AttendanceProvider` is the single source of truth for:
- Active session
- Current attendance records
- Server stats
- Wi-Fi device count
- Previous attendance data
- Loading and error states

---

## 9. Technology Stack

### Mobile App (Flutter)
| Package | Purpose |
|---------|---------|
| `flutter` | UI framework |
| `go_router` | Navigation |
| `provider` | State management |
| `shared_preferences` | Local data storage |
| `http` | REST API calls to Node.js server |
| `excel` | Excel report generation |
| `pdf` + `printing` | PDF report generation |
| `qr_flutter` | QR code display |
| `device_info_plus` | Device fingerprinting |
| `geolocator` + `geocoding` | GPS location collection |
| `firebase_core` + `cloud_firestore` + `firebase_auth` + `firebase_storage` | Cloud sync |
| `file_picker` | Upload previous session files |
| `share_plus` | Share exported reports |
| `network_discovery` | Wi-Fi subnet scanning |
| `uuid` | Unique IDs |
| `intl` | Date/time formatting |
| `path_provider` | File system access |

### Server (Node.js)
| Package | Purpose |
|---------|---------|
| `express` | Web server framework |
| `multer` | File upload handling |
| `pdf-parse` | Text extraction from PDFs |
| `pdfkit` | PDF generation |

### Cloud (Firebase)
| Service | Purpose |
|---------|---------|
| **Firebase Authentication** | Lecturer login |
| **Cloud Firestore** | Structured data storage (sessions, records) |
| **Firebase Storage** | Exported file hosting |

---

## 10. File & Folder Guide

### Root Level
| File | Purpose |
|------|---------|
| `server.js` | Node.js Express server — serves web form, receives student data, stores sessions, generates PDFs, parses uploaded PDFs |
| `package.json` | Node.js dependencies |
| `start-server.bat` | Windows batch script to start the server with automatic firewall rule creation |
| `pubspec.yaml` | Flutter dependencies and app metadata |

### `public/`
| File | Purpose |
|------|---------|
| `hotspot.html` | The student web form — enter PIN, see course info, fill name/matricule/email, submit registration |

### `lib/` (Flutter Source)
| Path | Purpose |
|------|---------|
| `main.dart` | App entry point — initializes server config, Firebase, providers, and GoRouter |
| `nav.dart` | GoRouter configuration with all app routes |
| `theme.dart` | Light and dark Material Design themes |

#### `lib/models/`
| File | Purpose |
|------|---------|
| `session.dart` | `AttendanceSession` data model |
| `attendance_record.dart` | `AttendanceRecord` and `AttendanceLocation` models |
| `student.dart` | `Student` data model |
| `user.dart` | `User` data model |

#### `lib/pages/`
| File | Purpose |
|------|---------|
| `home_page.dart` | Landing screen with role selection (Lecturer / Student) |
| `session_setup_page.dart` | Form to create a new session (course name, PIN generation, timing rules) |
| `lecturer_dashboard_page.dart` | Main dashboard — shows PIN, QR code, student list, stats, refresh, export buttons |
| `student_registration_page.dart` | In-app student registration (used when students use the Flutter app instead of the web form) |
| `signature_setup_page.dart` | Canvas for lecturers to draw and save their digital signature |
| `cloud_login_page.dart` | Firebase Authentication login/sign-up screen |
| `cloud_sessions_page.dart` | Browse and download past sessions from Firebase Cloud |

#### `lib/services/`
| File | Purpose |
|------|---------|
| `session_service.dart` | Core business logic — create/end sessions, register students, generate PINs/tokens, connection tracking, auto-end timers |
| `api_service.dart` | HTTP client for talking to the Node.js server — fetch attendees, stats, PDFs, reset sessions, remove attendees, parse PDFs |
| `storage_service.dart` | Local persistence using `SharedPreferences` — sessions, records, students |
| `cloud_service.dart` | Firebase integration — auth, Firestore CRUD, Storage uploads, real-time streams, offline sync |
| `pdf_service.dart` | Flutter-side PDF generation with daily snapshot, master roster, T.P table, and signature embedding |
| `excel_service.dart` | Excel report generation and previous session file parsing (Excel + PDF via server) |
| `signature_service.dart` | Save/load lecturer signature and name from local storage |
| `location_service.dart` | GPS permission handling, coordinate fetching, reverse geocoding |
| `device_service.dart` | Generate unique device fingerprints to prevent duplicate registrations |
| `network_discovery_service.dart` | Scan Wi-Fi subnet for connected devices |
| `server_config.dart` | Auto-detect server IP (emulator loopback vs. hotspot IP) |
| `file_service.dart` | Save and share files via native share dialogs |

#### `lib/providers/`
| File | Purpose |
|------|---------|
| `attendance_provider.dart` | Central state manager — exposes session, records, stats, loading states to UI; orchestrates service calls |

#### `lib/widgets/`
| File | Purpose |
|------|---------|
| `signature_pad.dart` | Custom drawing canvas for digital signatures |

---

## 11. Troubleshooting

### The App Can't Find the Server
1. Check that `node server.js` is running and the terminal is open.
2. Verify your phone is on the **same Wi-Fi network** as the PC.
3. Check the IP address in `lib/services/server_config.dart` matches your hotspot IP.
4. Run `ipconfig` on your PC and look for the "Mobile Hotspot" IPv4 address.
5. Update the IP in:
   - `server.js` (optional, it auto-detects)
   - `lib/services/server_config.dart`
   - `lib/pages/lecturer_dashboard_page.dart` (QR URL)

### Windows Firewall Blocks Students
Run PowerShell as Administrator:
```powershell
New-NetFirewallRule -DisplayName "Attendance Server" -Direction Inbound -LocalPort 5501 -Protocol TCP -Action Allow
```
Or use `start-server.bat` which does this automatically.

### Port 5501 Is Already in Use
```cmd
netstat -ano | findstr :5501
for /f "tokens=5" %a in ('netstat -ano ^| findstr :5501') do taskkill /F /PID %a
```
Then restart `node server.js`.

### Firebase Cloud Sync Not Working
1. Ensure `google-services.json` is in `android/app/`.
2. Check that Firebase Authentication, Firestore, and Storage are enabled in the Firebase Console.
3. Verify the lecturer is signed in.
4. Check internet connectivity.

### Student Phone Can't Load the Page
1. Turn off **mobile data** on the student phone so it doesn't bypass Wi-Fi.
2. Type the URL manually: `http://192.168.137.1:5501/public/hotspot.html`
3. Ensure the student is connected to the lecturer's hotspot, not a different Wi-Fi.

### APK Installation Fails
```cmd
flutter clean
flutter pub get
flutter build apk --debug
```
Then uninstall the old app from the phone before installing the new one.

---

## 12. Security & Privacy

| Concern | Mitigation |
|---------|------------|
| **Fake registrations** | Device fingerprinting prevents multiple registrations from the same phone per session |
| **Remote check-ins** | GPS location collection (optional) verifies physical presence |
| **Session collision** | 6-digit PINs isolate sessions; server rejects duplicate active PINs |
| **Token tampering** | Session tokens are 256-bit base64-encoded random strings |
| **Data privacy** | All hotspot traffic stays on the local LAN; no internet required |
| **Cloud access** | Firestore security rules ensure lecturers can only access their own data |
| **Signature forgery** | Digital signatures are stored locally on the lecturer's device |

---

## Quick Reference: Common Commands

```bash
# Start the server
node server.js

# Or use the batch file (Windows)
start-server.bat

# Build APK
flutter build apk --debug

# Install and run on connected device
flutter run

# Check what is using port 5501
netstat -ano | findstr :5501

# Add firewall rule (PowerShell Admin)
New-NetFirewallRule -DisplayName "Attendance Server" -Direction Inbound -LocalPort 5501 -Protocol TCP -Action Allow
```

---

## Summary

The Hotspot Attendance System is a complete, offline-capable attendance solution that combines:
- A **Flutter mobile app** for lecturers to manage sessions and generate reports
- A **Node.js server** running on the lecturer's PC to collect student registrations via a web form
- **Firebase Cloud** for optional backup, multi-device access, and GPS verification

It is designed for real-world classroom use where internet access is unreliable, privacy matters, and lecturers need both daily snapshots and cumulative attendance tracking across an entire semester.

