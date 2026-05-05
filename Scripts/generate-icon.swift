#!/usr/bin/env swift
// Generates the Hue House app icon as a 1024×1024 PNG plus a full .icns.
// Designed to align with Apple's Liquid Glass icon guidance: a layered
// composition of a tinted Squircle background, soft ambient highlight, an
// inner glass sheen, and a centered foreground glyph.
//
// Usage: ./Scripts/generate-icon.swift [output-dir]
// Default output dir: Packaging/

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
let scriptURL = URL(fileURLWithPath: arguments[0])
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputDir = arguments.count > 1
    ? URL(fileURLWithPath: arguments[1])
    : projectRoot.appendingPathComponent("Packaging", isDirectory: true)

try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

// MARK: - Drawing

struct RGBA {
    let r, g, b, a: CGFloat
    static let white = RGBA(r: 1, g: 1, b: 1, a: 1)
    static let clear = RGBA(r: 1, g: 1, b: 1, a: 0)
    var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
}

// Brand palette: violet → magenta → coral, mirroring HueGradientPreset.fallback.
let palette: [RGBA] = [
    RGBA(r: 0.42, g: 0.30, b: 0.95, a: 1),  // violet
    RGBA(r: 0.84, g: 0.32, b: 0.86, a: 1),  // magenta
    RGBA(r: 1.00, g: 0.48, b: 0.42, a: 1),  // coral
    RGBA(r: 1.00, g: 0.74, b: 0.36, a: 1),  // amber
]

func renderIcon(size: CGFloat) -> CGImage {
    let pixelSize = Int(size)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Failed to allocate bitmap context at size \(pixelSize)")
    }

    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    // macOS app icons leave ~10% padding around a continuous-corner Squircle.
    let inset: CGFloat = size * 0.082
    let iconRect = bounds.insetBy(dx: inset, dy: inset)
    let cornerRadius = iconRect.width * 0.225
    let squircle = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Soft ambient drop shadow under the squircle.
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.012),
        blur: size * 0.045,
        color: CGColor(srgbRed: 0.05, green: 0.02, blue: 0.16, alpha: 0.55)
    )
    ctx.addPath(squircle)
    ctx.setFillColor(palette[1].cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Background gradient (diagonal violet → coral → amber).
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let bgColors = palette.map(\.cgColor) as CFArray
    let bgStops: [CGFloat] = [0.0, 0.45, 0.78, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgStops) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: iconRect.minX + iconRect.width * 0.05, y: iconRect.maxY),
            end: CGPoint(x: iconRect.maxX, y: iconRect.minY + iconRect.height * 0.05),
            options: []
        )
    }
    ctx.restoreGState()

    // Top-left bloom — the Liquid Glass primary highlight.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let bloomColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0)
    ] as CFArray
    if let bloom = CGGradient(colorsSpace: colorSpace, colors: bloomColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            bloom,
            startCenter: CGPoint(x: iconRect.minX + iconRect.width * 0.18,
                                 y: iconRect.maxY - iconRect.height * 0.10),
            startRadius: 0,
            endCenter: CGPoint(x: iconRect.minX + iconRect.width * 0.18,
                               y: iconRect.maxY - iconRect.height * 0.10),
            endRadius: iconRect.width * 0.78,
            options: []
        )
    }
    ctx.restoreGState()

    // Subtle floor reflection along the bottom edge.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let floorColors = [
        CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.0),
        CGColor(srgbRed: 0.05, green: 0.02, blue: 0.10, alpha: 0.30)
    ] as CFArray
    if let floor = CGGradient(colorsSpace: colorSpace, colors: floorColors, locations: [0.6, 1.0]) {
        ctx.drawLinearGradient(
            floor,
            start: CGPoint(x: iconRect.midX, y: iconRect.maxY),
            end: CGPoint(x: iconRect.midX, y: iconRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Inner glass card (frosted lozenge that holds the glyph).
    let cardInset = iconRect.width * 0.18
    let cardRect = iconRect.insetBy(dx: cardInset, dy: cardInset)
    let cardCorner = cardRect.width * 0.30
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardCorner, cornerHeight: cardCorner, transform: nil)

    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.clip()
    let cardColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.32),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    ] as CFArray
    if let cardGradient = CGGradient(colorsSpace: colorSpace, colors: cardColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            cardGradient,
            start: CGPoint(x: cardRect.minX, y: cardRect.maxY),
            end: CGPoint(x: cardRect.maxX, y: cardRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Card hairline.
    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
    ctx.setLineWidth(size * 0.0035)
    ctx.strokePath()
    ctx.restoreGState()

    // Lightbulb glyph rendered from SF Symbols, then drawn into the context.
    drawLightbulbGlyph(in: ctx, frame: cardRect, color: .white)

    // Outer hairline for crisp edge.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.32))
    ctx.setLineWidth(size * 0.003)
    ctx.strokePath()
    ctx.restoreGState()

    // Top sheen — narrow specular highlight along the upper crown.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let sheenRect = CGRect(
        x: iconRect.minX + iconRect.width * 0.05,
        y: iconRect.maxY - iconRect.height * 0.18,
        width: iconRect.width * 0.90,
        height: iconRect.height * 0.16
    )
    let sheenPath = CGPath(
        roundedRect: sheenRect,
        cornerWidth: sheenRect.height * 0.5,
        cornerHeight: sheenRect.height * 0.5,
        transform: nil
    )
    ctx.addPath(sheenPath)
    ctx.clip()
    let sheenColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.42),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0)
    ] as CFArray
    if let sheenGradient = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            sheenGradient,
            start: CGPoint(x: sheenRect.midX, y: sheenRect.maxY),
            end: CGPoint(x: sheenRect.midX, y: sheenRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    return ctx.makeImage()!
}

