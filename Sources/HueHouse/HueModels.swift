import Foundation

struct HueBridgeDiscovery: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let internalIPAddress: String

    init(id: String, internalIPAddress: String) {
        self.id = id
        self.internalIPAddress = internalIPAddress
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case internalIPAddress = "internalipaddress"
    }
}

struct HueResourceResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let errors: [HueResponseError]
    let data: [T]

    func throwIfNeeded() throws {
        guard !errors.isEmpty else { return }
        throw HueAppError.bridgeRejected(
            errors.map(\.description).joined(separator: "\n")
        )
    }
}

struct HueResponseError: Decodable, Sendable {
    let description: String
}

struct HueUpdateResult: Decodable, Sendable {
    let rid: String?
    let rtype: String?
}

struct HueCreateUserEntry: Decodable, Sendable {
    let success: HueCreateUserSuccess?
    let error: HueCreateUserError?
}

struct HueCreateUserSuccess: Decodable, Sendable {
    let username: String
    let clientkey: String?
}

struct HueCreateUserError: Decodable, Sendable {
    let type: Int?
    let address: String?
    let description: String
}

struct HueLight: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let type: String?
    let owner: HueResourceReference?
    var metadata: HueMetadata
    var on: HueOnState?
    var dimming: HueDimming?
    var colorTemperature: HueColorTemperature?
    var color: HueColor?
    var gradient: HueGradient?

    var name: String {
        metadata.name
    }

    var isOn: Bool {
        on?.on ?? false
    }

    var supportsDimming: Bool {
        dimming != nil
    }

    var supportsColorTemperature: Bool {
        colorTemperature != nil
    }

    var supportsColor: Bool {
        color != nil
    }

    var supportsGradient: Bool {
        (gradient?.pointsCapable ?? 0) > 1 || (gradient?.points.count ?? 0) > 1
    }

    var brightness: Double {
        dimming?.brightness ?? 100
    }

    var detailLine: String {
        var pieces: [String] = []
        if supportsDimming {
            pieces.append("\(Int(brightness.rounded()))%")
        }
        if supportsGradient {
            pieces.append("gradient")
        } else if supportsColor {
            pieces.append("color")
        } else if supportsColorTemperature {
            pieces.append("white ambience")
        } else {
            pieces.append("on/off")
        }
        return pieces.joined(separator: " · ")
    }

    func canApply(_ preset: HuePreset) -> Bool {
        switch preset.kind {
        case .none:
            return false
        case .temperature:
            return supportsColorTemperature || supportsColor
        case .xy:
            return supportsColor
        }
    }
}

struct HueLightGroup: Decodable, Identifiable, Equatable, Sendable {
    static let allLightsID = "__all_lights__"

    let id: String
    let type: String
    let metadata: HueMetadata
    let children: [HueResourceReference]
    let services: [HueResourceReference]

    init(
        id: String,
        type: String,
        metadata: HueMetadata,
        children: [HueResourceReference] = [],
        services: [HueResourceReference] = []
    ) {
        self.id = id
        self.type = type
        self.metadata = metadata
        self.children = children
        self.services = services
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        metadata = try container.decode(HueMetadata.self, forKey: .metadata)
        children = try container.decodeIfPresent([HueResourceReference].self, forKey: .children) ?? []
        services = try container.decodeIfPresent([HueResourceReference].self, forKey: .services) ?? []
    }

    static var allLights: HueLightGroup {
        HueLightGroup(
            id: allLightsID,
            type: "home",
            metadata: HueMetadata(name: "All Lights", archetype: "home")
        )
    }

    var name: String {
        metadata.name
    }

    var kindTitle: String {
        switch type {
        case "room":
            "Room"
        case "zone":
            "Zone"
        default:
            "Home"
        }
    }

    var systemImage: String {
        switch type {
        case "room":
            "door.left.hand.open"
        case "zone":
            "square.3.layers.3d.down.right"
        default:
            "house"
        }
    }

