import Foundation

struct OperationProgress: Codable {
    let total: Int
    let processed: Int
    let statusMessage: String?

    init(total: Int, processed: Int, statusMessage: String? = nil) {
        self.total = total
        self.processed = processed
        self.statusMessage = statusMessage
    }
}
