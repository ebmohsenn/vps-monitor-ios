import Foundation
import SwiftUI

/// Centralized presenter for surfaced errors so we only show one alert at a time.
final class ErrorCenter: ObservableObject {
    struct AppError: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    @Published var activeError: AppError?

    static let shared = ErrorCenter()

    private var lastPresentedMessage: String?

    func publish(error: Error) {
        publish(message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }

    func publish(message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if activeError?.message == trimmed { return }
        if lastPresentedMessage == trimmed, activeError != nil { return }

        lastPresentedMessage = trimmed
        DispatchQueue.main.async {
            self.activeError = AppError(message: trimmed)
        }
    }

    func clearCurrent() {
        DispatchQueue.main.async {
            self.activeError = nil
            self.lastPresentedMessage = nil
        }
    }
}
