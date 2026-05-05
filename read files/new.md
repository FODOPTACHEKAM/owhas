# Differentiating Sessions Across Multiple Lecturer Devices

## Problem Statement

Currently, the attendance system uses a **static QR code URL** (`http://192.168.137.1:5501/public/hotspot.html`) across all sessions. This creates two critical issues when multiple lecturers launch sessions in proximity (same building, shared network, or overlapping Wi-Fi coverage):

1. **Student Confusion**: A student scanning any lecturer's QR code lands on the identical registration form with no visual indication of which course, lecturer, or session they are joining.

2. **Data Collision**: The Node.js server stores all attendees in a single global `attendees` array with **no session-scoped isolation**. If Lecturer A and Lecturer B both run sessions simultaneously, student registrations from both sessions merge into one pool. Reports, verification stats, and PDF exports become unreliable or completely invalid.

### Current Data Flow (Problematic)

```
Lecturer A Phone ──QR──▶ hotspot.html ──POST /connect──▶ server.js (global attendees[])
                                                              ▲
Lecturer B Phone ──QR──▶ hotspot.html ──POST /connect───────┘
```

Both QR codes encode the **exact same URL**. The server has no mechanism to bucket attendees by originating session.

---

## Alternative Approach: The "Printed Poster" Method (Offline & Static)

While embedding a session token directly into the QR code is technically robust, it requires students to **re-scan a new QR code for every single session**. In a university setting where students attend multiple classes per day, this creates friction at the classroom door.

A more practical, offline-friendly alternative is the **Printed Poster Method**.

### Concept

Since the Hotspot Attendance System (HAS) uses a **local IP address that stays consistent for a specific lecturer's phone hotspot** (e.g., `192.168.137.1`), the lecturer can print a **permanent physical poster** and post it on the classroom wall or door.

**How it works:**
1. The poster contains a **static "Base QR"** that always points to the local portal: `http://192.168.137.1:5501/public/hotspot.html`
2. When a lecturer starts a session, the Flutter app generates a **short, human-readable 6-digit Session PIN** (e.g., `558219`)
3. The lecturer writes this PIN on the whiteboard or projects it on screen
4. Students scan the permanent poster once, reach the portal, and type in the PIN to join today's specific session

### Student Experience

```
┌─────────────────────────────────────────┐
│  📱 Student walks into classroom        │
│                                         │
│  1. Sees laminated poster on wall:      │
│     ┌─────────────────────────┐         │
│     │  📷 SCAN TO REGISTER    │         │
│     │                         │         │
│     │  [PERMANENT QR CODE]    │         │
│     │                         │         │
│     │  ICTU Attendance System │         │
│     └─────────────────────────┘         │
│                                         │
│  2. Scans QR → Browser opens portal     │
│                                         │
│  3. Looks at whiteboard:                │
│     "Today's PIN: 558219"               │
│                                         │
│  4. Types PIN into form field           │
│     + enters matricule & name           │
│                                         │
│  5. ✅ "Registered for CS 101!"         │
└─────────────────────────────────────────┘
```

### Why This Method Excels

| Advantage | Explanation |
|-----------|-------------|
| **No re-scanning** | Students scan the poster once per semester and bookmark the page. Only the PIN changes. |
| **Low friction** | Typing 6 digits is faster than lining up to scan a new QR code on the lecturer's phone. |
| **Works offline** | The poster is physical. No internet required beyond the local hotspot. |
| **Lecturer convenience** | No need to hold up a phone or pass around a QR code. Just announce the PIN. |
| **Visual verification** | Students see the course name and lecturer after entering the PIN, confirming they're in the right session. |
| **Cost-effective** | One laminated poster per classroom costs almost nothing. |

### Technical Implementation: PIN-Based Session Differentiation

#### 1. PIN Generation (Flutter — `lib/services/session_service.dart`)

Instead of a long cryptographic token, generate a short numeric PIN:

```dart
import 'dart:math';

String generateSessionPin() {
  final random = Random.secure();
  // 6-digit PIN (100000 - 999999)
  return (100000 + random.nextInt(900000)).toString();
}
```

