import Foundation
import CryptoKit

final class Crypto {
    static let shared = Crypto()

    /// HMAC key used to sign requests, or `nil` when no secret is configured.
    let hmacKey: SymmetricKey?

    /// DER-encoded leaf certificate to pin, or `nil` to use normal TLS validation.
    /// Add a file named `pinned_cert.der` to the app and widget targets to enable pinning.
    let pinnedCertificateData: Data?

    private init() {
        let secret = AppConfig.hmacSecret
        hmacKey = secret.isEmpty ? nil : SymmetricKey(data: Data(secret.utf8))

        if let url = Bundle.main.url(forResource: "pinned_cert", withExtension: "der"),
           let data = try? Data(contentsOf: url),
           !data.isEmpty {
            pinnedCertificateData = data
        } else {
            pinnedCertificateData = nil
        }
    }
}
