# Hybrid Deployment: Online & Offline Architecture

You asked: **"How can I make sure that the system can also work online if there is no WiFi hardware to launch `server.js`?"**

By transitioning to a hybrid architecture, your system can operate in two distinct modes. This allows you to adapt based on whether the university provides internet access or relies on internal networks, while still maintaining high security against attendance fraud.

*Note: In this architecture, students do not install a mobile app. They access the system entirely through their smartphone's web browser.*

---

## 1. The Two Operational Modes

### Mode A: Offline Intranet (School Servers)
- **Infrastructure:** The `server.js` backend is hosted on the school's local on-premise servers (not the lecturer's personal laptop). The school broadcasts a local WiFi network (Intranet) that does not necessarily have internet access.
- **Student Flow:** Students connect to the school's local WiFi. When they open a browser, the captive portal (via `dns-server.js`) redirects them to the local server URL (e.g., `https://attendance.local:5501`).
- **Security Mechanism:** Physical presence is guaranteed by the physical range of the school's WiFi access points. If a student can reach the server, they are on campus and within range of the building.

### Mode B: Online Cloud (Public Internet)
- **Infrastructure:** `server.js` is hosted on a public cloud provider (like Render.com, Heroku, or AWS) and is accessible via a public URL (e.g., `https://attendance.myuniversity.edu`).
- **Student Flow:** Students use their own mobile data (4G/5G) or public WiFi. They simply type the URL into their Safari/Chrome browser.
- **Security Mechanism:** Since students can access the URL from anywhere in the world, the system relies on **GPS Geofencing** via the HTML5 Geolocation API to ensure they are physically inside the classroom.

---

## 2. Swapping Between Online and Offline Modes

Because students use web browsers instead of a dedicated mobile app, the swap between modes is primarily handled by how the students connect, rather than an app auto-detecting it.

### A. The Student Experience
- **Offline Mode:** The student joins the specific "Classroom WiFi". A captive portal pop-up automatically opens the attendance page on their browser.
- **Online Mode:** The lecturer writes a URL on the board(owhas.org) (or provides a QR code). The student scans it or types it into their browser using their mobile data.

### B. The Server Configuration Swap
Your Node.js backend handles the modes based on where it is deployed:
- **When Offline (School Server):** The server boots up, binds to the school's local IP, and generates the `selfsigned` SSL certificates. The `dns-server.js` script is running to intercept DNS requests and force the captive portal popup on student devices.
- **When Online (Cloud):** The cloud provider automatically assigns the domain and handles legitimate SSL certificates. The server ignores the self-signed certificates and does not run the DNS script.

---

## 3. Securing the Online Mode: GPS Geofencing via Web Browser

> [!WARNING]
> **The Online Vulnerability:** If the website is online, a student could text the active session URL and PIN to a friend who is at home. That friend could then mark themselves present using their mobile data!

To completely neutralize this threat, the Online Mode relies strictly on **GPS Geofencing**.

### How Web-Based GPS Geofencing Works:

1. **Automatic Classroom Location Capture:**
   The lecturer does **not** need to type their geolocation manually. When the lecturer clicks "Start Session", their device automatically captures their current GPS coordinates (Latitude & Longitude) and registers it as the exact "Target Location" for that session on the server.

2. **Student Browser Fetches Location:**
   When a student visits the attendance webpage, the website uses the standard HTML5 Geolocation API:
   `navigator.geolocation.getCurrentPosition(...)`
   The browser will prompt the student: *"attendance.myuniversity.edu wants to know your location."* The student must tap **Allow**.

3. **Data Transmission:**
   The frontend JavaScript sends the payload to the server: 
   `{ matricule, pin, latitude, longitude }`

4. **Server-Side Distance Calculation:**
   The Node.js server uses the **Haversine formula** to calculate the physical distance (in meters) between the classroom's coordinates and the student's coordinates.
   - If the distance is **< 50 meters**, the attendance is verified and accepted.
   - If the distance is **> 50 meters**, the server rejects the request with the error: *"You must be in the classroom to sign in."*

### Why GPS Geofencing is Effective
GPS relies on satellite positioning hardware inside the phone. Even through a web browser, it is extremely difficult for a standard student to spoof their GPS location on a modern iOS or Android device without using advanced developer tools. This ensures that physical attendance remains highly accurate even when the system is on the public internet.
