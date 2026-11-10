import Foundation

/// Build-time configuration shared by the app and the widget extension.
///
/// Values come from the target's Info.plist, which is filled in from
/// `Config/VPSMonitor.xcconfig` (and the optional, git-ignored
/// `Config/Local.xcconfig`). See the README for details.
enum AppConfig {
    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unresolved build setting (e.g. "$(VPS_HMAC_SECRET)") counts as missing.
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }

    /// App Group shared between the app and the widget (cache + settings).
    static var appGroupID: String? { infoValue("VPSAppGroupID") }

    /// UserDefaults shared with the widget when the App Group is available.
    static var sharedDefaults: UserDefaults {
        if let appGroupID, let defaults = UserDefaults(suiteName: appGroupID) {
            return defaults
        }
        return .standard
    }

    /// Default status endpoint used until the user sets one in Settings.
    static var defaultStatusEndpoint: String {
        infoValue("VPSStatusEndpoint") ?? "https://vps.example.com/api/status"
    }

    /// Shared secret for HMAC-SHA256 request signing. Empty disables signing.
    static var hmacSecret: String { infoValue("VPSHMACSecret") ?? "" }

    /// UserDefaults key holding the user-chosen status endpoint.
    static let serverEndpointKey = "server_endpoint"
}
