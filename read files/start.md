# OwHAS — Startup Guide

Everything you need to launch the system before class, in the correct order.

---

## Files at a Glance

| File / App | Who runs it | When |
|---|---|---|
| Windows Mobile Hotspot | Lecturer (PC Settings) | Before anything else |
| `backend/start-server.bat` | Lecturer (double-click) | Step 2 — starts the Node.js server |
| `backend/server.js` | Launched **by** the bat | Never run directly |
| `backend/setup.js` | Launched **by** the bat | Automatically, first run only |
| `backend/public/hotspot.html` | Student phones | Opened automatically via browser |
| Flutter lecturer app | Lecturer (phone/tablet) | Step 3 — after the server is running |

---

## Prerequisites (one-time, before the first ever class)

### 1. Install Node.js on the PC
Download and install from https://nodejs.org/ (LTS version).  
Verify with `node -v` in a terminal — must show v18 or higher.

### 2. Install npm dependencies
Open a terminal inside the `backend/` folder and run:
```bat
npm install
```
This installs Express, multer, pdf-parse, pdfkit, and all other packages
listed in `package.json`.  Only needed once (or after `package.json` changes).

### 3. Install the Flutter app on the lecturer's device
Run the Flutter app from VS Code / Android Studio:
```bat
flutter run
```
Or install the APK directly on the device.

---

## Startup Sequence — Every Class

Follow these steps **in order**.  Skipping or reversing them causes
"Server not reachable" errors in the Flutter app.

---

### Step 1 — Enable Windows Mobile Hotspot

**Settings → Network & Internet → Mobile Hotspot → turn On**

The hotspot must be ON before the server starts so the server detects
the correct IP (`192.168.137.1`).

> If you enable the hotspot AFTER starting the server, the server may
> have bound to the wrong IP.  Close the server and re-run the bat.

---

### Step 2 — Run `start-server.bat` as Administrator

**Right-click `backend/start-server.bat` → Run as administrator**

The bat self-elevates automatically, but some Windows versions still
require the right-click method.

What it does automatically:

| Step | Action |
|------|--------|
| Checks Node.js | Exits early with instructions if Node.js is missing |
| Configures firewall | Opens TCP 5501, TCP 80, UDP 53, UDP 5353, node.exe |
| Downloads face-api (first run) | `setup.js` fetches models from CDN — needs internet (~30 s) |
| Skips download on repeat runs | Only re-downloads if model files are missing or corrupted |
| Starts the server | Runs `node server.js` — the window must stay open |

**The server is ready when you see:**
```
[mDNS] Listening on 224.0.0.251:5353 ...
[HTTP80] Captive portal active on :80
========================================
```

**Do not close this window** during class — closing it stops the server
and disconnects all students.

---

### Step 3 — Open the Flutter Lecturer App

Launch the app on the lecturer's phone or tablet.

On startup it scans the local network for the server.  Once found, it
displays:
- Server status (green = connected)
- The session setup button

If it shows "Server not reachable":
1. Confirm the hotspot is enabled and the phone is connected to it.
2. Confirm the server bat is running and shows no errors.
3. Tap **Retry** inside the app.

---

### Step 4 — Create a Session

In the Flutter app: tap **Start Session**, fill in the course details,
and confirm.

This:
- Generates a 6-digit PIN.
- Registers the session on the server.
- Displays a QR code for students to scan.

---

### Step 5 — Students Join

Students connect their phones to the hotspot Wi-Fi, then either:

| Method | What to do |
|--------|-----------|
| **QR code** (easiest) | Scan the QR code shown on the lecturer's screen |
| **Direct IP** | Type `http://192.168.137.1` in Chrome and tap Go |

The attendance page (`hotspot.html`) opens automatically.
Students complete face verification and enter the session PIN.

---

## Ending a Session

1. In the Flutter app, tap **End Session**.
2. Export the attendance report (PDF or Excel) from the app.
3. Close the `start-server.bat` window — the server shuts down and
   DNS Client is restored automatically.

---

## File Roles — Detailed

### `backend/server.js`
The Node.js HTTP server.  Handles all API endpoints:
- `POST /api/session-init` — registers a session PIN
- `POST /api/validate-pin` — student enters PIN
- `POST /api/register-student` — student submits face + details
- `GET  /api/attendees` — live attendee list (polled by Flutter app)
- `POST /api/end-session` — closes the session
- `GET  /api/session-info` — returns course + lecturer info for QR token
- `POST /api/parse-pdf` — reads an existing attendance PDF
- `POST /api/generate-pdf` — creates a new attendance PDF
- `GET  /public/hotspot.html` — serves the student web page

Also starts:
- mDNS responder on `224.0.0.251:5353` (for `http://owhas.local`)
- HTTP redirect on port 80 (catches `http://192.168.137.1`)
- Captive portal handler (shows "Sign in to network" popup on phones)

### `backend/start-server.bat`
The **only file you launch manually**.  Wraps `server.js` with:
- Administrator self-elevation
- Firewall rule configuration
- One-time model download via `setup.js`
- Dnscache stop attempt (optional, for `owhas.lan`)
- Dnscache restoration on exit

### `backend/setup.js`
Downloads face-api.js and its neural network model files from jsDelivr
CDN into `backend/public/lib/` and `backend/public/models/`.
Runs once automatically; safe to re-run manually if models are corrupted.

### `backend/public/hotspot.html`
The student-facing single-page web app.  Self-contained — no framework,
no build step.  Handles:
- Session PIN entry
- QR code token parsing
- Camera access + face detection (via face-api.js)
- Student registration form
- Live "already registered" duplicate check

### Flutter lecturer app (`lib/`)
Runs on the lecturer's Android device.  Handles:
- Auto-detecting the server IP on the local network
- Session creation (course name, code, lecturer, duration, GPS geofence)
- Live attendee list with face thumbnails
- QR code display
- PDF/Excel export
- Cloud sync (Firebase, optional)

---

## Quick-Start Checklist

```
□ Windows Mobile Hotspot is ON
□ Student phones are connected to the hotspot Wi-Fi
□ start-server.bat is running as Administrator (window open, no error)
□ Server shows "[HTTP80] Captive portal active on :80"
□ Flutter app shows server as connected (green)
□ Session created — PIN and QR code visible
□ Students can open http://192.168.137.1 in Chrome
```

---

## Common Startup Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `node` is not recognized | Node.js not installed | Install from nodejs.org, restart terminal |
| `Cannot find module './src/services/pdfService'` | npm install not run | Run `npm install` in `backend/` |
| Flutter app: "Server not reachable" | Server not started, or hotspot off | Start bat first, then enable hotspot, then open app |
| `[DNS] Port 53 still in use` | Dnscache protected (Windows 10+) | Normal — `owhas.lan` won't work but `http://192.168.137.1` will |
| Face model tensor error | Corrupted model shard | Re-run bat — it detects size < 1 MB and re-downloads |
| Students can't open the page | Phone not on hotspot Wi-Fi | Confirm students connected to the correct hotspot SSID |
| Camera blocked on student phone | HTTP (not HTTPS) | Known limitation on plain HTTP; face capture still works via the built-in face-api.js flow |
