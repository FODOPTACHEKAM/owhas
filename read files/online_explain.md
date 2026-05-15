# OwHAS Online Mode — How It Works

---

## 1. The Three Session Scenarios

OwHAS can operate in three modes. The mode is determined by which servers are
reachable at session creation time, using `ServerConfig.detect()`.

| | **Offline (Hotspot)** | **Online (Cloud)** | **Hybrid** |
|---|---|---|---|
| Server location | Lecturer's PC on a local hotspot | Remote `owhas.org` | Both simultaneously |
| Student access | Must join the hotspot | Any internet connection | Either |
| Proximity proof | Being on the hotspot is proof | GPS validation required | GPS for online students; LAN for offline |
| Final export | Local PDF/Excel | Cloud PDF/Excel | Merged — one unified file |
| GPS in export | No | No | No |
| Source column | No | No | `offline` / `online` per record |
| Requires internet | No | Yes | Yes (for remote students) |

> **GPS coordinates are used only as a validation gate — they are never stored
> in the attendance record or exported to any file.**

---

## 2. How the App Detects Which Mode It Is In

When the Flutter app starts, `ServerConfig.detect()` runs in a background
isolate to avoid UI jank. It probes servers in this exact order:

```
1. Fixed hotspot gateways   →  192.168.137.1:5501, 192.168.43.1:5501, etc.
2. Full subnet scan         →  192.168.0.x, 192.168.1.x, 10.0.0.x  (parallel, 800 ms)
3. Android emulator         →  10.0.2.2:5501
4. Cloud server             →  https://owhas.org  (2 s timeout)
5. Fallback                 →  192.168.137.1:5501  (nothing found)
```

- Local IP responds first → `isOnline = false` (Offline mode)
- Only cloud responds → `isOnline = true` (Online mode)
- Both respond → `isOnline = false` but the cloud URL is also stored as a
  secondary endpoint for merge at end-of-session (Hybrid mode)

The flag `ServerConfig().isOnline` is used throughout the app to decide which
behaviours to enable (geolocation request, merge prompt, etc.).

### Why local-first matters

A classroom hotspot always responds in < 800 ms. The cloud URL is tried last and
with a longer timeout, so it never wins in a room where the local server is up.
In a fully remote session, no local IP responds at all, so only the cloud path is
taken.

---

## 3. Online Session — Full Flow

```
Lecturer phone                    Cloud server (owhas.org)           Student phone/laptop
─────────────────                 ────────────────────────           ────────────────────
[Create session]
  GPS captured once here
  POST /api/session-init
  { pin, courseName, duration,
    requireGeolocation: true,
    lecturerLat, lecturerLng,
    maxRadiusMeters }            ────────────────────────>
                                  Store session + lecturer coords
                                  Return { sessionToken }
[Dashboard shows QR]
  QR encodes:
  https://owhas.org/hotspot.html
  ?pin=XXXX                       ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─>  Student scans QR
                                                             Browser opens HTTPS page
                                                             [REQUEST GPS]
                                                             navigator.geolocation
                                                             .getCurrentPosition()
                                                             coords captured in memory
                                                             (never shown to student)
                                                             Student fills in name/matric
                                  POST /api/biometric-connect
                                  { pin, username, matricule,
                                    lat, lng }              <────────
                                  Haversine check:
                                    dist ≤ maxRadiusMeters?
                                    YES → record student
                                          (coords DISCARDED)
                                    NO  → 403 rejected
[Auto-refresh every 5 s]
  GET /api/attendees?pin=XXXX    <──────────────────────────
  Updates dashboard list
[End session]
  POST /api/end-session { pin }  ────────────────────────>
                                  Mark session closed
                                  Export available: /export?pin=XXXX
```

**Key point:** The server validates coordinates and then discards them. The stored
attendance record contains only name, matricule, timestamp, and source — no GPS data.

---

## 4. Geolocation — When and Why It Is Requested

### 4a. The Logic

In offline mode the LAN connection itself proves physical presence — no GPS needed.

In online mode a student can connect from anywhere. GPS is the equivalent of
"being on the same hotspot": it proves the student is physically in range of the
classroom before their name enters the record.

```
if (ServerConfig().isOnline) {
  → demand GPS coordinates from the student's browser
  → server checks distance against lecturer's location
  → if within range → record attendance (coords are then discarded)
  → if out of range → reject with distance error
} else {
  → no GPS requested (LAN proximity is sufficient proof)
}
```

### 4b. Lecturer GPS — Captured Once at Session Creation

The lecturer does not type their location. When they tap **Create Session** and
the app is in online mode, it silently captures GPS once:

```dart
// In _createSession(), when isOnline:
if (ServerConfig().isOnline && _requireGeolocation) {
  final pos = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
  lecturerLat = pos.latitude;
  lecturerLng = pos.longitude;
}
```

