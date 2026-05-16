# Deploying OwHAS on the University VLAN (ICTU_ATD)

This document explains exactly what code changes are needed when the university
IT department grants you a dedicated VLAN with SSID **ICTU_ATD**, a fixed server
IP, and control over DHCP and DNS.

---

## What Changes vs. Windows Mobile Hotspot

| | Windows Mobile Hotspot | University VLAN (ICTU_ATD) |
|---|---|---|
| Who creates the Wi-Fi | Lecturer's PC (Windows ICS) | University AP — always on |
| Who runs `node server.js` | Lecturer's PC — started each class | University server — permanent service/daemon |
| Server IP | Auto-detected (`192.168.137.1`) | Fixed, assigned by IT |
| DHCP | Windows ICS built-in | University server or IT (option 6) |
| DNS (port 53) | Bound to detected IP | Bound to fixed IP (same code) |
| Captive portal (port 80) | ✓ | ✓ — unchanged |
| mDNS (port 5353) | ✓ | ✓ — unchanged |
| Lecturer needs a laptop | Yes — runs server in class | No — phone only |
| Works across classrooms | No — one hotspot per session | Yes — SSID always present |

Everything in `hotspot.html`, the Node.js API, and the Flutter UI stays exactly the same.
Only **two constants** change, one **new function** is added (DHCP), and
`server.js` is installed as a permanent service so it runs without any human
starting it.

---

## Network Topology

```
University core router
        │
  VLAN ICTU_ATD (isolated — no internet route)
        │
        ├── Wi-Fi AP  (broadcasts SSID "ICTU_ATD" — always on, no human needed)
        │       │
        │   Lecturer & student phones  (connect to ICTU_ATD like any Wi-Fi)
        │       │
        │       ├── DHCP lease from 10.50.1.5  (university server)
        │       │     DNS advertised = 10.50.1.5
        │       │
        │       ├── DNS query → 10.50.1.5:53   (server replies: 10.50.1.5)
        │       ├── HTTP probe → 10.50.1.5:80  (302 → hotspot.html)
        │       └── Attendance page → 10.50.1.5:5501
        │
        └── University Server  (fixed IP: 10.50.1.5 — always on)
                node server.js runs as a Windows Service or Linux daemon
                starts automatically on boot, restarts on crash
                no manual intervention after initial setup
```

Replace `10.50.1.5` with whatever IP IT assigns to the university server.

The VLAN is isolated — there is no default route to the internet. Every DNS
query from student phones stays on the VLAN, so the captive portal probe always
hits your server's port 53 (no risk of phones falling back to mobile-data DNS).

**In-class workflow once this is deployed:**
- Lecturer opens the Flutter app on their phone, connects to ICTU_ATD, creates a session.
- Students connect to ICTU_ATD → "Sign in to network" appears → attendance page opens.
- No laptop. No manual server start. No QR code required (though it still works).

---

## Required Code Changes (2 edits)

### Edit 1 — `backend/server.js` : Add `SERVER_IP` constant

Add this block immediately after the `HEARTBEAT_GRACE_PERIODS` block (around
line 49), before the blank lines:

```javascript
// ══════════════════════════════════════════════════════════════════
//  UNIVERSITY VLAN — Fixed Server IP
//  ─────────────────────────────────────────────────────────────────
//  When running on the university VLAN (ICTU_ATD), IT assigns this
//  PC a fixed IP address.  Set SERVER_IP to that address so every
//  subsystem (DNS, mDNS, HTTP-80 redirect, QR code URL) uses it
//  directly instead of running auto-detection.
//
//  Leave SERVER_IP = null to stay in Windows Mobile Hotspot mode.
//  The auto-detect logic (detectHotspotIP) still runs as fallback.
// ══════════════════════════════════════════════════════════════════
const SERVER_IP = null;   // ← fill in e.g. '10.50.1.5' when IT gives you the IP
```

Then change line 859 from:

```javascript
const detectedHotspotIP = detectHotspotIP();
```

to:

```javascript
const detectedHotspotIP = SERVER_IP || detectHotspotIP();
```

That single two-line change is enough for the server. Every function that uses
`detectedHotspotIP` — `_startDnsServer`, `_startMdnsResponder`,
`_startHttp80Redirect`, the QR-code URL, the startup log — automatically uses
the fixed IP when `SERVER_IP` is set.

**To switch back to hotspot mode:** set `SERVER_IP = null` and restart.

---

