# OwHAS — JavaScript Files Explained

This document explains the role of every `.js` file that belongs to the
project (i.e. the four files you own and edit, not the hundreds inside
`node_modules/`).

---

## File Map

```
backend/
├── server.js                    ← Main HTTP server (the heart of the system)
├── dns-server.js                ← Optional DNS interceptor for captive-portal
├── setup.js                     ← One-time offline asset downloader
├── src/
│   └── services/
│       └── pdfService.js        ← PDF report generator
└── public/
    └── hotspot.html             ← Student web app (contains embedded JS)
```

---

## 1. `server.js` — Main HTTP/API Server

**Entry point.** Started by `start-server.bat` with `node server.js`.  
Everything the Flutter app and student web page talk to goes through this file.

### What it does

| Responsibility | Detail |
|----------------|--------|
| **Serves static files** | Serves `public/hotspot.html`, `public/lib/face-api.min.js`, and `public/models/*` over HTTP so student phones can load them without internet |
| **Session lifecycle** | `POST /api/session-init` — creates a session keyed on a 4-digit PIN; `POST /api/end-session` — deletes it |
| **PIN validation** | `POST /api/validate-pin` — verifies the student's PIN against active sessions; rejects expired sessions automatically |
| **Student registration** | `POST /connect` — classic (non-biometric) registration; `POST /api/biometric-connect` — biometric path that requires a valid face token |
| **Face verification** | `POST /api/verify-face` — receives the student's 128-dim face descriptor, checks it for uniqueness against all descriptors already in the session, and issues a one-time `faceId` token if unique |
| **Attendance export** | `GET /api/attendees` — returns the full attendee list as JSON; `GET /api/generate-pdf` — streams an attendance PDF built by `pdfService.js` |
| **Master-roster upload** | `POST /api/parse-pdf` — receives the lecturer's roster PDF, parses it with `pdf-parse`, and extracts student names and matricules |
| **QR URL helper** | `GET /api/qr-url` — returns the correct `hotspot.html` URL based on the server's actual IP so the Flutter QR code always points to the right address |
| **Rate limiting** | `express-rate-limit` blocks more than 10 PIN attempts per IP per 5-minute window on `/api/validate-pin` and `/api/biometric-connect` |
| **Session persistence** | `persistSessions()` writes active sessions to `sessions.json` after every create/end operation; on startup the server reloads any sessions that have not yet expired — so a crash or reboot mid-class does not wipe attendance data |

### Key in-memory data structures

```javascript
// One entry per active session, keyed by the 4-digit PIN string
activeSessions = Map<pin, {
    courseName, courseCode, lecturerId, lecturerName,
    sessionToken,          // QR-code fallback (opaque UUID)
    targetLocation,        // GPS geofence centre { latitude, longitude }
    attendees: [],         // committed student records
    faceDescriptors: [],   // { faceId, matricule, name, descriptor: Float32[128] }
    pendingFaces: Map(),   // faceId → { descriptor, reservedAt, used }
    createdAt, expiresAt,
}>
```

### Important design decisions

- **PIN is the primary session key.** The 4-digit PIN is what students type.
  The `sessionToken` is a secondary opaque key used when the student scans a
  QR code instead.
- **Face tokens are one-time.** `/api/verify-face` issues a `faceId` UUID
  valid for 5 minutes. `/api/biometric-connect` marks it `used: true`
  immediately so it cannot be replayed.
- **Geofencing is optional.** If the lecturer did not enable GPS when creating
  the session, `targetLocation` is `null` and the location check is skipped.

---

## 2. `dns-server.js` — Captive-Portal DNS Interceptor

**Optional helper — not started by default.**  
Only needed if you want phones to be redirected to the attendance page
automatically when they connect to the hotspot (captive-portal behaviour).

### What it does

Runs a UDP DNS server on port 53 of the hotspot IP (`192.168.137.1`).  
Every DNS query that arrives — regardless of the domain name requested —
is answered with the same A record pointing to `192.168.137.1`.

```
Student phone asks: "what is the IP of google.com?"
dns-server.js answers: "192.168.137.1"
Phone opens: http://192.168.137.1 → redirected to hotspot.html
```

This is how hotel Wi-Fi login pages work. The effect is that as soon as a
student joins the hotspot, their browser pops up the attendance form.

### Why it is separate

- Requires Node.js to run as administrator (port 53 is privileged).
- Interferes with normal internet browsing — all DNS lookups are hijacked.
- Not required for the system to work; students can just open the QR code URL.
- Start manually when you want the captive-portal experience:
  ```bat
  node dns-server.js
  ```

### Dependency

Uses the `native-dns` npm package (not in the current `package.json` — must
be installed separately with `npm install native-dns` before use).

---

## 3. `setup.js` — One-Time Offline Asset Downloader

**Run once on the lecturer's PC before first use.**

```bat
node setup.js
```

### What it does

Downloads all assets that student phones would otherwise need to fetch from
the internet at registration time:

