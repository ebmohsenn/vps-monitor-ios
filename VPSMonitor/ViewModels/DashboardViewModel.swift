import Foundation
import Combine

final class DashboardViewModel: ObservableObject {
    @Published private(set) var status: VPSStatusResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let store: ServerStore
    private var cancellables = Set<AnyCancellable>()

    init(store: ServerStore = .shared) {
        self.store = store
        bind()
    }

    private func bind() {
        store.$status
            .receive(on: DispatchQueue.main)
            .assign(to: &$status)

        store.$isRefreshing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        store.$lastError
            .map { $0?.localizedDescription }
            .removeDuplicates { $0 == $1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }

    func refresh() {
        store.refreshStatus(force: true)
    }

    static var preview: DashboardViewModel {
        DashboardViewModel(store: ServerStore.preview())
    }
}
