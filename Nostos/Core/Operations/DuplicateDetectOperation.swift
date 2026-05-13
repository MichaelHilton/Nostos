import Foundation

@MainActor
final class DuplicateDetectOperation: Operation<Int> {
    private let container: ServiceContainer

    init(container: ServiceContainer) {
        self.container = container
        super.init { 0 }
    }

    override func execute() {
        cancel()

        isLoading = true
        error = nil
        result = nil

        _cancelTask = Task {
            do {
                let detector = container.duplicateDetector
                let count = try detector.detect()
                result = count
            } catch {
                self.error = error.localizedDescription
            }

            isLoading = false
        }
    }
}