**PIN Properties:**
- **6 digits**: Easy to read, write, and type. Fits on a whiteboard.
- **No sequential patterns**: Avoid `111111`, `123456` via rejection sampling.
- **Collision-resistant across active sessions**: Server rejects a PIN if another active session is already using it.
- **Auto-expires**: When the lecturer ends the session, the PIN is deactivated.

#### 2. Lecturer Dashboard Display (Flutter — `lib/pages/lecturer_dashboard_page.dart`)

The dashboard prominently displays the session PIN alongside the static QR code:

```dart
class _SessionInfoCard extends StatelessWidget {
  final dynamic session;
  const _SessionInfoCard({required this.session});

  // Base URL never changes — this is the POSTER QR
  static const String _baseQrUrl = 'http://192.168.137.1:5501/public/hotspot.html';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... course name, start time, etc.
            
            // ─── PIN DISPLAY (Large & Prominent) ───
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: [
                  Text(
                    'SESSION PIN',
                    style: context.textStyles.labelLarge?.withColor(
                      Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    session.sessionPin, // e.g., "558219"
                    style: context.textStyles.displayLarge?.bold.withColor(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Write this on the board',
                    style: context.textStyles.bodySmall?.withColor(
                      Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // ─── STATIC POSTER QR (Optional display) ───
            Row(
              children: [
                QrImageView(
                  data: _baseQrUrl,
                  size: 80,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permanent Poster QR',
                        style: context.textStyles.titleSmall?.semiBold,
                      ),
                      Text(
                        'Students can scan this once and bookmark the page. The PIN changes each session.',
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 3. Student Web Form with PIN Entry (`public/hotspot.html`)

The web form now includes a PIN field before the personal details:

```html
<!-- New PIN input group -->
<div class="input-group">
    <label>🔑 Session PIN <span class="required-star">*</span></label>
    <input type="text" id="sessionPin" class="input-field" 
           placeholder="e.g., 558219" maxlength="6" inputmode="numeric" autocomplete="off">
    <div class="error-message" id="pinError"></div>
    <div class="helper-text">Enter the 6-digit PIN displayed by your lecturer.</div>
</div>

<!-- Session info panel (appears after valid PIN) -->
<div id="sessionInfoPanel" class="session-info" style="display: none;">
    <div class="result-title">📚 SESSION</div>
    <div class="result-content" id="sessionDetails">
        <!-- Populated via JS: "CS 101 - Dr. Smith" -->
    </div>
</div>
```

```javascript
// JavaScript: Validate PIN with server before showing registration form
async function validatePin(pin) {
    try {
        const response = await fetch(SERVER_URL + '/api/validate-pin', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ pin })
        });
        
        if (response.ok) {
            const data = await response.json();
            document.getElementById('sessionDetails').innerHTML = 
                `<strong>${data.courseName}</strong><br>Lecturer: ${data.lecturerName}`;
            document.getElementById('sessionInfoPanel').style.display = 'block';
            return true;
        } else {
            showPinError("Invalid or expired PIN. Check with your lecturer.");
            return false;
        }
    } catch (err) {
        showPinError("Cannot verify PIN. Check your connection.");
        return false;
    }
}
```

#### 4. Server-Side PIN Management (Node.js — `server.js`)

Replace the global `attendees` array with a **PIN-indexed session map**:

```javascript
// BEFORE (global pool — problematic)
let attendees = [];

// AFTER (PIN-scoped sessions)
const activeSessions = new Map(); // pin -> { courseName, lecturerId, attendees[], createdAt, expiresAt }

// Generate a new session with a PIN
app.post('/api/session-init', (req, res) => {
    const { courseName, courseCode, lecturerId, pin } = req.body;
    
    // Ensure PIN is unique among active sessions
    if (activeSessions.has(pin)) {
        return res.status(409).json({ error: 'PIN already in use by an active session' });
    }
    
    activeSessions.set(pin, {
        courseName,
        courseCode,
        lecturerId,
        attendees: [],
        createdAt: new Date(),
        expiresAt: new Date(Date.now() + 4 * 60 * 60 * 1000), // 4 hours
    });
    
    res.json({ success: true, pin, message: 'Session activated with PIN ' + pin });
});

