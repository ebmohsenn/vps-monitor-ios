import WidgetKit
import SwiftUI

struct VPSMonitorWidget: Widget {
    let kind: String = "VPSMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            VPSMonitorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("VPS Status")
        .description("Monitor your server status at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Provider: TimelineProvider {
    private let persistence = DataPersistence.shared

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), status: "online", cpu: 32.0, memory: 58.0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        Task {
            let entry = await loadEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let entry = await loadEntry()
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date().addingTimeInterval(600)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }

    private func loadEntry() async -> SimpleEntry {
        var currentStatus = persistence.loadStatus()

        do {
            let fresh = try await APIService.shared.fetchStatusAsync()
            persistence.saveStatus(fresh)
            currentStatus = fresh
        } catch {
            // Fallback to cached status if network fails
        }

        let summary = currentStatus?.systemSummary
        let statusText = currentStatus?.status ?? "unknown"
        return SimpleEntry(date: Date(), status: statusText, cpu: summary?.cpuUsage ?? 0, memory: summary?.memoryUsage ?? 0)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let status: String
    let cpu: Double
    let memory: Double

    var isOnline: Bool {
        switch status.lowercased() {
        case "ok", "online":
            return true
        default:
            return false
        }
    }
}

struct VPSMonitorWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VPS Status")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(entry.isOnline ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            
            HStack {
                Text("CPU:")
                    .font(.caption)
                Spacer()
                Text("\(entry.cpu, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Memory:")
                    .font(.caption)
                Spacer()
                Text("\(entry.memory, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct VPSMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        VPSMonitorWidget()
    }
}
