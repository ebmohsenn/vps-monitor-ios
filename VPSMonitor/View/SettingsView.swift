import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    @State private var endpointInput: String = ""
    @FocusState private var isEndpointFocused: Bool

    private let refreshOptions: [TimeInterval] = [60, 120, 300, 600]

    var body: some View {
        NavigationView {
            Form {
                Section("Server") {
                    TextField("Status endpoint", text: $endpointInput)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($isEndpointFocused)
                        .onSubmit(applyEndpointChange)

                    if let message = viewModel.endpointValidationError {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    Button("Save Endpoint", action: applyEndpointChange)

                    Button("Reset to Default", role: .destructive) {
                        viewModel.resetServerEndpoint()
                        endpointInput = viewModel.serverEndpoint
                        isEndpointFocused = false
                    }
                }

                Section("Monitoring") {
                    Picker("Refresh Interval", selection: $viewModel.refreshInterval) {
                        ForEach(refreshOptions, id: \.self) { value in
                            Text(intervalDescription(for: value)).tag(value)
                        }
                    }
                    .onChange(of: viewModel.refreshInterval) { value in
                        viewModel.updateRefreshInterval(value)
                    }

                    Toggle(isOn: $viewModel.autoRefreshEnabled) {
                        Text("Auto Refresh")
                    }
                    .onChange(of: viewModel.autoRefreshEnabled) { value in
                        viewModel.toggleAutoRefresh(value)
                    }

                    Toggle(isOn: $viewModel.notificationsEnabled) {
                        Text("Notifications")
                    }
                    .onChange(of: viewModel.notificationsEnabled) { value in
                        viewModel.toggleNotifications(value)
                    }
                }

                Section("Data") {
                    Button(role: .destructive) {
                        viewModel.clearCache()
                    } label: {
                        Text("Clear Cached Data")
                    }
                }

                Section("About") {
                    infoRow(title: "App Version", value: Bundle.main.versionString)
                    infoRow(title: "Build", value: Bundle.main.buildString)
                    infoRow(title: "API Endpoint", value: viewModel.serverEndpoint)
                }
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(.stack)
        .onAppear {
            endpointInput = viewModel.serverEndpoint
        }
    }

    private func intervalDescription(for value: TimeInterval) -> String {
        if value >= 60 {
            return "Every \(Int(value / 60)) min"
        }
        return "Every \(Int(value)) sec"
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func applyEndpointChange() {
        viewModel.updateServerEndpoint(endpointInput)

        if viewModel.endpointValidationError == nil {
            endpointInput = viewModel.serverEndpoint
            isEndpointFocused = false
        } else {
            endpointInput = endpointInput.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

private extension Bundle {
    var versionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildString: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsViewModel.preview)
    }
}
