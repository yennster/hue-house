import Foundation

enum HueAppError: LocalizedError {
    case missingBridgeHost
    case invalidBridgeHost(String)
    case missingApplicationKey
    case httpStatus(Int)
    case bridgeRejected(String)

    var errorDescription: String? {
        switch self {
        case .missingBridgeHost:
            "Enter or discover a Hue Bridge IP address first."
        case .invalidBridgeHost(let host):
            "The bridge address \u{201C}\(host)\u{201D} is not valid."
        case .missingApplicationKey:
            "This Mac is not paired with the Hue Bridge yet."
        case .httpStatus(let status):
            "The Hue Bridge returned HTTP \(status)."
        case .bridgeRejected(let message):
            HueAppError.formatted(message)
        }
    }

    static func message(for error: Error, fallback: String) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return formatted(description)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "\(fallback)\n\nNetwork error: \(formatted(nsError.localizedDescription))"
        }

        return "\(fallback)\n\n\(formatted(error.localizedDescription))"
    }

    /// Detail text only — without the operation fallback prefix. Use when the
    /// fallback is shown separately as the alert title.
    static func detail(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return formatted(description)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return formatted(nsError.localizedDescription)
        }

        return formatted(error.localizedDescription)
    }

    /// Capitalizes the first letter and ensures the message ends with terminal punctuation.
    static func formatted(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        var result = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        if let last = result.last, !".!?".contains(last) {
            result.append(".")
        }
        return result
    }
}
