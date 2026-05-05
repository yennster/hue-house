import Foundation
import Testing
import HueKit

@Suite("CSS gradient parser")
struct HueCSSGradientTests {

    @Test("Parses comma-separated named colors")
    func namedColors() throws {
        let colors = try HueCSSGradient.parse("red, green, blue")
        #expect(colors.count == 3)
    }

    @Test("Parses 6-digit hex colors")
    func hexColors() throws {
        let colors = try HueCSSGradient.parse("#ff0000, #00ff00, #0000ff")
        #expect(colors.count == 3)
        #expect(colors[0].red == 1.0)
        #expect(colors[0].green == 0.0)
        #expect(colors[1].green == 1.0)
        #expect(colors[2].blue == 1.0)
    }

    @Test("Parses 3-digit hex shorthand")
    func shortHex() throws {
        let colors = try HueCSSGradient.parse("#fff, #000")
        #expect(colors.count == 2)
        #expect(colors[0].red == 1.0)
        #expect(colors[1].red == 0.0)
    }

    @Test("Parses linear-gradient() syntax and skips the direction token")
    func linearGradient() throws {
        let colors = try HueCSSGradient.parse(
            "linear-gradient(90deg, #833AB4, #FD1D1D, #FCB045)"
        )
        #expect(colors.count == 3)
    }

    @Test("Parses radial-gradient() and conic-gradient() bodies")
    func otherGradientFunctions() throws {
        let radial = try HueCSSGradient.parse("radial-gradient(coral, indigo)")
        let conic = try HueCSSGradient.parse("conic-gradient(coral, indigo)")
        #expect(radial.count == 2)
        #expect(conic.count == 2)
    }

    @Test("Parses rgb()/rgba() including commas inside the parens")
    func rgbAndRgbaSyntax() throws {
        let colors = try HueCSSGradient.parse(
            "rgb(255, 0, 128), rgba(20, 30, 40, 0.8)"
        )
        #expect(colors.count == 2)
    }

    @Test("Empty input throws")
    func emptyInput() {
        #expect(throws: HueCSSGradientParseError.self) {
            _ = try HueCSSGradient.parse("")
        }
    }

    @Test("Unknown color in a plain comma list throws")
    func unknownColor() {
        #expect(throws: HueCSSGradientParseError.self) {
            _ = try HueCSSGradient.parse("red, notacolor, blue")
        }
    }

    @Test("Stop positions in gradient bodies are accepted but ignored")
    func stopPositionsTolerated() throws {
        let colors = try HueCSSGradient.parse(
            "linear-gradient(to right, #ff0000 0%, #00ff00 50%, #0000ff 100%)"
        )
        #expect(colors.count == 3)
    }
}
