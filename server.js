const express = require('express');
const path = require('path');
const os = require('os');
const { exec } = require('child_process');
const multer = require('multer');
const pdfParse = require('pdf-parse');
const { generateAttendancePDF } = require('./lib/services/pdfService');

const app = express();
const PORT = 5501;

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
    res.header('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.header('Pragma', 'no-cache');
    res.header('Expires', '0');
    if (req.method === 'OPTIONS') {
        return res.sendStatus(200);
    }
    next();
});

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ====== Static files ======
app.use('/public', express.static(path.join(__dirname, 'public'), {
    cacheControl: false,
    etag: false,
    lastModified: false
}));

// ====== Root redirect ======
app.get('/', (req, res) => {
    res.redirect('/public/hotspot.html');
});

// This tells the server what to do when someone visits /ping
app.get('/ping', (req, res) => {
    res.send('pong');
});

// Version check endpoint to verify server is the updated version
app.get('/api/version', (req, res) => {
    res.json({ version: '3.0', features: ['pdf-parse', 'session-number', 'tp-table', 'pin-sessions'] });
});

// ====== In-memory PIN-scoped session storage ======
// pin -> { courseName, courseCode, lecturerId, attendees[], createdAt, expiresAt }
const activeSessions = new Map();

// Session config defaults
let sessionConfig = {
    requiredConnectionMinutes: 15,
    gracePeriodMinutes: 5,
};

// ====== Helper: get session by PIN or token ======
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
const upload = multer({ storage: multer.memoryStorage() });

// ====== POST /api/session-init - Initialize a new PIN-scoped session ======
app.post('/api/session-init', (req, res) => {
    const { courseName, courseCode, lecturerId, lecturerName, pin, sessionToken, durationMinutes } = req.body;

    if (!pin || !/^\d{6}$/.test(pin)) {
        return res.status(400).json({ error: 'A valid 6-digit PIN is required.' });
    }

    if (activeSessions.has(pin)) {
        return res.status(409).json({ error: 'PIN already in use by an active session' });
    }

    const duration = typeof durationMinutes === 'number' && durationMinutes > 0 ? durationMinutes : 240;
    const expiresAt = new Date(Date.now() + duration * 60 * 1000);
    activeSessions.set(pin, {
        courseName: courseName || 'Untitled Course',
        courseCode: courseCode || null,
        lecturerId: lecturerId || 'unknown',
        lecturerName: lecturerName || lecturerId || 'Unknown Lecturer',
        sessionToken: sessionToken || null,
        attendees: [],
        createdAt: new Date(),
        expiresAt: expiresAt,
    });

    console.log(`[SESSION-INIT] PIN ${pin} activated for ${courseName || 'Untitled Course'} (expires ${expiresAt.toISOString()})`);
    res.json({ success: true, pin, message: 'Session activated with PIN ' + pin });
});

// ====== POST /api/validate-pin - Student validates PIN before registering ======
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

// ====== POST /api/end-session - Deactivate a session and free its PIN ======
app.post('/api/end-session', (req, res) => {
    const { pin } = req.body;
    const session = getSessionByPin(pin);

    if (!session) {
        return res.status(404).json({ error: 'Session not found or already expired' });
    }

    const attendeeCount = session.attendees.length;
    activeSessions.delete(pin);

    console.log(`[SESSION-END] PIN ${pin} deactivated. ${attendeeCount} attendee(s) recorded.`);
    res.json({
        success: true,
        message: `Session ended. ${attendeeCount} attendee(s) recorded.`,
        attendeeCount,
    });
});

