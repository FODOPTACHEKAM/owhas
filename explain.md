# Attendance App - Complete Setup & Usage Guide

## Table of Contents
1. [How It Works](#how-it-works)
2. [Prerequisites](#prerequisites)
3. [Step-by-Step Setup for Lecturer](#step-by-step-setup-for-lecturer)
4. [Step-by-Step for Students](#step-by-step-for-students)
5. [Troubleshooting](#troubleshooting)
6. [Architecture Overview](#architecture-overview)

---

## How It Works

This is a **hotspot-based attendance system**:

1. **Lecturer's PC** runs a Node.js server that hosts a web form
2. **Lecturer's phone** runs the Flutter app to create sessions and view attendance
3. **Students** connect to the lecturer's Wi-Fi hotspot, scan a QR code, and fill a web form
4. **Student data** is sent to the Node.js server and stored in memory
5. **Lecturer refreshes** the Flutter app to see registered students
6. **Lecturer downloads** the attendance PDF from the server

**Network Flow:**
```
Student Phone → Lecturer's Hotspot → Node.js Server (PC) → Flutter App (Lecturer's Phone)
                                    ↓
                              Stores attendance data
                                    ↓
                              Generates PDF report
```

---

## Prerequisites

### On the Lecturer's PC (Windows)
1. **Node.js** installed (check with `node --version`)
2. **Flutter** installed (check with `flutter --version`)
3. **Android Studio** or VS Code with Flutter extension
4. Wi-Fi hotspot capability (Windows Mobile Hotspot)

### On the Lecturer's Phone
1. **Flutter app installed** (via USB debugging or APK)
2. Connected to the **same network** as the PC (via hotspot or same Wi-Fi)

### On Student Phones
1. Any phone with a **web browser** and **camera** (for QR scanning)
2. Connected to the **lecturer's Wi-Fi hotspot**

---

## Step-by-Step Setup for Lecturer

### Step 1: Start the Node.js Server

1. Open **Command Prompt** (or PowerShell) as Administrator
2. Navigate to the project folder:
   ```cmd
   cd "c:\Users\Lenovo\Desktop\Android App\Att_App ui\attendance_app-first"
   ```
3. Start the server:
   ```cmd
   node server.js
   ```
4. You should see output like:
   ```
   ========================================
   Attendance Server running on http://192.168.137.1:5501/public/hotspot.html
   Test: http://192.168.137.1:5501/ping
   Static: C:\Users\...\public
   Browser opened successfully!
   ========================================
   ```

> **Leave this terminal open!** The server must keep running.

### Step 2: Enable Windows Mobile Hotspot

1. Press **Windows + I** to open Settings
2. Go to **Network & Internet > Mobile Hotspot**
3. Turn **ON** "Share my Internet connection with other devices"
4. Note the **Network name** and **Password**
5. Click **Edit** to set a custom name/password if needed

**Important:** The hotspot IP is usually `192.168.137.1`. If yours is different, update these files:
- `server.js` - change `192.168.137.1` to your actual hotspot IP
- `lib/services/api_service.dart` - change `baseUrl`
- `lib/pages/lecturer_dashboard_page.dart` - change `_qrUrl`

### Step 3: Run the Flutter App on Your Phone

**Option A: Via USB (Development)**
1. Enable **Developer Options** on your phone (tap Build Number 7 times)
2. Enable **USB Debugging**
3. Connect phone to PC via USB
4. In VS Code, press **F5** or run:
   ```cmd
   flutter run
   ```

**Option B: Build APK**
1. Build the APK:
   ```cmd
   flutter build apk --debug
   ```
2. Transfer `build/app/outputs/flutter-apk/app-debug.apk` to your phone
3. Install and open it

### Step 4: Create a Session

1. Open the Flutter app on your phone
2. Tap **"Create Session"**
3. Fill in:
   - Course Name (e.g., "Computer Science 101")
   - Grace Period (minutes)
   - Required Connection Time (minutes)
   - Max Attendance Count
4. Tap **"Start Session"**

A **QR code** will appear showing: `http://192.168.137.1:5501/public/hotspot.html`

### Step 5: Monitor Attendance

- The dashboard shows **Total**, **Verified**, **Pending**, and **Wi-Fi Devices**
- Tap the **refresh icon (↻)** to update the student list
- Students who registered via the web form will appear here

### Step 6: Download Attendance PDF

- Tap the **PDF icon** to generate a local PDF
- Tap the **share icon** to download the server's PDF (includes all web registrations)

---

## Step-by-Step for Students

### Step 1: Connect to Hotspot

1. Open **Wi-Fi settings** on your phone
2. Find and connect to the lecturer's hotspot (e.g., "LecturerHotspot")
3. Enter the password if prompted

### Step 2: Scan the QR Code

1. Open your **camera app** or a QR scanner
2. Point it at the QR code on the lecturer's phone
3. Tap the link that appears: `http://192.168.137.1:5501/public/hotspot.html`

### Step 3: Fill the Registration Form

1. The web page opens with a form
2. The page will automatically test the connection and show:
   - **Green ✅** "Connected to server! You can now register."
   - **Red ❌** If there's a connection problem (see troubleshooting)

3. Fill in:
   - **Username** (your full name)
   - **Matricule** (your student ID)
   - **Email** (your school email)

4. Tap **"Validate & Register"**
5. You should see: **"✅ Successfully Registered!"**

> **Important:** If you see an error, read it carefully and follow the troubleshooting steps below.

---

## Troubleshooting

### Problem 1: "Connection Failed" or "Cannot Reach Server"

**The phone cannot connect to the Node.js server.**

**Solutions:**

#### A. Check Windows Firewall
The firewall is likely blocking port 5501. Add a rule:

1. Open **PowerShell as Administrator**
2. Run:
   ```powershell
   New-NetFirewallRule -DisplayName "Attendance Server" -Direction Inbound -LocalPort 5501 -Protocol TCP -Action Allow
   ```
3. Restart the server

#### B. Check if Another Process is Using Port 5501
1. Open Command Prompt as Administrator
2. Run:
   ```cmd
   netstat -ano | findstr :5501
   ```
3. If you see results, kill the process:
   ```cmd
   for /f "tokens=5" %a in ('netstat -ano ^| findstr :5501') do taskkill /F /PID %a
   ```
4. Restart `node server.js`

#### C. Check Hotspot IP Address
Your PC's hotspot IP might not be `192.168.137.1`:

1. Open Command Prompt
2. Run:
   ```cmd
   ipconfig
   ```
3. Look for "Mobile Hotspot" or "Wi-Fi" adapter
4. Find the "IPv4 Address" (e.g., `192.168.137.1` or `192.168.1.5`)
5. Update ALL files with the correct IP:
   - `server.js`
   - `lib/services/api_service.dart`
   - `lib/pages/lecturer_dashboard_page.dart`
   - `public/hotspot.html`

#### D. Test from PC Browser First
Before testing on the phone:
1. Open Chrome on your PC
2. Go to: `http://192.168.137.1:5501/ping`
3. Should show: `{"status":"ok"}`
4. If this works, the server is running correctly

### Problem 2: "Server Error (405)"

**The request reached a server, but not OUR Express server.**

**This usually means:**
- Another program (like VS Code extension, IIS, or another Node process) is using port 5501
- The phone is connected to a different network

**Solutions:**

1. **Kill ALL Node processes:**
   ```cmd
   taskkill /F /IM node.exe
   ```
   Then restart ONLY our server:
   ```cmd
   node server.js
   ```

2. **Close VS Code completely** - The DSCodeGPT extension might be running its own server

3. **Check what process is using port 5501:**
   ```cmd
   netstat -ano | findstr :5501
   ```
   Then check what program it is:
   ```cmd
   tasklist | findstr <PID>
   ```

### Problem 3: "All Fields Are Required"

**The server received the request but the data is missing.**

**Solutions:**

1. Make sure you filled ALL three fields (Username, Matricule, Email)
2. Check the browser console for JavaScript errors:
   - In Chrome on phone: tap the **three dots > Developer tools > Console**
3. Try refreshing the page and filling again

### Problem 4: Student Phone Can't Scan QR Code

**Solutions:**

1. Make sure the student is connected to the **same hotspot**
2. Manually type the URL in the browser:
   ```
   http://192.168.137.1:5501/public/hotspot.html
   ```
3. If using mobile data, turn it OFF (the phone might try to use data instead of Wi-Fi)

### Problem 5: Flutter App Shows "No Students" After Refresh

**Solutions:**

1. Make sure the Flutter app is on the **same network** as the PC
2. Check that `lib/services/api_service.dart` has the correct `baseUrl`
3. Test the API from the phone's browser:
   ```
   http://192.168.137.1:5501/api/attendees
   ```
4. If this returns `{"attendees":[]}`, the server is working but no one registered yet

### Problem 6: APK Installation Failed (ADB Error)

**Solutions:**

1. **Uninstall the old app** from your phone first
2. Run:
   ```cmd
   flutter clean
   flutter pub get
   flutter run
   ```

---

## Architecture Overview

### Files and Their Roles

| File | Role |
|------|------|
| `server.js` | Node.js Express server - serves web form, receives student data, stores attendees, generates PDF |
| `public/hotspot.html` | The web form that students see and fill |
| `lib/main.dart` | Flutter app entry point |
| `lib/pages/lecturer_dashboard_page.dart` | Shows QR code, attendance stats, student list |
| `lib/pages/session_setup_page.dart` | Form to create a new attendance session |
| `lib/providers/attendance_provider.dart` | State management - talks to local storage and server |
| `lib/services/api_service.dart` | HTTP client for talking to Node.js server |
| `lib/services/session_service.dart` | Manages session creation and student registration |
| `lib/services/storage_service.dart` | Local SQLite/storage for offline data |
| `lib/services/network_discovery_service.dart` | Scans network for connected devices |

### Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Student Phone  │────▶│  Node.js Server  │────▶│  In-Memory      │
│  (Web Browser)  │POST │  (PC)            │STORE│  attendees[]    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                        │
                              ┌────────────────────────┘
                              ▼
                       ┌──────────────────┐
                       │  Flutter App     │
                       │  (Lecturer)      │
                       │  GET /api/       │
                       │  attendees       │
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  Display List    │
                       │  Download PDF    │
                       └──────────────────┘
```

### Ports Used

| Port | Used By |
|------|---------|
| 5501 | Node.js Express server (attendance API + web form) |
| 80 | Could be used if you change server port |

---

## Quick Checklist Before Each Class

- [ ] Start Windows Mobile Hotspot
- [ ] Run `node server.js` (keep terminal open)
- [ ] Open Flutter app on lecturer phone
- [ ] Create a new session
- [ ] Verify QR code displays correctly
- [ ] Test scan with your own phone first
- [ ] Ask students to connect to hotspot
- [ ] Students scan QR and register
- [ ] Refresh Flutter app to see registrations
- [ ] Download PDF at end of class

---

---

## Why "Go Live" Does Not Start This Server

You may notice a **"Go Live"** button in the bottom-right corner of VS Code. That button belongs to the **Live Server** extension (by Ritwick Dey), which is a completely separate tool from this project.

| Feature | Live Server (VS Code Extension) | `node server.js` |
|---------|--------------------------------|------------------|
| **What it is** | A generic static-file server for quick HTML preview | Your custom Express API + web form |
| **Port** | Usually `5500` | `5501` (set in `server.js`) |
| **Purpose** | Preview any `.html` file instantly | Host the attendance form, receive student data, generate PDFs |
| **How to start** | Click the "Go Live" button | Run `node server.js` in terminal, **or** double-click `start-server.bat` |
| **Connection to this app** | **None** — it does not know about your project | Required for the attendance system to work |

**Bottom line:** Clicking "Go Live" will start a server on port 5500, but students scanning the QR code will hit port 5501. The two are unrelated. Always start your server with `node server.js` or `start-server.bat`.

---

## QR Code Won't Load? Expanded Troubleshooting

### Step A: Find Your Real Hotspot IP

1. Start the server:
   ```cmd
   node server.js
   ```
   or double-click `start-server.bat`.
2. Look at the terminal output. It lists **all local IPv4 addresses**.
3. Find the one that matches your Mobile Hotspot adapter (often named something like "Local Area Connection* 12" or simply shows `192.168.137.x`).
4. Update these three files with that exact IP:
   - `lib/pages/lecturer_dashboard_page.dart` → `_qrUrl`
   - `lib/services/api_service.dart` → `baseUrl`
   - `server.js` → hardcoded `192.168.137.1` in the old startup message (now auto-detected)

### Step B: Verify Firewall is Open

Even if the server starts, Windows may block incoming connections on port 5501.

**Option 1 — Automatic (Recommended):**
Double-click `start-server.bat`. It automatically adds the firewall rule before launching Node.

**Option 2 — Manual:**
Open PowerShell as Administrator and run:
```powershell
New-NetFirewallRule -DisplayName "Attendance Server" -Direction Inbound -LocalPort 5501 -Protocol TCP -Action Allow
```

### Step C: Test From the PC First

Before testing with a phone:
1. Open Chrome on your PC
2. Go to: `http://<YOUR_HOTSPOT_IP>:5501/ping`
3. Should show: `pong`

If this works on the PC but not on the phone, the issue is either:
- The phone is not connected to the hotspot
- The phone is using mobile data instead of Wi-Fi (turn off mobile data temporarily)
- Windows Firewall is blocking the port

### Step D: Phone Still Won't Connect?

1. Turn off **mobile data** on the student phone so it cannot fall back to 4G/5G.
2. Open the phone's browser and type the URL manually instead of scanning the QR code.
3. Check that the QR URL in the Flutter app matches the IP printed by the server.

---

## Support

If you encounter an error not covered here:

1. Check the **server terminal** for error messages
2. Check the **phone browser console** for JavaScript errors
3. Note the **exact error message** and which step it happens at
4. Check that all IPs match your actual network setup
