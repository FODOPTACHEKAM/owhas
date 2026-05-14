# Deploying OwHAS Online

Three options, ordered from simplest to most powerful.

---

## Option 1 — Cloudflare Tunnel (5 min, free, no server needed)

Keep the server running on your PC.  Cloudflare punches a secure HTTPS
tunnel through your firewall so students on any network can reach it.

**Best for:** occasional classes, testing, or when students are remote.

### Steps

1. Download `cloudflared` for Windows from  
   https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/

2. Run the tunnel (no account required for a quick tunnel):
   ```bat
   cloudflared tunnel --url http://localhost:5501
   ```

3. Cloudflare prints a URL like `https://random-words-1234.trycloudflare.com`.  
   That is your student URL.  Display it or encode it as a QR code.

4. When class ends, close the terminal — the tunnel dies automatically.

### Notes

- The URL changes every time you open a new tunnel.  
  Fix it by creating a named tunnel (requires free Cloudflare account + `cloudflared tunnel create owhas`).
- HTTPS is provided automatically → camera works in Chrome.
- Your PC must stay on and connected to the internet during class.
- Face-api.js models are served from your PC through the tunnel — first
  load may be slow on a slow internet connection.

---

## Option 2 — Render.com Free Tier (permanent public URL)

Deploy the server to the cloud so it is always reachable, even when your
PC is off.

**Best for:** permanent deployment, online classes, multiple lecturers.

### What changes in the code

Before deploying, three things must be updated:

#### 2a. Load face-api.js and models from CDN (not local disk)

Render's free tier has an ephemeral filesystem — files written at runtime
are lost on restart.  The model files (`public/models/`) are too large to
commit to git.  Change `hotspot.html` to load them from jsDelivr instead
of from the server.

In `public/hotspot.html`, find the `faceapi.nets.` loading block and
change the model path from `'/models'` to the CDN base URL:

```javascript
// BEFORE (local server)
const MODEL_URL = '/models';

// AFTER (CDN — works offline-free on cloud)
const MODEL_URL = 'https://cdn.jsdelivr.net/gh/justadudewhohacks/face-api.js@0.22.2/weights';
```

Do the same for `face-api.min.js`:

```html
<!-- BEFORE -->
<script src="/lib/face-api.min.js"></script>

<!-- AFTER -->
<script src="https://cdn.jsdelivr.net/npm/face-api.js@0.22.2/dist/face-api.min.js"></script>
```

#### 2b. Persist sessions across restarts (use a JSON file)

Currently sessions live in memory and are lost when the server restarts.
On a free cloud host the server restarts every ~15 minutes of inactivity.

Quickest fix — write `activeSessions` to a JSON file:

```javascript
// At the top of server.js, after `const activeSessions = new Map();`
const SESSION_FILE = path.join(__dirname, 'sessions.json');

function _loadSessions() {
    try {
        const raw = require('fs').readFileSync(SESSION_FILE, 'utf8');
        const arr = JSON.parse(raw);
        arr.forEach(([k, v]) => activeSessions.set(k, v));
    } catch (_) {}
}

function _saveSessions() {
    require('fs').writeFileSync(SESSION_FILE, JSON.stringify([...activeSessions.entries()]));
}

// Call _loadSessions() right after the Map declaration.
// Call _saveSessions() inside session-init and end-session handlers.
_loadSessions();
```

For a more robust solution use SQLite (`npm install better-sqlite3`) or
Render's free PostgreSQL add-on.

#### 2c. Remove local-network-only code

The DNS server, mDNS responder, HTTP-80 redirect, Dnscache stopping, and
`detectHotspotIP()` are all local-hotspot specific.  Wrap them in an
environment check so they only run locally:

```javascript
if (process.env.NODE_ENV !== 'production') {
    _startMdnsResponder();
    _startDnsServer();
    _startHttp80Redirect();
}
```

Set `NODE_ENV=production` in the Render environment variables panel.

### Deployment steps

1. Push the `backend/` folder to a GitHub repository.

2. Go to https://render.com → New → Web Service → connect your repo.

3. Configure:
   | Field | Value |
   |-------|-------|
   | Root Directory | `backend` |
   | Build Command | `npm install` |
   | Start Command | `node server.js` |
   | Environment | `Node` |

4. Add environment variable: `NODE_ENV = production`

5. Click **Deploy**.  Render gives you a URL like  
   `https://owhas.onrender.com`.  Use that as the student URL.

### Free tier limits

| Limit | Detail |
|-------|--------|
| Sleep after 15 min inactivity | First request after sleep is slow (~30 s) |
| 750 compute-hours/month | Enough for daily classroom use |
| No persistent disk (free) | Sessions lost on restart — use the JSON file fix above or upgrade to $7/month Starter plan which includes a persistent disk |

---

## Option 3 — VPS (full control, ~$5/month)

Use a DigitalOcean Droplet, Linode Nanode, or Hetzner CX11.

### Steps

1. Create a $5/month Ubuntu 22.04 server.

2. SSH in and install Node.js:
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
   sudo apt install -y nodejs
   ```

3. Copy the `backend/` folder to the server (e.g. via `scp` or git clone).

4. Install dependencies:
   ```bash
   cd backend && npm install
   ```

5. Get a free SSL certificate with Caddy (handles HTTPS automatically):
   ```bash
   sudo apt install -y caddy
   ```
   Edit `/etc/caddy/Caddyfile`:
   ```
   owhas.yourdomain.com {
       reverse_proxy localhost:5501
   }
   ```
   Point your domain's A record to the server IP, then `sudo systemctl restart caddy`.
   Caddy fetches a Let's Encrypt certificate automatically.

6. Keep the server running with PM2:
   ```bash
   sudo npm install -g pm2
   pm2 start server.js --name owhas
   pm2 save
   pm2 startup
   ```

7. Student URL: `https://owhas.yourdomain.com`

### Why HTTPS matters

The browser blocks `getUserMedia()` (camera) on plain HTTP pages served
from non-localhost origins.  HTTPS makes the camera work on all phones.

Without HTTPS, face recognition is disabled and students must enter their
details manually.

---

## Summary

| Option | Setup time | Cost | Camera | Persistence | Best for |
|--------|-----------|------|--------|-------------|----------|
| Cloudflare Tunnel | 5 min | Free | ✅ (HTTPS) | ❌ (PC-local) | Occasional / remote class |
| Render.com | 30 min | Free tier | ✅ (HTTPS) | ⚠️ (needs fix) | Regular use, no server |
| VPS (Caddy) | 1–2 h | ~$5/month | ✅ (HTTPS) | ✅ | Permanent deployment |

---

## Security checklist before going online

The current server has no authentication — anyone with the URL can call
any API endpoint.  Before exposing to the internet:

- [ ] Add a secret header or API key to lecturer-only endpoints
  (`/api/session-init`, `/api/end-session`, `/api/parse-pdf`, `/api/generate-pdf`).
- [ ] Enable the `helmet` and `express-rate-limit` packages already in
  `package.json` (they are imported but disabled in `server.js`).
- [ ] Set `SESSION_SECRET` as an environment variable instead of hardcoding.
- [ ] Restrict CORS to your own domain once you have a fixed URL.
