# OwHAS — Improvement Plan

Full system review covering the Node.js backend (`server.js`), student web page
(`hotspot.html`), and the Flutter lecturer app (`lib/`).  
Items are grouped by theme, ordered from most impactful to least.

---

## 1. Critical Bugs — Fix These First

### 1.1 `storage_service.dart` — Student data deleted across all sessions

**File:** `lib/services/storage_service.dart:147`  
**Problem:** `clearSessionData()` removes the SharedPreferences key `'students'`, which is
shared across every session.  Ending session A wipes the student roster for
session B.

```dart
// WRONG — deletes students from every session
await _prefs!.remove('students');

// FIX — scope students to their session
await _prefs!.remove('students_$sessionId');
// (and update saveStudent / getStudents to use 'students_$sessionId' as key)
```

---

### 1.2 `attendance_provider.dart` — Silent server failure: student thinks they are registered but is not

**File:** `lib/providers/attendance_provider.dart:212–216`  
**Problem:** Server registration is marked "best-effort".  If the request fails, the
student is saved locally as `present` but the lecturer's export shows no record
of them.  No error is surfaced.

**Fix:** After a registration attempt fails, set a visible warning in the provider and
show a persistent snackbar asking the lecturer to check the student manually.

---

### 1.3 `lecturer_dashboard_page.dart` — Auto-refresh timer stacking

**File:** `lib/pages/lecturer_dashboard_page.dart:29–53`  
**Problem:** `_startAutoRefresh()` re-schedules itself after each call with
`Future.delayed`.  If `refreshRecords()` takes longer than the delay (network
slow, many students), the next timer fires before the previous one finishes and
timers pile up.

```dart
// FIX — cancel before re-scheduling
_refreshTimer?.cancel();
_refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
  provider.refreshRecords();
  provider.refreshWifiDeviceCount();
});
```

Switch to `Timer.periodic` with a single timer reference so only one is
ever alive.

---

### 1.4 `server.js` — All sessions lost on server crash or restart

**Problem:** `activeSessions` is an in-memory `Map`.  If the Node.js process exits
(power cut, crash, Windows Update reboot mid-class), all attendance data
disappears permanently.

**Fix (minimal — no external DB needed):** Write each session to a JSON file on
every write operation.  On startup, reload from file:

```javascript
const SESSION_FILE = path.join(__dirname, 'sessions.json');

function persistSessions() {
    const obj = {};
    for (const [pin, s] of activeSessions.entries()) {
        // pendingFaces cannot be serialised (Map) — drop it, it is transient
        const { pendingFaces, ...rest } = s;
        obj[pin] = rest;
    }
    fs.writeFileSync(SESSION_FILE, JSON.stringify(obj, null, 2));
}

// On startup
if (fs.existsSync(SESSION_FILE)) {
    const saved = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
    for (const [pin, s] of Object.entries(saved)) {
        if (new Date() < new Date(s.expiresAt)) {
            s.pendingFaces = new Map();
            activeSessions.set(pin, s);
        }
    }
}
```

Call `persistSessions()` inside every write endpoint
(`/api/session-init`, `/api/biometric-connect`, `/api/end-session`).

---

## 2. Security

### 2.1 Add rate limiting to prevent brute-force PIN guessing

**File:** `backend/server.js`  
**Problem:** The 6-digit PIN only has 1,000,000 combinations.  A student can
automate guesses through `/api/validate-pin` with no throttle.

**Fix:** Install `express-rate-limit` (already listed in package.json or add it):

```javascript
const rateLimit = require('express-rate-limit');

const pinLimiter = rateLimit({
    windowMs: 5 * 60 * 1000,   // 5 minutes
    max: 10,                    // 10 attempts per IP per window
    message: 'Too many PIN attempts. Wait 5 minutes.',
});
app.use('/api/validate-pin', pinLimiter);
app.use('/api/biometric-connect', pinLimiter);
```

Cost: 1 npm package, 5 lines.

---

### 2.2 Increase PIN entropy or add course-code confirmation

**Problem:** A student who guesses the PIN joins any active class, not just their own.

**Fix (no code change needed):** Require students to also enter the course code
after PIN validation.  The course code is displayed on the lecturer's screen and
is hard to guess from outside the room.  Server already returns `courseName`
after PIN validation — add a hidden `courseCode` field and validate it in
`/api/biometric-connect`.

---

### 2.3 `signature_service.dart` — Signature stored unencrypted on disk

**File:** `lib/services/signature_service.dart:18–19`  
**Problem:** The lecturer's signature (a PNG) is stored as base64 in
`SharedPreferences`.  On a rooted Android device anyone can read it and reuse
it.

