import Foundation
import HueKit

enum LightFixtures {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    static func decode(_ json: String) throws -> HueLight {
        try decoder.decode(HueLight.self, from: Data(json.utf8))
    }

    static func gradientStrip(brightness: Double = 80, pointsCapable: Int = 5) throws -> HueLight {
        try decode("""
        {
            "id": "test-strip",
            "type": "light",
            "metadata": {"name": "Test Strip", "archetype": "hue_lightstrip"},
            "on": {"on": true},
            "dimming": {"brightness": \(brightness), "min_dim_level": 1},
            "color": {"xy": {"x": 0.3, "y": 0.3}},
            "gradient": {
                "points": [],
                "mode": "interpolated_palette",
                "points_capable": \(pointsCapable),
                "pixel_count": 24
            }
        }
        """)
    }

    static func colorBulb(brightness: Double = 80) throws -> HueLight {
        try decode("""
        {
            "id": "test-bulb",
            "type": "light",
            "metadata": {"name": "Test Bulb", "archetype": "sultan_bulb"},
            "on": {"on": true},
            "dimming": {"brightness": \(brightness), "min_dim_level": 1},
            "color": {"xy": {"x": 0.3, "y": 0.3}}
        }
        """)
    }

    static func ambianceBulb(brightness: Double = 80) throws -> HueLight {
        try decode("""
        {
            "id": "test-amb",
            "type": "light",
            "metadata": {"name": "White Bulb", "archetype": "sultan_bulb"},
            "on": {"on": true},
            "dimming": {"brightness": \(brightness), "min_dim_level": 1},
            "color_temperature": {"mirek": 366, "mirek_valid": true}
        }
        """)
    }
}