// ====== POST /api/parse-pdf - Parse previous session PDF ======
app.post('/api/parse-pdf', upload.single('pdf'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ success: false, error: 'No PDF file uploaded' });
        }

        console.log(`[PARSE-PDF] Received PDF file: ${req.file.originalname}, size: ${req.file.size} bytes`);

        const data = await pdfParse(req.file.buffer);
        const text = data.text;
        console.log(`[PARSE-PDF] Extracted ${text.length} characters of text from PDF`);

        // Extract session / T.P number from the PDF text
        const sessionNumber = extractSessionNumber(text);
        console.log(`[PARSE-PDF] Detected session number: ${sessionNumber}`);

        const students = [];
        const lines = text.split('\n');
        let inMasterRoster = false;
        let rosterHeaderFound = false;

        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed) continue;

            // Detect entry into MASTER ROSTER section
            if (trimmed.includes('MASTER ROSTER') || trimmed.includes('Cumulative Attendance') || trimmed.includes('T.P')) {
                inMasterRoster = true;
                rosterHeaderFound = false;
                console.log(`[PARSE-PDF] Entered MASTER ROSTER section at line: "${trimmed.substring(0, 60)}"`);
                continue;
            }

            // Detect exit from MASTER ROSTER section
            if (inMasterRoster &&
                (trimmed.includes('DAILY SNAPSHOT') ||
                 trimmed.includes('Generated by') ||
                 trimmed.includes('Attendance Report') ||
                 trimmed.includes('Course:') ||
                 trimmed.includes('Lecturer Signature'))) {
                console.log(`[PARSE-PDF] Exited MASTER ROSTER section at line: "${trimmed.substring(0, 60)}"`);
                inMasterRoster = false;
                continue;
            }

            // Skip header rows inside MASTER ROSTER
            if (inMasterRoster &&
                (trimmed.includes('Matricule') ||
                 trimmed.includes('Previous') ||
                 trimmed.includes('New Total') ||
                 trimmed.includes('Percentage') ||
                 trimmed.includes('Name') ||
                 trimmed.includes('Prev.') ||
                 trimmed.includes('New') ||
                 trimmed.includes('+/-'))) {
                rosterHeaderFound = true;
                continue;
            }

            // Skip total/summary rows
            if (inMasterRoster && trimmed.toLowerCase().startsWith('total:')) {
                continue;
            }

            if (inMasterRoster && rosterHeaderFound) {
                const parsed = parseMasterRosterLine(trimmed);
                if (parsed) {
                    students.push(parsed);
                }
            }
        }

        // Fallback: if no students found in MASTER ROSTER, try parsing entire document
        if (students.length === 0) {
            console.log('[PARSE-PDF] No students found in MASTER ROSTER, trying fallback parsing...');
            for (const line of lines) {
                const trimmed = line.trim();
                if (!trimmed) continue;
                // Skip obvious header/footer lines
                if (trimmed.includes('Attendance Report') || trimmed.includes('Course:') ||
                    trimmed.includes('Generated by') || trimmed.includes('Session Date') ||
                    trimmed.includes('Duration Required') || trimmed.includes('Total Students')) {
                    continue;
                }
                const parsed = parseMasterRosterLine(trimmed);
                if (parsed && !students.find(s => s.matricule === parsed.matricule)) {
                    students.push(parsed);
                }
            }
        }

        console.log(`[PARSE-PDF] Extracted ${students.length} student(s) from uploaded PDF`);
        if (students.length > 0) {
            console.log(`[PARSE-PDF] First student sample:`, students[0]);
            console.log(`[PARSE-PDF] Last student sample:`, students[students.length - 1]);
        }

        res.json({ success: true, students, sessionNumber });
    } catch (err) {
        console.error('[PARSE-PDF] Error:', err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

/// Extract session / T.P number from PDF text
function extractSessionNumber(text) {
    // Look for patterns like "T.P 3", "T.P. 3", "TP 3", "Session 3", "Session: 3"
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

    // Default: try to infer from "Previous Session Data: Uploaded" or other context
    // If we can't find one, return 1 as default
    return 1;
}

/// Parse a single line from PDF MASTER ROSTER to extract student data
function parseMasterRosterLine(line) {
    // More flexible matricule regex:
    // Supports: UC2024001, 21/ucs/001, CS-2024-001, FE21A001, ENG2024001, etc.
    // Pattern: letters/digits mixed, with optional separators, ending with digits
    const matriculeRegex = /\b([A-Za-z]{1,6}[\/\-]?\d{2,4}[\/\-]?[A-Za-z]{0,4}\d{2,8}|[A-Za-z]{2,6}\d{4,12}|\d{2}[\/\-][A-Za-z]{2,4}[\/\-]\d{2,6})\b/;
    const matriculeMatch = line.match(matriculeRegex);
    if (!matriculeMatch) return null;

    const matricule = matriculeMatch[1].toUpperCase();
    let name = '';

    // Try to extract name from before the matricule
    const beforeMatricule = line.substring(0, matriculeMatch.index).trim();
    // Try to extract name from after the matricule
    const afterMatricule = line.substring(matriculeMatch.index + matriculeMatch[0].length).trim();

    // Heuristic: names typically contain alphabetic characters and are 2-5 words long
    const isValidName = (str) => {
        const words = str.split(/\s+/).filter(w => w.length > 1 && /[a-zA-Z]/.test(w));
        return words.length >= 1 && words.length <= 6;
    };

    const cleanName = (str) => {
        return str
            .replace(/\b(Verified|Pending|Yes|No|N\/A|Prev\.|New|Total|Percentage|Change|\+|\-)\b/gi, '')
            .replace(/\d{1,2}:\d{2}/g, '')
            .replace(/\d+\s*min/gi, '')
            .replace(/\d+\s*%/g, '')
            .replace(/[\(\)\[\]\{\}]/g, '')
            .replace(/\s+/g, ' ')
            .trim();
    };

    const cleanedBefore = cleanName(beforeMatricule);
    const cleanedAfter = cleanName(afterMatricule);

    if (isValidName(cleanedBefore)) {
        name = cleanedBefore;
    } else if (isValidName(cleanedAfter)) {
        // Take first 2-3 words after matricule as name
        const words = cleanedAfter.split(/\s+/).filter(w => w.length > 0);
        const nameWords = words.slice(0, Math.min(3, words.length));
        name = nameWords.join(' ');
    }

    // If still no name, try a broader extraction
    if (!name || name.length < 2) {
        const allWords = line.split(/\s+/).filter(w => /^[a-zA-Z]{2,}$/.test(w));
        if (allWords.length >= 2) {
            name = allWords.slice(0, Math.min(3, allWords.length)).join(' ');
        }
    }

    if (!name || name.length < 2) name = 'Unknown';

    // Extract numbers more intelligently
    // Remove the matricule part first to avoid confusion
    const lineWithoutMatricule = line.replace(matriculeMatch[0], ' ');
    const numberRegex = /\b(\d+)\b/g;
    const numbers = [];
    let m;
    while ((m = numberRegex.exec(lineWithoutMatricule)) !== null) {
        const n = parseInt(m[1], 10);
        if (n >= 0 && n <= 999) numbers.push(n);
    }

    let totalPresence = 0;
    if (numbers.length >= 2) {
        // In "Prev. New +/- %" format, New Total is often the 2nd number
        totalPresence = numbers[1];
    } else if (numbers.length === 1) {
        totalPresence = numbers[0];
    }

    // Validate: total presence should be a reasonable small number
    if (totalPresence > 200) {
        // Probably picked up a year or ID number, reset to 0
        totalPresence = 0;
    }

    return { matricule, name, totalPresence };
}

// ====== POST /connect - Student Registration (PIN-scoped) ======
app.post('/connect', (req, res) => {
    console.log('[POST /connect] Raw body:', req.body);
    console.log('[POST /connect] Content-Type:', req.headers['content-type']);

    const { username, matricule, email, sessionPin, sessionToken } = req.body;
    const studentIP = req.headers['x-forwarded-for'] || req.ip || req.connection.remoteAddress;

    // Validation Check
    if (!username || !matricule || !email) {
        console.log('[POST /connect] MISSING FIELDS:', { username, matricule, email });
        return res.status(400).send("All fields are required.");
    }

    // Determine which session this registration belongs to
    let session = null;
    let pin = sessionPin;

    if (pin && /^\d{6}$/.test(pin)) {
        session = getSessionByPin(pin);
    } else if (sessionToken) {
        // Fallback: find session by token
        for (const [p, s] of activeSessions.entries()) {
            if (s.sessionToken === sessionToken) {
                session = s;
                pin = p;
                break;
            }
        }
    }

    // Backward compatibility: if no PIN provided and only one active session exists, use it
    if (!session && activeSessions.size === 1) {
        const entry = Array.from(activeSessions.entries())[0];
        session = entry[1];
        pin = entry[0];
    }

    if (!session) {
        return res.status(400).send("A valid Session PIN is required. Ask your lecturer for the current PIN.");
    }

    // Session-scoped Duplicate Check
    const existingEntry = session.attendees.find(a => a.ip === studentIP);
    if (existingEntry) {
        if (existingEntry.username !== username || existingEntry.matricule !== matricule) {
            return res.status(403).send("Error: This device is already registered under a different name in this session.");
        }
        return res.status(200).send("You are already registered for this session!");
    }

    // Save Data in session-scoped array
    const newAttendee = {
        username,
        matricule,
        email,
        ip: studentIP,
        connectedAt: new Date().toISOString(),
        time: new Date().toLocaleString()
    };

    session.attendees.push(newAttendee);
    console.log(`[SUCCESS] Registered: ${username} (${matricule}) from ${studentIP} into session PIN ${pin}`);
    console.log(`[TOTAL] Session ${pin}: ${session.attendees.length} attendee(s) registered`);

    res.status(200).send(`Successfully registered for ${session.courseName}!`);
});

// ====== Also accept GET /connect for testing ======
app.get('/connect', (req, res) => {
    res.status(200).send("Connect endpoint is working. Use POST to register.");
});

// ====== Export PDF (scoped by PIN) ======
app.get('/export', (req, res) => {
    const pin = req.query.pin;
    const session = getSessionByPin(pin);

    if (!session) {
        return res.status(404).send("Session not found. Provide a valid PIN via ?pin=");
    }

    if (session.attendees.length === 0) return res.send("No attendees for this session yet.");

    res.setHeader('Content-Type', 'application/pdf');
    const pdfSessionInfo = {
        courseName: session.courseName,
        courseCode: session.courseCode,
        requiredConnectionMinutes: sessionConfig.requiredConnectionMinutes,
    };
    generateAttendancePDF(session.attendees, res, pdfSessionInfo);
});

// ====== API Endpoints ======
app.post('/api/session-config', express.json(), (req, res) => {
    const { requiredConnectionMinutes, gracePeriodMinutes } = req.body;
    if (typeof requiredConnectionMinutes === 'number') {
        sessionConfig.requiredConnectionMinutes = requiredConnectionMinutes;
    }
    if (typeof gracePeriodMinutes === 'number') {
        sessionConfig.gracePeriodMinutes = gracePeriodMinutes;
    }
    res.json({ success: true, config: sessionConfig });
});

app.get('/api/attendees', (req, res) => {
    const pin = req.query.pin;
    const session = getSessionByPin(pin);

    if (!session) {
        return res.status(404).json({ error: 'Session not found' });
    }

    res.json({ attendees: session.attendees });
});

// ====== Reset attendees (scoped by PIN; creates new session if PIN doesn't exist) ======
app.post('/api/reset', (req, res) => {
    const { courseName, courseCode, pin, lecturerId } = req.body;

    if (!pin || !/^\d{6}$/.test(pin)) {
        return res.status(400).json({ error: 'A valid 6-digit PIN is required.' });
    }

    let session = activeSessions.get(pin);
    let previousCount = 0;

    if (session) {
        previousCount = session.attendees.length;
        session.attendees = [];
        if (courseName) session.courseName = courseName;
        if (courseCode !== undefined) session.courseCode = courseCode;
        if (lecturerId) session.lecturerId = lecturerId;
    } else {
        // Create new session bucket if PIN doesn't exist
        const expiresAt = new Date(Date.now() + 4 * 60 * 60 * 1000);
        activeSessions.set(pin, {
            courseName: courseName || 'Untitled Course',
            courseCode: courseCode || null,
            lecturerId: lecturerId || 'unknown',
            sessionToken: null,
            attendees: [],
            createdAt: new Date(),
            expiresAt: expiresAt,
        });
    }

    console.log(`[RESET] PIN ${pin}: Cleared ${previousCount} attendee(s). New session started.`);
    console.log(`[SESSION] Course: ${courseName || 'Untitled Course'}, Code: ${courseCode || 'N/A'}`);
    res.json({ success: true, message: 'Session reset.', previousCount, pin });
});

app.get('/api/stats', (req, res) => {
    const pin = req.query.pin;
    const session = getSessionByPin(pin);

    if (!session) {
        return res.status(404).json({ error: 'Session not found' });
    }

    const now = new Date();
    const requiredMinutes = sessionConfig.requiredConnectionMinutes;
    let verified = 0;
    let pending = 0;

    session.attendees.forEach(a => {
        const connectedAt = new Date(a.connectedAt);
        const durationMinutes = Math.floor((now - connectedAt) / 60000);
        if (durationMinutes >= requiredMinutes) {
            verified++;
        } else {
            pending++;
        }
    });

    res.json({ total: session.attendees.length, verified, pending, requiredConnectionMinutes: requiredMinutes });
});

// ====== Remove a specific attendee by matricule (scoped by PIN) ======
app.post('/api/remove-attendee', (req, res) => {
    const { matricule, pin } = req.body;
    if (!matricule) {
        return res.status(400).json({ success: false, error: 'Matricule is required' });
    }

    const session = getSessionByPin(pin);
    if (!session) {
        return res.status(404).json({ success: false, error: 'Session not found' });
    }

    const beforeCount = session.attendees.length;
    session.attendees = session.attendees.filter(a => a.matricule !== matricule);
    const removedCount = beforeCount - session.attendees.length;
    console.log(`[REMOVE] PIN ${pin}: Removed ${removedCount} attendee(s) with matricule ${matricule}`);
    res.json({ success: true, removedCount });
});

// ====== CATCH-ALL: Log any unmatched routes ======
app.use((req, res) => {
    console.log(`[UNMATCHED ROUTE] ${req.method} ${req.url}`);
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

// ====== START SERVER ======
app.listen(PORT, '0.0.0.0', () => {
    const localIPs = getLocalIPs();
    console.log(`========================================`);
    console.log(`Attendance Server running on port ${PORT}`);
    console.log(`Static folder: ${path.join(__dirname, 'public')}`);
    console.log(`----------------------------------------`);
    console.log(`Available on these addresses:`);
    localIPs.forEach(ip => {
        console.log(`  http://${ip.address}:${PORT}/public/hotspot.html  (${ip.name})`);
    });
    console.log(`----------------------------------------`);
    console.log(`Test endpoint: http://localhost:${PORT}/ping`);
    console.log(`========================================`);

    if (process.platform === 'win32') {
        console.log(`\n⚠️  WINDOWS FIREWALL WARNING:`);
        console.log(`   If phones on the hotspot cannot reach this server,`);
        console.log(`   run PowerShell as Administrator and execute:`);
        console.log(`   New-NetFirewallRule -DisplayName "Attendance Server" -Direction Inbound -LocalPort ${PORT} -Protocol TCP -Action Allow`);
        console.log(`   Or double-click start-server.bat to do it automatically.\n`);
    }

    // Try to open the first non-internal IP in the default browser
    const firstIP = localIPs.length > 0 ? localIPs[0].address : 'localhost';
    const openUrl = `http://${firstIP}:${PORT}/public/hotspot.html`;
    const platform = process.platform;
    const cmd = platform === 'win32' ? `start ${openUrl}` :
                platform === 'darwin' ? `open ${openUrl}` :
                `xdg-open ${openUrl}`;

    exec(cmd, (err) => {
        if (err) {
            console.log('Could not auto-open browser:', err.message);
        } else {
            console.log('Browser opened successfully!');
        }
    });
});

