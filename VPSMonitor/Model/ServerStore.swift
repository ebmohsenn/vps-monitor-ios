import Foundation
import Combine
import WidgetKit

/// Shared store coordinating status refreshes, history, and app-wide settings.
final class ServerStore: ObservableObject {
    static let shared = ServerStore()

    @Published private(set) var status: VPSStatusResponse?
    @Published private(set) var history: [VPSHistoricalSample]
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var isLoadingHistory: Bool = false
    @Published private(set) var lastError: Error?

    private let api: APIServiceProtocol
    private let persistence: DataPersistenceProtocol
    private let errorCenter: ErrorCenter
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: AnyCancellable?

    private enum StorageKey {
        static let refreshInterval = "refresh_interval"
        static let autoRefreshEnabled = "auto_refresh_enabled"
    }

    init(api: APIServiceProtocol = APIService.shared,
         persistence: DataPersistenceProtocol = DataPersistence.shared,
         errorCenter: ErrorCenter = .shared) {
        self.api = api
        self.persistence = persistence
        self.errorCenter = errorCenter
        self.history = persistence.loadHistory()
        self.status = persistence.loadStatus()

        scheduleAutoRefreshIfNeeded()
    }

    // MARK: - Data Loading

    func refreshStatus(force: Bool = false) {
        guard !isRefreshing || force else { return }

        isRefreshing = true
        lastError = nil

        api.fetchStatus()
            .sink { [weak self] completion in
                guard let self else { return }
                self.isRefreshing = false
                if case let .failure(error) = completion {
                    self.lastError = error
                    self.errorCenter.publish(error: error)
                } else {
                    self.errorCenter.clearCurrent()
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.status = response
                self.persistence.saveStatus(response)
                self.lastError = nil
                WidgetCenter.shared.reloadAllTimelines()
            }
            .store(in: &cancellables)
    }

    func loadHistory(force: Bool = false) {
        guard !isLoadingHistory || force else { return }

        isLoadingHistory = true
        lastError = nil

        api.fetchHistory()
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingHistory = false
                if case let .failure(error) = completion {
                    self.lastError = error
                    self.errorCenter.publish(error: error)
                }
            } receiveValue: { [weak self] samples in
                guard let self else { return }
                self.history = samples
                self.persistence.saveHistory(samples)
                self.lastError = nil
            }
            .store(in: &cancellables)
    }

    func clearCache() {
        persistence.clearAll()
        status = nil
        history = []
        lastError = nil
    }

    // MARK: - Auto Refresh

    var refreshInterval: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: StorageKey.refreshInterval)
            return stored > 0 ? stored : 300
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKey.refreshInterval)
            scheduleAutoRefreshIfNeeded()
        }
    }

    var isAutoRefreshEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: StorageKey.autoRefreshEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: StorageKey.autoRefreshEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKey.autoRefreshEnabled)
            scheduleAutoRefreshIfNeeded()
        }
    }

    func scheduleAutoRefreshIfNeeded() {
        refreshTimer?.cancel()
        guard isAutoRefreshEnabled else { return }

        refreshTimer = Timer.publish(every: refreshInterval, tolerance: refreshInterval * 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshStatus()
            }
    }
}

// Used by SwiftUI previews (kept in all configurations so Release builds compile).
extension ServerStore {
    static func preview() -> ServerStore {
        let store = ServerStore(api: PreviewAPIService(),
                                persistence: InMemoryPersistence(status: PreviewData.status, history: PreviewData.history),
                                errorCenter: ErrorCenter())
        store.status = PreviewData.status
        store.history = PreviewData.history
        return store
    }
}
