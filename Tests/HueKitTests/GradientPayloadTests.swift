import Foundation
import Testing
import HueKit

@Suite("Gradient payload shape")
struct GradientPayloadTests {

    /// Regression for v0.6.1: gradient PUT payloads must wrap each point's
    /// chromaticity in `color.xy`, not just `xy`. The flat shape made the
    /// bridge reject every gradient apply against gradient-capable lights
    /// and mark them as unreachable in the session skip list.
    @Test("Gradient-capable light: points are wrapped in `color.xy`")
    func gradientPointsAreWrappedInColor() throws {
        let preset = HueGradientPreset.fallback
        let light = try LightFixtures.gradientStrip()

        let json = try decodedPayload(preset: preset, light: light)
        let gradient = try #require(json["gradient"] as? [String: Any])
        let points = try #require(gradient["points"] as? [[String: Any]])

        #expect(points.count >= 2, "Hue requires at least 2 gradient points.")
        for point in points {
            let color = try #require(point["color"] as? [String: Any], "Each point must wrap xy in a `color` object.")
            let xy = try #require(color["xy"] as? [String: Any])
            #expect(xy["x"] is Double)
            #expect(xy["y"] is Double)
        }
        #expect(gradient["mode"] as? String == "interpolated_palette")
        #expect(json["color"] == nil, "Gradient payload should not also send a flat color.")
    }

    @Test("Gradient-capable light: payload also turns the light on and sets brightness")
    func gradientPayloadIncludesOnAndDimming() throws {
        let preset = HueGradientPreset.fallback
        let light = try LightFixtures.gradientStrip()

        let json = try decodedPayload(preset: preset, light: light)
        let on = try #require(json["on"] as? [String: Any])
        #expect(on["on"] as? Bool == true)
        let dimming = try #require(json["dimming"] as? [String: Any])
        let brightness = try #require(dimming["brightness"] as? Double)
        #expect(brightness >= 1 && brightness <= 100)
    }

    @Test("Color-only light: receives a flat `color.xy` and no gradient field")
    func colorLightUsesFlatColor() throws {
        let preset = HueGradientPreset.fallback
        let light = try LightFixtures.colorBulb()

        let json = try decodedPayload(preset: preset, light: light)
        #expect(json["gradient"] == nil)
        let color = try #require(json["color"] as? [String: Any])
        let xy = try #require(color["xy"] as? [String: Any])
        #expect(xy["x"] is Double)
        #expect(xy["y"] is Double)
    }

    @Test("Color-temperature-only light: receives a mirek payload, no color")
    func ambianceLightUsesMirek() throws {
        let preset = HueGradientPreset.fallback
        let light = try LightFixtures.ambianceBulb()

        let json = try decodedPayload(preset: preset, light: light)
        #expect(json["color"] == nil)
        #expect(json["gradient"] == nil)
        let ct = try #require(json["color_temperature"] as? [String: Any])
        #expect(ct["mirek"] is Int)
    }

    @Test("Gradient point count is bounded by light's `pointsCapable`")
    func gradientPointCountRespectsCapability() throws {
        // Preset has 3 colors; a strip with capability 2 should send at most 2 points.
        let preset = HueGradientPreset.fallback
        let light = try LightFixtures.gradientStrip(pointsCapable: 2)

        let json = try decodedPayload(preset: preset, light: light)
        let gradient = try #require(json["gradient"] as? [String: Any])
        let points = try #require(gradient["points"] as? [[String: Any]])
        #expect(points.count == 2)
    }

    private func decodedPayload(preset: HueGradientPreset, light: HueLight) throws -> [String: Any] {
        let data = try #require(preset.payload(for: light, index: 0, total: 1))
        let json = try JSONSerialization.jsonObject(with: data)
        return try #require(json as? [String: Any])
    }
}
