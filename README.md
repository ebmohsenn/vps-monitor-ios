# VPS Monitor for iOS

A small SwiftUI app and home-screen widget that show the health of your own Linux server (VPS):
CPU, memory and disk usage, load average, uptime, the state of selected services, and recent history.

The app reads a simple JSON API that you host yourself. A reference backend in Python
(standard library only) is included in [`server/`](server/).

![iOS](https://img.shields.io/badge/iOS-15.0%2B-blue.svg)
![Widget](https://img.shields.io/badge/widget-iOS%2017%2B-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **Dashboard**: CPU, memory and disk usage, uptime, load average, and services with a running/stopped badge.
- **History**: recent CPU, memory and disk samples served by your backend.
- **System**: summary and per-service CPU and memory.
- **Settings**: change the status endpoint at runtime, refresh interval (1/2/5/10 min), auto refresh, clear the cache.
- **Widget** (small and medium): online/offline dot, CPU and memory. It refreshes about every 10 minutes and whenever the app gets new data.
- **Offline cache**: the last snapshot and history are stored in a shared App Group container, so the app and the widget can show the last known state.
- **Optional request signing** (HMAC-SHA256) and **optional certificate pinning**.
- Built with SwiftUI and Combine. No third-party dependencies.

## Screenshots

_Screenshots coming soon._

<!--
| Dashboard | History | Widget |
|-----------|---------|--------|
| ![Dashboard](docs/screenshots/dashboard.png) | ![History](docs/screenshots/history.png) | ![Widget](docs/screenshots/widget.png) |
-->

## How it works

```
┌──────────────┐   HTTPS GET (optionally HMAC-signed)   ┌───────────────────────────┐
│ iOS app      │ ─────────────────────────────────────▶ │ your server               │
│  + widget    │ ◀───────────────────────────────────── │  /api/status              │
└──────────────┘          JSON                          │  /api/status/history      │
                                                        └───────────────────────────┘
```

The app makes two `GET` requests to one base URL, the **status endpoint**:

| Request | Response |
|---|---|
| `GET <status endpoint>` | current snapshot |
| `GET <status endpoint>/history` | array of past samples |

The history URL is the status URL with `/history` added to the end. If your status endpoint is a PHP script,
for example `https://host/api/vps-status.php`, the script gets the history request through `PATH_INFO`.

### Status response

```json
{
  "status": "ok",
  "timestamp": "2026-11-10T09:30:00Z",
  "systemSummary": {
    "cpuUsage": 12.5,
    "memoryUsage": 48.1,
    "diskUsage": 63.0,
    "uptime": "12d 4h",
    "load": [0.31, 0.27, 0.22]
  },
  "services": [
    { "name": "nginx", "status": "running", "cpu": 41.2, "memory": 18.5 }
  ]
}
```

- `status`: the widget shows green for `"ok"` or `"online"`. Any other value shows red.
- `cpuUsage`, `memoryUsage` and `diskUsage` are percentages from 0 to 100.
- A service whose `status` is `"running"` gets a green badge. Any other value gets a red badge.
- Each service's `name` must be unique. The meaning of `cpu` and `memory` is up to your backend. The reference server sends CPU seconds and MB.
- Timestamps use ISO 8601 **without fractional seconds** (`2026-11-10T09:30:00Z`). This is what Swift's `JSONDecoder` `.iso8601` strategy accepts.

### History response

```json
[
  { "timestamp": "2026-11-10T09:30:00Z", "cpuUsage": 12.5, "memoryUsage": 48.1, "diskUsage": 63.0 }
]
```

### Request signing (optional)

If you set a secret (`VPS_HMAC_SECRET`, see [Configuration](#configuration)), every request gets two headers:

| Header | Value |
|---|---|
| `X-Request-Timestamp` | ISO 8601 UTC time, e.g. `2026-11-10T09:30:00Z` |
| `X-Request-Signature` | `base64( HMAC-SHA256( secret, "GET" + <full request URL> + <timestamp> ) )` |

The server rebuilds the same string, compares the signatures in constant time, and rejects timestamps that are
too old. Behind a reverse proxy, the server must use the **public** URL the app called
(`https://vps.example.com/api/status`), not the internal one.

> The secret is compiled into the app bundle, so anyone holding the app binary can extract it. Treat it as a
> lightweight access key for a single-user tool, not as strong authentication. For stronger protection, put the
> endpoint behind a VPN, mTLS, or an IP allow-list.

### Certificate pinning (optional)

Pinning is **off** by default, and normal iOS TLS validation applies. To pin, export your server's leaf
certificate in DER format, name it `pinned_cert.der`, and add it to **both** the `VPSMonitor` and
`VPSMonitorWidgetExtension` targets. Requests then succeed only when the server's leaf certificate is
byte-for-byte identical to that file. This also works with a self-signed certificate. You have to ship a
new build every time the certificate is renewed.

## Reference server

[`server/vps_status_server.py`](server/vps_status_server.py) implements the API above using only the Python
standard library. It reads metrics from `/proc` and `os.getloadavg()`, and reads service state from `systemctl`.

```bash
# on the server (Linux, Python 3.8+)
export VPS_SERVICES="nginx,postgresql"          # systemd units to report
export VPS_HMAC_SECRET="a-long-random-string"   # optional; must match the app
export VPS_PUBLIC_BASE_URL="https://vps.example.com"
python3 server/vps_status_server.py             # listens on 127.0.0.1:8787
```

Put it behind a TLS reverse proxy. For example, with nginx:

```nginx
location /api/status {
    proxy_pass http://127.0.0.1:8787;
    proxy_set_header Host $host;
}
```

History is kept in memory: one sample every 5 minutes, 24 hours retained by default. It starts empty each time
the server restarts. See the docstring at the top of the script for every option. You can also write your own
backend in any language, as long as it returns the JSON above.

## Requirements

- Xcode 15 or later (the project format is Xcode 15)
- iOS 15.0+ for the app, iOS 17.0+ for the widget
- An Apple Developer account to run on a device. The App Group capability needs a team.
- A server that exposes the API described above

## Build and run

The project has **no CocoaPods or Swift Package dependencies**. Open the project and build it.

```bash
git clone https://github.com/<your-account>/vps-monitor-ios.git
cd vps-monitor-ios
cp Config/Local.example.xcconfig Config/Local.xcconfig   # then edit it
open VPSMonitor.xcodeproj
```

1. In `Config/Local.xcconfig`, set your bundle ID prefix, App Group, Team ID, default endpoint and, optionally, the HMAC secret.
2. In Xcode, select the **VPSMonitor** scheme and a simulator or device, then press Run.
3. To test the widget, run the **VPSMonitorWidgetExtension** scheme, or add the widget from the home screen.

> Earlier private versions used CocoaPods, but none of the pods were imported by the code, so the Podfile was
> removed. If you add pods, run `pod install` and open the generated `.xcworkspace` instead.

## Configuration

Build-time settings are in [`Config/VPSMonitor.xcconfig`](Config/VPSMonitor.xcconfig). Any of them can be
overridden in the git-ignored `Config/Local.xcconfig`.

| Setting | Purpose | Default |
|---|---|---|
| `VPS_BUNDLE_ID_PREFIX` | App bundle ID. The widget uses `<prefix>.widget` | `com.example.vpsmonitor` |
| `VPS_APP_GROUP_ID` | App Group shared by the app and widget (cache and endpoint setting) | `group.com.example.vpsmonitor` |
| `DEVELOPMENT_TEAM` | Your Apple Team ID | empty |
| `VPS_STATUS_ENDPOINT` | Default status endpoint | `https://vps.example.com/api/status` |
| `VPS_HMAC_SECRET` | Shared secret for request signing. Empty means requests are not signed | empty |

In `.xcconfig` files `//` starts a comment, so write URLs as `https:/$()/host/path`.

These values are copied into both targets' `Info.plist` and read at runtime by
[`AppConfig.swift`](VPSMonitor/AppConfig.swift). The endpoint can also be changed in the app under
**Settings → Server**. The new value is stored in the App Group, so the widget uses it too.

Register the App Group ID in your Apple Developer account, or let Xcode's automatic signing create it.
Without a working App Group, the app falls back to its own cache and the widget falls back to the default endpoint.

## Project structure

```
VPSMonitor/                 iOS app target
├── AppDelegate.swift       UIKit app delegate (@main)
├── SceneDelegate.swift     hosts the SwiftUI root view
├── VPSMonitorApp.swift     composes the store and view models
├── AppConfig.swift         build-time configuration (shared with the widget)
├── Model/                  API models and the shared ServerStore
├── Services/               networking, signing/pinning, cache, notifications
├── ViewModels/             one view model per tab, plus preview data
└── View/                   SwiftUI screens
VPSMonitorWidget/           WidgetKit extension
Config/                     xcconfig files (placeholders and local overrides)
server/                     reference backend (Python)
```

## Known limitations

- Only one server at a time.
- The **Notifications** toggle only asks for permission. Nothing sends alerts yet: there is no threshold logic and no push backend.
- History depends on the backend. The reference server keeps it only in memory.
- No unit tests yet.

## Contributing

Issues and pull requests are welcome. Please keep the app free of third-party dependencies unless there is a strong reason to add one.

## License

[MIT](LICENSE) © 2026 Mohsen Ebrahimizadeh
