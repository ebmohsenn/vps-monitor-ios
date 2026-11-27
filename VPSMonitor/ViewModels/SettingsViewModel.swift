import Foundation

final class SettingsViewModel: ObservableObject {
    @Published var refreshInterval: TimeInterval
    @Published var notificationsEnabled: Bool
    @Published var autoRefreshEnabled: Bool
    @Published var serverEndpoint: String
    @Published var endpointValidationError: String?

    private let store: ServerStore
    private let notificationService = NotificationService.shared
    private let defaults = UserDefaults.standard
    /// The endpoint lives in the App Group defaults so the widget sees it too.
    private let sharedDefaults = AppConfig.sharedDefaults

    private enum Key {
        static let notificationsEnabled = "notifications_enabled"
    }

    static var defaultServerEndpoint: String { AppConfig.defaultStatusEndpoint }

    init(store: ServerStore = .shared) {
        self.store = store
        self.refreshInterval = store.refreshInterval
        self.autoRefreshEnabled = store.isAutoRefreshEnabled
        self.notificationsEnabled = defaults.bool(forKey: Key.notificationsEnabled)
        self.serverEndpoint = sharedDefaults.string(forKey: AppConfig.serverEndpointKey) ?? Self.defaultServerEndpoint
    }

    func updateRefreshInterval(_ value: TimeInterval) {
        refreshInterval = value
        store.refreshInterval = value
    }

    func toggleAutoRefresh(_ value: Bool) {
        autoRefreshEnabled = value
        store.isAutoRefreshEnabled = value
    }

    func toggleNotifications(_ value: Bool) {
        notificationsEnabled = value
        defaults.set(value, forKey: Key.notificationsEnabled)
        if value {
            notificationService.requestAuthorization()
        }
    }

    func clearCache() {
        store.clearCache()
    }

    func updateServerEndpoint(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https", url.host?.isEmpty == false else {
            endpointValidationError = "Enter an https:// URL. iOS blocks plain HTTP."
            return
        }

        guard trimmed != serverEndpoint else {
            endpointValidationError = nil
            return
        }

        endpointValidationError = nil
        serverEndpoint = trimmed
        sharedDefaults.set(trimmed, forKey: AppConfig.serverEndpointKey)

        store.clearCache()
        store.refreshStatus(force: true)
        store.loadHistory(force: true)
    }

    func resetServerEndpoint() {
        endpointValidationError = nil
        if serverEndpoint == Self.defaultServerEndpoint {
            return
        }
        serverEndpoint = Self.defaultServerEndpoint
        sharedDefaults.removeObject(forKey: AppConfig.serverEndpointKey)
        store.clearCache()
        store.refreshStatus(force: true)
        store.loadHistory(force: true)
    }

    static var preview: SettingsViewModel {
        let model = SettingsViewModel(store: ServerStore.preview())
        model.serverEndpoint = "https://vps.example.com/api/status"
        return model
    }
}
