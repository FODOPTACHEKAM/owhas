const express = require('express');
const path = require('path');
const os = require('os');
const { exec, execSync } = require('child_process');
const multer = require('multer');
const pdfParse = require('pdf-parse');
const { generateAttendancePDF } = require('./src/services/pdfService');

const app = express();

// ====== HARDCODED SERVER CONFIG ======
const PORT = 5501; // same port for both HTTP and HTTPS













// No Helmet, no rate limiting â€” this is a private LAN server.
// Security middleware was blocking phone connections and adds no benefit here.

// ====== DEBUG: Log EVERY incoming request ======
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} from ${req.ip}`);
    next();
});

// ====== CORS for all origins ======
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
    // Required by Chrome Private Network Access: allows pages served from a
    // private IP to fetch other endpoints on the same private-network server.
    res.header('Access-Control-Allow-Private-Network', 'true');
    res.header('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.header('Pragma', 'no-cache');
    res.header('Expires', '0');
    if (req.method === 'OPTIONS') {
        return res.sendStatus(200);
    }
    next();
});

// ====== SECURITY: Payload Limits ======
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

// ====== Static files ======
app.use('/public', express.static(path.join(__dirname, 'public'), {
    cacheControl: false,
    etag: false,
    lastModified: false
}));

// Serve face-api.js and models at root-relative paths used by hotspot.html
app.use('/lib',    express.static(path.join(__dirname, 'public', 'lib'),    { cacheControl: false, etag: false }));
app.use('/models', express.static(path.join(__dirname, 'public', 'models'), { cacheControl: false, etag: false }));

// Explicit route for hotspot.html â€” handles query params like ?s= cleanly
app.get('/public/hotspot.html', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'hotspot.html'));
});

// ====== Root redirect ======
app.get('/', (req, res) => {
    res.redirect('/public/hotspot.html');
});

app.get('/ping', (req, res) => {
    res.json({ status: 'ok' });
});

app.get('/api/version', (req, res) => {
    res.json({ version: '3.0', features: ['pdf-parse', 'session-number', 'tp-table', 'pin-sessions'] });
});

// ====== GET /api/qr-url ======
app.get('/api/qr-url', (req, res) => {
    // Prefer the browser's actual origin when available so the generated URL
    // tracks the IP currently visible in the browser address bar.
    const origin = req.headers.origin || `${req.protocol}://${req.headers.host}` || `http://${req.socket.localAddress}:${PORT}`;
    const qrUrl = `${origin}/public/hotspot.html`;
    res.json({ qrUrl });
});

// ====== In-memory PIN-scoped session storage ======
const activeSessions = new Map();

let sessionConfig = {
    requiredConnectionMinutes: 15,
    gracePeriodMinutes: 5,
};

// ====== Haversine Formula for GPS Geofencing ======
function calculateDistance(lat1, lon1, lat2, lon2) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
    const R = 6371e3;
    const toRadians = (deg) => deg * (Math.PI / 180);
    const dLat = toRadians(lat2 - lat1);
    const dLon = toRadians(lon2 - lon1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

// Euclidean distance between two 128-dim face descriptors
function faceDistance(a, b) {
    return Math.sqrt(a.reduce((sum, val, i) => sum + Math.pow(val - b[i], 2), 0));
}

// Resolve session from PIN or session token
function getSessionByPinOrToken(pin, token) {
    if (pin) return getSessionByPin(pin);
    if (token) {
        for (const [, s] of activeSessions.entries()) {
            if (s.sessionToken === token) return s;
        }
    }
    return null;
}

function getSessionByPin(pin) {
    if (!pin) return null;
    const session = activeSessions.get(pin);
    if (!session) return null;
    if (new Date() > new Date(session.expiresAt)) {
        activeSessions.delete(pin);
        return null;
    }
    return session;
}

// ====== Multer setup for PDF uploads ======
// No fileFilter: mobile browsers often send PDFs as application/octet-stream
// instead of application/pdf, which would cause a strict filter to reject them.
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 },
});

