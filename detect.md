# ServerConfig.detect() — Full Explanation

---

## What It Is

`ServerConfig.detect()` is the method responsible for deciding which server the
app will talk to for the rest of the session. It answers one question:

> "Is there a local hotspot server nearby, or should I use the cloud?"

The result drives every subsequent API call — session creation, student
registration, QR code generation, and dashboard refreshes all use the URL that
`detect()` found.

---

## Where It Lives

| File | Location |
|---|---|
| Method definition | `lib/services/server_config.dart` → `ServerConfig.detect()` line 173 |
| Background worker | `lib/services/server_config.dart` → `_detectServerInBackground()` line 16 |
| Called at startup | `lib/main.dart` line 14 |

---

## When It Runs

`detect()` is called **once**, during app startup, before the UI is shown:

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CourseService.seedFromManagement();
  await ServerConfig().detect();   // ← here
  await CloudService().initialize();
  runApp(const MyApp());
}
```

The `await` means the app waits for detection to finish before painting any
screen. This ensures `ServerConfig.baseUrl` is always ready by the time the
first widget appears.

---

## The Singleton Pattern

`ServerConfig` uses the singleton pattern — only one instance ever exists:

```dart
static final ServerConfig _instance = ServerConfig._internal();
factory ServerConfig() => _instance;
ServerConfig._internal();
```

This means `ServerConfig()` anywhere in the codebase always returns the same
object with the same cached detection result. There is no risk of two parts of
the app using different base URLs.

---

## The Cache Guard — `_hasDetected`

```dart
Future<void> detect() async {
  if (_hasDetected) return;   // ← exits immediately on all calls after the first
  // ... detection logic
}
```

Once detection runs successfully, `_hasDetected = true` is set and never cleared
unless `reset()` is called explicitly. Every subsequent call to `detect()`
returns in nanoseconds without doing any network work.

**Consequence:** If the app was launched while offline, the cached result is
`isOnline = false`. Connecting to the internet afterwards does nothing — the
app already made its decision and locked it in.

---

## The Background Isolate

Detection does not run on the main UI thread. It uses Flutter's `compute()`
function to spawn a background isolate:

```dart
final result = await compute<void, _ServerDetectionResult>(
  _detectServerInBackground,
  null,
);
```

`_detectServerInBackground` is a **top-level function** (required by `compute`)
that performs all the network probes. Running it on a separate thread means
hundreds of parallel HTTP requests do not freeze or slow the UI.

---

## The Four Detection Blocks

Detection proceeds in strict sequential order. The first block that finds a
responding server wins — later blocks are skipped.

---

### Block 1 + 2 — Local Network Scan (767 addresses, parallel)

All addresses are tried at the same time with an **800 ms timeout** each:

**Fixed candidates (5 addresses):**
```
http://192.168.137.1:5501   ← Windows Mobile Hotspot (most common case)
http://10.0.0.1:5501
http://192.168.43.1:5501    ← Android hotspot
http://172.20.10.1:5501     ← iOS hotspot
http://192.168.50.1:5501
```

**Full subnet scan (762 addresses):**
```
http://192.168.0.1  – 192.168.0.254  : 5501   (254 IPs)
http://192.168.1.1  – 192.168.1.254  : 5501   (254 IPs)
http://10.0.0.1     – 10.0.0.254     : 5501   (254 IPs)
```

Total: **767 parallel probes** all racing against the same 800 ms clock.

For each address, `_pingWithStrictTimeout()` sends `GET <address>/ping` and
checks for HTTP 200. The first address that returns 200 wins. The result:

```dart
return _ServerDetectionResult(url: winnerAddress, isOnline: false);
```

`isOnline: false` — a local server was found, this is Offline Mode.

If **none** of the 767 respond within 800 ms, the block exits and continues.

---

### Block 3 — Android Emulator Check (1 address, 800 ms)

```
http://10.0.2.2:5501
```

`10.0.2.2` is the special loopback address Android emulators use to reach the
host machine. This is only relevant when running the app in an Android Studio
emulator, not on a real phone.

Same result format: if it responds → `isOnline: false`, stop. If not → continue.

---

### Block 4 — Cloud Server Check (1 address, 2000 ms)

```
https://owhas.org
```

This is the **only block that can set `isOnline: true`**. The timeout is 2
seconds instead of 800 ms because an internet round-trip takes longer than a
local LAN probe.

```dart
if (await _pingWithStrictTimeout(onlineUrl, const Duration(seconds: 2))) {
  return _ServerDetectionResult(url: onlineUrl, isOnline: true);
}
```

If `owhas.org` responds with HTTP 200 → `isOnline: true`, Online Mode active.
If not → fall to Fallback.

---

### Fallback — Nothing Found

```dart
return _ServerDetectionResult(url: 'http://192.168.137.1:5501', isOnline: false);
```

If every single block fails, the app defaults to the Windows Mobile Hotspot
address. `isOnline` stays `false`. The orange warning banner will appear in the
dashboard because no server was actually confirmed.

---

## Worst-Case Timing

```
Block 1+2  →  800 ms  (all 767 probes timeout)
Block 3    →  800 ms  (emulator probe times out)
Block 4    →  2000 ms (cloud probe times out)
                ─────