**Fix:** Use the `flutter_secure_storage` package to store the base64 string
instead of SharedPreferences.  It uses Android Keystore / iOS Keychain.

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
const _secureStorage = FlutterSecureStorage();
await _secureStorage.write(key: 'lecturer_signature', value: base64Str);
```

---

### 2.4 `hotspot.html` — face-api.js load failure is silently swallowed

**File:** `backend/public/hotspot.html`  
**Problem:** If the model files do not load (CDN blocked, corrupted shard, slow
connection), the app continues and the face-capture button is still tappable.
The student gets a JavaScript error that is not shown to them.

**Fix:** Add a visible blocking error state if models fail, so students know to
refresh and the lecturer knows to re-run setup.

```javascript
// In _initFaceApi(), if any model load rejects:
this._status(
  'Face recognition models failed to load. Ask your lecturer to re-run start-server.bat.',
  'error'
);
this.el.captureBtn.disabled = true;
```

---

## 3. Student UX — `hotspot.html`

### 3.1 No camera preview before capture

**Problem:** Students tap "Capture Face" and immediately get a file-picker or camera
intent.  They have no live preview to check framing, lighting, or angle before
taking the photo.  This leads to rejected captures and frustrated retries.

**Fix:** Replace the file-input approach with a `<video>` stream using
`getUserMedia()`.  Face-api.js supports running detection on a video feed in
real time and adding a face-in-frame guide overlay.

```html
<video id="videoEl" autoplay muted playsinline></video>
<canvas id="overlayCanvas"></canvas>
```

```javascript
// Draw detection box and landmarks live on overlayCanvas
const stream = await navigator.mediaDevices.getUserMedia({ video: true });
videoEl.srcObject = stream;
// Run detectSingleFace on videoEl in a loop, draw bounding box,
// capture automatically when landmarks are stable for 1 second.
```

This is the most impactful UX improvement for students.

---

### 3.2 No model-loading progress indicator

**Problem:** When a student opens `hotspot.html` for the first time, the page blocks
silently for 5–10 seconds loading the face-api models (~7 MB).  Students see
nothing and often refresh, restarting the download.

**Fix:** Show a progress bar or step indicator during load:

```javascript
this._status('Loading face recognition (1/3)…', 'info');
await faceapi.nets.tinyFaceDetector.loadFromUri('/models');
this._status('Loading face recognition (2/3)…', 'info');
await faceapi.nets.faceLandmark68Net.loadFromUri('/models');
this._status('Loading face recognition (3/3)…', 'info');
await faceapi.nets.faceRecognitionNet.loadFromUri('/models');
this._status('Ready — enter the session PIN.', 'success');
```

---

### 3.3 No retry limit for face rejections

**Problem:** A student whose face is rejected (bad lighting, not registered) can
attempt capture infinitely.  This wastes time and ties up the session.

**Fix:** After 3 failed captures (non-unique face or detection failure), show a
message: "Face could not be verified after 3 attempts. Please see your lecturer."
Disable the capture button.  The lecturer can add them manually via the Flutter
app.

---

### 3.4 Session expiry not shown to student

**Problem:** The session has a timer (`expiresAt`), but the student web page has no
visible countdown.  Students who arrive late don't know how much time they have
left to register.

**Fix:** After PIN validation, the server returns or you can derive the expiry from
the session.  Show a countdown in the status bar:

```
⏱  Session closes in 14 min
```

---

### 3.5 Add geofence feedback before submission

**Problem:** If GPS is required and the student is outside the 50 m radius, they fill
in their details and hit Submit — only then do they learn they are out of range.
This is frustrating on slow devices.

**Fix:** After PIN validation succeeds, immediately request GPS and check distance
against the session's `targetLocation`.  If out of range, warn before step 2
("You appear to be 80 m from the classroom.  Move closer before submitting.")

---

## 4. Lecturer UX — Flutter App

### 4.1 No "Copy PIN" shortcut on the dashboard

**Problem:** When a student calls out "what is the PIN?", the lecturer has to read 6
digits off the QR screen.  There is no tap-to-copy shortcut.

**Fix:** Add a `GestureDetector` wrapping the PIN text that copies to clipboard and
shows a brief SnackBar: "PIN copied".

```dart
GestureDetector(
  onTap: () {
    Clipboard.setData(ClipboardData(text: session.pin));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN copied to clipboard')),
    );
  },
  child: Text(session.pin, style: ...),
)
```

---

### 4.2 Auto-refresh runs sequentially instead of in parallel

**File:** `lib/pages/lecturer_dashboard_page.dart:50–51`  
**Problem:** `refreshRecords()` and `refreshWifiDeviceCount()` are called one after
the other.  Both are network calls, so the dashboard takes twice as long to update.

**Fix:**

```dart
await Future.wait([
  provider.refreshRecords(),
  provider.refreshWifiDeviceCount(),
]);
```

---

### 4.3 Session setup: no validation that duration > grace period

**File:** `lib/pages/session_setup_page.dart`  
**Problem:** A lecturer can set duration = 5 minutes and grace period = 10 minutes
(which is logically impossible — the grace period extends beyond the session).
The server accepts it silently.

**Fix:** In `_startSession()`, validate before sending:

```dart
if (gracePeriod >= duration) {
  _showError('Grace period must be shorter than session duration.');
  return;
}
```

---

### 4.4 No CSV export option

**Problem:** The app exports PDF only.  Many departments need data in Excel/CSV for
their own systems.  The server already returns structured JSON from
`/api/attendees`.

**Fix:** Add a CSV export button alongside the PDF export.  The Flutter `csv` package
can convert the attendee list in a few lines, and `file_service.dart` already
handles saving and sharing:

```dart
String toCsv(List<AttendanceRecord> records) {
  final header = 'Name,Matricule,Email,Time,Verified\n';
  final rows = records.map((r) =>
    '${r.studentName},${r.matricule},${r.email},${r.time},${r.faceVerified}'
  ).join('\n');
  return header + rows;
}
```

---

### 4.5 Server detection: manual IP entry fallback

**File:** `lib/services/server_config.dart`  
**Problem:** Server auto-detection pings 500+ IPs in parallel.  If the hotspot uses
a non-standard subnet, all probes fail and the app falls back silently to
`192.168.137.1`.  No way for the lecturer to override.

**Fix:** Add a settings page with a manual IP field.  Save the override in
SharedPreferences.  On startup, if an override exists, skip the scan and use it
directly.

---

## 5. Performance

### 5.1 `attendance_provider.dart` — Statistics recomputed on every call

**File:** `lib/providers/attendance_provider.dart:538–555`  
`getStats()` recalculates averages, counts, and durations over every record on
every UI rebuild.  With 200 students it runs thousands of times.

**Fix:** Cache `_statsCache` and invalidate it only when `refreshRecords()` writes
new data.

---

### 5.2 `storage_service.dart` — Full list re-serialised on every save

**File:** `lib/services/storage_service.dart:20–33`  
Every `saveAttendanceRecord()` call reads the entire list, appends, and writes
the full JSON back.  With 200 students this is 200 reads and 200 full writes.

**Fix (medium-term):** Replace SharedPreferences with SQLite (`sqflite` package).
Each write becomes a single `INSERT OR REPLACE` row instead of a full JSON
re-serialisation.

---

### 5.3 `server.js` — PDF generation blocks the event loop

**Problem:** `generateAttendancePDF()` builds the full PDF synchronously in the main
Node.js thread.  With a large class (150+ students), this can block all other
requests for several hundred milliseconds.

**Fix:** Move PDF generation to a `worker_thread` or `child_process.fork()`.  
Alternatively, pipe the PDFKit output directly to the response stream rather than
buffering the entire document in memory first.

---

### 5.4 `server_config.dart` — 500+ parallel pings

**File:** `lib/services/server_config.dart:30–41`  
**Problem:** All three subnets (254 IPs each) are probed simultaneously at startup.
This hammers the hotspot network and can interfere with other connected devices.

**Fix:** Probe the three known fixed IPs first (`192.168.137.1`,
`192.168.43.1`, `10.0.2.2`).  Only start the full subnet scan if those fail.
This covers 95 % of cases instantly with 3 requests instead of 762.

```dart
const knownIps = ['192.168.137.1', '192.168.43.1', '10.0.2.2'];
for (final ip in knownIps) {
  if (await _probe('http://$ip:5501')) return 'http://$ip:5501';
}
// Fall back to full scan only if needed
```

---

## 6. Missing Features Worth Adding

### 6.1 Session history / past sessions screen

Currently the lecturer can only see the live session.  There is no way to view or
re-export a past session without the server still running.  Implement a
"Past Sessions" screen that reads from the persisted `sessions.json` (once 1.4 is
done) or from `StorageService`.

---

### 6.2 Manually add a student from the dashboard

**File:** `lib/pages/lecturer_dashboard_page.dart`  
For students who cannot complete face verification (phone camera broken,
accommodation needed), the lecturer should be able to tap "Add manually", fill in
name/matricule/email, and the server adds them with `faceVerified: false`.  The
PDF should clearly mark these rows as "Manual".

The server endpoint `/api/biometric-connect` can accept a `manualOverride: true`
field when the request comes from the lecturer's session token, which bypasses the
`faceId` requirement.

---

### 6.3 Offline-first sync queue

**Problem:** If the server is off for 30 seconds (brief crash), every attendance
record submitted during that window is lost.  The Flutter app has no queue.

**Fix:** In `api_service.dart`, wrap every POST in a retry queue stored in
SharedPreferences.  On reconnect, flush the queue automatically.

---

### 6.4 Face capture retry cap + lecturer notification

When a student's face is rejected by the server as a duplicate (proxy attempt),
the server logs it but the lecturer is not notified in real time.  Add a
`/api/events` SSE endpoint (Server-Sent Events) or include a `rejections` counter
in `/api/attendees` response.  The Flutter dashboard shows "⚠ 2 suspicious
attempts" on the relevant student row.

---

### 6.5 Session QR code printed on PDF report

The generated attendance PDF should include a small QR code showing the session
date, course code, and PIN used.  This makes archiving easier — scanning the PDF
later tells you exactly what session it belongs to.  `pdfkit` supports images;
the `qrcode` npm package generates a PNG buffer in one call.

---

### 6.6 Dark mode for `hotspot.html`

The page is displayed in a dark lecture hall on student phones.  A `@media
(prefers-color-scheme: dark)` stylesheet costs 20 lines of CSS and dramatically
reduces eye strain.

---

## 7. Code Quality

### 7.1 `server.js` — `parseMasterRosterLine` is 57 lines of brittle regex

**File:** `backend/server.js:299–356`  
This function has 6 different matricule patterns and multiple name-cleaning
substitutions.  It is the most fragile part of the backend.

**Recommendation:** Add a dedicated unit test file `backend/test-roster-parse.js`
with 10–15 sample lines from real PDFs.  Run it with `node test-roster-parse.js`
before each release.  Maintain the test file alongside the function.

---

### 7.2 `api_service.dart` — Repeated try-catch boilerplate

Every method has the same `try { ... } catch (e) { throw Exception('Failed to X: $e'); }` pattern.
Extract a helper:

```dart
Future<T> _request<T>(String label, Future<T> Function() fn) async {
  try {
    return await fn();
  } catch (e) {
    throw Exception('$label: $e');
  }
}
```

---

### 7.3 `start-server.bat` — No Node.js version check

The bat checks only that `node` exists, not that it is v14.17+.  `randomUUID()`
requires Node 14.17.  On an older Node install the server crashes with a cryptic
error at startup.

**Fix:**

```bat
for /f "tokens=1 delims=v." %%i in ('node -v') do set NODE_MAJOR=%%i
if %NODE_MAJOR% LSS 14 (
    echo Node.js 14 or higher is required. Please update at https://nodejs.org/
    pause & exit /b 1
)
```

---

### 7.4 `pubspec.yaml` — Outdated packages with known issues

| Package | Current | Latest | Issue |
|---------|---------|--------|-------|
| `http` | `^0.13.0` | `1.2.x` | Missing security and TLS fixes |
| `google_mlkit_face_detection` | `^0.11.0` | `^0.13.x` | Deprecated APIs on Android 14 |

Run `flutter pub outdated` and update these two at minimum.

---

## 8. Priority Summary

| Priority | Item | Effort |
|----------|------|--------|
| P0 | 1.1 — student data wiped across sessions | 30 min |
| P0 | 1.2 — silent registration failure | 1 hour |
| P0 | 1.3 — refresh timer stacking | 15 min |
| P0 | 1.4 — sessions lost on server restart (persist to JSON) | 2 hours |
| P1 | 2.1 — add PIN rate limiting | 20 min |
| P1 | 3.1 — live camera preview (replace file-input) | 1 day |
| P1 | 3.2 — model loading progress | 30 min |
| P1 | 4.1 — Copy PIN shortcut | 15 min |
| P1 | 4.4 — CSV export | 2 hours |
| P2 | 2.3 — secure signature storage | 1 hour |
| P2 | 3.4 — session countdown on student page | 1 hour |
| P2 | 4.5 — manual server IP override | 1 hour |
| P2 | 5.4 — fix 500+ parallel pings | 30 min |
| P2 | 6.2 — manual add student from dashboard | 3 hours |
| P3 | 6.1 — session history screen | 1 day |
| P3 | 6.3 — offline sync queue | 1 day |
| P3 | 5.2 — SQLite for local storage | 2 days |


implement the imp.md changing the PIN code to a 4 digit PIN 