// ====== POST /api/session-init ======
app.post('/api/session-init', (req, res) => {
    const { courseName, courseCode, lecturerId, lecturerName, pin, sessionToken, durationMinutes, latitude, longitude } = req.body;

    if (!pin || !/^\d{6}$/.test(pin)) {
        return res.status(400).json({ error: 'A valid 6-digit PIN is required.' });
    }
    // Evict the PIN if it belongs to an already-expired session before collision check.
    // activeSessions.has() would otherwise return true for stale entries.
    getSessionByPin(pin);
    if (activeSessions.has(pin)) {
        return res.status(409).json({ error: 'PIN already in use by an active session' });
    }

    const duration = typeof durationMinutes === 'number' && durationMinutes > 0 ? durationMinutes : 240;
    const expiresAt = new Date(Date.now() + duration * 60 * 1000);
    const targetLocation = (latitude !== undefined && longitude !== undefined)
        ? { latitude: parseFloat(latitude), longitude: parseFloat(longitude) }
        : null;

    activeSessions.set(pin, {
        courseName: courseName || 'Untitled Course',
        courseCode: courseCode || null,
        lecturerId: lecturerId || 'unknown',
        lecturerName: lecturerName || lecturerId || 'Unknown Lecturer',
        sessionToken: sessionToken || null,
        targetLocation: targetLocation,
        attendees: [],
        faceDescriptors: [], // { matricule, name, descriptor: Float32[128] }
        createdAt: new Date(),
        expiresAt: expiresAt,
    });

    const geoLog = targetLocation ? `(GPS: ${targetLocation.latitude}, ${targetLocation.longitude})` : '(No GPS)';
    console.log(`[SESSION-INIT] PIN ${pin} activated for ${courseName || 'Untitled'} ${geoLog} (expires ${expiresAt.toISOString()})`);
    res.json({ success: true, pin, message: 'Session activated with PIN ' + pin });
});

// ====== GET /api/session-info?token=xxx ======
// Returns session details for the QR-code (token) path so the student page
// can display the real course name and instructor instead of placeholders.
app.get('/api/session-info', (req, res) => {
    const { token } = req.query;
    if (!token) return res.status(400).json({ error: 'token is required' });
    const session = getSessionByPinOrToken(null, token);
    if (!session) return res.status(404).json({ error: 'Session not found or expired' });
    res.json({
        courseName:   session.courseName,
        courseCode:   session.courseCode,
        lecturerName: session.lecturerName,
        lecturerId:   session.lecturerId,
    });
});

// ====== POST /api/validate-pin ======
app.post('/api/validate-pin', (req, res) => {
    const { pin } = req.body;
    const session = getSessionByPin(pin);
    if (!session) {
        return res.status(404).json({ error: 'Invalid or expired PIN' });
    }
    res.json({
        valid: true,
        courseName: session.courseName,
        courseCode: session.courseCode,
        lecturerId: session.lecturerId,
        lecturerName: session.lecturerName,
    });
});

// ====== POST /api/end-session ======
app.post('/api/end-session', (req, res) => {
    const { pin } = req.body;
    const session = getSessionByPin(pin);
    if (!session) {
        return res.status(404).json({ error: 'Session not found or already expired' });
    }
    const attendeeCount = session.attendees.length;
    activeSessions.delete(pin);
    console.log(`[SESSION-END] PIN ${pin} deactivated. ${attendeeCount} attendee(s) recorded.`);
    res.json({ success: true, message: `Session ended. ${attendeeCount} attendee(s) recorded.`, attendeeCount });
});