    func contains(_ light: HueLight) -> Bool {
        guard id != Self.allLightsID else { return true }

        return (children + services).contains { reference in
            if reference.rtype == "light", reference.rid == light.id {
                return true
            }

            if reference.rtype == "device", reference.rid == light.owner?.rid {
                return true
            }

            return false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case metadata
        case children
        case services
    }
}

struct HueResourceReference: Decodable, Equatable, Sendable {
    let rid: String
    let rtype: String
}

struct HueMetadata: Decodable, Equatable, Sendable {
    let name: String
    let archetype: String?
}

struct HueOnState: Decodable, Equatable, Sendable {
    let on: Bool
}

struct HueDimming: Decodable, Equatable, Sendable {
    let brightness: Double
    let minDimLevel: Double?
}

struct HueColorTemperature: Decodable, Equatable, Sendable {
    let mirek: Int?
    let mirekValid: Bool?
}

struct HueColor: Decodable, Equatable, Sendable {
    let xy: HueXY?
}

struct HueXY: Decodable, Equatable, Sendable {
    let x: Double
    let y: Double
}

struct HueGradient: Decodable, Equatable, Sendable {
    let points: [HueGradientPoint]
    let mode: String?
    let pointsCapable: Int?
    let pixelCount: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points = try container.decodeIfPresent([HueGradientPoint].self, forKey: .points) ?? []
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        pointsCapable = try container.decodeIfPresent(Int.self, forKey: .pointsCapable)
        pixelCount = try container.decodeIfPresent(Int.self, forKey: .pixelCount)
    }

    private enum CodingKeys: String, CodingKey {
        case points
        case mode
        case pointsCapable
        case pixelCount
    }
}

struct HueGradientPoint: Decodable, Equatable, Sendable {
    let xy: HueXY
}

struct HueGradientColor: Hashable, Sendable, Codable {
    let x: Double
    let y: Double
    let red: Double
    let green: Double
    let blue: Double

    var xyObject: [String: [String: Double]] {
        ["xy": ["x": x, "y": y]]
    }

    /// Builds a gradient color from sRGB components in the 0…1 range. Performs
    /// gamma decoding and converts to CIE 1931 xy via the standard sRGB → XYZ
    /// matrix (D65 reference white) so the bridge interprets the chromaticity
    /// the same way a CSS browser does.
    static func fromSRGB(red r: Double, green g: Double, blue b: Double) -> HueGradientColor {
        func linearize(_ component: Double) -> Double {
            let c = min(1, max(0, component))
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let lr = linearize(r)
        let lg = linearize(g)
        let lb = linearize(b)

        let xValue = lr * 0.4124564 + lg * 0.3575761 + lb * 0.1804375
        let yValue = lr * 0.2126729 + lg * 0.7151522 + lb * 0.0721750
        let zValue = lr * 0.0193339 + lg * 0.1191920 + lb * 0.9503041
        let sum = xValue + yValue + zValue

        let x = sum > 0 ? xValue / sum : 0.3127  // D65 white point
        let y = sum > 0 ? yValue / sum : 0.3290

        return HueGradientColor(
            x: x,
            y: y,
            red: min(1, max(0, r)),
            green: min(1, max(0, g)),
            blue: min(1, max(0, b))
        )
    }

    /// Inverse of `fromSRGB`: converts the bridge's CIE 1931 xy chromaticity back
    /// into a display-ready sRGB triple. Useful for painting an in-app preview
    /// of the bulb's current color. `relativeBrightness` (0…1) controls Y; pass
    /// the cached dimming value if you want the swatch to reflect dimming too.
    static func sRGB(fromXY x: Double, y: Double, relativeBrightness: Double = 1.0) -> (red: Double, green: Double, blue: Double) {
        let safeY = max(0.0001, y)
        let Y = max(0, min(1, relativeBrightness))
        let X = (Y / safeY) * x
        let Z = (Y / safeY) * (1 - x - y)

        // sRGB → XYZ (D65) inverted.
        let lr =  3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z
        let lg = -0.9692660 * X + 1.8760108 * Y + 0.0415560 * Z
        let lb =  0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z

        func gammaEncode(_ value: Double) -> Double {
            let v = max(0, value)
            if v <= 0.0031308 {
                return 12.92 * v
            }
            return 1.055 * pow(v, 1.0 / 2.4) - 0.055
        }

        return (
            red:   min(1, max(0, gammaEncode(lr))),
            green: min(1, max(0, gammaEncode(lg))),
            blue:  min(1, max(0, gammaEncode(lb)))
        )
    }

    static func mix(_ start: HueGradientColor, _ end: HueGradientColor, amount: Double) -> HueGradientColor {
        let t = min(1, max(0, amount))
        return HueGradientColor(
            x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t,
            red: start.red + (end.red - start.red) * t,
            green: start.green + (end.green - start.green) * t,
            blue: start.blue + (end.blue - start.blue) * t
        )
    }
}

struct HueGradientPreset: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let brightness: Double
    let fallbackMirek: Int
    let colors: [HueGradientColor]
    let isCustom: Bool

