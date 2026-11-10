# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-10

First open-source release, extracted from a private app (developed September 2025).

### Added
- SwiftUI app with four tabs: Dashboard, History, System, Settings.
- Home-screen widget (small and medium) showing status, CPU and memory.
- Configurable status endpoint (in Settings) with build-time default via `Config/VPSMonitor.xcconfig`.
- Optional HMAC-SHA256 request signing and optional certificate pinning.
- On-disk cache in a shared App Group so the widget can show the last known state.
- Reference backend `server/vps_status_server.py` (Python standard library only).

### Changed
- Project and targets renamed to `VPSMonitor` / `VPSMonitorWidgetExtension`; bundle IDs,
  team ID and App Group are now placeholders set in one xcconfig file.
- The endpoint setting is stored in the App Group so the widget uses the same server as the app.
- The app asks the widget to reload after each successful refresh.
- CocoaPods removed: none of the listed pods were imported by the app.

### Fixed
- Certificate pinning compared against a placeholder file, which made every HTTPS request fail;
  pinning is now opt-in and only active when a real certificate is bundled.
- Cached data could not be read back (date decoding strategy mismatch).
- Release builds failed because preview helpers were only compiled in Debug.
- Service rows used a new random identity on every render.
