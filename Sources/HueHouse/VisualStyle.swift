import HueKit
import SwiftUI

enum SiriGlassButtonTone {
    case standard
    case prominent
    case destructive
    case quiet
}

enum HueTheme {
    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.08, green: 0.08, blue: 0.10)
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        primaryText(scheme).opacity(scheme == .dark ? 0.68 : 0.62)
    }

    static func tertiaryText(_ scheme: ColorScheme) -> Color {
        primaryText(scheme).opacity(scheme == .dark ? 0.46 : 0.42)
    }

    static func controlTint(_ scheme: ColorScheme) -> Color {
        primaryText(scheme)
    }

    static func glassTint(_ scheme: ColorScheme, opacity: Double = 0.06) -> Color {
        primaryText(scheme).opacity(opacity)
    }

    static func hairline(_ scheme: ColorScheme, opacity: Double = 0.20) -> Color {
        primaryText(scheme).opacity(opacity)
    }

    static func shadow(_ scheme: ColorScheme, opacity: Double = 0.14) -> Color {
        .black.opacity(scheme == .dark ? opacity : opacity * 0.65)
    }

    static func backgroundColors(_ scheme: ColorScheme) -> [Color] {
        if scheme == .dark {
            [
                Color(red: 0.035, green: 0.038, blue: 0.045),
                Color(red: 0.070, green: 0.074, blue: 0.086),
                Color(red: 0.105, green: 0.108, blue: 0.120),
                Color(red: 0.050, green: 0.052, blue: 0.060)
            ]
        } else {
            [
                Color(red: 0.965, green: 0.965, blue: 0.975),
                Color(red: 0.910, green: 0.920, blue: 0.940),
                Color(red: 0.985, green: 0.985, blue: 0.990),
                Color(red: 0.880, green: 0.892, blue: 0.915)
            ]
        }
    }

    static func sheenColors(_ scheme: ColorScheme) -> [Color] {
        if scheme == .dark {
            [
                .white.opacity(0.18),
                .white.opacity(0.035),
                .clear,
                .white.opacity(0.08)
            ]
        } else {
            [
                .white.opacity(0.70),
                .white.opacity(0.22),
                .clear,
                .black.opacity(0.045)
            ]
        }
    }
}

extension View {
    func hueGlass(cornerRadius: CGFloat = 20, tint: Color? = nil, interactive _: Bool = false) -> some View {
        // The macOS 26 `glassEffect` Liquid Glass material refracts and tints
        // surrounding UI, which screenshots capture as ghosted reflections of
        // the rest of the window. We always use `.regularMaterial` plus a
        // hairline stroke for a calm, screenshot-friendly surface that still
        // keeps a sense of depth. The `interactive` parameter is kept for
        // source compatibility but ignored.
        //
        // Material, tint, stroke, and shadow are all packaged inside a single
        // `.background { … }` so the shadow's alpha mask comes only from the
        // rounded shape — not from the wrapped row content. Otherwise, opaque
        // text/icons inside the card contribute rectangular bumps to the
        // shadow, which read as hard square corners in light mode.
        background {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            shape
                .fill(.regularMaterial)
                .overlay(shape.fill(tint ?? .clear))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.16), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                .allowsHitTesting(false)
        }
    }

    func siriTextFieldChrome() -> some View {
        modifier(SiriTextFieldChrome())
    }

    func siriSectionTitle() -> some View {
        modifier(SiriSectionTitle())
    }
}

extension Color {
    init(hueGradientColor color: HueGradientColor) {
        self.init(red: color.red, green: color.green, blue: color.blue)
    }
}

struct SiriGlassButtonStyle: ButtonStyle {
    var tone: SiriGlassButtonTone = .standard
    var fullWidth = false
    var compact = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .lineLimit(1)
            .labelStyle(.titleAndIcon)
            .symbolRenderingMode(.monochrome)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 7 : 9)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .foregroundStyle(foregroundColor)
            .background {
                SiriGlassControlBackground(
                    tone: tone,
                    cornerRadius: compact ? 14 : 18,
                    isPressed: configuration.isPressed,
                    isEnabled: isEnabled
                )
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.46)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch tone {
        case .prominent:
            colorScheme == .dark ? .black : .white
        default:
            HueTheme.primaryText(colorScheme)
        }
    }
}

