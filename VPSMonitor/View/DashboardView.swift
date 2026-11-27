import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                if let status = viewModel.status {
                    List {
                        Section("System Summary") {
                            summaryRow(title: "CPU", value: status.systemSummary.cpuUsage, unit: "%")
                            summaryRow(title: "Memory", value: status.systemSummary.memoryUsage, unit: "%")
                            summaryRow(title: "Disk", value: status.systemSummary.diskUsage, unit: "%")
                            infoRow(title: "Uptime", value: status.systemSummary.uptime)
                            infoRow(title: "Load", value: status.systemSummary.load.map { String(format: "%.2f", $0) }.joined(separator: ", "))
                        }

                        Section("Services") {
                            ForEach(status.services) { service in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(service.name.capitalized)
                                            .font(.headline)
                                        Text("CPU: \(service.cpu, specifier: "%.1f") • Memory: \(service.memory, specifier: "%.1f")")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    statusBadge(for: service.status)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        viewModel.refresh()
                    }
                } else if viewModel.isLoading {
                    ProgressView("Loading…")
                } else {
                    emptyState
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                if viewModel.status == nil {
                    viewModel.refresh()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func summaryRow(title: String, value: Double, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value, specifier: "%.1f") \(unit)")
                .bold()
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func statusBadge(for status: String) -> some View {
        Text(status.capitalized)
            .font(.caption)
            .padding(6)
            .background(status == "running" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundColor(status == "running" ? .green : .red)
            .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Data Available")
                .font(.title3)
            Button("Retry") {
                viewModel.refresh()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(DashboardViewModel.preview)
    }
}