func drawLightbulbGlyph(in ctx: CGContext, frame: CGRect, color: RGBA) {
    let symbolName = "lightbulb.2.fill"
    let cfg = NSImage.SymbolConfiguration(pointSize: frame.height * 0.78, weight: .semibold)
    guard
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
    else {
        // Fallback: draw a circle if SF Symbols fails for some reason.
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: frame.insetBy(dx: frame.width * 0.25, dy: frame.height * 0.25))
        return
    }

    // Tint by drawing into a transparent NSImage and remasking.
    let tinted = NSImage(size: symbol.size, flipped: false) { rect in
        guard let cg = NSGraphicsContext.current?.cgContext else { return false }
        cg.saveGState()
        symbol.draw(in: rect)
        cg.setBlendMode(.sourceIn)
        cg.setFillColor(color.cgColor)
        cg.fill(rect)
        cg.restoreGState()
        return true
    }

    // Glyph drop shadow for depth.
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -frame.height * 0.015),
        blur: frame.height * 0.05,
        color: CGColor(srgbRed: 0.05, green: 0.02, blue: 0.16, alpha: 0.45)
    )

    let aspect = symbol.size.width / max(symbol.size.height, 1)
    var glyphHeight = frame.height * 0.62
    var glyphWidth = glyphHeight * aspect
    if glyphWidth > frame.width * 0.86 {
        glyphWidth = frame.width * 0.86
        glyphHeight = glyphWidth / aspect
    }
    let glyphRect = CGRect(
        x: frame.midX - glyphWidth / 2,
        y: frame.midY - glyphHeight / 2,
        width: glyphWidth,
        height: glyphHeight
    )

    var imageRect = glyphRect
    if let cgGlyph = tinted.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) {
        ctx.draw(cgGlyph, in: glyphRect)
    }
    ctx.restoreGState()
}

// MARK: - iOS variant

