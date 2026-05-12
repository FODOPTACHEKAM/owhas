# How to Get "PIN Verified" Status on Student Registration

## What must be true for PIN verification to succeed

Three things must all be true at the same time:

1. **Lecturer's Windows Mobile Hotspot is ON**
2. **Backend server is running** on the lecturer's PC (port 5501)
3. **Student's phone is connected to that hotspot**

If any one of these is missing, the student will see the red **"Invalid PIN or server unreachable"** badge instead of the green **"PIN Verified!"** badge.

---

## Step-by-step setup

### On the Lecturer's PC

**Step 1 — Enable Windows Mobile Hotspot**

```
Settings → Network & Internet → Mobile Hotspot → toggle ON
```

- Network name and password are shown on that page — share them with students
- The hotspot creates a local network at `192.168.137.1`

**Step 2 — Start the backend server**

Open PowerShell/CMD in the backend folder and run:

```powershell
cd "C:\Users\Lenovo\Desktop\Android App\Att_App ui\attendance_app-first\backend"
node server.js
```

You should see output like:
```
Server running on http://0.0.0.0:5501
```

Keep this window open for the entire class session.

**Step 3 — Open the app and create a session**

1. Open the app on the lecturer's phone
2. Go to **Session Setup**
3. Fill in course name, duration, etc. and tap **Start Session**
4. The app generates a 6-digit PIN — this is what students will enter

**Step 4 — Share the PIN with students**

Either:
- Show the PIN from the **Live Session** dashboard (the white badge top-right)
- Display the QR code so students scan it directly (skips PIN entry)

The QR code links to the web registration page served at:
```
http://192.168.137.1:5501/public/hotspot.html
```
Students can also type that URL directly into a mobile browser instead of scanning the QR code.

---

### On the Student's Phone

**Step 1 — Join the hotspot**

```
Settings → Wi-Fi → select the lecturer's hotspot name → enter the password
```

The phone must show "Connected" (not "No internet" is fine — the local server does not need internet).

**Step 2 — Open the app and go to Register**

Tap **Student Registration** on the home screen.

**Step 3 — Enter the 6-digit PIN**

Type the PIN the lecturer shared and tap **Verify PIN**.

**What you should see:**

| Badge | Meaning |
|---|---|
| Spinner — *"Verifying PIN with server…"* | App is contacting `192.168.137.1:5501` |
| ✓ Green — *"PIN Verified!"* | Connected and PIN accepted → advances to Step 2 |
| ✗ Red — *"Invalid PIN or server unreachable"* | See troubleshooting below |

---

## Troubleshooting the red error badge

### "Invalid PIN or server unreachable"

Work through these checks in order:

**1. Is the student on the hotspot?**
- Open the phone's Wi-Fi settings and confirm it shows the lecturer's hotspot name as the connected network.

**2. Is the server running?**
- On the lecturer's PC, check the PowerShell window — it must still show `Server running on http://0.0.0.0:5501`.
- If the window is closed, restart it with `node server.js`.

**3. Can the phone reach the server?**
- Open a browser on the student's phone and go to: `http://192.168.137.1:5501/ping`
- You should see `pong` as plain text. If the page doesn't load, the phone is not reaching the server.
- Also try the registration page directly: `http://192.168.137.1:5501/public/hotspot.html`
  - If it loads, the server and hotspot are working correctly.
  - If it shows "Cannot GET /public/hotspot.html", the `backend/public/` folder is missing or the server was not started from the `backend/` directory.

**4. Is Windows Firewall blocking port 5501?**
- On the lecturer's PC, open PowerShell as Administrator and run:
  ```powershell
  netsh advfirewall firewall add rule name="AttApp Server" dir=in action=allow protocol=TCP localport=5501
  ```
- Then retry.

**5. Is the PIN correct?**
- The PIN is exactly 6 digits. Confirm with the lecturer.
- If the session was restarted, a new PIN is generated — the old one is invalid.

**6. Is the Mobile Hotspot still on?**
- Windows sometimes turns off the hotspot automatically after a few minutes of inactivity. Re-enable it in Settings.

---

## How the app auto-detects the server

The app tries these addresses in order (all in parallel, 300 ms timeout each):

| Priority | URL | Used for |
|---|---|---|
| 1st | `http://192.168.137.1:5501` | Windows Mobile Hotspot (main case) |
| 2nd | `http://192.168.1.1:5501` | Home/office router hotspot |
| 3rd | `http://192.168.0.1:5501` | Alternative router |
| 4th | `http://10.0.0.1:5501` | Enterprise network |
| 5th | `http://10.0.2.2:5501` | Android Emulator only |
| Fallback | `https://owhas.com` | Cloud server (internet required) |

If none responds, it falls back to `192.168.137.1:5501` by default.

You do not need to configure this manually — it is automatic.

---

## Quick checklist (print this for class)

- [ ] Lecturer's Mobile Hotspot is ON
- [ ] `node server.js` is running and shows port 5501 (started from the `backend/` folder)
- [ ] Session has been created in the app (PIN is visible on dashboard)
- [ ] Student's phone Wi-Fi is connected to the hotspot
- [ ] Student typed the correct 6-digit PIN **or** opened `http://192.168.137.1:5501/public/hotspot.html` in a browser
- [ ] Green "PIN Verified!" badge appears → student can proceed
