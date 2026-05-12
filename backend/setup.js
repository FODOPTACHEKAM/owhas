/**
 * One-time setup: downloads face-api.js and its face recognition models
 * so the server runs fully offline (no CDN, no internet on student phones).
 *
 * Run once on the lecturer's PC (which has internet):
 *   node setup.js
 *
 * After this, start-server.bat starts the server with all assets local.
 */

const https = require('https');
const http  = require('http');
const fs    = require('fs');
const path  = require('path');

const PUBLIC_DIR = path.join(__dirname, 'public');
const MODELS_DIR = path.join(PUBLIC_DIR, 'models');
const LIB_DIR    = path.join(PUBLIC_DIR, 'lib');

[PUBLIC_DIR, MODELS_DIR, LIB_DIR].forEach(d => fs.mkdirSync(d, { recursive: true }));

function download(url, dest, { forceRedownload = false } = {}) {
    return new Promise((resolve, reject) => {
        if (!forceRedownload && fs.existsSync(dest)) {
            // Validate the cached file is not a stub / partial download.
            // All face-api JSON manifests are >1 KB; all binary shards are >50 KB.
            const size = fs.statSync(dest).size;
            if (size < 1000) {
                console.log(`  WARN  ${path.basename(dest)}  (cached file is only ${size} bytes — re-downloading)`);
                fs.unlinkSync(dest);
            } else {
                console.log(`  SKIP  ${path.basename(dest)}  (already exists, ${(size / 1024).toFixed(0)} KB)`);
                return resolve();
            }
        }
        const tmp = dest + '.tmp';
        const file = fs.createWriteStream(tmp);
        const client = url.startsWith('https') ? https : http;

        const req = client.get(url, (res) => {
            if (res.statusCode === 301 || res.statusCode === 302) {
                file.close();
                if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
                return download(res.headers.location, dest).then(resolve).catch(reject);
            }
            if (res.statusCode !== 200) {
                file.close();
                if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
                return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
            }
            const expectedBytes = parseInt(res.headers['content-length'] || '0', 10);
            let bytes = 0;
            res.on('data', chunk => { bytes += chunk.length; });
            res.pipe(file);
            file.on('finish', () => {
                file.close();
                // Reject if we received suspiciously few bytes
                if (bytes < 1000) {
                    if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
                    return reject(new Error(`Downloaded only ${bytes} bytes for ${path.basename(dest)} — file appears corrupted`));
                }
                // Reject if Content-Length was provided but doesn't match
                if (expectedBytes > 0 && bytes !== expectedBytes) {
                    if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
                    return reject(new Error(`Incomplete: got ${bytes} bytes, expected ${expectedBytes} for ${path.basename(dest)}`));
                }
                fs.renameSync(tmp, dest);
                console.log(`  OK    ${path.basename(dest)}  (${(bytes / 1024).toFixed(0)} KB)`);
                resolve();
            });
        });
        req.on('error', err => {
            file.close();
            if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
            reject(err);
        });
    });
}

const BASE = 'https://cdn.jsdelivr.net/gh/justadudewhohacks/face-api.js@0.22.2/weights';

const FILES = [
    [
        'https://cdn.jsdelivr.net/npm/face-api.js@0.22.2/dist/face-api.min.js',
        path.join(LIB_DIR, 'face-api.min.js')
    ],
    [`${BASE}/tiny_face_detector_model-weights_manifest.json`, path.join(MODELS_DIR, 'tiny_face_detector_model-weights_manifest.json')],
    [`${BASE}/tiny_face_detector_model-shard1`,                path.join(MODELS_DIR, 'tiny_face_detector_model-shard1')],
    [`${BASE}/face_landmark_68_model-weights_manifest.json`,   path.join(MODELS_DIR, 'face_landmark_68_model-weights_manifest.json')],
    [`${BASE}/face_landmark_68_model-shard1`,                  path.join(MODELS_DIR, 'face_landmark_68_model-shard1')],
    [`${BASE}/face_recognition_model-weights_manifest.json`,   path.join(MODELS_DIR, 'face_recognition_model-weights_manifest.json')],
    [`${BASE}/face_recognition_model-shard1`,                  path.join(MODELS_DIR, 'face_recognition_model-shard1')],
    [`${BASE}/face_recognition_model-shard2`,                  path.join(MODELS_DIR, 'face_recognition_model-shard2')],
];

(async () => {
    console.log('====================================================');
    console.log('  OwHAS — One-time offline asset download');
    console.log('====================================================');
    console.log(`Saving to: ${PUBLIC_DIR}`);
    console.log('');

    for (const [url, dest] of FILES) {
        try {
            await download(url, dest);
        } catch (e) {
            console.error(`\n  FAIL  ${path.basename(dest)}: ${e.message}`);
            console.error('  Check your internet connection and try again.\n');
            process.exit(1);
        }
    }

    console.log('');
    console.log('====================================================');
    console.log('  All files downloaded. The server can now run');
    console.log('  without any internet connection on student phones.');
    console.log('====================================================');
})();
