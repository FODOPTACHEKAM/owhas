# How hotspot.html Opens Automatically on Student Phones

---

## Overview

When a student connects their phone to the lecturer's Wi-Fi hotspot, three
separate mechanisms work together to bring the attendance page to their screen
without them needing to type any URL:

| Mechanism | How student sees it | Port | Needs Admin? |
|---|---|---|---|
| Captive portal | "Sign in to network" popup | 80 | Yes |
| mDNS hostname | Types `http://owhas.local` | 5353 (UDP) | No |
| LAN DNS hostname | Types `http://owhas.lan` | 53 (UDP) | Yes |

All three are started automatically when `server.js` runs.

---

## Mechanism 1 — Captive Portal (the automatic popup)

### What phones do when they join a new Wi-Fi

Every major phone OS has a built-in "captive portal detection" system. The
moment a device connects to a Wi-Fi network it sends a test HTTP request to a
well-known address to check whether the network has internet access.

| OS | URL probed | Expected response |
|---|---|---|
| Android (Chrome / AOSP) | `http://connectivitycheck.gstatic.com/generate_204` | HTTP 204 (No Content) |
| Android (alternate) | `/gen_204` | HTTP 204 |
| iOS / macOS | `/hotspot-detect.html` | HTTP 200 with specific body |
| iOS (older) | `/library/test/success.html` | HTTP 200 |
| Windows | `/connecttest.txt` | HTTP 200 |
| Windows NCSI | `/ncsi.txt` | HTTP 200 |
| Firefox | `/success.txt` | HTTP 200 |

If the response is **anything other than what is expected** (e.g., a `302`
redirect), the OS concludes "this network has a captive portal" and:

1. Shows a **"Sign in to network"** notification.
2. Taps it → opens the phone's built-in mini browser.
3. The mini browser follows the redirect → lands on `hotspot.html`.

This is the same mechanism used by hotel Wi-Fi login pages, airport portals,
and school networks.

### How the server intercepts the probe

`server.js` starts a **second HTTP server on port 80** (the browser default
port). This server listens on all network interfaces (`0.0.0.0:80`) and
intercepts every captive portal probe path:

```javascript
// backend/server.js  →  _startHttp80Redirect()

const captivePaths = [
  '/generate_204',              // Android Chrome
  '/gen_204',                   // Android alt
  '/hotspot-detect.html',       // iOS / macOS
  '/library/test/success.html', // iOS older
  '/connecttest.txt',           // Windows
  '/ncsi.txt',                  // Windows NCSI
  '/success.txt',               // Firefox
  '/canonical.html',            // Ubuntu
  '/chat',                      // Android alt
];

captivePaths.forEach(p =>
  redirect.get(p, (_req, res) =>
    res.redirect(302, 'http://192.168.137.1:5501/public/hotspot.html')
  )
);

// Any other URL on port 80 → attendance page
redirect.use((_req, res) => res.redirect(302, attendancePage));
```

The 302 redirect tells the OS browser: "go here instead." Every path on
port 80 lands the student on `hotspot.html`.

### Why port 80 needs Administrator rights

Windows does not allow programs to bind to ports below 1024 unless they are
running as Administrator. Port 80 is below 1024, so if `server.js` is started
with a normal double-click, the captive portal server fails with:

```
[HTTP80] Port 80 permission denied — run start-server.bat as Administrator.
```

**Solution:** Always start the server using `start-server.bat`, which
self-elevates to Administrator automatically.

---

## Mechanism 2 — mDNS Hostname: `http://owhas.local`

### What mDNS is

mDNS (Multicast DNS, RFC 6762) is a zero-configuration protocol that lets
devices resolve `.local` hostnames without any central DNS server. Android 8+,
iOS, and Windows 10+ all support it natively.

When a student types `http://owhas.local` in Chrome, the phone sends a
multicast DNS query to the group address `224.0.0.251` on UDP port 5353. Any
device on the same LAN segment that claims to own `owhas.local` can answer.