// Validate a student's PIN
app.post('/api/validate-pin', (req, res) => {
    const { pin } = req.body;
    const session = activeSessions.get(pin);
    
    if (!session) {
        return res.status(404).json({ error: 'Invalid or expired PIN' });
    }
    
    if (new Date() > session.expiresAt) {
        activeSessions.delete(pin);
        return res.status(410).json({ error: 'Session has expired' });
    }
    
    res.json({ 
        valid: true, 
        courseName: session.courseName,
        lecturerName: session.lecturerId // or resolved name
    });
});

// Register a student with PIN
app.post('/connect', (req, res) => {
    const { username, matricule, email, sessionPin } = req.body;
    const studentIP = req.headers['x-forwarded-for'] || req.ip;
    
    // 1. Validate PIN
    if (!sessionPin || !/^\d{6}$/.test(sessionPin)) {
        return res.status(400).send("A valid 6-digit Session PIN is required.");
    }
    
    const session = activeSessions.get(sessionPin);
    if (!session) {
        return res.status(404).send("Invalid or expired PIN. Ask your lecturer for the current PIN.");
    }
    
    // 2. Session-scoped duplicate check
    const existingEntry = session.attendees.find(a => a.ip === studentIP);
    if (existingEntry) {
        if (existingEntry.matricule !== matricule) {
            return res.status(403).send("This device is already registered under a different matricule.");
        }
        return res.status(200).send("You are already registered for this session!");
    }
    
    // 3. Store in session-scoped array
    session.attendees.push({
        username, matricule, email,
        ip: studentIP,
        connectedAt: new Date().toISOString(),
        time: new Date().toLocaleString()
    });
    
    res.status(200).send(`Successfully registered for ${session.courseName}!`);
});

// Get attendees for a specific session (lecturer dashboard)
app.get('/api/attendees', (req, res) => {
    const pin = req.query.pin;
    const session = activeSessions.get(pin);
    
    if (!session) {
        return res.status(404).json({ error: 'Session not found' });
    }
    
    res.json({ attendees: session.attendees });
});

// End session (deactivates PIN)
app.post('/api/end-session', (req, res) => {
    const { pin } = req.body;
    const session = activeSessions.get(pin);
    
    if (!session) {
        return res.status(404).json({ error: 'Session not found' });
    }
    
    // Generate final report, then clean up
    const attendeeCount = session.attendees.length;
    activeSessions.delete(pin); // PIN is now free for reuse
    
    res.json({ 
        success: true, 
        message: `Session ended. ${attendeeCount} attendee(s) recorded.`,
        attendeeCount 
    });
});
```

### Comparison: Token-in-QR vs. Printed Poster + PIN

| Criteria | Token-in-QR | Printed Poster + PIN |
|----------|-------------|----------------------|
| **Student effort per session** | Must scan new QR each time | Type 6 digits (or bookmark page) |
| **Lecturer effort per session** | Display phone with QR | Write PIN on board or announce verbally |
| **Physical materials** | Phone screen only | One laminated poster per room |
| **Works without lecturer phone visible?** | No | Yes |
| **Session differentiation** | Strong (long token) | Strong (6-digit PIN) |
| **Collision risk** | Negligible | Low (1 in 900,000, plus server rejects duplicates) |
| **Offline capability** | Requires QR generation | Poster is permanent |
| **Ease of implementation** | Moderate | Simple |
| **Best for** | Ad-hoc or roaming sessions | Fixed classrooms, recurring lectures |

### Recommendation

For the Hotspot Attendance System's typical use case — **university classrooms with recurring lectures** — the **Printed Poster + PIN Method is strongly recommended** as the primary approach. It reduces friction for both students and lecturers while maintaining clean session isolation.

The Token-in-QR approach remains valuable as a **fallback or alternative** for:
- Ad-hoc sessions outside regular classrooms
- Lecturers who move between rooms without posters
- Situations where a student cannot see the whiteboard (e.g., remote registration)

Both methods can coexist in the same codebase: the server accepts either `sessionToken` (from QR) or `sessionPin` (from poster), and the Flutter app lets the lecturer choose which mode to use when starting a session.

---

## Proposed Solution: Session-Specific QR Code Tokens

When a lecturer launches a session, the QR code should encode a **unique, non-guessable session token** that ties every student registration back to that specific session and lecturer device.

### Key Design Principles

| Principle | Rationale |
|-----------|-----------|
| **Uniqueness** | No two sessions should ever share the same token, even if created by the same lecturer seconds apart. |
| **Tamper Resistance** | Tokens should be opaque (e.g., UUID v4 or signed JWT) so students cannot forge or predict other session tokens. |
| **Self-Contained** | The token alone should be sufficient for the server to identify the session without additional database lookups (stateless preferred). |
| **Time-Bound** | Tokens should expire when the session ends to prevent stale registrations. |
| **Readable by Web** | The QR code is scanned by student phones via a web browser, so the token must travel via URL query parameters or path segments. |

---

## Technical Implementation

### 1. Session Token Generation (Flutter — `lib/services/session_service.dart`)

When `createSession()` is called, generate a cryptographically secure session token:

```dart
import 'dart:math';
import 'dart:convert';

String generateSessionToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}
```

**Token Composition Options:**

| Approach | Format | Pros | Cons |
|----------|--------|------|------|
| **Opaque UUID** | `sess_abc123...xyz` | Simple, no data leakage | Requires server-side lookup |
| **Signed JWT** | `eyJhbGciOiJIUzI1NiIs...` | Self-contained (sessionId, lecturerId, courseName, expiry) | Slightly longer QR payload |
| **Composite Token** | `sessionId:lecturerId:signature` | Verifiable without DB, moderate length | Requires shared secret for HMAC |

**Recommended**: **Signed JWT** or **Composite HMAC Token** because the Node.js server is stateless (in-memory `attendees[]`). A self-contained token avoids needing a session database on the server.

**Example Composite Token:**
```
<sessionId>:<lecturerId>:<courseCode>:<timestamp>:<HMAC-SHA256>
```

The Flutter app and Node.js server share a lightweight secret (e.g., stored in `lib/services/api_service.dart` and `server.js`) to verify the HMAC.

---

### 2. QR Code URL Structure (Flutter — `lib/pages/lecturer_dashboard_page.dart`)

Replace the static `_qrUrl` with a dynamic, tokenized URL:

```dart
// BEFORE (static — problematic)
static const String _qrUrl = 'http://192.168.137.1:5501/public/hotspot.html';

// AFTER (dynamic — session-scoped)
String get _qrUrl {
  final token = session.sessionToken; // generated at creation
  return 'http://192.168.137.1:5501/public/hotspot.html?s=$essionToken';
}
```

**QR Code Payload:**
```
http://192.168.137.1:5501/public/hotspot.html?s=eyJzZXNzaW9uSWQiOiJzZXNfMTIzIiwibGVjdHVyZXJJZCI6ImxlY3RfNDU2IiwiY291cnNlIjoiQ1MgMTAxIiwiZXhwIjoxNzE2MjM5MDIyfQ.signature
```

The query parameter `s` carries the session token. The `hotspot.html` page reads this on load.

---

### 3. Student-Side Token Extraction (Web — `public/hotspot.html`)

Modify the student registration page to parse the token from the URL and display session context:

```javascript
// On page load
const urlParams = new URLSearchParams(window.location.search);
const sessionToken = urlParams.get('s');

if (!sessionToken) {
  showError("Invalid QR code. Please scan the QR code provided by your lecturer.");
}

// Optional: Decode JWT payload to show course/lecturer info
const payload = JSON.parse(atob(sessionToken.split('.')[1]));
document.getElementById('sessionInfo').textContent = 
  `Registering for: ${payload.course} | Lecturer: ${payload.lecturerId}`;
```

**Visual Differentiation for Students:**
- Display **course name** and **lecturer name** prominently on the form header
- Show a **session-specific color** or **icon** derived from the token hash
- This prevents students from accidentally registering for the wrong session

---

### 4. Server-Side Token Validation & Isolation (Node.js — `server.js`)

#### 4.1 Store Attendees with Session Context

Change the global `attendees` array to a **Map of session-scoped arrays**:

```javascript
// BEFORE (global pool — problematic)
let attendees = [];

