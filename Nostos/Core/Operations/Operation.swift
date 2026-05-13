import Foundation

@MainActor
class Operation<Result>: ObservableObject {
    typealias AsyncWork = () async throws -> Result

    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var result: Result?
    @Published var progress: OperationProgress?

    var _cancelTask: Task<Void, Never>?
    private let work: AsyncWork

    init(work: @escaping AsyncWork) {
        self.work = work
    }

    func execute() {
        _cancelTask?.cancel()
        _cancelTask = Task {
            isLoading = true
            error = nil
            result = nil
            progress = nil

            do {
                result = try await work()
            } catch {
                self.error = error.localizedDescription
            }

            isLoading = false
        }
    }

    func cancel() {
        _cancelTask?.cancel()
        _cancelTask = nil
        isLoading = false
    }

    func updateProgress(_ progress: OperationProgress) {
        Task { @MainActor in
            self.progress = progress
        }
    }
}
