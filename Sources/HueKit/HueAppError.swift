import Foundation

public enum HueAppError: LocalizedError {
    case missingBridgeHost
    case invalidBridgeHost(String)
    case missingApplicationKey
    case httpStatus(Int)
    case bridgeRejected(String)
    case partialGradient(failed: [String], total: Int, underlying: Error?, previouslySkipped: Int)

    public var errorDescription: String? {
        switch self {
        case .missingBridgeHost:
            "Enter or discover a Hue Bridge IP address first."
        case .invalidBridgeHost(let host):
            "The bridge address \u{201C}\(host)\u{201D} is not valid."
        case .missingApplicationKey:
            "This Mac is not paired with the Hue Bridge yet."
        case .partialGradient(let failed, let total, let underlying, let previouslySkipped):
            HueAppError.partialGradientMessage(
                failed: failed,
                total: total,
                underlying: underlying,
                previouslySkipped: previouslySkipped
            )
        case .httpStatus(let status):
            switch status {
            case 429:
                "The Hue Bridge is rate-limiting requests. Try again in a moment."
            case 401, 403:
                "The Hue Bridge rejected this app's credentials. Try pairing again."
            case 500..<600:
                "The Hue Bridge ran into an internal error (HTTP \(status))."
            default:
                "The Hue Bridge returned HTTP \(status)."
            }
        case .bridgeRejected(let message):
            HueAppError.formatted(message)
        }
    }

    public static func message(for error: Error, fallback: String) -> String {
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
    public static func detail(for error: Error) -> String {
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

    private static func partialGradientMessage(
        failed: [String],
        total: Int,
        underlying _: Error?,
        previouslySkipped: Int
    ) -> String {
        let succeeded = total - failed.count - previouslySkipped
        let names: String = {
            switch failed.count {
            case 0: return ""
            case 1: return failed[0]
            case 2: return "\(failed[0]) and \(failed[1])"
            case 3...4: return failed.dropLast().joined(separator: ", ") + ", and \(failed.last!)"
            default:
                let first = failed.prefix(3).joined(separator: ", ")
                return "\(first), and \(failed.count - 3) more"
            }
        }()

        if names.isEmpty {
            return "Updated \(succeeded) of \(total) lights."
        }
        return "Updated \(succeeded) of \(total). Skipping \(names) this session."
    }

    /// Capitalizes the first letter and ensures the message ends with terminal punctuation.
    public static func formatted(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        var result = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        if let last = result.last, !".!?".contains(last) {
            result.append(".")
        }
        return result
    }
}
