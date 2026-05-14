# OwHAS — System Difficulties & Known Challenges

A comprehensive analysis of every practical, technical, security, legal, and
operational difficulty this system can face in a real institution deployment.
Grouped from most to least critical.

---

## 1. Network and Connectivity

### 1.1 Hotspot IP detection failure

The server auto-detects its own IP by probing known gateway addresses and
scanning three subnets in parallel. If the institution's hotspot uses a
non-standard subnet (e.g. `10.10.x.x`, `172.16.x.x`, `100.64.x.x`), all
probes fail and the Flutter app silently falls back to `192.168.137.1`.
Students can open the page (they are already connected) but the Flutter app
cannot reach the server, showing a "server offline" warning throughout the
session.

**Impact:** The lecturer app cannot refresh attendance records in real time.
Export still works if the lecturer opens the server directly.

**Workaround:** Add a manual IP override field in the app settings
(imp.md item 4.5 — not yet implemented).

---

### 1.2 Windows Mobile Hotspot limitations

Windows Mobile Hotspot is limited to **10 simultaneous Wi-Fi client
connections** on many hardware/driver combinations. In a class of 50 students,
40 cannot connect at all until others disconnect.

Students must:
1. Connect to Wi-Fi
2. Load the page (keeps the TCP connection alive for the model download)
3. Submit (one more short request)
4. Disconnect

If students leave the page open after registering, they hold a slot and block
others. There is no mechanism to force-disconnect idle students.

**Impact:** Severe in classes larger than ~30 students unless a router is used.

**Workaround:** Use a dedicated travel router (e.g. TP-Link TL-MR100)
connected to the laptop via USB tethering instead of Windows Mobile Hotspot.

---

### 1.3 University IT blocks hotspot creation

Many universities disable Windows Mobile Hotspot via Group Policy or mobile
device management (MDM) to prevent rogue access points. A lecturer's
university-issued laptop may refuse to create a hotspot at all, showing a
"Can't set up mobile hotspot" error even when the hardware supports it.

**Impact:** The entire system is non-functional on managed institutional
hardware.

**Workaround:** Use a personal laptop or dedicated hotspot device (Mi-Fi),
or request a policy exception from IT.

---

### 1.4 Windows Firewall blocks port 5501

Windows Firewall blocks all incoming connections on port 5501 by default.
The server appears to start successfully (it is bound to the port), but
student devices cannot connect — requests time out silently.

**Impact:** Students see the Wi-Fi connection succeed but cannot load
`hotspot.html` at all.

**Workaround:** The `start-server.bat` script must include a firewall
`netsh advfirewall` rule. If run without administrator privileges it silently
fails to add the rule.

---

### 1.5 Android vs iOS hotspot IP differences

| Platform | Typical hotspot gateway IP |
|----------|---------------------------|
| Windows Mobile Hotspot | `192.168.137.1` |
| Android hotspot | `192.168.43.1` |
| iOS hotspot | `172.20.10.1` |

If the lecturer uses a phone hotspot instead of the PC, the gateway IP
changes and the Flutter app (running on the same phone) cannot use
`localhost` — it must detect and use the external hotspot IP.

---

### 1.6 Signal range in large lecture theatres

Lecture theatres can seat 300–500 students across 30+ metres. A single
laptop Wi-Fi antenna covers roughly 15–20 metres indoors. Students in the
back rows may associate with the hotspot but experience -70 dBm signal,
causing the 7 MB face-api.js model download to take 2–5 minutes and
timeout, leaving the page blank or stuck on "Loading face recognition".

---

## 2. Face Recognition Accuracy

### 2.1 Lighting conditions

Face-api.js's TinyFaceDetector is a lightweight model optimised for mobile.
It degrades significantly under:

| Condition | Effect |
|-----------|--------|
| Dark lecture hall (projector only) | Face not detected at all — confidence < 0.45 threshold |
| Harsh overhead fluorescent lighting | Strong shadows on eye sockets; landmark extraction fails |
| Backlit student (window behind them) | Face appears as dark silhouette; descriptor is inaccurate |
| Partial face in frame | Landmark model places 68 points incorrectly; wrong descriptor |

**Impact:** Students cannot complete registration without retrying multiple
times, slowing the entire class.

---