Total      →  3600 ms  before the Fallback fires
```

In the best case (local server found immediately), detection completes in a
few milliseconds. In the worst case (no server anywhere), it takes about
3.6 seconds before the UI shows.

---

## What Gets Stored After Detection

```dart
_detectedUrl = result.url;    // the winning address (or fallback)
_isOnline    = result.isOnline; // true only if owhas.org won
_hasDetected = true;          // locks the cache
```

These are read by the rest of the app via getters:

| Getter | Returns |
|---|---|
| `ServerConfig().baseUrl` | The detected URL, or hotspot fallback |
| `ServerConfig().isOnline` | `true` = cloud mode, `false` = local mode |
| `ServerConfig().onlineUrl` | Always `https://owhas.org` (constant) |
| `ServerConfig().hotspotUrl` | Always `http://192.168.137.1:5501` (built at runtime) |
| `ServerConfig().emulatorUrl` | Always `http://10.0.2.2:5501` (built at runtime) |

---

## The `_pingWithStrictTimeout()` Helper

```dart
Future<bool> _pingWithStrictTimeout(String url, Duration timeout) async {
  try {
    final response = await http
        .get(Uri.parse('$url/ping'))
        .timeout(timeout, onTimeout: () {
          throw TimeoutException('Ping timeout for $url');
        });
    return response.statusCode == 200;
  } catch (_) {
    return false;   // any error → treat as not found
  }
}
```

Every probe appends `/ping` to the URL. The server (both local and cloud) must
respond to `GET /ping` with HTTP 200 for detection to succeed. Any exception —
timeout, connection refused, DNS failure — silently returns `false`.

---

## The `reset()` Method

```dart
void reset() {
  _hasDetected = false;
  _detectedUrl = null;
  _isOnline    = false;
}
```

`reset()` clears all three cached values. The very next call to `detect()` will
redo the full scan from scratch. This is the only way to re-run detection after
the app is already open.

---

## The Retry Button

The orange warning banner in the Lecturer Dashboard has a **Retry** button. It
calls:

```dart
ServerConfig().reset();          // clears _hasDetected
await ServerConfig().detect();   // full re-scan from scratch
```

Use this if:
- The app was launched before you connected to the internet.
- The `owhas.org` server was offline at startup but is now running.
- You switched from one network to another after opening the app.

---

## Full Flow Diagram

```
app starts (main.dart)
        │
        ▼
ServerConfig().detect()
        │
        ├─ _hasDetected == true? → return immediately (cached result)
        │
        └─ _hasDetected == false
                │
                ▼
        compute(_detectServerInBackground)   ← background isolate
                │
                ├─ Block 1+2: 767 local IPs, parallel, 800 ms timeout
                │       │
                │       ├─ Any responds HTTP 200?
                │       │     YES → url = winner, isOnline = false  ──────┐
                │       │     NO  → continue                              │
                │                                                         │
                ├─ Block 3: emulator 10.0.2.2, 800 ms timeout             │
                │       │                                                 │
                │       ├─ Responds HTTP 200?                             │
                │       │     YES → url = 10.0.2.2:5501, isOnline = false ┤
                │       │     NO  → continue                              │
                │                                                         │
                ├─ Block 4: owhas.org, 2000 ms timeout                    │
                │       │                                                 │
                │       ├─ Responds HTTP 200?                             │
                │       │     YES → url = owhas.org, isOnline = true  ────┤
                │       │     NO  → continue                              │
                │                                                         │
                └─ Fallback: url = 192.168.137.1:5501, isOnline = false ──┤
                                                                          │
                                                   ◄────────────────────┘
        _detectedUrl = url
        _isOnline    = isOnline
        _hasDetected = true

        All API calls from this point use ServerConfig().baseUrl
```

---

## Summary Table

| Situation | `isOnline` | `baseUrl` |
|---|---|---|
| Local server found on LAN | `false` | The LAN IP that responded |
| Android emulator server found | `false` | `http://10.0.2.2:5501` |
| `owhas.org` found (no local server) | `true` | `https://owhas.org` |
| Nothing found anywhere | `false` | `http://192.168.137.1:5501` (fallback) |
| App launched offline, no Retry | `false` | `http://192.168.137.1:5501` (fallback) |
| Retry tapped after connecting | depends on current network | re-runs all 4 blocks |
