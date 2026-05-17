# Running a Hybrid Session (In-Class + Remote Students)

A hybrid session serves **both** groups at the same time:

| Group | Connects via | Presence signal |
|---|---|---|
| In-class students | ICTU_ATD captive portal | Wi-Fi proximity to VLAN |
| Remote students | Public ngrok URL (internet) | PIN knowledge + face biometric |

Both groups register on the **same VLAN server**, into the **same session**, and appear on
the **same lecturer dashboard** — no merging, no second device.

---

## How It Works

```
VLAN server (10.50.1.5)
        │
        ├── port 5501 ← IN-CLASS  (ICTU_ATD captive portal)
        │                          student connects → "Sign in" popup → hotspot.html
        │
        └── port 5501 ← REMOTE   (via ngrok HTTPS tunnel)
                                   lecturer shares URL → student types it → hotspot.html
```

ngrok creates a public HTTPS tunnel that forwards internet traffic to the
VLAN server's port 5501.  Both paths land students on the same `hotspot.html`
page, hitting the same `/api/biometric-connect` endpoint with the same PIN.

The VLAN session has **no GPS target** (because `ServerConfig().isOnline` is
`false` on the local server — GPS is only captured for owhas.org cloud
sessions).  Presence for in-class students is proved by Wi-Fi proximity;
presence for remote students is attested by the face biometric captured at
registration.

---

## Prerequisites

Before the first hybrid class:

- [ ] VLAN server running permanently as a service on `10.50.1.5` — see [captive.md](captive.md)
- [ ] ngrok installed on the university server
- [ ] Lecturer has the OwHAS Flutter app installed and connected to ICTU_ATD

### Installing ngrok (once, on the university server)

**Windows:**
```
winget install ngrok
```
or download the ZIP from `https://ngrok.com/download`, extract `ngrok.exe` into
`C:\owhas\backend\` (or any folder on PATH).

**Linux:**
```bash
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok
```

Create a free account at `https://ngrok.com` and authenticate once:
```
ngrok config add-authtoken <your-token>
```

---

## Session Launch — Step by Step

### Step 1 — Start the ngrok tunnel

On the university server, open a terminal and run:

```
ngrok http 5501
```

ngrok prints a table like this:

```
Session Status     online
Forwarding         https://abc12345.ngrok-free.app → http://localhost:5501
```

Copy the `https://...ngrok-free.app` URL.  Keep this terminal open for the
entire class — closing it drops remote students' access.

---

### Step 2 — Create the session (Flutter app)

1. On your phone, connect to **ICTU_ATD**.
2. Open the OwHAS Flutter app.
3. Tap **Setup New Session**.
4. Fill in course name, code, duration, and required connection time.
5. Tap **Start Session**.

The dashboard opens and shows the 4-digit **PIN**.  Note it down — you will
give it to both groups.

---

### Step 3 — Announce to students

**In-class students** — no URL needed:
```
Connect your phone to ICTU_ATD.
Tap "Sign in to network" when the notification appears.
Enter PIN: [PIN from dashboard]
```

**Remote students** — share the ngrok URL (chat / email / slide):
```
Open your browser and go to:
  https://abc12345.ngrok-free.app
Enter PIN: [PIN from dashboard]
```

Both groups follow the same three-step registration:
  PIN → Face capture → Personal details

---

### Step 4 — Monitor on the dashboard

The Flutter dashboard shows **all students** — in-class and remote — in a
single list.  There is no distinction in the UI, but you can tell the groups
apart from the server log:

```
[FACE-OK] Dupont Alice (21T1234)  ip=10.50.1.47   ← in-class (VLAN IP)
[FACE-OK] Martin Paul (21T5678)   ip=41.202.x.x   ← remote   (public IP via ngrok)
```

VLAN students always have a `10.50.1.x` IP.  Remote students have a public IP.

---

### Step 5 — End the session

Tap **End Session** on the Flutter dashboard.  The system:
- Stops accepting new registrations.
- Calculates verified attendance (required connection time reached).
- Exports to PDF on request.

The exported PDF contains both groups in one unified list.

---

## ngrok URL Sharing Workflow

The URL changes every time ngrok restarts (free plan).  Build the share step
into your pre-class routine:

| When | What to do |
|---|---|
| 5 min before class | Run `ngrok http 5501`, copy the URL |
| Start of class | Paste URL into the class group chat or put it on the projector slide |
| End of class | Close ngrok terminal (or leave open for next session) |

### Fixing the URL (paid plan)

With a paid ngrok account, you can reserve a static domain:

```
ngrok http --domain=ictu-atd.ngrok.app 5501
```

The URL never changes.  Students bookmark it and no pre-class sharing is
needed.

---

## Face Biometric Works for Both Groups

The `hotspot.html` page loads face-api.js models from the VLAN server:
```
/models/tiny_face_detector_model-weights_manifest.json
/models/face_landmark_68_model-weights_manifest.json
/models/face_recognition_model-weights_manifest.json
```

When accessed via the ngrok URL (`https://...ngrok-free.app/models/...`), the
server responds identically.  HTTPS from ngrok means `getUserMedia` (camera) is
permitted in all browsers — the same as for in-class students on ICTU_ATD.

Face deduplication runs server-side: if the same face tries to register twice
— whether in-class or remote — the second attempt is rejected.

---

## What Happens if ngrok Is Unavailable

Fall back to the **dual-session** approach:

| | Session A | Session B |
|---|---|---|
| Server | VLAN (`10.50.1.5`) | owhas.org (cloud) |
| Students | In-class (captive portal) | Remote (internet) |
| Dashboard | Flutter app (VLAN) | owhas.org web dashboard |
| Export | VLAN PDF | Cloud PDF |
| Merge | Combine both PDFs manually at end of class | |

**How to run Session B on owhas.org:**
1. On a second device (or browser tab), open `https://owhas.org`.
2. Log in with your lecturer account.
3. Create a session for the same course — **deny location permission** when
   prompted so no GPS target is set (otherwise remote students would fail GPS
   validation immediately).
4. Share the cloud PIN with remote students.

Manually combine the two exported PDFs or Excel files after class.

---

## Limitations of Hybrid Mode

| Limitation | Impact |
|---|---|
| No GPS enforcement for remote students | Remote students prove identity by face only — no location check |
| ngrok free URL changes per restart | Must reshare URL before each class |
| ngrok free tier: 1 active agent, rate-limited | Works for most classes; upgrade for >100 concurrent remote connections |
| Remote students need internet (obvious) | Ensure they know the hotspot.html URL before losing connectivity |
| Server logs needed to distinguish groups | Dashboard UI does not label in-class vs remote |

---

## Quick Reference Card (print and keep)

```
HYBRID SESSION LAUNCH CHECKLIST
────────────────────────────────────────────────────────────
□  On university server:    ngrok http 5501
□  Copy URL:                https://________________.ngrok-free.app
□  Flutter app → ICTU_ATD → Setup → Start Session
□  Note PIN:                ____________
□  In-class slide:          "Connect to ICTU_ATD → tap Sign in → PIN: ____"
□  Remote message:          "Go to https://_____.ngrok-free.app → PIN: ____"
□  Monitor dashboard — both groups appear in same list
□  End session → Export PDF → done
────────────────────────────────────────────────────────────
```