// ====== POST /api/parse-pdf ======
app.post('/api/parse-pdf', upload.single('pdf'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ success: false, error: 'No PDF file uploaded' });
        }
        console.log(`[PARSE-PDF] Received: ${req.file.originalname}, size: ${req.file.size} bytes`);
        const data = await pdfParse(req.file.buffer);
        const text = data.text;
        const sessionNumber = extractSessionNumber(text);
        const students = [];
        const lines = text.split('\n');
        let inMasterRoster = false;
        let rosterHeaderFound = false;

        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed) continue;
            if (trimmed.includes('MASTER ROSTER') || trimmed.includes('Cumulative Attendance') || trimmed.includes('T.P')) {
                inMasterRoster = true;
                rosterHeaderFound = false;
                continue;
            }
            if (inMasterRoster && (trimmed.includes('DAILY SNAPSHOT') || trimmed.includes('Generated by') ||
                trimmed.includes('Attendance Report') || trimmed.includes('Course:') || trimmed.includes('Lecturer Signature'))) {
                inMasterRoster = false;
                continue;
            }
            if (inMasterRoster && (trimmed.includes('Matricule') || trimmed.includes('Previous') ||
                trimmed.includes('New Total') || trimmed.includes('Percentage') || trimmed.includes('Name') ||
                trimmed.includes('Prev.') || trimmed.includes('New') || trimmed.includes('+/-'))) {
                rosterHeaderFound = true;
                continue;
            }
            if (inMasterRoster && trimmed.toLowerCase().startsWith('total:')) continue;
            if (inMasterRoster && rosterHeaderFound) {
                const parsed = parseMasterRosterLine(trimmed);
                if (parsed) students.push(parsed);
            }
        }

        if (students.length === 0) {
            for (const line of lines) {
                const trimmed = line.trim();
                if (!trimmed) continue;
                if (trimmed.includes('Attendance Report') || trimmed.includes('Course:') ||
                    trimmed.includes('Generated by') || trimmed.includes('Session Date') ||
                    trimmed.includes('Duration Required') || trimmed.includes('Total Students')) continue;
                const parsed = parseMasterRosterLine(trimmed);
                if (parsed && !students.find(s => s.matricule === parsed.matricule)) students.push(parsed);
            }
        }

        console.log(`[PARSE-PDF] Extracted ${students.length} student(s)`);
        res.json({ success: true, students, sessionNumber });
    } catch (err) {
        console.error('[PARSE-PDF] Error:', err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

function extractSessionNumber(text) {
    const patterns = [
        /T\.?P\.?\s*(\d+)/i,
        /Session\s*(?:Number|#)?\s*:?\s*(\d+)/i,
        /Session\s+(\d+)/i,
        /Total\s*Presence\s*:?\s*(\d+)/i,
    ];
    for (const pattern of patterns) {
        const match = text.match(pattern);
        if (match) {
            const num = parseInt(match[1], 10);
            if (num > 0 && num < 1000) return num;
        }
    }
    return 1;
}

function parseMasterRosterLine(line) {
    const matriculeRegex = /\b([A-Za-z]{1,6}[\/\-]?\d{2,4}[\/\-]?[A-Za-z]{0,4}\d{2,8}|[A-Za-z]{2,6}\d{4,12}|\d{2}[\/\-][A-Za-z]{2,4}[\/\-]\d{2,6})\b/;
    const matriculeMatch = line.match(matriculeRegex);
    if (!matriculeMatch) return null;
    const matricule = matriculeMatch[1].toUpperCase();
    let name = '';
    const beforeMatricule = line.substring(0, matriculeMatch.index).trim();
    const afterMatricule = line.substring(matriculeMatch.index + matriculeMatch[0].length).trim();
    const isValidName = (str) => {
        const words = str.split(/\s+/).filter(w => w.length > 1 && /[a-zA-Z]/.test(w));
        return words.length >= 1 && words.length <= 6;
    };
    const cleanName = (str) => str
        .replace(/\b(Verified|Pending|Yes|No|N\/A|Prev\.|New|Total|Percentage|Change|\+|\-)\b/gi, '')
        .replace(/\d{1,2}:\d{2}/g, '').replace(/\d+\s*min/gi, '').replace(/\d+\s*%/g, '')
        .replace(/[\(\)\[\]\{\}]/g, '').replace(/\s+/g, ' ').trim();
    const cleanedBefore = cleanName(beforeMatricule);
    const cleanedAfter = cleanName(afterMatricule);
    if (isValidName(cleanedBefore)) {
        name = cleanedBefore;
    } else if (isValidName(cleanedAfter)) {
        const words = cleanedAfter.split(/\s+/).filter(w => w.length > 0);
        name = words.slice(0, Math.min(3, words.length)).join(' ');
    }
    if (!name || name.length < 2) {
        const allWords = line.split(/\s+/).filter(w => /^[a-zA-Z]{2,}$/.test(w));
        if (allWords.length >= 2) name = allWords.slice(0, Math.min(3, allWords.length)).join(' ');
    }
    if (!name || name.length < 2) name = 'Unknown';
    const lineWithoutMatricule = line.replace(matriculeMatch[0], ' ');
    const numberRegex = /\b(\d+)\b/g;
    const numbers = [];
    let m;
    while ((m = numberRegex.exec(lineWithoutMatricule)) !== null) {
        const n = parseInt(m[1], 10);
        if (n >= 0 && n <= 999) numbers.push(n);
    }
    let totalPresence = numbers.length >= 2 ? numbers[1] : numbers.length === 1 ? numbers[0] : 0;
    if (totalPresence > 200) totalPresence = 0;
    return { matricule, name, totalPresence };
}

// ====== POST /connect ======
// Flutter app student registration path (no face verification).
app.post('/connect', (req, res) => {
    const { username, matricule, email, sessionPin, sessionToken, latitude, longitude } = req.body;
    const studentIP = req.headers['x-forwarded-for'] || req.ip || req.socket.remoteAddress;

    if (!username || !matricule || !email) {
        return res.status(400).send("All fields are required.");
    }
    if (username.length > 100 || matricule.length > 30 || email.length > 150) {
        return res.status(400).send("Invalid input length.");
    }

    let session = null;
    let pin = sessionPin;

    if (pin && /^\d{6}$/.test(pin)) {
        session = getSessionByPin(pin);
    } else if (sessionToken) {
        for (const [p, s] of activeSessions.entries()) {
            if (s.sessionToken === sessionToken) { session = s; pin = p; break; }
        }
    }
    if (!session && activeSessions.size === 1) {
        const entry = Array.from(activeSessions.entries())[0];
        session = entry[1]; pin = entry[0];
    }
    if (!session) {
        return res.status(400).send("A valid Session PIN is required. Ask your lecturer for the current PIN.");
    }

    if (session.targetLocation) {
        if (latitude === undefined || longitude === undefined) {
            return res.status(403).send("This session requires GPS location to be enabled.");
        }
        const dist = calculateDistance(session.targetLocation.latitude, session.targetLocation.longitude, parseFloat(latitude), parseFloat(longitude));
        if (dist === null || isNaN(dist)) return res.status(400).send("Invalid GPS coordinates.");
        if (dist > 50) return res.status(403).send(`Geofence Error: You are ${dist.toFixed(0)}m away from the classroom.`);
    }

    const existingEntry = session.attendees.find(a => a.ip === studentIP);
    if (existingEntry) {
        if (existingEntry.username !== username || existingEntry.matricule !== matricule) {
            return res.status(403).send("Error: This device is already registered under a different name.");
        }
        return res.status(200).send("You are already registered for this session!");
    }

    session.attendees.push({ username, matricule, email, ip: studentIP, connectedAt: new Date().toISOString(), time: new Date().toLocaleString() });
    console.log(`[SUCCESS] Registered: ${username} (${matricule}) from ${studentIP} into PIN ${pin}`);
    res.status(200).send(`Successfully registered for ${session.courseName}!`);
});

app.get('/connect', (req, res) => {
    res.status(200).send("Connect endpoint is working. Use POST to register.");
});

// ====== POST /api/verify-face ======
// Checks a 128-dim face descriptor against all faces registered in the session.
// Returns { unique: true } or { unique: false, matchedName: '...' }
app.post('/api/verify-face', (req, res) => {
    const { pin, sessionToken, descriptor } = req.body;
    const session = getSessionByPinOrToken(pin, sessionToken);
    if (!session) return res.status(404).json({ error: 'Session not found or expired' });

    if (!Array.isArray(descriptor) || descriptor.length !== 128) {
        return res.status(400).json({ error: 'descriptor must be a 128-element numeric array' });
    }

    const THRESHOLD = 0.6; // face-api.js recommended distance threshold
    for (const entry of (session.faceDescriptors || [])) {
        if (faceDistance(descriptor, entry.descriptor) < THRESHOLD) {
            return res.json({ unique: false, matchedName: entry.name });
        }
    }
    res.json({ unique: true });
});

// ====== POST /api/biometric-connect ======
// hotspot.html student registration path (with face descriptor).
app.post('/api/biometric-connect', (req, res) => {
    const { username, matricule, email, sessionPin, sessionToken, descriptor, latitude, longitude } = req.body;
    const studentIP = req.headers['x-forwarded-for'] || req.ip || req.socket.remoteAddress;

    if (!username || !matricule || !email) {
        return res.status(400).send("All fields are required.");
    }
    if (username.length > 100 || matricule.length > 30 || email.length > 150) {
        return res.status(400).send("Invalid input length.");
    }

    let session = null;
    let pin = sessionPin;
    if (pin && /^\d{6}$/.test(pin)) session = getSessionByPin(pin);
    if (!session && sessionToken) {
        for (const [p, s] of activeSessions.entries()) {
            if (s.sessionToken === sessionToken) { session = s; pin = p; break; }
        }
    }
    if (!session && activeSessions.size === 1) {
        const entry = Array.from(activeSessions.entries())[0];
        session = entry[1]; pin = entry[0];
    }
    if (!session) return res.status(400).send("A valid Session PIN is required.");

    if (session.targetLocation) {
        if (latitude === undefined || longitude === undefined) {
            return res.status(403).send("This session requires GPS location.");
        }
        const dist = calculateDistance(session.targetLocation.latitude, session.targetLocation.longitude, parseFloat(latitude), parseFloat(longitude));
        if (dist === null || isNaN(dist)) return res.status(400).send("Invalid GPS coordinates.");
        if (dist > 50) return res.status(403).send(`Geofence Error: You are ${dist.toFixed(0)}m away.`);
    }

    const existingEntry = session.attendees.find(a => a.ip === studentIP);
    if (existingEntry) {
        if (existingEntry.username !== username || existingEntry.matricule !== matricule) {
            return res.status(403).send("Error: This device is already registered under a different name.");
        }
        return res.status(200).send("You are already securely registered for this session!");
    }

    // Store face descriptor for duplicate detection in future registrations
    if (Array.isArray(descriptor) && descriptor.length === 128) {
        if (!session.faceDescriptors) session.faceDescriptors = [];
        if (!session.faceDescriptors.find(f => f.matricule === matricule)) {
            session.faceDescriptors.push({ matricule, name: username, descriptor });
        }
    }

    session.attendees.push({ username, matricule, email, ip: studentIP, faceVerified: true, connectedAt: new Date().toISOString(), time: new Date().toLocaleString() });
    console.log(`[SUCCESS-FACE] Registered: ${username} (${matricule}) from ${studentIP} into PIN ${pin}`);
    res.status(200).send(`Successfully registered for ${session.courseName}!`);
});

// ====== GET /export ======
app.get('/export', (req, res) => {
    const pin = req.query.pin;
    const session = getSessionByPin(pin);
    if (!session) return res.status(404).send("Session not found. Provide a valid PIN via ?pin=");
    if (session.attendees.length === 0) return res.send("No attendees for this session yet.");
    res.setHeader('Content-Type', 'application/pdf');
    generateAttendancePDF(session.attendees, res, {
        courseName: session.courseName,
        courseCode: session.courseCode,
        requiredConnectionMinutes: sessionConfig.requiredConnectionMinutes,
    });
});

// ====== API Endpoints ======
app.post('/api/session-config', express.json(), (req, res) => {
    const { requiredConnectionMinutes, gracePeriodMinutes } = req.body;
    if (typeof requiredConnectionMinutes === 'number') sessionConfig.requiredConnectionMinutes = requiredConnectionMinutes;
    if (typeof gracePeriodMinutes === 'number') sessionConfig.gracePeriodMinutes = gracePeriodMinutes;
    res.json({ success: true, config: sessionConfig });
});

app.get('/api/attendees', (req, res) => {
    const pin = req.query.pin;
    const session = getSessionByPin(pin);
    if (!session) return res.status(404).json({ error: 'Session not found' });
    res.json({ attendees: session.attendees });
});

app.post('/api/reset', (req, res) => {
    const { courseName, courseCode, pin, lecturerId, durationMinutes } = req.body;
    if (!pin || !/^\d{6}$/.test(pin)) return res.status(400).json({ error: 'A valid 6-digit PIN is required.' });
    let session = activeSessions.get(pin);
    let previousCount = 0;
    if (session) {
        previousCount = session.attendees.length;
        session.attendees = [];
        session.faceDescriptors = [];
        if (courseName) session.courseName = courseName;
        if (courseCode !== undefined) session.courseCode = courseCode;
        if (lecturerId) session.lecturerId = lecturerId;
    } else {
        const duration = typeof durationMinutes === 'number' && durationMinutes > 0 ? durationMinutes : 240;
        activeSessions.set(pin, {
            courseName: courseName || 'Untitled Course',
            courseCode: courseCode || null,
            lecturerId: lecturerId || 'unknown',
            sessionToken: null,
            attendees: [],
            faceDescriptors: [],
            createdAt: new Date(),
            expiresAt: new Date(Date.now() + duration * 60 * 1000),
        });
    }
    console.log(`[RESET] PIN ${pin}: Cleared ${previousCount} attendee(s).`);
    res.json({ success: true, message: 'Session reset.', previousCount, pin });
});

app.get('/api/stats', (req, res) => {
    const pin = req.query.pin;
    const session = getSessionByPin(pin);
    if (!session) return res.status(404).json({ error: 'Session not found' });
    const now = new Date();
    let verified = 0, pending = 0;
    session.attendees.forEach(a => {
        const mins = Math.floor((now - new Date(a.connectedAt)) / 60000);
        mins >= sessionConfig.requiredConnectionMinutes ? verified++ : pending++;
    });
    res.json({ total: session.attendees.length, verified, pending, requiredConnectionMinutes: sessionConfig.requiredConnectionMinutes });
});

app.post('/api/remove-attendee', (req, res) => {
    const { matricule, pin } = req.body;
    if (!matricule) return res.status(400).json({ success: false, error: 'Matricule is required' });
    const session = getSessionByPin(pin);
    if (!session) return res.status(404).json({ success: false, error: 'Session not found' });
    const beforeCount = session.attendees.length;
    session.attendees = session.attendees.filter(a => a.matricule !== matricule);
    if (session.faceDescriptors) {
        session.faceDescriptors = session.faceDescriptors.filter(f => f.matricule !== matricule);
    }
    res.json({ success: true, removedCount: beforeCount - session.attendees.length });
});

// ====== CATCH-ALL ======
app.use((req, res) => {
    console.log(`[UNMATCHED] ${req.method} ${req.url}`);
    res.status(404).send(`Route not found: ${req.method} ${req.url}`);
});

// ====== Helper: list all local IPv4 addresses ======
function getLocalIPs() {
    const interfaces = os.networkInterfaces();
    const ips = [];
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                ips.push({ name, address: iface.address });
            }
        }
    }
    return ips;
}

