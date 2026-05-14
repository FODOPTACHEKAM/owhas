+++++++++++++# OwHAS — Warning & Error Messages Reference

This document covers every message the lecturer can see in the dashboard,
when each one appears, and whether it appears in offline, online, or hybrid mode.

---

## The Orange Banner (Server Warning)

This is the most visible message — the full-width orange strip shown in the
dashboard when the server cannot be reached.

```
┌─────────────────────────────────────────────────────────────────┐
│ 🔴  Server not reachable — web registration (hotspot.html) is   │  [Retry]
│     unavailable. Start node server.js on the PC and connect     │
│     phones to the same Wi-Fi. Use the Retry button in the       │
│     dashboard to reconnect.                                      │
└─────────────────────────────────────────────────────────────────┘
```

### When it appears

The banner is set inside `AttendanceProvider.createSession()` at the moment
the app tries to push the session configuration to the server right after the
session is created. If that push (`pushSessionConfig`) throws any exception,
`_serverWarning` is set and the orange banner is shown.

### When it clears

- The lecturer taps **Retry** and the server responds successfully.
- The session is ended (warning is reset inside `_cleanupSession()`).

---

## Message Table by Scenario

### Scenario A — Fully Offline (hotspot, no internet)

The local Node.js server (`192.168.137.1:5501`) is the only server in use.

| Situation | Message shown | Where |
|---|---|---|
| Local server is running when session is created | No banner | — |
| Local server is NOT running when session is created | Orange banner (shown above) | Dashboard banner |
| Retry pressed, server still down | `"Server still not reachable — ensure node server.js is running and the phone is on the same Wi-Fi."` | Orange banner (updated text) |
| Retry pressed, server now up | Banner disappears, green SnackBar: `"Server connected successfully"` | SnackBar |
| Upload previous session while server is down | `"Server is not reachable. Ensure the Node.js server is running on your PC and your phone is connected to the same Wi-Fi/hotspot."` | SnackBar (error) |
| No file selected for upload | `"No file was selected or the file could not be read."` | SnackBar (error) |
| Server returned empty PDF on export | `"Server returned empty PDF"` | SnackBar (error) |
| PDF generation failed (local) | `"PDF generation failed: [reason]"` | SnackBar (error) |
| No records to generate PDF from | `"No active session or records to report"` | SnackBar (error) |
| Session auto-expired (timer) | `"Session ended — time limit reached"` | SnackBar, then redirects home |
| Student added manually | `"Student added manually"` | SnackBar (success) |
| Student removed | `"Student removed"` | SnackBar (success) |
| PDF shared | `"PDF shared"` | SnackBar (success) |
| PDF saved | `"PDF saved to: [path]"` | SnackBar (success) |

---

### Scenario B — Fully Online (cloud only, no local server)

`ServerConfig.detect()` found no local IP and fell through to `owhas.com`.
The cloud server is the only server.

| Situation | Message shown | Where |
|---|---|---|
| Cloud server is reachable at session creation | No banner | — |
| Cloud server is NOT reachable at session creation | Orange banner (same text — see note below) | Dashboard banner |
| Retry pressed, cloud still down | `"Server still not reachable — ensure node server.js is running and the phone is on the same Wi-Fi."` | Orange banner |
| Retry pressed, cloud now reachable | Banner disappears, green SnackBar: `"Server connected successfully"` | SnackBar |

> **Current code note:** When the banner appears in online mode, it still says
> *"Start node server.js on the PC"* — this text is hardcoded for the offline
> case. In a future fix, the message should read:
> *"Cloud server (owhas.com) is not reachable. Check your internet connection
> and try again."* when `ServerConfig().isOnline` is `true`.

All other messages (PDF, upload, manual student, etc.) are the same as offline
because they are generated locally and do not depend on which server is active.

---

### Scenario C — Hybrid (local hotspot AND cloud, same PIN)

Both the local hotspot server and `owhas.com` are running simultaneously
under the same PIN.

**Will the orange banner appear?**

**No — not in normal circumstances.**

Here is why:

`ServerConfig.detect()` tries local IPs first (800 ms timeout) and only
reaches the cloud URL if every local candidate fails. In hybrid mode the local
hotspot server is always reachable in < 800 ms, so it wins the race. The app
treats the local server as the primary server, pushes session config to it,
the push succeeds, and `_serverWarning` is never set.

```
detect() order:
  1. 192.168.137.1:5501 ← responds in ~50 ms  ← WINS
  2. subnet scan         (skipped, #1 already found)
  3. owhas.com           (never reached)
```

The cloud server continues to receive student registrations in the background
through the `POST /api/biometric-connect` calls that come from remote students'
browsers — but that path does not go through the Flutter app's session-config
push, so no warning is triggered.

| Situation | Banner appears? | Reason |
|---|---|---|
| Both servers running, local responds first | No | Local push succeeds |
| Local server crashes mid-session, cloud still up | Yes (on next retry) | Next `refreshRecords` call to local server fails; lecturer should tap Retry which will re-detect and find the cloud |
| Cloud unreachable, local running | No | Local server is the primary; cloud is never tested for the push |
| Both servers unreachable | Yes | Same as offline-server-down case |

---

## Full Message Catalogue

| Message text | Type | Trigger |
|---|---|---|
| `"Server not reachable — web registration (hotspot.html) is unavailable…"` | Orange banner | `createSession()` → `pushSessionConfig()` throws |
| `"Server still not reachable — ensure node server.js is running…"` | Orange banner (updated) | `retryServerConnection()` still fails after retry |
| `"Server connected successfully"` | SnackBar green | `retryServerConnection()` succeeds |
| `"Server is not reachable. Ensure the Node.js server is running…"` | SnackBar error | `uploadPreviousSession()` → `pingServer()` fails |
| `"No file was selected or the file could not be read."` | SnackBar error | `uploadPreviousSession()` — no file picked |
| `"Previous session data loaded successfully"` | SnackBar | `uploadPreviousSession()` success |
| `"Failed to load previous session"` | SnackBar error | `uploadPreviousSession()` general error |
| `"No active session or records to report"` | SnackBar error | `generatePDFReport()` — no session or empty list |
| `"PDF generation failed: [reason]"` | SnackBar error | `generatePDFReport()` exception |
| `"PDF shared"` | SnackBar | `generateAndSharePDFReport()` success |
| `"Failed to share PDF: [reason]"` | SnackBar error | `generateAndSharePDFReport()` exception |
| `"PDF saved to: [path]"` | SnackBar | `downloadPDFReport()` success |
| `"Failed to download PDF: [reason]"` | SnackBar error | `downloadPDFReport()` exception |
| `"Server returned empty PDF"` | SnackBar error | `downloadAndShareServerPdf()` — server returned null |
| `"Download failed: [reason]"` | SnackBar error | `downloadAndShareServerPdf()` exception |
| `"Student added manually"` | SnackBar | `registerManualStudent()` success |
| `"Failed to add student: [reason]"` | SnackBar error | `registerManualStudent()` failure |
| `"Student removed"` | SnackBar green | `removeStudent()` success |
| `"Failed to remove student"` | SnackBar error | `removeStudent()` failure |
| `"Session ended — time limit reached"` | SnackBar | Auto-expiry timer fires |
| `"Failed to end session: [reason]"` | SnackBar error | `forceEndSession()` throws in `_endSession()` |

---

## Summary: Does the Orange Banner Appear When Online?

| Mode | Local server | Cloud server | Banner appears? |
|---|---|---|---|
| Offline | Running | — | No |
| Offline | Down | — | **Yes** |
| Online | — | Reachable | No |
| Online | — | Down | **Yes** (message text is misleading — says "node server.js") |
| Hybrid | Running | Reachable | No (local wins detection, cloud is never the primary) |
| Hybrid | Down | Reachable | Yes on initial create; Retry re-detects cloud and clears it |
| Hybrid | Running | Down | No (local is primary, cloud down is not checked) |
| Hybrid | Both down | Both down | **Yes** |
