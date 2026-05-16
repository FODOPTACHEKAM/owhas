# Why Online Mode Is Not Detected — Full Explanation

---

## The Core Misunderstanding

**Having internet on your phone is NOT the same as being in Online Mode.**

In OwHAS, "Online Mode" means one specific thing:
> `owhas.org` responded to a `/ping` request with `{"status":"ok"}` and
> no local server responded first.

Just having a Wi-Fi connection or mobile data does not trigger Online Mode.
The app does not check your network type, signal strength, or whether a
browser can open a website. It only checks whether the servers it knows
about are reachable — and it checks them in a fixed order where local
servers always come before the cloud.

---

## How the Detection Works (Step by Step)

When the app starts, `ServerConfig.detect()` runs in a background isolate.
It does the following four blocks in strict sequential order:

```
BLOCK 1 + 2 — Local network scan
────────────────────────────────────────────────────────────────
Tries 767 IP addresses in parallel, each with an 800 ms timeout:

  Fixed candidates:
    192.168.137.1:5501   (Windows Mobile Hotspot)
    192.168.43.1:5501    (Android hotspot)
    172.20.10.1:5501     (iOS hotspot)
    10.0.0.1:5501
    192.168.50.1:5501

  Subnet scan:
    192.168.0.1 – 192.168.0.254 : 5501   (254 IPs)
    192.168.1.1 – 192.168.1.254 : 5501   (254 IPs)
    10.0.0.1    – 10.0.0.254    : 5501   (254 IPs)

  → If ANY of these replies with HTTP 200:
      isOnline = false   ← local server found, STOP HERE
  → If NONE reply:
      Wait the full 800 ms for all timeouts, then continue.

BLOCK 3 — Android emulator check
────────────────────────────────────────────────────────────────
  10.0.2.2:5501 with 800 ms timeout

  → If it replies: isOnline = false, STOP HERE
  → If no reply:   continue after 800 ms

BLOCK 4 — Cloud server check  ← THE ONLY PLACE isOnline CAN BE TRUE
────────────────────────────────────────────────────────────────
  https://owhas.org/ping with 2000 ms timeout

  → If owhas.org replies with HTTP 200: isOnline = true ✓
  → If no reply:  fall through to FALLBACK

FALLBACK — Nothing found
────────────────────────────────────────────────────────────────
  isOnline = false
  baseUrl  = http://192.168.137.1:5501  (default hotspot URL)
  (No server was found — the orange warning banner will appear)
```

The total worst-case time before the cloud is even tried:
`800 ms (block 1+2) + 800 ms (block 3) = 1600 ms minimum delay`.

---

## The Three Reasons Online Mode Fails

### Reason 1 — owhas.org Has No Running Server

This is the most common reason.

Owning the domain name `owhas.org` or pointing it to an IP address is not
enough. A Node.js server running `server.js` must be actively deployed and
listening on that domain, and it must respond to:

```
GET https://owhas.org/ping
→ { "status": "ok" }
```

If the server is not deployed, Block 4 gets no response and the detection
falls to the Fallback. The app ends up in offline mode with the orange
warning banner, even though the phone has internet.

**What you need to do:**
Deploy the `backend/` folder to a cloud platform. The `onl.md` file in this
project explains three options:
- Cloudflare Tunnel (5 minutes, free, runs from your PC)
- Render.com (permanent free URL, no PC needed)
- A VPS like DigitalOcean (~$5/month, full control)

Until one of these is done, Online Mode will never activate.

---

### Reason 2 — The App Was Launched Before You Were Connected

`detect()` runs **once** — at app startup in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CourseService.seedFromManagement();
  await ServerConfig().detect();   // ← runs ONCE here
  await CloudService().initialize();
  runApp(const MyApp());
}
```

After this runs, `_hasDetected` is set to `true`. Every future call to
`detect()` returns immediately with the cached result — it never rescans:

```dart
Future<void> detect() async {
  if (_hasDetected) return;   // ← exits immediately if already run
  // ... detection logic
}
```

**The scenario that causes the problem:**
1. You open the app while offline or on a network with no server.
2. Detection runs → nothing found → Fallback → `isOnline = false` cached.
3. You connect to the internet (Wi-Fi or mobile data).
4. The app is still running → `_hasDetected = true` → detection will NOT
   re-run → still shows `isOnline = false`.
5. Your phone has internet but the app will never know unless you force
   a re-scan.

**How to fix it:**
- Tap the **Retry** button on the orange warning banner. This calls
  `ServerConfig().reset()` followed by `detect()` again.
- Or close the app completely and reopen it while connected.

---

### Reason 3 — Something on Your Wi-Fi Responds on Port 5501

This is rare but possible on corporate, university, or shared networks.

If any device on the current Wi-Fi network happens to respond to a TCP
connection on port 5501 with an HTTP 200 status code, the subnet scan in
Block 1+2 will treat it as a local OwHAS server and set `isOnline = false`.
The cloud is never tried.

Port 5501 is not a standard well-known port, so this is unlikely in a home
or personal hotspot. It is more likely in large institutional networks where
many services run on non-standard ports.

**How to check:**
Look at the server warning banner in the dashboard — it shows which URL
was detected. If it shows an unexpected local IP (e.g., `192.168.1.45:5501`)
that is not your PC, a device on the network is interfering.

---

## Summary Table

| Situation | Online Mode activates? | Reason |
|---|---|---|
| Phone has internet, `owhas.org` server is running, app just opened | YES | Block 4 finds the cloud server |
| Phone has internet, `owhas.org` server is NOT deployed | NO | Block 4 gets no response → Fallback |
| Phone was offline at app launch, connected later | NO | `_hasDetected = true`, cached result used |
| Phone has internet but local PC server is also running | NO | Block 1/2 finds local server first |
| Phone has internet, tapped Retry after connecting | YES (if server deployed) | `reset()` clears cache, `detect()` re-runs |
| Phone has internet, another device on the LAN uses port 5501 | NO | Block 1/2 false positive |

---

## What Must Be True for Online Mode to Activate

All three conditions must be met simultaneously:

```
1. owhas.org must have a deployed, running server
   that responds to GET /ping with HTTP 200.

2. No local server (server.js on a PC) must be
   reachable on the phone's current network.

3. The app must run detect() AFTER the phone is
   already connected to the internet.
   (Launch the app while online, or tap Retry.)
```

If any one of these three is missing, the app will not enter Online Mode
regardless of whether the phone has an active internet connection.

---

## How to Force a Re-Detection Without Restarting

If the app is already open and you want to switch to Online Mode:

1. Ensure `owhas.org` has a running server.
2. Ensure you are connected to the internet.
3. Ensure no local server is running on your network.
4. Tap the **Retry** button on the orange warning banner
   in the Lecturer Dashboard.

The Retry button calls:
```dart
ServerConfig().reset();   // clears _hasDetected = false
await ServerConfig().detect();  // full re-scan from scratch
```

If `owhas.org` responds this time, the banner disappears and the app
switches to Online Mode for the current session.
