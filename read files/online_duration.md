# How OwHAS Tracks Student Duration — Offline vs Online

---

## The Core Question

> "How does the system ensure that a student who attended online actually
> stayed in the hall for the required period?"

This document explains exactly how duration tracking works in each mode,
where the current implementation has a gap for online students, and what
the correct solution is.

---

## Part 1 — How Offline Duration Tracking Works (the strong model)

### What happens when an offline student registers

When a student connects to the hotspot and submits the form on `hotspot.html`,
the server stores their `connectedAt` timestamp and their IP address.

The Node.js server knows:
- When they first appeared (`connectedAt`)
- That they are still on the LAN (their browser is open on the hotspot)

### How duration is measured

Every time the lecturer's dashboard auto-refreshes (every 5 seconds), the
Flutter app calls:

```
GET /api/attendees?pin=XXXX
```

The server returns each student's `connectedAt`. The app then computes:

```dart
// In AttendanceProvider._convertServerAttendees()
final durationMinutes = now.difference(joinedAt).inMinutes;
final isVerified = durationMinutes >= requiredConnectionMinutes;
```

So the duration grows naturally with every refresh — as real time passes,
`now - connectedAt` increases, and eventually crosses `requiredConnectionMinutes`.

### Why offline students CANNOT cheat the duration

The hotspot is the enforcement mechanism. To stay "connected" a student must:

1. Keep their phone joined to the lecturer's Wi-Fi hotspot.
2. Keep the browser tab open on `hotspot.html`.

If the student leaves the room and walks out of Wi-Fi range:
- Their device disconnects from the hotspot.
- Their browser loses network access.
- They cannot re-register because their device fingerprint is already in the
  session — the server will reject a second registration from the same device.

**Conclusion:** In offline mode, staying connected to the hotspot IS staying
in the room. The physical network enforces physical presence for the full
duration. The timer is valid.

---

## Part 2 — How Online Duration Tracking Currently Works (the weak model)

### What happens when an online student registers

An online student:
1. Opens `hotspot.html` on the cloud server from any internet connection.
2. Grants GPS permission.
3. GPS is validated against the lecturer's location (Haversine check).
4. Submits name, matricule, email.
5. One HTTP POST is sent. The server stores the record with `connectedAt = now`.

**That is the end of the interaction.** There is no open connection kept after
the form is submitted.

### How duration is measured for online students

Exactly the same formula as offline:

```dart
// Same code path in _convertServerAttendees()
final durationMinutes = now.difference(joinedAt).inMinutes;
final isVerified = durationMinutes >= requiredConnectionMinutes;
```

The app treats every student the same — it calculates elapsed time since
`connectedAt` regardless of whether the student submitted via hotspot or cloud.

### The Gap — Why Online Duration Is Not Enforced

```
Offline student:         Online student:
─────────────────        ─────────────────────────────────────────
Submits form             Submits form
↓                        ↓
Stays on hotspot         GPS validated ✓   ← only check happens HERE
↓                        ↓
Timer counts up          Form closes — student can leave immediately
↓                        ↓
Leaves hotspot           Timer STILL counts up from submission time
↓                        ↓
Connection lost          Gets "Verified" after requiredConnectionMinutes
↓                        even though they are no longer present
Cannot re-register
Timer stops effectively
```

**The problem in plain language:**

An online student can:
1. Walk into the classroom.
2. Open the page, grant GPS, submit the form.
3. Walk out immediately.
4. After `requiredConnectionMinutes` have passed, they appear as **Verified**
   in the dashboard — as if they stayed the whole time.

This is because the server only validates GPS **at the moment of submission**,
not continuously. The timer counts wall-clock time from `connectedAt`, not
time during which the student was provably present.

---

## Part 3 — How Online Duration SHOULD Be Enforced (the correct model)

To make online duration tracking as strong as offline, the student's continued
presence must be confirmed periodically throughout the session — not just once
at registration.

### The Correct Design: GPS Heartbeats

After successful registration, `hotspot.html` should send a small "I am still
here" request to the server every N minutes (e.g., every 2 minutes). Each
heartbeat includes the student's current GPS coordinates, validated against the
same radius as the initial check.

```
Student registers (GPS check ✓)
↓
Every 2 minutes, browser sends:
  POST /api/heartbeat
  { pin, matricule, lat, lng, token }
↓
Server checks:
  distance(lecturerLat, lecturerLng, lat, lng) ≤ maxRadiusMeters ?
  YES → update lastSeen timestamp, mark as "still present"
  NO  → mark student as "left early", stop their duration clock
↓
If browser closes (student leaves page):
  No more heartbeats received
  After 2 missed heartbeats → server marks student as disconnected
  Duration clock freezes at last confirmed heartbeat time
```