// ====== Helper: find the IP of the interface that holds the default route ======
// This is the interface the phone is most likely sharing (same router/hotspot).
function getDefaultRouteIP() {
    try {
        const output = execSync('route print 0.0.0.0', { encoding: 'utf8', timeout: 3000 });
        for (const line of output.split('\n')) {
            const parts = line.trim().split(/\s+/);
            // Row format: Network  Netmask  Gateway  Interface  Metric
            if (parts[0] === '0.0.0.0' && parts[1] === '0.0.0.0' && parts[3]) {
                const ifaceIP = parts[3];
                // Skip loopback and link-local
                if (!ifaceIP.startsWith('127.') && !ifaceIP.startsWith('169.254.')) {
                    console.log(`[HOTSPOT] Default route interface IP: ${ifaceIP}`);
                    return ifaceIP;
                }
            }
        }
    } catch (e) { /* non-fatal */ }
    return null;
}

// ====== Helper: auto-detect hotspot IP (for URL generation, not binding) ======
function detectHotspotIP() {
    const localIPs = getLocalIPs();

    // Subnet order: hotspot adapters always win over router/LAN interfaces.
    // The default-route heuristic is intentionally NOT used first — the PC can
    // have both a home-router connection (which owns the default route) AND a
    // Mobile Hotspot adapter. Students connect to the hotspot, not the router.
    const orderedRanges = [
        '192.168.137.',   // Windows Mobile Hotspot (standard)
        '10.0.0.',        // Windows Mobile Hotspot (alternate)
        '192.168.43.',    // Android phone hotspot
        '172.20.10.',     // iOS Personal Hotspot
        '192.168.50.',    // Some modem hotspots
        '192.168.0.',     // Home router / general LAN
        '192.168.1.',     // Home router alternate
    ];

    for (const range of orderedRanges) {
        const found = localIPs.find(ip => ip.address.startsWith(range));
        if (found) {
            console.log(`[HOTSPOT] Detected IP by range: ${found.address} (${found.name})`);
            return found.address;
        }
    }

    // Last resort: use the default-route interface if nothing matched above
    const defaultRouteIP = getDefaultRouteIP();
    if (defaultRouteIP && localIPs.find(ip => ip.address === defaultRouteIP)) {
        console.log(`[HOTSPOT] Falling back to default-route IP: ${defaultRouteIP}`);
        return defaultRouteIP;
    }

    const firstIP = localIPs.length > 0 ? localIPs[0].address : 'localhost';
    console.log(`[HOTSPOT] Fallback IP: ${firstIP}`);
    return firstIP;
}