### 2.2 Masks, glasses, hats, and accessories

| Accessory | Effect on descriptor |
|-----------|---------------------|
| Surgical/N95 mask | Obscures 40% of facial landmarks; descriptor shifts significantly |
| Thick-framed glasses | Distorts landmark positions around eye sockets |
| Sun hat / cap | Covers forehead landmarks; descriptor is unreliable |
| Hair covering face | Detection confidence drops below 0.45 |

A student who registered without glasses and returns for a later session with
glasses may produce a descriptor far enough from their stored one that the
system fails to recognise them as already registered — or, worse, the system
accepts them again as a new face (false negative for duplicate detection).

---

### 2.3 Camera quality variation

Students use phones ranging from 5-year-old budget devices (2 MP front
camera, no autofocus, no portrait mode) to modern flagship phones (50 MP,
multi-lens, AI processing). The face descriptors produced by these cameras
for the same person can differ enough to affect the 0.6 distance threshold.

A student who registers with a low-quality image may later fail the proxy
check for innocent reasons (different lighting + different camera angle).

---

### 2.4 Photo-based proxy attack

The current system cannot distinguish a live face from a photograph of that
face displayed on another phone's screen. A student can hold up a photo of a
classmate who is not present, extract their descriptor, and register them
without their knowledge or consent.

Liveness detection (blink detection, 3D depth, motion analysis) is not
implemented. Implementing it would require replacing TinyFaceDetector with a
heavier model or using a native ML SDK on the lecturer's Flutter app.

---

### 2.5 Identical or near-identical faces

The 0.6 Euclidean distance threshold is calibrated for the general population.
For identical twins, the inter-twin distance can fall below 0.6, causing the
second twin's registration to be rejected as a duplicate of the first.
Similarly, some non-twin siblings may trigger false duplicate matches.

There is no manual override path in the face verification flow — the only
workaround is for the lecturer to add the second twin manually (bypassing face
verification entirely).

---

### 2.6 Large class descriptor accumulation

Each registered student adds one 128-element Float32 descriptor to
`session.faceDescriptors`. Duplicate checking requires comparing every new
descriptor against all existing ones in O(n) time.

| Class size | Comparisons for last student |
|------------|------------------------------|
| 30 students | 29 |
| 100 students | 99 |
| 300 students | 299 |

While this is fast in absolute terms, it runs synchronously in the Node.js
event loop. For very large cohorts the server may delay its response to the
`/api/verify-face` call by tens of milliseconds, which accumulates if many
students register simultaneously.

---

## 3. PIN Security

### 3.1 Low entropy with 4-digit PIN

The PIN space is 10,000 combinations (1000–9999). With multiple sessions
running daily across a faculty:

- If 20 sessions run per day, a student seeing one PIN can guess another
  session's PIN by trial and error within ~500 attempts (expected value).
- The rate limiter allows 10 attempts per IP per 5-minute window. A student
  with 50 phones (or IP rotation via VPN) can attempt all 10,000 PINs in
  under 9 hours.

**Impact:** A motivated student could join a session they are not enrolled
in, inflating attendance counts for a different course.

**Partial mitigation already in place:** Rate limiting on
`/api/validate-pin`. Full mitigation would require adding course-code
confirmation after PIN validation (imp.md item 2.2).

---

### 3.2 PIN collision between concurrent sessions

If two lecturers start sessions in adjacent rooms at the same time, there is
a 1 in 10,000 chance of generating the same PIN. The second lecturer's
`/api/session-init` call is rejected with HTTP 409. The Flutter app must
regenerate and retry, but currently shows only a generic error and requires
the lecturer to manually press "Start Session" again.

---

### 3.3 PIN visible on projector screen

The lecturer typically mirrors their phone screen to the projector so
students can scan the QR code. The PIN is displayed in large text on the
session header card. Any student who photographs the projector can share the
PIN outside the classroom immediately.

---

## 4. Data Persistence and Loss

### 4.1 Server crash between attendee commits

When a student completes `/api/biometric-connect`, the attendee is added to
`session.attendees` in memory, and `persistSessions()` writes the entire
session to `sessions.json`. If the process crashes between the in-memory
write and the file write (e.g. power cut lasting < 100 ms), the student is
lost permanently — they registered, received a success message, but are not
in the file.