### Why a heartbeat approach works

| Scenario | Offline (current) | Online with heartbeats |
|---|---|---|
| Student submits and stays | Timer grows ✓ | Timer grows, heartbeats confirm presence ✓ |
| Student submits and leaves immediately | Timer stops (hotspot disconnects) ✓ | Timer stops after 2 missed heartbeats ✓ |
| Student submits, leaves, comes back | Cannot re-register (device fingerprint) ✓ | Heartbeats resume, time gap recorded |
| Student submits from outside the radius | GPS check blocks it ✓ | GPS check blocks it ✓ |
| Student submits inside radius, drives away | Hotspot disconnects ✓ | GPS heartbeat fails radius check, timer stops ✓ |

### What changes in the code

**hotspot.html (browser side):**
```javascript
// After successful registration, start heartbeat loop
let heartbeatToken = response.token; // server returns one-time token
let heartbeatInterval = setInterval(async () => {
  const pos = await getCurrentPosition();
  await fetch('/api/heartbeat', {
    method: 'POST',
    body: JSON.stringify({
      pin: sessionPin,
      matricule: studentMatricule,
      token: heartbeatToken,
      lat: pos.coords.latitude,
      lng: pos.coords.longitude,
    })
  });
}, 2 * 60 * 1000); // every 2 minutes

// If student closes the tab, heartbeats stop automatically
window.addEventListener('beforeunload', () => {
  clearInterval(heartbeatInterval);
});
```

**server.js (new endpoint):**
```javascript
app.post('/api/heartbeat', (req, res) => {
  const { pin, matricule, token, lat, lng } = req.body;
  const session = activeSessions.get(pin);
  if (!session) return res.status(404).json({ error: 'Session not found' });

  const student = session.attendees.find(a => a.matricule === matricule);
  if (!student || student.heartbeatToken !== token) {
    return res.status(403).json({ error: 'Invalid token' });
  }

  // Validate GPS still within range
  const dist = haversineMeters(
    session.lecturerLat, session.lecturerLng, lat, lng
  );
  if (dist > session.maxRadiusMeters) {
    student.leftEarly = true;
    student.lastSeen = student.lastSeen; // freeze the clock
    return res.status(403).json({ error: 'Out of range — attendance frozen' });
  }

  student.lastSeen = new Date().toISOString(); // extend verified window
  res.json({ ok: true });
});
```

**Duration calculation (updated):**
Instead of `now - connectedAt`, use `lastSeen - connectedAt` for online
students. If heartbeats stopped (student left), `lastSeen` freezes and the
duration no longer grows.

---

## Part 4 — Current Status Summary

| Check | Offline | Online (current) | Online (with heartbeats) |
|---|---|---|---|
| Present at registration | ✅ LAN proximity | ✅ GPS at submission | ✅ GPS at submission |
| Still present after 5 min | ✅ Must stay on hotspot | ❌ Not checked | ✅ GPS heartbeat |
| Still present at verification | ✅ Must stay on hotspot | ❌ Timer runs regardless | ✅ Last heartbeat ≤ 2 min ago |
| Leaves and comes back | ✅ Blocked by device fingerprint | ❌ Timer was running | ⚠️ Gap recorded in duration |
| Closes browser tab | ✅ Hotspot disconnects | ❌ Timer was running | ✅ Heartbeats stop |

The GPS heartbeat feature described in Part 3 is not yet implemented. It is
listed in the project's Future Work section as a required enhancement before
the online mode can be considered as reliable as the offline hotspot mode
for enforcing duration-based verification.

---

## Part 5 — What the Current System Guarantees Online

Even without heartbeats, the current online mode still provides meaningful
guarantees:

1. **The student was physically present at the time of submission** — GPS
   validation at submission time confirms they were within the radius of the
   classroom when they registered. They could not have submitted from home.

2. **Device fingerprinting prevents re-registration** — the same device
   cannot submit attendance twice for the same session.

3. **Face recognition prevents proxy registration** — if the student
   registers on the lecturer's device, a second face cannot re-use the same
   slot.

4. **The time window is bounded** — the session has a fixed end time. The
   maximum duration a student can appear to have is the session length —
   they cannot inflate their time by registering before the session or
   after it ends.

What it does NOT guarantee: that the student who was present at submission
time stayed present for the full `requiredConnectionMinutes`. For that,
heartbeats are required.
