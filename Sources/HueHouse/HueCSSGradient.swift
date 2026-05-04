import Foundation

enum HueCSSGradientParseError: LocalizedError {
    case empty
    case noColors

    var errorDescription: String? {
        switch self {
        case .empty:
            "Paste a CSS gradient like \u{201C}linear-gradient(90deg, #ff0080, #ffd700)\u{201D}."
        case .noColors:
            "Couldn\u{2019}t find any colors in that gradient string."
        }
    }
}

/// Parses CSS `linear-gradient` / `radial-gradient` / `conic-gradient` strings
/// into the bridge's RGB→xy gradient color format. Direction tokens (`90deg`,
/// `to right`, etc.) and stop positions (`50%`) are accepted but discarded —
/// Hue's gradient API only consumes the ordered color list.
enum HueCSSGradient {
    static func parse(_ input: String) throws -> [HueGradientColor] {
        let cleaned = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ";"))

        guard !cleaned.isEmpty else { throw HueCSSGradientParseError.empty }

        let body: String
        if let openParen = cleaned.firstIndex(of: "("),
           let closeParen = cleaned.lastIndex(of: ")"),
           openParen < closeParen {
            body = String(cleaned[cleaned.index(after: openParen)..<closeParen])
        } else {
            body = cleaned
        }

        let parts = splitTopLevelCommas(body)
        var colors: [HueGradientColor] = []
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let color = parseColorStop(trimmed) {
                colors.append(color)
            }
            // First token may be the direction ("90deg", "to right") — skipped silently.
        }

        guard !colors.isEmpty else { throw HueCSSGradientParseError.noColors }
        return colors
    }

    /// Splits on commas that aren't inside parentheses (so `rgba(1, 2, 3, 1)`
    /// stays intact while still separating top-level color stops).
    private static func splitTopLevelCommas(_ source: String) -> [String] {
        var parts: [String] = []
        var depth = 0
        var current = ""
        for character in source {
            switch character {
            case "(":
                depth += 1
                current.append(character)
            case ")":
                depth -= 1
                current.append(character)
            case "," where depth == 0:
                parts.append(current)
                current = ""
            default:
                current.append(character)
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    private static func parseColorStop(_ stop: String) -> HueGradientColor? {
        let lower = stop.lowercased()

        if lower.hasPrefix("rgba(") || lower.hasPrefix("rgb(") {
            guard let openParen = stop.firstIndex(of: "("),
                  let closeParen = stop.firstIndex(of: ")"),
                  openParen < closeParen else { return nil }
            let inner = stop[stop.index(after: openParen)..<closeParen]
            let raw = inner.split(whereSeparator: { $0 == "," || $0 == "/" || $0 == " " })
            let comps = raw.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard comps.count >= 3,
                  let r = parseChannel(comps[0]),
                  let g = parseChannel(comps[1]),
                  let b = parseChannel(comps[2])
            else { return nil }
            return HueGradientColor.fromSRGB(red: r, green: g, blue: b)
        }

        // Strip any trailing position (e.g. "#ff0000 50%").
        let firstToken = stop.split(separator: " ").first.map(String.init) ?? stop

        if firstToken.hasPrefix("#") {
            return parseHex(String(firstToken.dropFirst()))
        }

        if let named = namedColor(firstToken.lowercased()) {
            return named
        }

        return nil
    }

    /// Channel value can be 0–255, 0–1, or "<n>%". Hex components are handled separately.
    private static func parseChannel(_ raw: String) -> Double? {
        if raw.hasSuffix("%") {
            guard let value = Double(raw.dropLast()) else { return nil }
            return min(1, max(0, value / 100))
        }
        guard let value = Double(raw) else { return nil }
        if value > 1 {
            return min(1, value / 255)
        }
        return min(1, max(0, value))
    }

    private static func parseHex(_ hex: String) -> HueGradientColor? {
        var s = hex
        if s.count == 3 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        guard s.count >= 6, let value = UInt32(s.prefix(6), radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return HueGradientColor.fromSRGB(red: r, green: g, blue: b)
    }

    private static let namedColors: [String: (Double, Double, Double)] = [
        "black": (0, 0, 0),
        "white": (1, 1, 1),
        "red": (1, 0, 0),
        "lime": (0, 1, 0),
        "green": (0, 0.5, 0),
        "blue": (0, 0, 1),
        "yellow": (1, 1, 0),
        "cyan": (0, 1, 1),
        "aqua": (0, 1, 1),
        "magenta": (1, 0, 1),
        "fuchsia": (1, 0, 1),
        "orange": (1, 0.647, 0),
        "pink": (1, 0.753, 0.796),
        "hotpink": (1, 0.412, 0.706),
        "purple": (0.5, 0, 0.5),
        "violet": (0.933, 0.51, 0.933),
        "indigo": (0.294, 0, 0.510),
        "teal": (0, 0.5, 0.5),
        "gold": (1, 0.843, 0),
        "coral": (1, 0.498, 0.314)
    ]

    private static func namedColor(_ name: String) -> HueGradientColor? {
        guard let rgb = namedColors[name] else { return nil }
        return HueGradientColor.fromSRGB(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}
