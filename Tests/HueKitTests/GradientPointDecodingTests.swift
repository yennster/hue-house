import Foundation
import Testing
import HueKit

@Suite("Gradient point decoding")
struct GradientPointDecodingTests {

    @Test("Decodes the canonical Hue v2 wrapped shape: {color: {xy: {x, y}}}")
    func wrappedShape() throws {
        let json = #"{"color": {"xy": {"x": 0.31, "y": 0.43}}}"#
        let point = try JSONDecoder().decode(HueGradientPoint.self, from: Data(json.utf8))
        #expect(point.xy.x == 0.31)
        #expect(point.xy.y == 0.43)
    }

    @Test("Also accepts the legacy flat shape: {xy: {x, y}}")
    func flatShape() throws {
        let json = #"{"xy": {"x": 0.5, "y": 0.5}}"#
        let point = try JSONDecoder().decode(HueGradientPoint.self, from: Data(json.utf8))
        #expect(point.xy.x == 0.5)
        #expect(point.xy.y == 0.5)
    }

    @Test("Decodes a gradient resource with wrapped points end-to-end")
    func gradientWithWrappedPoints() throws {
        let json = """
        {
            "points": [
                {"color": {"xy": {"x": 0.1, "y": 0.2}}},
                {"color": {"xy": {"x": 0.3, "y": 0.4}}}
            ],
            "mode": "interpolated_palette",
            "points_capable": 5,
            "pixel_count": 24
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let gradient = try decoder.decode(HueGradient.self, from: Data(json.utf8))
        #expect(gradient.points.count == 2)
        #expect(gradient.pointsCapable == 5)
        #expect(gradient.points[0].xy.x == 0.1)
        #expect(gradient.points[1].xy.y == 0.4)
    }

    @Test("Empty points array round-trips without error")
    func emptyPoints() throws {
        let json = """
        {
            "points": [],
            "mode": "interpolated_palette",
            "points_capable": 5,
            "pixel_count": 24
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let gradient = try decoder.decode(HueGradient.self, from: Data(json.utf8))
        #expect(gradient.points.isEmpty)
        #expect(gradient.pointsCapable == 5)
    }
}
