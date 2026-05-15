# URL generation in ServerConfig

## What changed

1. The emulator and hotspot URLs are no longer stored as static full URL constants.
2. Instead, `ServerConfig` now generates them at runtime using getters:
   - `emulatorUrl` constructs the emulator loopback address from host + port.
   - `hotspotUrl` constructs the hotspot address from the configured hotspot host + port.
3. This means the actual URL string is produced dynamically at runtime rather than hard-coded as a single static string.

## Why this matters

- The emulator and hotspot server addresses can change depending on the network environment.
- Generating the URLs dynamically makes the code easier to update later if the host or port needs to change.
- It also keeps the online cloud URL separate from local network URL generation logic.

## Current implementation details

- `ServerConfig().emulatorUrl`
  - Returns a URL built from the emulator host and default server port.
  - Example: `http://10.0.2.2:5501`

- `ServerConfig().hotspotUrl`
  - Returns a URL built from the hotspot host and default server port.
  - Example: `http://192.168.137.1:5501`

- `ServerConfig().onlineUrl`
  - This remains a static constant because it represents the fixed online cloud endpoint.
  - The value is `https://owhas.org`.

## Role of `_onlineUrl`

- `_onlineUrl` is the fixed production cloud server address.
- It is used only when the app detects an internet-accessible server.
- Unlike emulator/hotspot URLs, it does not depend on local network host discovery.
- This means it is intentionally kept constant, since the online endpoint is a stable public URL.