// AFTER (session-scoped buckets)
const sessionAttendees = new Map(); // sessionToken -> Array<attendee>
const sessionMetadata = new Map();  // sessionToken -> { courseName, lecturerId, createdAt, expiresAt }
```

#### 4.2 Validate Token on Registration

```javascript
app.post('/connect', (req, res) => {
    const { username, matricule, email, sessionToken } = req.body;
    
    // 1. Token presence check
    if (!sessionToken) {
        return res.status(400).send("Missing session token. Please scan the QR code again.");
    }

    // 2. Token integrity check (verify HMAC or JWT signature)
    if (!verifyToken(sessionToken)) {
        return res.status(403).send("Invalid or expired session token.");
    }

    // 3. Token expiration check
    const meta = sessionMetadata.get(sessionToken);
    if (meta && new Date() > new Date(meta.expiresAt)) {
        return res.status(410).send("This session has ended. Registration is closed.");
    }

    // 4. Session-scoped duplicate check
    const attendees = sessionAttendees.get(sessionToken) || [];
    const studentIP = req.headers['x-forwarded-for'] || req.ip;
    const existingEntry = attendees.find(a => a.ip === studentIP);
    
    if (existingEntry) {
        if (existingEntry.matricule !== matricule) {
            return res.status(403).send("This device is already registered under a different matricule in this session.");
        }
        return res.status(200).send("You are already registered for this session!");
    }

    // 5. Store with session context
    const newAttendee = {
        username, matricule, email,
        ip: studentIP,
        sessionToken,
        connectedAt: new Date().toISOString(),
        time: new Date().toLocaleString()
    };

    if (!sessionAttendees.has(sessionToken)) {
        sessionAttendees.set(sessionToken, []);
    }
    sessionAttendees.get(sessionToken).push(newAttendee);
    
    res.status(200).send("Successfully Registered for " + (meta?.courseName || 'the session') + "!");
});
```

#### 4.3 Session-Scoped API Endpoints

All data retrieval endpoints must filter by `sessionToken`:

```javascript
// GET /api/attendees?s=<token>
app.get('/api/attendees', (req, res) => {
    const token = req.query.s;
    if (!token || !sessionAttendees.has(token)) {
        return res.status(404).json({ error: 'Session not found' });
    }
    res.json({ attendees: sessionAttendees.get(token) });
});

// GET /api/stats?s=<token>
app.get('/api/stats', (req, res) => {
    const token = req.query.s;
    const attendees = sessionAttendees.get(token) || [];
    // ... calculate verified/pending scoped to this session only
});

// GET /export?s=<token>
app.get('/export', (req, res) => {
    const token = req.query.s;
    const attendees = sessionAttendees.get(token) || [];
    if (attendees.length === 0) return res.send("No attendees for this session yet.");
    generateAttendancePDF(attendees, res, sessionMetadata.get(token));
});
```

---

### 5. Flutter-to-Server Communication (`lib/services/api_service.dart`)

The Flutter app must include the `sessionToken` in every API call:

```dart
class ApiService {
  static const String baseUrl = 'http://192.168.137.1:5501';
  String? _sessionToken;

  void setSessionToken(String token) => _sessionToken = token;