These coordinates are sent to the cloud server with the session-init request and
stored as the reference point for all student validations. They are also not
included in any export.

A permission rationale is shown before the system dialog:
> "Your location is captured once at session creation to verify that
> students are physically present. It is not shared or exported."

### 4c. What the Student Sees (hotspot.html)

The page receives `requireGeolocation: true` from the server config endpoint and
requests GPS before showing the attendance form:

```javascript
// hotspot.html — online mode
if (sessionConfig.requireGeolocation) {
  navigator.geolocation.getCurrentPosition(
    (position) => {
      // Stored in memory only — never displayed to student
      studentLat = position.coords.latitude;
      studentLng = position.coords.longitude;
      document.getElementById('geo-status').textContent = '✓ Location confirmed';
      document.getElementById('attendance-form').style.display = 'block';
    },
    (error) => {
      document.getElementById('geo-error').textContent =
        'Location access is required for this online session. ' +
        'Enable GPS and allow location in your browser, then reload.';
    },
    { enableHighAccuracy: true, timeout: 15000 }
  );
}
```

The form is hidden until GPS succeeds. If the student denies, they cannot submit
and must ask the lecturer to add them manually.

### 4d. Server-Side Radius Check (Haversine)

The student's coordinates travel with the submission and are discarded after
the check passes:

```javascript
function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
            Math.cos(lat1 * Math.PI / 180) *
            Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// In POST /api/biometric-connect:
if (session.requireGeolocation) {
  if (!body.lat || !body.lng) {
    return res.status(400).json({ error: 'Location data is required for this session.' });
  }
  const dist = haversineMeters(
    session.lecturerLat, session.lecturerLng,
    body.lat, body.lng
  );
  if (dist > session.maxRadiusMeters) {
    return res.status(403).json({
      error: `You appear to be ${Math.round(dist)} m away. Maximum allowed is ${session.maxRadiusMeters} m.`,
    });
  }
  // Validation passed — do NOT store lat/lng in the attendance record
}

// Record stored without coordinates:
session.attendees.push({
  username: body.username,
  matricule: body.matricule,
  timestamp: new Date().toISOString(),
  source: 'online',
  // lat and lng intentionally omitted
});
```

---

## 5. Differences in the Session Setup UI

| Field | Offline | Online |
|---|---|---|
| Session PIN | Auto-generated 4-digit | Auto-generated 4-digit |
| Duration | ✅ | ✅ |
| Grace period | ✅ | ✅ |
| **Require geolocation** | hidden | ✅ (toggle, default ON) |
| **Max radius (meters)** | hidden | ✅ (text field, default 200) |

---

## 6. What Changes in the Dashboard (Online vs Offline)

| Feature | Offline | Online |
|---|---|---|
| Server warning banner | Shows if local server unreachable | Shows if cloud unreachable |
| Retry button | Rescans local subnet | Re-pings `owhas.org` |
| QR code URL | `http://192.168.137.1:5501/…` | `https://owhas.org/hotspot.html?pin=XXXX` |
| Student count badge | Refreshed from LAN | Refreshed from cloud API |
| PDF/Excel export | Fetched from LAN server | Fetched from cloud server |
| Session persistence | Lost if PC crashes | Survives server restarts |
| GPS in export | No | No — used for validation only |
| Source column | No | Yes — every record tagged `online` |

---

## 7. Hybrid Mode — Merging Offline and Online Records

Hybrid mode applies when the same PIN is active on both the local hotspot server
and the cloud server simultaneously. This happens in a blended classroom: some
students are physically in the room on the hotspot, others are joining remotely
over the internet.

### 7a. Why the Merge Happens in the Flutter App

The cloud server never sees offline data — it has no way to reach the local
hotspot. Only the lecturer's phone has simultaneous access to both servers at
end-of-session time. The Flutter app is therefore the merge point.

### 7b. The PIN Is the Join Key

Both servers store attendees keyed by the same PIN. This is what links the two
datasets together without any extra identifiers.

### 7c. Step-by-Step Merge Flow

```
1. Lecturer taps "End Session"
   (both servers must still be reachable at this moment)

2. Flutter app queries the LAN server:
   GET http://192.168.137.1:5501/api/attendees?pin=XXXX
   → [ { username, matricule, timestamp, source: 'offline' }, … ]

3. Flutter app queries the cloud server:
   GET https://owhas.org/api/attendees?pin=XXXX
   → [ { username, matricule, timestamp, source: 'online' }, … ]

4. Dart merge — deduplicate by matricule, online wins ties:
   final merged = mergeAttendees(offlineList, onlineList);

5. Merged list is pushed to the cloud as the canonical record:
   POST https://owhas.org/api/merge-session
   { pin, attendees: [...merged] }

6. Both servers are closed:
   POST http://192.168.137.1:5501/api/end-session { pin }
   POST https://owhas.org/api/end-session { pin }

7. Export the unified file:
   GET https://owhas.org/export?pin=XXXX
   → single PDF/Excel — no GPS data, source column included
```

