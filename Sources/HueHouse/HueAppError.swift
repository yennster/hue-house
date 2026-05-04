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
            "The bridge address \"\(host)\" is not valid."
        case .missingApplicationKey:
            "This Mac is not paired with the Hue Bridge yet."
        case .httpStatus(let status):
            "The Hue Bridge returned HTTP \(status)."
        case .bridgeRejected(let message):
            message
        }
    }

    static func message(for error: Error, fallback: String) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "\(fallback)\n\nNetwork error: \(nsError.localizedDescription)"
        }

        return "\(fallback)\n\n\(error.localizedDescription)"
    }
}