private struct SiriGlassControlBackground: View {
    let tone: SiriGlassButtonTone
    let cornerRadius: CGFloat
    let isPressed: Bool
    let isEnabled: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: fillColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(isPressed ? fillOpacity + 0.08 : fillOpacity)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: strokeColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPressed ? 1.35 : 0.9
                    )
                    .opacity(isEnabled ? 1 : 0.5)
            }
            .shadow(color: HueTheme.shadow(colorScheme, opacity: shadowOpacity), radius: isPressed ? 5 : 12, y: isPressed ? 2 : 7)
    }

    private var fillColors: [Color] {
        switch tone {
        case .prominent:
            if colorScheme == .dark {
                [.white.opacity(0.94), .white.opacity(0.76)]
            } else {
                [.black.opacity(0.84), .black.opacity(0.70)]
            }
        case .destructive, .standard:
            [
                HueTheme.primaryText(colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.08),
                HueTheme.primaryText(colorScheme).opacity(colorScheme == .dark ? 0.06 : 0.035)
            ]
        case .quiet:
            [
                HueTheme.primaryText(colorScheme).opacity(colorScheme == .dark ? 0.10 : 0.045),
                HueTheme.primaryText(colorScheme).opacity(colorScheme == .dark ? 0.035 : 0.020)
            ]
        }
    }

    private var strokeColors: [Color] {
        [
            .white.opacity(colorScheme == .dark ? 0.42 : 0.70),
            HueTheme.primaryText(colorScheme).opacity(colorScheme == .dark ? 0.20 : 0.16),
            HueTheme.primaryText(colorScheme).opacity(colorScheme == .dark ? 0.12 : 0.10)
        ]
    }

    private var fillOpacity: Double {
        switch tone {
        case .prominent:
            0.92
        case .destructive:
            0.55
        case .standard:
            0.64
        case .quiet:
            0.48
        }
    }

    private var shadowOpacity: Double {
        switch tone {
        case .prominent:
            0.18
        default:
            0.12
        }
    }
}

private struct SiriTextFieldChrome: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(HueTheme.primaryText(colorScheme))
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background {
                SiriGlassControlBackground(
                    tone: .quiet,
                    cornerRadius: 18,
                    isPressed: false,
                    isEnabled: isEnabled
                )
            }
            .overlay(alignment: .trailing) {
                Image(systemName: "network")
                    .font(.system(size: 12, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(HueTheme.tertiaryText(colorScheme))
                    .padding(.trailing, 12)
            }
    }
}

private struct SiriSectionTitle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(HueTheme.secondaryText(colorScheme))
            .textCase(.uppercase)
    }
}

struct SiriAppGlyph: View {
    let systemImage: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    HueTheme.primaryText(colorScheme).opacity(colorScheme == .dark ? 0.20 : 0.08),
                                    HueTheme.primaryText(colorScheme).opacity(colorScheme == .dark ? 0.06 : 0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(HueTheme.hairline(colorScheme, opacity: 0.24), lineWidth: 1)
                }

            Image(systemName: systemImage)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(HueTheme.primaryText(colorScheme))
                .symbolRenderingMode(.monochrome)
        }
        .shadow(color: HueTheme.shadow(colorScheme, opacity: 0.14), radius: 16, y: 7)
    }
}

struct HuePaletteStrip: View {
    let colors: [HueGradientColor]

    var body: some View {
        LinearGradient(
            colors: colors.map(Color.init(hueGradientColor:)),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct HueLiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: HueTheme.backgroundColors(colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.14 : 0.70),
                    .clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 520
            )
            .blendMode(colorScheme == .dark ? .screen : .normal)

            LinearGradient(
                colors: HueTheme.sheenColors(colorScheme),
                startPoint: .top,
                endPoint: .bottomTrailing
            )
            .blendMode(colorScheme == .dark ? .screen : .normal)
        }
        .ignoresSafeArea()
    }
}
