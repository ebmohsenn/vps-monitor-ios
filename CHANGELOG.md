# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Security
- Reference server: refuses to start without `VPS_HMAC_SECRET` on a non-loopback bind (override with
  `VPS_ALLOW_UNSIGNED=1`) and prints a warning whenever it runs unsigned. The README now says plainly that an
  unsigned endpoint behind a reverse proxy is public.
- Reference server: a signature header with non-ASCII bytes raised an unhandled `TypeError` (dropped connection
  and a traceback per request). It is now rejected with 401.
- Reference server: connections time out after 10 seconds, a snapshot is reused for 2 seconds so requests cannot
  fan out into `systemctl` calls, unit names are passed after `--`, the history sampler survives a failed read,
  and the `Server` header no longer shows the Python version.

### Changed
- Settings accepts only `https://` endpoints. iOS blocks plain HTTP, so an `http://` endpoint could never work.
- The HTTP 401 message also points at the device clock: a clock more than 5 minutes off fails the signature check.
- The privacy manifests declare reason `CA92.1` for the app's own `UserDefaults` in addition to the App Group one.
- CI: the checkout action is pinned to a commit and no longer keeps credentials.

## [1.0.1] - 2026-11-27

### Added
- GitHub Actions workflow that builds the app and widget for the iOS Simulator and checks the
  reference server's syntax on every push and pull request.

### Fixed
- Dashboard and History wrapped the error banner and the content in a `Group` inside
  `NavigationView`, which turns them into separate navigation columns; after a failed request the
  data could end up hidden behind the error text, and `onAppear` ran once per child. They now use a
  `VStack`, and all tabs use stack navigation (no empty split view on wide screens).
- HTTP errors were reported as meaningless `URLError` codes; they now say which HTTP status the
  server returned (with a hint about the HMAC secret for 401).
- Requests could wait up to 7 days for connectivity, so the widget never fell back to its cache
  while offline. The total request time is now capped at 30 seconds.
- History rows showed only the date; they now show the date and time of each sample.
- `Config/Local.example.xcconfig` no longer contains a fake Team ID or a dummy HMAC secret that
  would be used as-is if the file was copied without editing.

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

[Unreleased]: https://github.com/Ebmohsennn/vps-monitor-ios/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/Ebmohsennn/vps-monitor-ios/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Ebmohsennn/vps-monitor-ios/releases/tag/v1.0.0
