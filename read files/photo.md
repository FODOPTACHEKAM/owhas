# Local face-api.js Model Hosting Instructions

To make face recognition work fully offline, download the face-api.js library and required model files into your backend server and update `hotspot.html` to load them from the local server.

## Step 1 — Download the Models
Run these commands inside PowerShell from the backend folder:

```powershell
cd "C:\Users\Lenovo\Desktop\Android App\Att_App ui\attendance_app-first\backend"

# Create models folder
mkdir public\models -Force

# Download face-api.js library
curl -L "https://cdn.jsdelivr.net/npm/@vladmandic/face-api/dist/face-api.js" -o public\models\face-api.js

# Download the 3 required model files
curl -L "https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/tiny_face_detector_model-weights_manifest.json" -o "public\models\tiny_face_detector_model-weights_manifest.json"
curl -L "https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/tiny_face_detector_model-shard1" -o "public\models\tiny_face_detector_model-shard1"
curl -L "https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/face_landmark_68_model-weights_manifest.json" -o "public\models\face_landmark_68_model-weights_manifest.json"
curl -L "https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/face_landmark_68_model-shard1" -o "public\models\face_landmark_68_model-shard1"
curl -L "https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/face_recognition_model-weights_manifest.json" -o "public\models\face_recognition_model-weights_manifest.json"
curl -L "https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/face_recognition_model-shard1" -o "public\models\face_recognition_model-shard1"
curl -L "https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/face_recognition_model-shard2" -o "public\models\face_recognition_model-shard2"
```

## Step 2 — Verify the Download
Run:

```powershell
dir public\models
```

You should see these files:

- `face-api.js`
- `tiny_face_detector_model-weights_manifest.json`
- `tiny_face_detector_model-shard1`
- `face_landmark_68_model-weights_manifest.json`
- `face_landmark_68_model-shard1`
- `face_recognition_model-weights_manifest.json`
- `face_recognition_model-shard1`
- `face_recognition_model-shard2`

That is a total of **8 files**.

## Step 3 — `hotspot.html` (already done)

`hotspot.html` already loads all models from the local server. No further changes needed.

The relevant lines in `hotspot.html`:

```html
<!-- face-api.js loaded locally — no CDN required -->
<script src="/public/models/face-api.js" onerror="window._faceApiMissing=true"></script>
```

And inside the `FaceRecognitionManager.init()` method:

```js
await faceapi.nets.tinyFaceDetector.loadFromUri('/public/models');
await faceapi.nets.faceLandmark68Net.loadFromUri('/public/models');
await faceapi.nets.faceRecognitionNet.loadFromUri('/public/models');
```

All paths use `/public/models` — a relative URL that always resolves to the same host and port the page was served from. No hardcoded IPs.

## Troubleshooting

**"face-api.js not found" error in the browser**

The `onerror` handler sets `window._faceApiMissing = true`. This means `backend/public/models/face-api.js` was not found — either the file is missing or the server was not started from the `backend/` folder.

Fix: restart the server from the `backend/` directory:

```powershell
cd "C:\Users\Lenovo\Desktop\Android App\Att_App ui\attendance_app-first\backend"
node server.js
```

**Models download slowly on first use**

The models are served from `backend/public/models/` by the local Express server. They are fully offline once the server is running — no internet required.