    init(
        id: String,
        title: String,
        subtitle: String,
        brightness: Double,
        fallbackMirek: Int,
        colors: [HueGradientColor],
        isCustom: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.brightness = brightness
        self.fallbackMirek = fallbackMirek
        self.colors = colors
        self.isCustom = isCustom
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, brightness, fallbackMirek, colors, isCustom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decode(String.self, forKey: .subtitle)
        brightness = try c.decode(Double.self, forKey: .brightness)
        fallbackMirek = try c.decode(Int.self, forKey: .fallbackMirek)
        colors = try c.decode([HueGradientColor].self, forKey: .colors)
        isCustom = try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }

    static let all: [HueGradientPreset] = [
        HueGradientPreset(
            id: "aurora",
            title: "Aurora Veil",
            subtitle: "mint, teal, violet",
            brightness: 82,
            fallbackMirek: 280,
            colors: [
                HueGradientColor(x: 0.17, y: 0.39, red: 0.36, green: 0.95, blue: 0.78),
                HueGradientColor(x: 0.15, y: 0.18, red: 0.20, green: 0.70, blue: 1.00),
                HueGradientColor(x: 0.28, y: 0.12, red: 0.66, green: 0.39, blue: 1.00)
            ]
        ),
        HueGradientPreset(
            id: "solstice",
            title: "Solstice Glass",
            subtitle: "rose, peach, gold",
            brightness: 78,
            fallbackMirek: 340,
            colors: [
                HueGradientColor(x: 0.53, y: 0.25, red: 1.00, green: 0.34, blue: 0.56),
                HueGradientColor(x: 0.46, y: 0.39, red: 1.00, green: 0.62, blue: 0.36),
                HueGradientColor(x: 0.51, y: 0.45, red: 1.00, green: 0.82, blue: 0.30)
            ]
        ),
        HueGradientPreset(
            id: "lagoon",
            title: "Midnight Lagoon",
            subtitle: "cyan, blue, indigo",
            brightness: 70,
            fallbackMirek: 230,
            colors: [
                HueGradientColor(x: 0.15, y: 0.22, red: 0.20, green: 0.88, blue: 1.00),
                HueGradientColor(x: 0.16, y: 0.08, red: 0.12, green: 0.32, blue: 1.00),
                HueGradientColor(x: 0.22, y: 0.08, red: 0.38, green: 0.24, blue: 0.95)
            ]
        ),
        HueGradientPreset(
            id: "garden",
            title: "Glass Garden",
            subtitle: "lime, jade, sky",
            brightness: 76,
            fallbackMirek: 300,
            colors: [
                HueGradientColor(x: 0.35, y: 0.55, red: 0.66, green: 0.96, blue: 0.35),
                HueGradientColor(x: 0.20, y: 0.47, red: 0.18, green: 0.84, blue: 0.58),
                HueGradientColor(x: 0.16, y: 0.22, red: 0.28, green: 0.78, blue: 1.00)
            ]
        ),
        HueGradientPreset(
            id: "ember",
            title: "Ember Bloom",
            subtitle: "coral, ruby, violet",
            brightness: 74,
            fallbackMirek: 370,
            colors: [
                HueGradientColor(x: 0.58, y: 0.36, red: 1.00, green: 0.42, blue: 0.24),
                HueGradientColor(x: 0.67, y: 0.31, red: 1.00, green: 0.10, blue: 0.20),
                HueGradientColor(x: 0.31, y: 0.13, red: 0.73, green: 0.28, blue: 1.00)
            ]
        ),
        HueGradientPreset(
            id: "opal",
            title: "Opal Mist",
            subtitle: "lavender, pearl, aqua",
            brightness: 88,
            fallbackMirek: 250,
            colors: [
                HueGradientColor(x: 0.30, y: 0.18, red: 0.78, green: 0.62, blue: 1.00),
                HueGradientColor(x: 0.34, y: 0.34, red: 0.93, green: 0.94, blue: 0.86),
                HueGradientColor(x: 0.17, y: 0.31, red: 0.46, green: 0.96, blue: 0.90)
            ]
        )
    ]

