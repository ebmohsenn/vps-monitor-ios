import SwiftUI

enum AppComposer {
    static func makeRootView() -> some View {
        let store = ServerStore.shared
        store.refreshStatus(force: true)
        store.loadHistory(force: true)
        store.scheduleAutoRefreshIfNeeded()

        let dashboardViewModel = DashboardViewModel(store: store)
        let historyViewModel = HistoryViewModel(store: store)
        let systemInfoViewModel = SystemInfoViewModel(store: store)
        let settingsViewModel = SettingsViewModel(store: store)
        let errorCenter = ErrorCenter.shared

        return RootTabView()
            .environmentObject(dashboardViewModel)
            .environmentObject(historyViewModel)
            .environmentObject(systemInfoViewModel)
            .environmentObject(settingsViewModel)
            .environmentObject(errorCenter)
    }
}