### 7d. The Deduplication Rule

```javascript
// Node.js — called by POST /api/merge-session
function mergeAttendees(offlineList, onlineList) {
  const map = new Map();

  // Offline records go in first
  for (const student of offlineList) {
    map.set(student.matricule, { ...student, source: 'offline' });
  }

  // Online records overwrite offline ones for the same matricule.
  // Online is preferred because it went through GPS validation.
  for (const student of onlineList) {
    map.set(student.matricule, { ...student, source: 'online' });
  }

  // Return plain objects — no lat/lng field anywhere
  return [...map.values()];
}
```

If a student appears in both lists (e.g. submitted on the hotspot AND remotely),
the online record is kept. Its source column shows `online`. No coordinates are
present in either record.

### 7e. What the Exported File Looks Like

```
#   Name         Matricule   Time    Source
1   Alice Ngo    19D0145     09:02   online
2   Bob Mba      20A0012     09:05   offline
3   Carol Fon    18C0089     09:07   online
4   Denis Tabi   21B0334     09:11   offline
```

There is no latitude or longitude column anywhere in the export. GPS data is
ephemeral: it is captured in the browser, sent over HTTPS, validated on the
server, and then discarded. Only the validated *fact* of attendance is recorded.

### 7f. Edge Cases

| Situation | Behaviour |
|---|---|
| LAN server already shut down when end-session is tapped | Only online records are exported; offline data is lost. Merge must happen before the hotspot is off |
| Same PIN reused on different days | Scope records by `(pin + date)` to prevent cross-day pollution. Cloud server should reject a merge for an already-closed PIN |
| Student present on both lists, different names | Online record wins (dedup by matricule). Name discrepancy flagged in server log |
| Cloud unreachable at merge time | App retries 3 times, then falls back to local-only export with a warning |

---

## 8. Security Differences

### Offline
- Attack surface: local LAN only. Attacker must be physically on the hotspot.
- PIN brute-force: rate-limited to 10 attempts / 5 min per IP.
- No HTTPS needed (closed LAN, no eavesdropper risk in the classroom).

### Online / Hybrid
- Attack surface: the public internet.
- HTTPS mandatory (Cloudflare Tunnel / Caddy / Render all provide it).
- All lecturer-only endpoints (`/api/session-init`, `/api/end-session`,
  `/api/merge-session`, `/api/generate-pdf`) require an API key header:
  ```
  X-Lecturer-Key: <env var on the server>
  ```
- GPS coordinates sent by the student should be bound to a one-time token so
  a student cannot replay another student's coordinates.
- Rate-limit `/api/biometric-connect` to 5 attempts / 2 min per IP online
  (IPs are routable and not shared by the whole room as on a LAN).
- GPS is validated then discarded — no coordinate data is persisted, which
  limits privacy risk from a database breach.

---

## 9. Package Requirements (Flutter side)

```yaml
# pubspec.yaml additions
dependencies:
  geolocator: ^12.0.0          # GPS positioning (lecturer side)
  permission_handler: ^11.0.0  # Runtime permission dialog
```

Android (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

iOS (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is captured once at session creation to verify students are physically present. It is not stored or exported.</string>
```

---

## 10. Geolocation Limitations

| Limitation | Detail |
|---|---|
| Indoor GPS drift | GPS can be off 10–50 m indoors. Use `maxRadiusMeters` ≥ 150 for campus buildings |
| Student GPS denial | Student cannot submit; lecturer must add them manually |
| VPN spoofing | GPS comes from device hardware — a VPN cannot spoof it |
| Mocked GPS apps | Android allows GPS mocking. Detectable: mock providers often report `accuracy: 0` |
| iOS Safari | Requires HTTPS and a user gesture before geolocation fires — the submit tap satisfies this |
| No GPS hardware | Desktops and some Chromebooks have no GPS module — lecturer adds them manually |

---

## 11. Summary: Decision Tree

```
App starts — ServerConfig.detect() runs
  │
  ├─ Local hotspot server responds?
  │     YES
  │      │
  │      ├─ Cloud server ALSO responds?
  │      │     YES → Hybrid mode
  │      │           • Hotspot students: LAN, no GPS
  │      │           • Remote students: internet, GPS validated
  │      │           • Merge at End Session in Flutter app
  │      │           • Unified export from cloud, no GPS data
  │      │
  │      └─ Cloud does NOT respond → Offline mode
  │                 • Students join the hotspot
  │                 • No GPS needed
  │                 • Local export only
  │
  └─ Local server NOT found
        │
        ├─ Cloud server responds?
        │     YES → Online mode
        │           • Students use any internet connection
        │           • GPS validated then discarded
        │           • Cloud export, no GPS data
        │
        └─ Neither responds → Fallback to offline default
              (server warning banner shown in dashboard)
```
