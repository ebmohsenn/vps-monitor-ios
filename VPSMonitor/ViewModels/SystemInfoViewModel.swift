import Foundation
import Combine

final class SystemInfoViewModel: ObservableObject {
    @Published private(set) var services: [VPSServiceInfo] = []
    @Published private(set) var systemSummary: VPSSystemSummary?

    private let store: ServerStore
    private var cancellables = Set<AnyCancellable>()

    init(store: ServerStore = .shared) {
        self.store = store
        bind()
    }

    private func bind() {
        store.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let status else { return }
                self?.services = status.services
                self?.systemSummary = status.systemSummary
            }
            .store(in: &cancellables)
    }

    static var preview: SystemInfoViewModel {
        SystemInfoViewModel(store: ServerStore.preview())
    }
}
