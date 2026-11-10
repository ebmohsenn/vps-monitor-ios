import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var errorCenter: ErrorCenter

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.doc.horizontal")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SystemInfoView()
                .tabItem {
                    Label("System", systemImage: "server.rack")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .alert(item: $errorCenter.activeError) { appError in
            Alert(title: Text("Error"),
                  message: Text(appError.message),
                  dismissButton: .default(Text("OK")) {
                      errorCenter.clearCurrent()
                  })
        }
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
            .environmentObject(DashboardViewModel.preview)
            .environmentObject(HistoryViewModel.preview)
            .environmentObject(SystemInfoViewModel.preview)
            .environmentObject(SettingsViewModel.preview)
    }
}