  Future<List<Map<String, dynamic>>> fetchServerAttendees() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/attendees?s=$_sessionToken'),
    ).timeout(const Duration(seconds: 10));
    // ...
  }

  Future<void> resetServerSession({String? courseName, String? courseCode}) async {
    // When creating a new session, also register the token on the server
    final response = await http.post(
      Uri.parse('$baseUrl/api/session-init'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sessionToken': _sessionToken,
        'courseName': courseName,
        'courseCode': courseCode,
        'expiresAt': DateTime.now().add(Duration(hours: 4)).toIso8601String(),
      }),
    );
  }
}
```

---

## Data Collection Differentiation

With session tokens, data collection becomes cleanly partitioned:

| Data Point | Without Tokens (Current) | With Tokens (Proposed) |
|------------|--------------------------|------------------------|
| **Attendee List** | Global merge of all sessions | Isolated per `sessionToken` |
| **Verification Stats** | Incorrect (cross-session contamination) | Accurate per session |
| **PDF Export** | All students from all sessions | Only students from the requested session |
| **Wi-Fi Device Count** | Global count | Can be scoped if token is passed to network scan |
| **Cumulative Attendance** | Ambiguous which session contributed | Clear lineage: `sessionToken` → `attendanceRecord` |
| **Lecturer Analytics** | Impossible to attribute | Direct attribution via `lecturerId` in token |

### Example: Two Simultaneous Sessions

```
Lecturer A (CS 101) ──QR──▶ hotspot.html?s=TOKEN_A ──▶ server.js ──▶ attendees[TOKEN_A]
Lecturer B (MATH 202) ──QR──▶ hotspot.html?s=TOKEN_B ──▶ server.js ──▶ attendees[TOKEN_B]
```

- Student X scans Lecturer A's QR → stored in `attendees[TOKEN_A]`
- Student Y scans Lecturer B's QR → stored in `attendees[TOKEN_B]`
- Lecturer A refreshes dashboard → sees only `attendees[TOKEN_A]`
- Lecturer B downloads PDF → exports only `attendees[TOKEN_B]`

---

## Security Considerations

| Threat | Mitigation |
|--------|------------|
| **Token Guessing** | Use 256-bit random tokens or HMAC-signed payloads. Entropy must be > 128 bits. |
| **Token Replay** | Bind token to session time window. Reject registrations after `endTime` or explicit session closure. |
| **Token Sharing** | Acceptable risk — if a student shares their QR code with a friend, both register under the same session (which is valid for attendance). |
| **Man-in-the-Middle** | Tokens travel over HTTP (hotspot LAN). Since the lecturer controls the network, this is acceptable. For production, consider HTTPS with a local certificate. |
| **Server Memory Exhaustion** | `sessionAttendees` Map grows with each session. Implement cleanup: remove entries older than 24 hours or when `session.isActive == false`. |

---

## Migration Path

### Phase 1: Backward-Compatible Token Support
- Modify `server.js` to accept an **optional** `sessionToken` field
- If no token is provided, fall back to a `"legacy"` default bucket
- Existing QR codes without `?s=` continue to work

### Phase 2: Flutter App Updates
- Update `session_service.dart` to generate tokens on session creation
- Update `lecturer_dashboard_page.dart` to encode token in QR code
- Update `api_service.dart` to pass token in all requests

### Phase 3: Web Form Updates
- Update `hotspot.html` to read `?s=` parameter
- Display session info (course name, lecturer) on the form
- Send `sessionToken` in the `POST /connect` body

### Phase 4: Server Full Migration
- Make `sessionToken` **required** on all endpoints
- Remove legacy global `attendees` array
- Implement automatic session cleanup

---

## Files Requiring Changes

| File | Change |
|------|--------|
| `lib/services/session_service.dart` | Generate `sessionToken` when creating `AttendanceSession` |
| `lib/models/session.dart` | Add `sessionToken` field to `AttendanceSession` model |
| `lib/pages/lecturer_dashboard_page.dart` | Encode `sessionToken` into QR code URL (`_qrUrl`) |
| `lib/services/api_service.dart` | Pass `sessionToken` in all HTTP requests to the server |
| `public/hotspot.html` | Read `?s=` parameter, display session context, include token in POST body |
| `server.js` | Replace global `attendees[]` with `Map<token, attendees[]>`, validate tokens on every request |
| `lib/services/pdfService.js` / `lib/services/pdf_service.dart` | Filter attendees by `sessionToken` when generating reports |

---

## Summary

The core issue is that the **QR code is a dumb pointer** to a shared resource. By making the QR code a **smart, self-describing token**, we achieve:

1. **Student Clarity**: Students see exactly which course and lecturer they are registering for
2. **Data Integrity**: Each session's attendance data is physically isolated on the server
3. **Multi-Lecturer Support**: Multiple lecturers can run sessions in the same room without data collision
4. **Auditability**: Every attendance record is traceable back to a specific session and lecturer device

The token-based approach is minimal in complexity but maximal in impact for data correctness.