### Edit 2 — `lib/services/server_config.dart` : Add VLAN IP to detection

The Flutter app scans a list of IPs at startup to find the server.  Add the
fixed IP as the **first** candidate so detection succeeds instantly instead of
waiting for the 767-IP subnet scan.

In `_detectServerInBackground()`, change the `fixedCandidates` list:

```dart
final fixedCandidates = <String>[
    'http://10.50.1.5:5501',          // ← University VLAN fixed IP (add this first)
    'http://192.168.137.1:5501',      // Windows Mobile Hotspot
    'http://10.0.0.1:5501',
    'http://192.168.43.1:5501',       // Android hotspot
    'http://172.20.10.1:5501',        // iOS hotspot
    'http://192.168.50.1:5501',
];
```

Also update the fallback default at the end of the function (line 77):

```dart
// change the fallback so the app opens the right page even if detection times out
return _ServerDetectionResult(url: 'http://10.50.1.5:5501', isOnline: false);
```

And update `_defaultHotspotHost` (line 114) so the QR code URL and
`hotspotUrl` getter reflect the VLAN IP:

```dart
static const String _defaultHotspotHost = '10.50.1.5';  // ← University VLAN fixed IP
```

After editing, rebuild the Flutter app (`flutter run` or create a new APK) so
the updated constant is compiled in.

---

## Optional: DHCP Server (if IT grants DHCP control)

DHCP is what makes the captive portal **fully automatic**: the DHCP response
tells every phone "your DNS server is `10.50.1.5`." The phone then sends its
captive-portal probe to `10.50.1.5:53`, which answers with `10.50.1.5`, which
triggers the port-80 redirect, which triggers the "Sign in to network"
notification — all without the student doing anything.

You have two ways to achieve this:

### Option A — Ask IT to set DHCP option 6 (recommended if possible)

If IT manages DHCP for the VLAN but allows you to specify the DNS server, ask
them to set **DHCP option 6 (DNS Server)** to `10.50.1.5`. No code changes
needed, and there is no risk of conflicting DHCP servers.

### Option B — Run your own DHCP server inside `server.js`

Use this when the VLAN has **no** existing DHCP server (IT set it up empty just
for you).

**Step 1 — Install the package (once):**
```
cd backend
npm install dhcp
```

**Step 2 — Add `_startDhcpServer()` to `server.js`** (paste after the
`_startHttp80Redirect` function, before the final blank lines):

```javascript
// ══════════════════════════════════════════════════════════════════
//  DHCP SERVER  (university VLAN only)
//  ─────────────────────────────────────────────────────────────────
//  Assigns IPs to student phones and advertises detectedHotspotIP
//  as the DNS server.  This is what makes the captive portal fully
//  automatic — the phone knows to use our DNS from the moment it
//  gets its IP lease.
//  Port 67 UDP — requires Administrator rights.
//  Only called when SERVER_IP is set (VLAN mode).
// ══════════════════════════════════════════════════════════════════
function _startDhcpServer() {
    let dhcpLib;
    try {
        dhcpLib = require('dhcp');
    } catch (e) {
        console.log('[DHCP] Package not installed. Run: cd backend && npm install dhcp');
        return;
    }

    // Derive pool range and broadcast from the server IP
    // e.g. SERVER_IP = '10.50.1.5'  →  pool = 10.50.1.10 – 10.50.1.200
    const parts     = detectedHotspotIP.split('.');
    const subnet    = `${parts[0]}.${parts[1]}.${parts[2]}`;
    const rangeStart = `${subnet}.10`;
    const rangeEnd   = `${subnet}.200`;
    const broadcast  = `${subnet}.255`;

    const server = dhcpLib.createServer({
        range:     [rangeStart, rangeEnd],
        netmask:   '255.255.255.0',
        router:    [detectedHotspotIP],
        dns:       [detectedHotspotIP],   // ← the critical line: phone uses our DNS
        broadcast,
        server:    detectedHotspotIP,
        leaseTime: 3600,                  // 1 hour per lease
        randomIP:  true,
    });

    server.on('bound', ({ address, mac }) => {
        console.log(`[DHCP] Assigned ${address} to ${mac}`);
    });

    server.on('error', err => {
        if (err.code === 'EACCES')
            console.log('[DHCP] Port 67 denied — run start-server.bat as Administrator.');
        else
            console.log('[DHCP] Error: ' + err.message);
        server.close();
    });

    server.listen();
    console.log(`[DHCP] Serving ${rangeStart}–${rangeEnd}, DNS=${detectedHotspotIP}`);
    _addFirewallRule(67, 'OwHAS DHCP 67', 'UDP');
}
```

