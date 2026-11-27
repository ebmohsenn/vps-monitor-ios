import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var viewModel: HistoryViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                if viewModel.samples.isEmpty {
                    emptyState
                } else {
                    List(viewModel.samples) { sample in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(sample.timestamp, style: .date) \(sample.timestamp, style: .time)")
                                .font(.headline)
                            Text("CPU: \(sample.cpuUsage, specifier: "%.1f")% • Memory: \(sample.memoryUsage, specifier: "%.1f")% • Disk: \(sample.diskUsage, specifier: "%.1f")%")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { viewModel.load() }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.load) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                if viewModel.samples.isEmpty {
                    viewModel.load()
                }
            }
            .overlay(alignment: .center) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No historical data yet")
                .font(.headline)
            Text("Pull to refresh after the first successful sync.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(HistoryViewModel.preview)
    }
}