`fs.writeFileSync` is atomic on most operating systems (write to temp file
then rename), but the Node.js process itself can be killed mid-write.

---

### 4.2 Face descriptors lost on restart

`sessions.json` persists the `attendees[]` and `faceDescriptors[]` arrays.
However, `pendingFaces` is a `Map` and is explicitly excluded from
serialisation (it is transient by design). If the server restarts while 10
students are mid-registration (between step 1 and step 2), all 10 pending
face tokens become invalid and those students must restart the registration
process from the beginning.

---

### 4.3 SharedPreferences corruption on Android

The Flutter app stores session data, student lists, and attendance records in
`SharedPreferences` (a flat JSON file backed by Android's `SharedPreferences`
XML). If the phone runs out of storage mid-write, or Android kills the
process while writing, the JSON can become malformed. On next launch, all
data for that key is silently discarded (the `catch (_)` blocks return empty
lists).

There is no integrity check, backup, or recovery mechanism.

---

### 4.4 No offline sync queue

If the Flutter app loses server connectivity mid-session (lecturer's laptop
sleeps, Wi-Fi driver crashes), every subsequent `refreshRecords()` call
silently fails. The app continues showing stale data. When the server comes
back online, there is no catch-up mechanism — records that arrived at the
server during the Flutter app's disconnection appear only on next refresh.

---

## 5. Scale and Performance

### 5.1 PDF generation blocks the event loop

`generateAttendancePDF()` in `pdfService.js` builds the entire PDF
synchronously in the main Node.js thread using PDFKit. For a class of
200 students with multi-page output, this can take 200–500 ms of blocking
time. During this window, no other HTTP requests — including student
`/api/biometric-connect` calls — are processed.

**Impact:** In a large class where the lecturer requests a report mid-session,
multiple students may experience registration delays or timeouts.

---

### 5.2 SharedPreferences full JSON re-serialisation

Every `saveAttendanceRecord()` call reads the entire list for that session,
appends one record, and writes the full JSON back. With 200 students this is
200 reads and 200 full writes of growing payloads. The last write serialises
a list containing all 200 records.

On low-end Android devices with slow internal storage, the UI can stutter
or the operation can take hundreds of milliseconds per write.

---

### 5.3 Startup subnet scan overhead

Even though the fixed candidates (5 IPs) are tried first, the full subnet
scan of 762 IPs still runs in the background. All 762 HTTP requests fire
simultaneously. On a crowded hotspot this floods the router with probe
packets, potentially delaying legitimate student connections during the
first few seconds after the lecturer opens the app.

---

## 6. Device and Browser Compatibility

### 6.1 getUserMedia restriction on iOS Safari

`getUserMedia()` (camera access from a web page) is supported in iOS Safari
14+ but has strict restrictions:

- Works only over HTTPS or `localhost`. The hotspot server runs over plain
  HTTP on a LAN IP. Safari on iPhone/iPad blocks camera access entirely in
  this context.
- Students on iPhones cannot complete the face scan step and receive a
  cryptic "NotAllowedError" with no explanation.

**Impact:** Any iPhone user cannot use the biometric path and must be
added manually by the lecturer.

**Fix required:** Serve the page over HTTPS with a self-signed certificate,
and distribute the certificate to student devices — a significant operational
burden.

---

### 6.2 WebGL not available on old Android WebView

face-api.js uses TensorFlow.js, which requires WebGL for GPU-accelerated
inference. Devices running Android 5.x or 6.x, or cheap phones with
deliberately disabled GPU drivers, return `null` from
`document.createElement('canvas').getContext('webgl')`.

TensorFlow.js falls back to a CPU backend, which is 10–50× slower. Model
inference that takes 200 ms on a modern phone can take 3–10 seconds on an
old device. The student waits silently with no progress indicator.

---

### 6.3 Camera permission denied or absent

Students who previously denied camera permission to their browser cannot
retract that denial without visiting browser settings — a process most
students are unfamiliar with. The app shows a generic error and no
step-by-step instructions.

Some university MDM profiles deny camera access to browsers entirely.

---

### 6.4 Students with no front camera

Low-end feature phones, some tablets, and shared or borrowed devices may
have no front camera. The face step is impossible. There is a file-picker
fallback (upload a photo), but students in an exam context rarely have a
suitable photo of themselves on their device.

