import Foundation
import Combine

final class HistoryViewModel: ObservableObject {
    @Published private(set) var samples: [VPSHistoricalSample] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let store: ServerStore
    private var cancellables = Set<AnyCancellable>()

    init(store: ServerStore = .shared) {
        self.store = store
        bind()
    }

    private func bind() {
        store.$history
            .receive(on: DispatchQueue.main)
            .assign(to: &$samples)

        store.$isLoadingHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        store.$lastError
            .map { $0?.localizedDescription }
            .removeDuplicates { $0 == $1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }

    func load() {
        store.loadHistory(force: true)
    }

    static var preview: HistoryViewModel {
        HistoryViewModel(store: ServerStore.preview())
    }
}