**Step 3 — Call it from the startup block.**
In the `app.listen` callback (around line 905), make two changes: guard
`_openBrowser` so it is skipped on the headless university server, and add the
DHCP call:

```javascript
app.listen(PORT, '0.0.0.0', () => {
    _logStartup('http', PORT);
    _addFirewallRule(PORT, 'OwHAS Attendance 5501', 'TCP');
    if (!SERVER_IP) _openBrowser('http://' + detectedHotspotIP + ':' + PORT + '/public/hotspot.html');
    _startMdnsResponder();
    _startDnsServer();
    _startHttp80Redirect();
    if (SERVER_IP) _startDhcpServer();   // ← only runs in VLAN mode
});
```

`_openBrowser` tries to open Chrome on the machine running the server. On a
headless university server there is no desktop, so the call fails with a
harmless error. The `if (!SERVER_IP)` guard eliminates that noise: the browser
auto-opens only in hotspot mode (lecturer's PC). The `if (SERVER_IP)` guard on
`_startDhcpServer` ensures DHCP never starts in hotspot mode, where Windows ICS
already handles it.

---

## How the Captive Portal Fires on the VLAN

```
Student connects to ICTU_ATD
          │
          ▼
Phone broadcasts DHCP Discover
  → Server (10.50.1.5:67) replies with DHCP Offer
  → Phone gets IP: 10.50.1.x
  → Phone is told: DNS = 10.50.1.5
          │
          ▼
Phone OS sends captive portal probe
  GET http://connectivitycheck.gstatic.com/generate_204
          │
          ▼
Phone looks up "connectivitycheck.gstatic.com"
  → DNS query to 10.50.1.5:53
  → Server answers with A record: 10.50.1.5
          │
          ▼
HTTP request goes to 10.50.1.5:80
  → Port-80 redirect server intercepts /generate_204
  → Returns 302 → http://10.50.1.5:5501/public/hotspot.html
          │
          ▼
Phone sees 302 ≠ expected 204
  → Marks network as captive portal
  → Shows "Sign in to network" notification
          │
          ▼
Student taps → hotspot.html opens → attendance registration
```

The logic inside `server.js` (`_startDnsServer`, `_startHttp80Redirect`) is
**identical** to the hotspot setup. The only difference is that DHCP now
explicitly points phones to your DNS, making the trigger 100% reliable instead
of depending on the phone's fallback behaviour.

---

## Running server.js as a Permanent Service

The university server must run `node server.js` automatically on boot and
restart it on crash — no human logs in to start it. Two options:

---

### Option W — Windows: NSSM (Non-Sucking Service Manager)

NSSM wraps any executable as a proper Windows service. It handles auto-start,
crash-recovery, and log capture.

**Step 1 — Download NSSM** from `https://nssm.cc` and place `nssm.exe` inside
`C:\owhas\backend\` (or in a folder already on PATH).

**Step 2 — Install the service** (run once in an Administrator command prompt):

```bat
nssm install OwHAS "C:\Program Files\nodejs\node.exe" "C:\owhas\backend\server.js"
nssm set OwHAS AppDirectory    "C:\owhas\backend"
nssm set OwHAS DisplayName     "OwHAS Attendance Server"
nssm set OwHAS Description     "OwHAS Wi-Fi attendance — auto-start on boot"
nssm set OwHAS Start           SERVICE_AUTO_START
nssm set OwHAS AppStdout       "C:\owhas\backend\owhas.log"
nssm set OwHAS AppStderr       "C:\owhas\backend\owhas.log"
nssm set OwHAS AppRotateFiles  1
nssm set OwHAS AppRotateBytes  10485760
nssm start OwHAS
```

The service now starts on every boot. Ports 80, 53, and 67 (all < 1024) are
accessible because Windows services run as SYSTEM by default.

**To update server.js:** edit the file, then `nssm restart OwHAS`.

**To view logs in real time:**
```bat
powershell Get-Content C:\owhas\backend\owhas.log -Wait
```

---

### Option L — Linux: systemd

```ini
# Save as: /etc/systemd/system/owhas.service

[Unit]
Description=OwHAS Attendance Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/owhas/backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable owhas    # start on every boot
sudo systemctl start owhas
sudo journalctl -u owhas -f    # tail live logs
```

`User=root` is required because ports 80, 53, and 67 are privileged (< 1024).

**To update server.js:** edit the file, then `sudo systemctl restart owhas`.

---

## Port Summary

| Port | Protocol | Purpose | Admin | Changed? |
|---|---|---|---|---|
| 5501 | TCP | Main server — API, `hotspot.html` | No | No |
| 80 | TCP | Captive portal redirect | Yes | No |
| 5353 | UDP | mDNS — `owhas.local` | No | No |
| 53 | UDP | LAN DNS — all hostnames | Yes | No |
| **67** | **UDP** | **DHCP — IP + DNS advertisement** | **Yes** | **New (VLAN only)** |

---

## Deployment Checklist

### One-time setup (done once by you and IT — never repeated)

- [ ] IT has assigned a **fixed IP** to the university server on the ICTU_ATD VLAN
- [ ] `SERVER_IP` in `backend/server.js` is set to that IP
- [ ] Fixed IP added as first entry in `fixedCandidates` in `server_config.dart`
- [ ] `_defaultHotspotHost` and the fallback URL in `server_config.dart` updated
- [ ] Flutter APK rebuilt and installed on all lecturer phones
- [ ] DHCP configured — either:
  - (Option A) IT confirmed DHCP option 6 = your fixed IP, **or**
  - (Option B) `npm install dhcp` done, `_startDhcpServer()` added and called
- [ ] `_openBrowser` guarded with `if (!SERVER_IP)` in the `app.listen` callback
- [ ] `server.js` installed as a permanent service:
  - Windows: NSSM service installed and started (see above)
  - Linux: systemd unit enabled and started (see above)
- [ ] Service verified — logs show:
  ```
  [DHCP] Serving 10.50.1.10–10.50.1.200, DNS=10.50.1.5
  [DNS]  Listening on 10.50.1.5:53
  [HTTP80] Captive portal active on :80
  [mDNS] Listening on 224.0.0.251:5353 — owhas.local → 10.50.1.5
  ```
- [ ] Smoke test: connect a phone to ICTU_ATD → "Sign in to network" appears within ~5 s

---

### Per-class workflow (lecturer — phone only, no laptop)

1. Open the Flutter app on your phone.
2. Connect the phone to ICTU_ATD.
3. App detects the server at `10.50.1.5` instantly (first candidate in the list).
4. Create a session (course name, PIN, optional GPS boundary).
5. Students connect to ICTU_ATD — captive portal fires automatically.
6. Monitor attendance on the dashboard. Export PDF when done.

---

## Troubleshooting

### "Sign in to network" does not appear

1. **Is DHCP giving out DNS?**  
   On the test phone, go to Wi-Fi details for ICTU_ATD and check the DNS server
   field. It must show `10.50.1.5` (your server). If it shows `8.8.8.8` or
   anything else, DHCP option 6 is not set correctly.

2. **Try forget and reconnect.**  
   Captive portal probes only fire on fresh connections. Forget the network and
   rejoin.

3. **Check port 67.**  
   Terminal must show `[DHCP] Serving ...`. If it shows `Package not installed`
   or `Port 67 denied`, see below.

### `npm install dhcp` or `[DHCP] Package not installed`

```
cd backend
npm install dhcp
```

### Port 67 access denied

Port 67 is below 1024 and requires elevated rights.

- **Windows service (NSSM):** NSSM services run as SYSTEM by default — no
  extra steps needed. If you see this error, verify the service is installed
  correctly with `nssm status OwHAS`.
- **Linux (systemd):** ensure `User=root` is in the `[Service]` block, then
  `sudo systemctl restart owhas`.

### Two DHCP servers conflict

If IT forgot to disable their own DHCP for the VLAN before you started yours,
phones receive offers from both servers and get unpredictable IPs/DNS. Contact
IT and ask them to **disable the DHCP scope** for the ICTU_ATD VLAN — your
server handles it.

### Flutter app does not connect to server

If the fixed IP changed (IT reassigned it), update `SERVER_IP` in `server.js`,
the first entry of `fixedCandidates` and `_defaultHotspotHost` in
`server_config.dart`, then rebuild the Flutter APK.

### `http://owhas.local` does not work on VLAN

mDNS operates at layer 2 — it only reaches devices on the same LAN segment.
If the AP is on a separate VLAN segment from the PC (with routing between
them), multicast packets may be filtered. Use the full IP or `owhas.lan` via
DNS instead.
