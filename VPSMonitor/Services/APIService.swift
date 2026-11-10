import Foundation
import Combine
import CryptoKit

protocol APIServiceProtocol {
    func fetchStatus() -> AnyPublisher<VPSStatusResponse, Error>
    func fetchHistory() -> AnyPublisher<[VPSHistoricalSample], Error>
}

final class APIService: NSObject, APIServiceProtocol, URLSessionDelegate {
    static let shared = APIService()

    private lazy var session: URLSession = {
        if let customSession {
            return customSession
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    private let jsonDecoder: JSONDecoder
    private let customSession: URLSession?
    private let baseURLOverride: URL?

    private override init() {
        self.customSession = nil
        jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        baseURLOverride = nil
        super.init()
    }

    init(session: URLSession? = nil,
         baseURL: URL? = nil,
         decoder: JSONDecoder? = nil) {
        self.customSession = session
        self.jsonDecoder = decoder ?? {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
        self.baseURLOverride = baseURL
        super.init()
    }

    func fetchStatus() -> AnyPublisher<VPSStatusResponse, Error> {
        authorizedRequest(url: currentStatusURL())
    }

    /// History lives at `<status endpoint>/history`.
    func fetchHistory() -> AnyPublisher<[VPSHistoricalSample], Error> {
        authorizedRequest(url: currentStatusURL().appendingPathComponent("history"))
    }

    private func currentStatusURL() -> URL {
        if let override = baseURLOverride {
            return override
        }

        if let stored = AppConfig.sharedDefaults.string(forKey: AppConfig.serverEndpointKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty,
           let url = URL(string: stored),
           let scheme = url.scheme?.lowercased(),
           scheme == "https" || scheme == "http" {
            return url
        }

        return URL(string: AppConfig.defaultStatusEndpoint)!
    }

    private func authorizedRequest<T: Decodable>(url: URL) -> AnyPublisher<T, Error> {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Optional HMAC-SHA256 signature over "GET" + absolute URL + timestamp.
        if let key = Crypto.shared.hmacKey {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let payload = "GET\(url.absoluteString)\(timestamp)"
            let signature = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
            request.addValue(timestamp, forHTTPHeaderField: "X-Request-Timestamp")
            request.addValue(Data(signature).base64EncodedString(), forHTTPHeaderField: "X-Request-Signature")
        }

        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard 200..<300 ~= httpResponse.statusCode else {
                    throw URLError(.init(rawValue: httpResponse.statusCode))
                }
                return data
            }
            .decode(type: T.self, decoder: jsonDecoder)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    /// Certificate pinning: only active when `pinned_cert.der` is bundled.
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let pinned = Crypto.shared.pinnedCertificateData
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // The leaf certificate must match the pinned one byte-for-byte. This also
        // allows a self-signed certificate on your own server.
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if SecCertificateCopyData(leaf) as Data == pinned {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

extension APIService {
    func fetchStatusAsync() async throws -> VPSStatusResponse {
        for try await value in fetchStatus().values {
            return value
        }
        throw URLError(.badServerResponse)
    }
}