// ====== START SERVER on port 5501 (HTTPS when certs present, HTTP otherwise) ======
const detectedHotspotIP = detectHotspotIP();

function _logStartup(scheme, port) {
    const localIPs = getLocalIPs();
    const modeLabel = scheme === 'https'
        ? 'HTTPS - camera enabled in Chrome'
        : 'HTTP only - no SSL (camera blocked by browser on phones)';
    console.log('========================================');
    console.log('[MODE] ' + modeLabel);
    console.log('[HOST] 0.0.0.0:' + port + ' (listening on all interfaces)');
    console.log('[HOTSPOT] Primary IP: ' + detectedHotspotIP);
    console.log('----------------------------------------');
    console.log('Accessible on these addresses:');
    localIPs.forEach(ip => {
        const marker = ip.address === detectedHotspotIP ? ' * PRIMARY' : '';
        console.log('  ' + scheme + '://' + ip.address + ':' + port + '/public/hotspot.html  (' + ip.name + ')' + marker);
    });
    console.log('  ' + scheme + '://localhost:' + port + '/public/hotspot.html');
    console.log('----------------------------------------');
}

function _addFirewallRule(port, label) {
    if (process.platform !== 'win32') return;
    const cmds = [
        'netsh advfirewall firewall delete rule name="' + label + '"',
        'netsh advfirewall firewall add rule name="' + label + '" dir=in action=allow protocol=TCP localport=' + port + ' profile=any',
    ].join(' && ');
    exec(cmds, (err) => {
        if (!err) console.log('[FIREWALL] Port ' + port + ' inbound rule ensured (profile=any).');
        else       console.log('[FIREWALL] Could not auto-add rule for port ' + port + ' - run start-server.bat as Admin.');
    });
}

function _openBrowser(url) {
    const cmd = process.platform === 'win32' ? 'start ' + url :
                process.platform === 'darwin' ? 'open ' + url : 'xdg-open ' + url;
    exec(cmd, (err) => { if (err) console.log('Could not auto-open browser:', err.message); });
}

app.listen(PORT, '0.0.0.0', () => {
    _logStartup('http', PORT);
    _addFirewallRule(PORT, 'OwHAS Attendance 5501');
    _openBrowser('http://' + detectedHotspotIP + ':' + PORT + '/public/hotspot.html');
});