/// Renders a flat, full-bleed iOS app icon. iOS applies its own corner mask,
/// so this skips the inset, the squircle clip, the outer hairline, and the
/// ambient drop-shadow that the macOS icon needs.
func renderIOSIcon(size: CGFloat) -> CGImage {
    let pixelSize = Int(size)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Failed to allocate iOS bitmap context at size \(pixelSize)")
    }

    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)

    // Background gradient — full bleed.
    let bgColors = palette.map(\.cgColor) as CFArray
    let bgStops: [CGFloat] = [0.0, 0.45, 0.78, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgStops) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: bounds.maxY),
            end: CGPoint(x: bounds.maxX, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    // Top-left bloom highlight.
    let bloomColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0)
    ] as CFArray
    if let bloom = CGGradient(colorsSpace: colorSpace, colors: bloomColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            bloom,
            startCenter: CGPoint(x: bounds.width * 0.20, y: bounds.height * 0.85),
            startRadius: 0,
            endCenter: CGPoint(x: bounds.width * 0.20, y: bounds.height * 0.85),
            endRadius: bounds.width * 0.85,
            options: []
        )
    }

    // Bottom shading.
    let floorColors = [
        CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.0),
        CGColor(srgbRed: 0.05, green: 0.02, blue: 0.10, alpha: 0.30)
    ] as CFArray
    if let floor = CGGradient(colorsSpace: colorSpace, colors: floorColors, locations: [0.6, 1.0]) {
        ctx.drawLinearGradient(
            floor,
            start: CGPoint(x: bounds.midX, y: bounds.maxY),
            end: CGPoint(x: bounds.midX, y: 0),
            options: []
        )
    }

    // Frosted glass card holding the glyph — give the icon depth.
    let cardInset = bounds.width * 0.16
    let cardRect = bounds.insetBy(dx: cardInset, dy: cardInset)
    let cardCorner = cardRect.width * 0.30
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardCorner, cornerHeight: cardCorner, transform: nil)

    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.clip()
    let cardColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.32),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    ] as CFArray
    if let cardGradient = CGGradient(colorsSpace: colorSpace, colors: cardColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            cardGradient,
            start: CGPoint(x: cardRect.minX, y: cardRect.maxY),
            end: CGPoint(x: cardRect.maxX, y: cardRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
    ctx.setLineWidth(size * 0.0035)
    ctx.strokePath()
    ctx.restoreGState()

    drawLightbulbGlyph(in: ctx, frame: cardRect, color: .white)

    return ctx.makeImage()!
}

// MARK: - PNG writing

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Failed to create image destination at \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        fatalError("Failed to finalize PNG at \(url.path)")
    }
}

// MARK: - Iconset

let masterSize: CGFloat = 1024
let masterImage = renderIcon(size: masterSize)
let masterURL = outputDir.appendingPathComponent("AppIcon-1024.png")
writePNG(masterImage, to: masterURL)
print("wrote \(masterURL.lastPathComponent)")

// Also write a Mac toolbar / menu bar template-friendly small image.
let menuBarImage = renderIcon(size: 256)
writePNG(menuBarImage, to: outputDir.appendingPathComponent("AppIcon-256.png"))

// Build .iconset/ for iconutil.
let iconsetURL = outputDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconVariant {
    let pixelSize: CGFloat
    let name: String
}

let variants: [IconVariant] = [
    .init(pixelSize: 16,   name: "icon_16x16.png"),
    .init(pixelSize: 32,   name: "icon_16x16@2x.png"),
    .init(pixelSize: 32,   name: "icon_32x32.png"),
    .init(pixelSize: 64,   name: "icon_32x32@2x.png"),
    .init(pixelSize: 128,  name: "icon_128x128.png"),
    .init(pixelSize: 256,  name: "icon_128x128@2x.png"),
    .init(pixelSize: 256,  name: "icon_256x256.png"),
    .init(pixelSize: 512,  name: "icon_256x256@2x.png"),
    .init(pixelSize: 512,  name: "icon_512x512.png"),
    .init(pixelSize: 1024, name: "icon_512x512@2x.png"),
]

for variant in variants {
    let img = renderIcon(size: variant.pixelSize)
    writePNG(img, to: iconsetURL.appendingPathComponent(variant.name))
}

// Run iconutil to produce the .icns.
let icnsURL = outputDir.appendingPathComponent("AppIcon.icns")
try? FileManager.default.removeItem(at: icnsURL)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}
print("wrote \(icnsURL.lastPathComponent)")

// Also write the iOS-flavored full-bleed icon to the iOS asset catalog.
let iosCatalog = projectRoot
    .appendingPathComponent("iOS/HueHouseiOS/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
if FileManager.default.fileExists(atPath: iosCatalog.deletingLastPathComponent().path) {
    let iosImage = renderIOSIcon(size: 1024)
    let iosURL = iosCatalog.appendingPathComponent("AppIcon-1024.png")
    writePNG(iosImage, to: iosURL)
    print("wrote iOS/HueHouseiOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
}