---

## 7. Privacy and Legal

### 7.1 Biometric data classification

In the European Union (GDPR Article 9) and in many other jurisdictions
(CCPA, PIPL in China, POPIA in South Africa), biometric data used for
the purpose of uniquely identifying a person is **special category data**
requiring explicit, informed, per-purpose consent before collection.

The 128-element face descriptor is derived from a biometric — it is
technically biometric data even though the raw image is not stored. A
university deploying OwHAS without a formal consent process, a data
processing agreement, and a Data Protection Impact Assessment (DPIA) risks
regulatory sanctions.

---

### 7.2 Face descriptors stored unencrypted in server memory

`session.faceDescriptors` is a plain JavaScript array in the server process's
heap. Anyone with access to the laptop can attach a debugger, trigger a
Node.js heap dump, or simply read `sessions.json` on disk to obtain every
student's face descriptor in plain text. The descriptor cannot be reversed
to reconstruct a face, but it can be used to identify a student in a
different biometric system that uses the same face-api.js model.

---

### 7.3 No consent mechanism in the student UI

`hotspot.html` asks students to scan their face without explaining:
- What data is collected (128 numbers derived from their face)
- How long it is stored (in memory for the session duration)
- Who has access to it (the lecturer's laptop)
- What it is used for (duplicate detection only)

A consent checkbox before the face-scan step is not implemented.

---

### 7.4 Attendance data retained on lecturer's device indefinitely

Session data persists in the Flutter app's `SharedPreferences` until
explicitly cleared. There is no automatic deletion policy, no maximum
retention period, and no way for a student to request deletion of their
record. This may conflict with institutional data retention policies.

---

## 8. Operational and Human Factors

### 8.1 Lecturer technical skill requirements

Setting up OwHAS requires a lecturer to:
1. Install Node.js on their personal Windows laptop
2. Run `node setup.js` from a terminal before first use
3. Start the server via `start-server.bat` before every class
4. Enable Windows Mobile Hotspot or a physical router
5. Open the Flutter app and create a session
6. Show the QR code on the projector

Any of these steps can fail silently, and there is no automated pre-class
checklist in the app. A lecturer who misses step 3 or step 4 only discovers
the problem when students start reporting "can't connect".

---

### 8.2 Registration queue bottleneck

In a class of 100 students, each registration takes:
- Model download: 30–60 s (only on first visit — cached after that)
- Face scan + verification: 3–10 s
- Form fill + submit: 15–30 s

If the session grace period is 5 minutes, the total throughput is roughly
6–12 students per minute. A class of 100 students needs 8–17 minutes just
for the biometric path, which may exceed the grace period for students who
arrive on time but are slow to scan.

---

### 8.3 Students joining the wrong session

If two lecturers run sessions simultaneously in adjacent rooms on different
laptops, a student who connects to the wrong hotspot SSID lands on the wrong
`hotspot.html`. There is no room name or building location displayed on the
student page — only course name, which the student may not immediately
recognise as wrong if they are enrolled in similarly named courses.

---

### 8.4 Session expiry not communicated clearly to late arrivals

A student who arrives after the session has expired sees "Invalid or expired
PIN" with no context — no explanation that the session closed or when it
closed. They cannot distinguish a wrong PIN from an expired session.

---

### 8.5 Power failure or laptop sleep mid-session

If the lecturer's laptop sleeps (lid closed, screensaver power policy), the
Node.js server process is suspended. All pending student requests queue at the
TCP layer and eventually time out. When the laptop wakes, the server resumes,
but students who timed out see an error and must reload and retry — losing
their face token (5-minute TTL may have expired).

Windows power settings must be configured to prevent sleep while the hotspot
is active. This is not documented in any setup guide for the system.

---

## 9. Accessibility

### 9.1 Students who cannot use face recognition

Students may be unable to complete the face scan for legitimate reasons:

| Condition | Effect |
|-----------|--------|
| Full-face medical device (oxygen mask, bandage) | Face not detected |
| Niqab/face covering (religious) | Face not detected |
| Severe facial disfigurement | Landmark extraction fails |
| Prosthetic eye or severe asymmetry | Descriptor is anomalous |
| Partial blindness (cannot align face to camera) | Poor capture quality |

The manual add path exists in the Flutter app, but it requires the student to
approach the lecturer individually, which may be embarrassing or disruptive.
There is no self-service accommodation path.

---

### 9.2 Screen reader incompatibility

`hotspot.html` uses `<section>` elements with hidden/visible toggling via CSS
`display: none`. Some transitions and status messages are updated by directly
setting `textContent` on a `<div>`, without ARIA live-region attributes
(`aria-live="polite"`). Screen readers may not announce these updates,
leaving visually impaired students without feedback about whether their PIN
was accepted or their face was detected.

---

### 9.3 Small tap targets on mobile

The form fields and buttons in `hotspot.html` are sized for a typical
smartphone. On small-screen devices (4.5-inch displays, minimum font size
settings) or for users with motor impairments, the tap targets may be below
the WCAG 2.1 minimum of 44×44 CSS pixels, causing repeated mis-taps.

---

## 10. Maintenance and Long-term Sustainability

### 10.1 face-api.js pinned at v0.22.2

`setup.js` downloads `face-api.min.js@0.22.2` from jsDelivr. The
face-api.js project has not had a release since December 2020. The CDN URL
will continue to work, but:

- Security vulnerabilities discovered in the pinned version will never be
  patched.
- The underlying TensorFlow.js version in this release has known
  incompatibilities with Chrome 120+ due to WebGL API changes that cause
  silent fallback to the (slower) CPU backend.
- If jsDelivr removes the version, `setup.js` fails and the server cannot
  start at all.

---

### 10.2 Node.js version and native-dns dependency

`dns-server.js` depends on `native-dns`, which requires building a native
C++ addon. It is incompatible with Node.js 16+ due to deprecated V8 APIs.
If a lecturer updates Node.js as part of a Windows update, `dns-server.js`
will fail to start with a cryptic native module error.

---

### 10.3 Session JSON schema evolution

`sessions.json` is written by the current server version. If the session data
structure changes in a future update (new fields added or renamed), old
sessions restored from `sessions.json` will have missing or mismatched fields.
There is no schema version in the file, so the server cannot detect or migrate
old formats — it silently reads incomplete data.

---

### 10.4 No automated test suite

There are no unit tests for `server.js`, `pdfService.js`, or `setup.js`.
Every change to the server must be verified manually by running the full
registration flow. The `parseMasterRosterLine()` function — described in
imp.md as the most fragile part of the backend — has 57 lines of regex and
no automated regression tests at all.

---

## Summary Table

| # | Difficulty | Severity | Frequency |
|---|-----------|----------|-----------|
| 1.1 | IP detection failure on non-standard subnet | High | Occasional |
| 1.2 | Windows 10-client hotspot limit | Critical | Always in large classes |
| 1.3 | University IT blocks hotspot | Critical | Common on managed hardware |
| 1.4 | Windows Firewall blocks port 5501 | High | First-time setup |
| 2.1 | Poor lighting — face not detected | High | Every dark venue |
| 2.2 | Masks, glasses, accessories | Medium | Daily |
| 2.4 | Photo-based proxy attack | High | Motivated cheaters |
| 2.5 | Identical twins rejected | Medium | Rare |
| 3.1 | 4-digit PIN brute-force risk | Medium | Theoretical |
| 3.3 | PIN visible on projector | Medium | Every session |
| 4.1 | Data lost on mid-write crash | Medium | Rare |
| 4.4 | No offline sync queue | Medium | Occasional |
| 5.1 | PDF generation blocks event loop | Medium | Large classes |
| 6.1 | iOS Safari blocks camera (HTTP) | Critical | All iPhone users |
| 6.2 | No WebGL on old Android | Medium | Budget phones |
| 7.1 | GDPR biometric consent missing | Critical | Every deployment |
| 7.3 | No consent UI before face scan | High | Every student |
| 8.1 | High lecturer technical skill required | High | Onboarding |
| 8.2 | Registration queue exceeds grace period | High | Large classes |
| 8.3 | Students join wrong session | Medium | Multi-room deployments |
| 8.5 | Laptop sleep kills server mid-session | High | Every session risk |
| 9.1 | Face recognition inaccessible to some students | High | Any deployment |
| 10.1 | face-api.js unpatchable (frozen project) | Medium | Long-term |