| Asset | Destination | Size |
|-------|-------------|------|
| `face-api.min.js` | `public/lib/face-api.min.js` | ~630 KB |
| TinyFaceDetector manifest + shard | `public/models/` | ~190 KB |
| FaceLandmark68 manifest + shard | `public/models/` | ~350 KB |
| FaceRecognition manifest + shards (×2) | `public/models/` | ~6.2 MB |

After `setup.js` completes, `server.js` serves all of these locally over the
hotspot LAN — no internet required during a live session.

### Smart caching

- Skips files that already exist and are larger than 1 KB (the minimum
  meaningful size for these assets).
- Re-downloads files smaller than 1 KB — these are stub/corrupted partial
  downloads from a previous interrupted run.
- Validates `Content-Length` against actual bytes received; aborts if they
  differ (catches truncated downloads).
- Downloads to a `.tmp` file first, then renames atomically — so a
  crash mid-download leaves no corrupt file behind.

### Source URLs

All assets come from the `jsDelivr` CDN pinned at `face-api.js@0.22.2`.
The pinned version ensures the model weights are always compatible with the
library version embedded in `hotspot.html`.

---

## 4. `src/services/pdfService.js` — PDF Report Generator

**Called by `server.js`** when the Flutter app requests an attendance PDF
(`GET /api/generate-pdf`).

### What it does

Accepts the session's attendee list and session metadata, then builds a
formatted A4 PDF using the `pdfkit` library and pipes it directly to the
HTTP response stream.

### Output structure

```
┌─────────────────────────────────────────┐
│  <Course Name> Attendance Report        │  ← Title (large, navy)
│  Course Code: IFT3025                   │  ← Subtitle (if code exists)
├─────────────────────────────────────────┤
│  Course / Date / Duration Required      │  ← Session metadata block
├──────────────┬──────────┬───────┬───────┤
│ Student Name │Matricule │ Email │Joined │  ← Table header (navy background)
├──────────────┼──────────┼───────┼───────┤
│ ...          │ ...      │  ●    │ HH:MM │  ← Alternating row shading
│              │          │  ●    │       │    ● green = verified
│              │          │  ●    │       │    ● orange = still pending
├──────────────────────────────────────────┤
│  Total: N    │ Verified: X │ Pending: Y  │  ← Summary box
└──────────────────────────────────────────┘
│  Generated by Hotspot Attendance System │  ← Footer
```

### Verification logic

A student is marked **Verified** (green dot) if the time elapsed since
`connectedAt` is ≥ `requiredConnectionMinutes`. Otherwise they are
**Pending** (orange dot). This threshold is set by the lecturer when creating
the session.

### Multi-page handling

If the attendee list overflows the page (more than ~38 rows at 18 px/row
before the 720 pt bottom margin), the function adds a new page and redraws
the table header automatically.

### Interface

```javascript
generateAttendancePDF(dataList, stream, sessionInfo)
//  dataList    – array of attendee objects { username, matricule, email,
//                connectedAt }
//  stream      – writable stream (the Express res object)
//  sessionInfo – { courseName, courseCode, requiredConnectionMinutes }
```

---

## 5. Embedded JS in `public/hotspot.html` — Student Web App

Technically not a `.js` file, but the `<script>` block inside `hotspot.html`
is a self-contained JavaScript application worth documenting here.

### What it does

Runs entirely in the student's phone browser. Three-step registration flow:

```
Step 1 — PIN         Step 2 — Face Scan       Step 3 — Details & Submit
────────────────     ─────────────────────     ──────────────────────────
Student types PIN    Camera opens (or          Name / Matricule / Email
→ POST /api/         file-picker fallback)     → POST /api/biometric-
  validate-pin       face-api.js extracts        connect
← Course name +      128-dim descriptor        ← "Successfully registered"
  lecturer shown     → POST /api/verify-face
                     ← unique? → faceId token
```

### Key responsibilities

| Part | Detail |
|------|--------|
| **Face-api model loading** | Loads TinyFaceDetector, FaceLandmark68Net, FaceRecognitionNet from `/models` (local server) with step-by-step progress messages |
| **Face descriptor extraction** | Runs `detectSingleFace().withFaceLandmarks().withFaceDescriptor()` on the captured image to produce the 128-dim Float32 vector sent to the server |
| **Retry cap** | After 3 failed face captures the capture button is disabled and the student is told to see the lecturer |
| **Session countdown** | After PIN validation the remaining session time is computed from the server's `expiresAt` and shown as a live countdown |
| **Geofence pre-check** | GPS is requested immediately after PIN validation; if the student is > 50 m from the classroom they see a warning before submitting |
| **QR / PIN dual path** | If the page is opened via a QR code (`?s=<token>` query param), the PIN step is skipped and the session info is loaded from `/api/session-info?token=` |
| **Input sanitisation** | PIN input strips non-digits and clamps to 4 characters in real time; name/matricule/email are trimmed before submission |
