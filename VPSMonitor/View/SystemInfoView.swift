import SwiftUI

struct SystemInfoView: View {
    @EnvironmentObject private var systemViewModel: SystemInfoViewModel
    @EnvironmentObject private var dashboardViewModel: DashboardViewModel

    var body: some View {
        NavigationView {
            List {
                if let summary = systemViewModel.systemSummary {
                    Section("Summary") {
                        summaryRow(title: "CPU", value: String(format: "%.1f%%", summary.cpuUsage))
                        summaryRow(title: "Memory", value: String(format: "%.1f%%", summary.memoryUsage))
                        summaryRow(title: "Disk", value: String(format: "%.1f%%", summary.diskUsage))
                        summaryRow(title: "Uptime", value: summary.uptime)
                    }
                }

                Section("Services") {
                    if systemViewModel.services.isEmpty {
                        Text("No services tracked")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(systemViewModel.services) { service in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(service.name.capitalized)
                                        .font(.headline)
                                    Spacer()
                                    statusBadge(for: service.status)
                                }
                                Text("CPU: \(service.cpu, specifier: "%.1f")% • Memory: \(service.memory, specifier: "%.1f")MB")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("System Info")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: dashboardViewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func statusBadge(for status: String) -> some View {
        Text(status.capitalized)
            .font(.caption2)
            .padding(4)
            .background(status == "running" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundColor(status == "running" ? .green : .red)
            .clipShape(Capsule())
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

struct SystemInfoView_Previews: PreviewProvider {
    static var previews: some View {
        SystemInfoView()
            .environmentObject(SystemInfoViewModel.preview)
            .environmentObject(DashboardViewModel.preview)
    }
}
