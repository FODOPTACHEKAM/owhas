# TODO: Fix QR Loading & "Go Live" Confusion

## Information Gathered

### Issue 1: QR code scanned -> HTML page doesn't load
The QR code encodes `http://192.168.137.1:5501/public/hotspot.html`. Multiple failure points:
1. **Hardcoded IP mismatch**: `192.168.137.1` is hardcoded in `server.js`, `public/hotspot.html`, `lib/services/api_service.dart`, and `lib/pages/lecturer_dashboard_page.dart`. Windows Mobile Hotspot does not guarantee this IP — it varies by system.
2. **`public/hotspot.html` uses hardcoded `SERVER_URL`**: The JS fetches from `http://192.168.137.1:5501` regardless of what IP/port it was actually loaded from.
3. **Windows Firewall**: Port 5501 is likely blocked unless explicitly allowed.
4. **Phone mobile-data fallback**: Android/iOS may route the request over cellular data instead of Wi-Fi when the hardcoded IP isn't reachable on the hotspot subnet.

### Issue 2: "node server.js does not activate the Go Live extension"
The "Go Live" button is from the VS Code Live Server extension (Ritwick Dey), which is a completely separate static-file server that runs on its own port (default 5500). Running `node server.js` starts your custom Express server on port 5501. These two have nothing to do with each other.

## Plan

### Files to edit

| # | File | Change | Status |
|---|------|--------|--------|
| 1 | `public/hotspot.html` | Replace hardcoded `SERVER_URL` with `window.location.origin` so the form works no matter what IP/port it was loaded from. | [x] DONE |
| 2 | `server.js` | Add `os.networkInterfaces()` to dynamically detect and print ALL local IPv4 addresses at startup. Print a clear firewall warning if the OS is Windows. | [x] DONE |
| 3 | `lib/pages/lecturer_dashboard_page.dart` | Add a comment above `_qrUrl` explaining how to update it, and add a small UI note showing the QR URL so the user can verify it matches the printed server IP. | [x] DONE |
| 4 | `lib/services/api_service.dart` | Add a comment explaining `baseUrl` must match the actual hotspot IP. | [x] DONE |
| 5 | `start-server.bat` *(new)* | One-click batch script that opens Windows Firewall for port 5501 and then launches `node server.js`. | [x] DONE |
| 6 | `explain.md` | Add a new section clearly distinguishing Live Server ("Go Live") vs `node server.js`, plus expanded QR troubleshooting steps. | [x] DONE |

### Follow-up steps after editing
1. Run `start-server.bat` to auto-open the firewall and start the server.
2. Check the terminal output for the correct hotspot IP.
3. Verify the QR code URL in the Flutter app matches that IP.
4. Test scanning from a phone connected to the hotspot.

