import Foundation

struct RefreshStepError: LocalizedError {
    var step: String
    var underlying: Error

    var errorDescription: String? {
        "Could not refresh \(step): \(underlying.localizedDescription)"
    }
}
