import Foundation

protocol DataPersistenceProtocol {
    func saveStatus(_ response: VPSStatusResponse)
    func loadStatus() -> VPSStatusResponse?
    func saveHistory(_ samples: [VPSHistoricalSample])
    func loadHistory() -> [VPSHistoricalSample]
    func clearAll()
}

final class DataPersistence: DataPersistenceProtocol {
    static let shared = DataPersistence()

    private let fileManager = FileManager.default
    private let statusURL: URL
    private let historyURL: URL

    private init() {
        let directory: URL
        if let appGroupID = AppConfig.appGroupID,
           let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            directory = container
        } else {
            directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        }
        statusURL = directory.appendingPathComponent("status.json", isDirectory: false)
        historyURL = directory.appendingPathComponent("history.json", isDirectory: false)
    }

    func saveStatus(_ response: VPSStatusResponse) {
        save(response, to: statusURL)
    }

    func loadStatus() -> VPSStatusResponse? {
        load(from: statusURL)
    }

    func saveHistory(_ samples: [VPSHistoricalSample]) {
        save(samples, to: historyURL)
    }

    func loadHistory() -> [VPSHistoricalSample] {
        load(from: historyURL) ?? []
    }

    func clearAll() {
        try? fileManager.removeItem(at: statusURL)
        try? fileManager.removeItem(at: historyURL)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Persistence save error: \(error)")
        }
    }

    private func load<T: Decodable>(from url: URL) -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Persistence load error: \(error)")
            return nil
        }
    }
}
