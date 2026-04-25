const express = require('express');
const path = require('path');
const os = require('os');
const { exec } = require('child_process');
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

// ====== In-memory storage ======
let attendees = [];

let sessionConfig = {
  requiredConnectionMinutes: 15,
  gracePeriodMinutes: 5,
};

// ====== POST /connect - Student Registration ======
app.post('/connect', (req, res) => {
    console.log('[POST /connect] Raw body:', req.body);
    console.log('[POST /connect] Content-Type:', req.headers['content-type']);
    
    const { username, matricule, email } = req.body;
    const studentIP = req.headers['x-forwarded-for'] || req.ip || req.connection.remoteAddress;

    // Validation Check
    if (!username || !matricule || !email) {
        console.log('[POST /connect] MISSING FIELDS:', { username, matricule, email });
        return res.status(400).send("All fields are required.");
    }

    // Duplicate Check
    const existingEntry = attendees.find(a => a.ip === studentIP);
    if (existingEntry) {
        if (existingEntry.username !== username || existingEntry.matricule !== matricule) {
            return res.status(403).send("Error: This device is already registered under a different name.");
        }
        return res.status(200).send("You are already registered!");
    }

    // Save Data
    const newAttendee = {
        username,
        matricule,
        email,
        ip: studentIP,
        connectedAt: new Date().toISOString(),
        time: new Date().toLocaleString()
    };

    attendees.push(newAttendee);
    console.log(`[SUCCESS] Registered: ${username} (${matricule}) from ${studentIP}`);
    console.log(`[TOTAL] ${attendees.length} attendee(s) registered`);
    
    res.status(200).send("Successfully Registered!");
});

// ====== Also accept GET /connect for testing ======
app.get('/connect', (req, res) => {
    res.status(200).send("Connect endpoint is working. Use POST to register.");
});

// ====== Export PDF ======
app.get('/export', (req, res) => {
    if (attendees.length === 0) return res.send("No attendees yet.");
    res.setHeader('Content-Type', 'application/pdf');
    generateAttendancePDF(attendees, res);
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
    res.json({ attendees });
});

app.get('/api/stats', (req, res) => {
    const now = new Date();
    const requiredMinutes = sessionConfig.requiredConnectionMinutes;
    let verified = 0;
    let pending = 0;

    attendees.forEach(a => {
        const connectedAt = new Date(a.connectedAt);
        const durationMinutes = Math.floor((now - connectedAt) / 60000);
        if (durationMinutes >= requiredMinutes) {
            verified++;
        } else {
            pending++;
        }
    });

    res.json({ total: attendees.length, verified, pending, requiredConnectionMinutes: requiredMinutes });
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
