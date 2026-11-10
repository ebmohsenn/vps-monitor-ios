import Foundation

struct VPSSystemSummary: Codable {
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    let uptime: String
    let load: [Double]
}

struct VPSServiceInfo: Codable, Identifiable {
    let name: String
    let status: String
    let cpu: Double
    let memory: Double

    var id: String { name }
}

struct VPSStatusResponse: Codable {
    let status: String
    let timestamp: Date
    let systemSummary: VPSSystemSummary
    let services: [VPSServiceInfo]
}

struct VPSHistoricalSample: Identifiable, Codable {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double

    var id: Date { timestamp }
}
