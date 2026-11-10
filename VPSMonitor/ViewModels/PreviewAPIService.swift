import Foundation
import Combine

struct PreviewData {
    static let status = VPSStatusResponse(
        status: "ok",
        timestamp: Date(),
        systemSummary: VPSSystemSummary(cpuUsage: 32.5, memoryUsage: 58.1, diskUsage: 44.2, uptime: "3 days", load: [0.8, 0.9, 1.1]),
        services: [
            VPSServiceInfo(name: "nginx", status: "running", cpu: 2.3, memory: 45.6),
            VPSServiceInfo(name: "mysql", status: "running", cpu: 4.1, memory: 512.0)
        ]
    )

    static let history: [VPSHistoricalSample] = (0..<10).map { index in
        VPSHistoricalSample(timestamp: Date().addingTimeInterval(-Double(index) * 3600), cpuUsage: Double.random(in: 20...80), memoryUsage: Double.random(in: 30...90), diskUsage: Double.random(in: 10...70))
    }
}

final class PreviewAPIService: APIServiceProtocol {
    func fetchStatus() -> AnyPublisher<VPSStatusResponse, Error> {
        Just(PreviewData.status)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func fetchHistory() -> AnyPublisher<[VPSHistoricalSample], Error> {
        Just(PreviewData.history)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

final class InMemoryPersistence: DataPersistenceProtocol {
    private var statusValue: VPSStatusResponse?
    private var historyValue: [VPSHistoricalSample]

    init(status: VPSStatusResponse? = nil, history: [VPSHistoricalSample] = []) {
        self.statusValue = status
        self.historyValue = history
    }

    func saveStatus(_ response: VPSStatusResponse) {
        statusValue = response
    }

    func loadStatus() -> VPSStatusResponse? {
        statusValue
    }

    func saveHistory(_ samples: [VPSHistoricalSample]) {
        historyValue = samples
    }

    func loadHistory() -> [VPSHistoricalSample] {
        historyValue
    }

    func clearAll() {
        statusValue = nil
        historyValue = []
    }
}