### How the server answers mDNS queries

`server.js` starts a raw UDP socket that joins the mDNS multicast group and
listens for queries:

```javascript
// backend/server.js  →  _startMdnsResponder()

const sock = dgram.createSocket({ type: 'udp4', reuseAddr: true });
sock.bind(5353, () => {
  sock.addMembership('224.0.0.251', detectedHotspotIP);
});

sock.on('message', (msg, rinfo) => {
  if (_mdnsIsQueryForOwhas(msg)) {
    const resp = _buildDnsResponse(msg, detectedHotspotIP);
    sock.send(resp, 5353, '224.0.0.251');
  }
});
```

The `_mdnsIsQueryForOwhas()` function parses the raw DNS packet bytes and
checks whether the queried hostname ends with `owhas.local`. If it does, the
server sends back an `A record` pointing `owhas.local` → `192.168.137.1`
(or whatever the detected hotspot IP is).

### Why mDNS does NOT need Administrator rights

UDP port 5353 is above 1024. Windows allows any user-level process to bind to
it. mDNS is therefore the most reliable mechanism — it works even if you forgot
to run as Administrator.

### Student instruction for mDNS

```
Connect to the hotspot Wi-Fi.
Open Chrome (or Safari on iPhone).
Type:  http://owhas.local
```

The page opens. No IP address needed.

---

## Mechanism 3 — LAN DNS Server: `http://owhas.lan`

### What this does

`server.js` starts a raw UDP server that binds to port 53 on the hotspot IP
address only (`192.168.137.1:53`, not `0.0.0.0:53`). This means it acts as a
DNS resolver specifically for devices connected to the hotspot — the PC's own
DNS resolver is not affected.

When a student's phone looks up `owhas.lan`, the DNS query goes to the hotspot
gateway `192.168.137.1`, which is the PC's hotspot IP. The server answers every
A-record query with the same hotspot IP, redirecting the student's browser to
the attendance page.

```javascript
// backend/server.js  →  _startDnsServer()

dns.bind(53, detectedHotspotIP, () => {
  console.log('[DNS] Listening on ' + detectedHotspotIP + ':53');
  console.log('[DNS] Students type: http://owhas.lan');
});

dns.on('message', (msg, rinfo) => {
  const response = _buildDnsResponse(msg, detectedHotspotIP);
  dns.send(response, rinfo.port, rinfo.address);
});
```

Unlike the mDNS responder, this server answers **all** DNS queries, not just
`owhas.local`. Any hostname a student types resolves to the hotspot IP.

### Why port 53 needs Administrator rights

Port 53 is below 1024. Additionally, on Windows, the `Dnscache` service
normally holds port 53. Even if Administrator rights are granted, the Dnscache
service must release port 53 first.

`server.js` handles this gracefully — it retries up to 4 times with 3-second
delays, and logs clearly if it cannot bind:

```
[DNS] Port 53 busy (attempt 1/4) — retrying in 3 s...
[DNS] Port 53 access denied — run start-server.bat as Administrator.
[DNS] owhas.lan will NOT work; students must use the full IP address.
```

This is non-fatal — the server still runs without the LAN DNS. The captive
portal and mDNS paths still work.

---

## How `start-server.bat` Sets Everything Up

`backend/start-server.bat` is the correct way to start the server for class.
It does three things automatically:

**Step 1 — Self-elevates to Administrator**
```bat
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
```
If not already Admin, it re-launches itself with the UAC prompt. This unlocks
ports 80 and 53.

**Step 2 — Adds Windows Firewall rules**
```bat
netsh advfirewall firewall add rule name="OwHAS Attendance 5501" ...
```
Opens TCP port 5501 on all profiles so student phones can reach the server.
The server also adds firewall rules for ports 80 (TCP), 5353 (UDP), and 53
(UDP) dynamically from Node.js itself when it starts.

**Step 3 — Starts `server.js`**
```bat
node server.js
```

