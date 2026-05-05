import Foundation
import Testing
import HueKit

@Suite("sRGB ↔ xy color math")
struct ColorMathTests {

    @Test("Pure red has high x and moderate y in CIE 1931")
    func redChromaticity() {
        let red = HueGradientColor.fromSRGB(red: 1, green: 0, blue: 0)
        #expect(red.x > 0.6, "Red xy.x should be in the high-x corner of the gamut")
        #expect(red.y < 0.4)
    }

    @Test("Pure green sits in the upper part of the gamut")
    func greenChromaticity() {
        let green = HueGradientColor.fromSRGB(red: 0, green: 1, blue: 0)
        #expect(green.y > 0.5)
    }

    @Test("Pure blue is in the low-x low-y corner")
    func blueChromaticity() {
        let blue = HueGradientColor.fromSRGB(red: 0, green: 0, blue: 1)
        #expect(blue.x < 0.25)
        #expect(blue.y < 0.20)
    }

    @Test("White converts close to D65 (≈0.3127, 0.3290)")
    func whiteIsD65() {
        let white = HueGradientColor.fromSRGB(red: 1, green: 1, blue: 1)
        #expect(abs(white.x - 0.3127) < 0.005)
        #expect(abs(white.y - 0.3290) < 0.005)
    }

    @Test("Components are clamped into 0…1")
    func componentsClamped() {
        let clamped = HueGradientColor.fromSRGB(red: 1.5, green: -0.2, blue: 0.5)
        #expect(clamped.red == 1.0)
        #expect(clamped.green == 0.0)
        #expect(clamped.blue == 0.5)
    }

    @Test("xy → sRGB returns values inside the unit cube")
    func reverseConversionStaysInGamut() {
        let rgb = HueGradientColor.sRGB(fromXY: 0.4, y: 0.4, relativeBrightness: 0.6)
        #expect(rgb.red >= 0 && rgb.red <= 1)
        #expect(rgb.green >= 0 && rgb.green <= 1)
        #expect(rgb.blue >= 0 && rgb.blue <= 1)
    }

    @Test("Mixing two colors at amount 0 returns the start color")
    func mixAtZero() {
        let start = HueGradientColor.fromSRGB(red: 1, green: 0, blue: 0)
        let end = HueGradientColor.fromSRGB(red: 0, green: 0, blue: 1)
        let mixed = HueGradientColor.mix(start, end, amount: 0)
        #expect(abs(mixed.x - start.x) < 1e-9)
        #expect(abs(mixed.y - start.y) < 1e-9)
    }

    @Test("Mixing two colors at amount 1 returns the end color")
    func mixAtOne() {
        let start = HueGradientColor.fromSRGB(red: 1, green: 0, blue: 0)
        let end = HueGradientColor.fromSRGB(red: 0, green: 0, blue: 1)
        let mixed = HueGradientColor.mix(start, end, amount: 1)
        #expect(abs(mixed.x - end.x) < 1e-9)
        #expect(abs(mixed.y - end.y) < 1e-9)
    }

    @Test("Mixing at midpoint lands halfway between the endpoints")
    func mixAtHalf() {
        let start = HueGradientColor(x: 0.0, y: 0.0, red: 0, green: 0, blue: 0)
        let end = HueGradientColor(x: 1.0, y: 1.0, red: 1, green: 1, blue: 1)
        let mixed = HueGradientColor.mix(start, end, amount: 0.5)
        #expect(abs(mixed.x - 0.5) < 1e-9)
        #expect(abs(mixed.y - 0.5) < 1e-9)
    }
}