    static var fallback: HueGradientPreset {
        all[0]
    }

    func payload(for light: HueLight, index: Int, total: Int) -> Data? {
        var object: [String: Any] = [
            "on": ["on": true]
        ]

        if light.supportsDimming {
            object["dimming"] = ["brightness": min(100, max(1, brightness))]
        }

        if light.supportsGradient {
            object["gradient"] = [
                "points": gradientColors(for: light).map(\.xyObject),
                "mode": "interpolated_palette"
            ]
        } else if light.supportsColor {
            object["color"] = color(at: index, total: total).xyObject
        } else if light.supportsColorTemperature {
            object["color_temperature"] = ["mirek": fallbackMirek]
        }

        return try? JSONSerialization.data(withJSONObject: object, options: [])
    }

    func color(at index: Int, total: Int) -> HueGradientColor {
        guard total > 1 else {
            return interpolatedColor(at: 0.5)
        }

        return interpolatedColor(at: Double(index) / Double(total - 1))
    }

    private func gradientColors(for light: HueLight) -> [HueGradientColor] {
        let capability = light.gradient?.pointsCapable ?? colors.count
        let count = min(max(capability, 2), colors.count)

        guard count > 1 else {
            return [colors[0]]
        }

        return (0..<count).map { index in
            interpolatedColor(at: Double(index) / Double(count - 1))
        }
    }

    private func interpolatedColor(at position: Double) -> HueGradientColor {
        guard colors.count > 1 else { return colors[0] }

        let bounded = min(1, max(0, position))
        let scaled = bounded * Double(colors.count - 1)
        let lowerIndex = Int(scaled.rounded(.down))
        let upperIndex = min(colors.count - 1, lowerIndex + 1)
        let amount = scaled - Double(lowerIndex)

        return HueGradientColor.mix(colors[lowerIndex], colors[upperIndex], amount: amount)
    }
}

enum HuePreset: String, CaseIterable, Identifiable, Sendable {
    case none
    case warm
    case cool
    case red
    case green
    case blue

    enum Kind {
        case none
        case temperature
        case xy
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            "Preset"
        case .warm:
            "Warm"
        case .cool:
            "Cool"
        case .red:
            "Red"
        case .green:
            "Green"
        case .blue:
            "Blue"
        }
    }

    var systemImage: String {
        switch self {
        case .none:
            "paintpalette"
        case .warm:
            "sunset.fill"
        case .cool:
            "snowflake"
        case .red:
            "flame.fill"
        case .green:
            "leaf.fill"
        case .blue:
            "drop.fill"
        }
    }

    var kind: Kind {
        switch self {
        case .none:
            .none
        case .warm, .cool:
            .temperature
        case .red, .green, .blue:
            .xy
        }
    }

    static var rowPresets: [HuePreset] {
        [.warm, .cool, .red, .green, .blue]
    }

    var payload: Data? {
        let object: [String: Any]

        switch self {
        case .none:
            return nil
        case .warm:
            object = [
                "on": ["on": true],
                "dimming": ["brightness": 72],
                "color_temperature": ["mirek": 366]
            ]
        case .cool:
            object = [
                "on": ["on": true],
                "dimming": ["brightness": 100],
                "color_temperature": ["mirek": 153]
            ]
        case .red:
            object = [
                "on": ["on": true],
                "dimming": ["brightness": 85],
                "color": ["xy": ["x": 0.675, "y": 0.322]]
            ]
        case .green:
            object = [
                "on": ["on": true],
                "dimming": ["brightness": 85],
                "color": ["xy": ["x": 0.409, "y": 0.518]]
            ]
        case .blue:
            object = [
                "on": ["on": true],
                "dimming": ["brightness": 85],
                "color": ["xy": ["x": 0.167, "y": 0.04]]
            ]
        }

        return try? JSONSerialization.data(withJSONObject: object, options: [])
    }
}