---

## Complete Flow When a Student Connects to the Hotspot

```
Student joins lecturer's Wi-Fi hotspot
            │
            ▼
Phone OS sends captive portal probe
  GET http://connectivitycheck.gstatic.com/generate_204
            │
            ▼
DNS resolves "connectivitycheck.gstatic.com"
  → hotspot gateway = 192.168.137.1
  → DNS server on :53 answers → 192.168.137.1
            │
            ▼
HTTP request goes to 192.168.137.1:80
  → Port-80 redirect server intercepts /generate_204
  → Returns 302 → http://192.168.137.1:5501/public/hotspot.html
            │
            ▼
Phone OS detects 302 ≠ expected 204
  → Marks network as "captive portal"
  → Shows "Sign in to network" notification
            │
            ▼
Student taps notification
  → Mini browser opens
  → Follows the 302 to hotspot.html
  → Attendance registration page appears
```

---

## What the Student Sees

| Situation | What appears on the phone |
|---|---|
| Server started as Admin, both ports 80 and 53 open | "Sign in to network" notification appears automatically within ~3 seconds of connecting |
| Only mDNS working (no Admin) | Student types `http://owhas.local` in browser — page opens |
| LAN DNS working (Admin + port 53 free) | Student types `http://owhas.lan` — page opens |
| All three fail | Student types full IP e.g. `http://192.168.137.1:5501` or scans QR code |

---

## Troubleshooting

### "Sign in to network" does not appear

**1. Is port 80 open?**
Look at the server terminal. You should see:
```
[HTTP80] Captive portal active on :80
[HTTP80] Android/iOS will auto-popup "Sign in to network" → attendance page
```
If instead you see:
```
[HTTP80] Port 80 permission denied — run start-server.bat as Administrator.
```
Close the terminal, right-click `start-server.bat` → **Run as administrator**.

**2. Is port 53 open?**
Look for:
```
[DNS] Listening on 192.168.137.1:53
```
If you see `Port 53 still in use`, open a PowerShell Admin window and run:
```powershell
net stop Dnscache
```
Then restart the server. Port 53 will now be available.
Note: stopping Dnscache only affects DNS caching, not internet connectivity.

**3. Is Windows Firewall blocking port 80?**
Run in Admin PowerShell:
```powershell
netsh advfirewall firewall add rule name="OwHAS HTTP 80" dir=in action=allow protocol=TCP localport=80 profile=any
```

**4. Some phones ignore captive portals**
Some Android phones with aggressive battery optimisation suppress the
notification. The student should open Chrome manually and type
`http://owhas.local`.

### `http://owhas.local` does not open

Check the terminal for:
```
[mDNS] Listening on 224.0.0.251:5353 — owhas.local → 192.168.137.1
```
If this line is missing, the mDNS socket failed. Check firewall for UDP
port 5353.

Some very old Android versions (Android 7 and below) do not support mDNS.
Those students must use the full IP address or QR code.

### `http://owhas.lan` does not open

`owhas.lan` depends on port 53. If port 53 failed (see above), `.lan` will not
resolve. Use `.local` instead — it works without port 53.

---

## Summary: What Each Port Does

| Port | Protocol | Started by | Purpose | Needs Admin |
|---|---|---|---|---|
| 5501 | TCP | `app.listen(5501)` | Main attendance server — all API endpoints, hotspot.html | No |
| 80 | TCP | `_startHttp80Redirect()` | Captive portal — intercepts OS probes, triggers auto-popup | **Yes** |
| 5353 | UDP | `_startMdnsResponder()` | mDNS — resolves `owhas.local` without a central DNS server | No |
| 53 | UDP | `_startDnsServer()` | LAN DNS — resolves `owhas.lan` and all hostnames for hotspot clients | **Yes** |

All four are started from a single `node server.js` command. The `start-server.bat`
file ensures the necessary Administrator rights are present so all four ports
open successfully.
