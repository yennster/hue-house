import SwiftUI

struct RGBAColorSheet: View {
    @Binding var red: Double
    @Binding var green: Double
    @Binding var blue: Double
    @Binding var alphaPercent: Double
    var onCommit: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var previewColor: Color {
        Color(
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            opacity: max(0.05, alphaPercent / 100)
        )
    }

    private var hexString: String {
        String(
            format: "#%02X%02X%02X%02X",
            Int(red.rounded()),
            Int(green.rounded()),
            Int(blue.rounded()),
            Int((alphaPercent / 100 * 255).rounded())
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ZStack {
                    AlphaCheckerboard()
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    RoundedRectangle(cornerRadius: 14)
                        .fill(previewColor)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.secondary.opacity(0.35), lineWidth: 0.75)
                        )

                    Text(hexString)
                        .font(.callout.monospaced().weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.horizontal)

                channelSlider("R", value: $red, range: 0...255, tint: .red)
                channelSlider("G", value: $green, range: 0...255, tint: .green)
                channelSlider("B", value: $blue, range: 0...255, tint: .blue)
                channelSlider("A", value: $alphaPercent, range: 0...100, tint: .gray, suffix: "%")

                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func channelSlider(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        tint: Color,
        suffix: String = ""
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.callout.weight(.semibold))
                .frame(width: 16, alignment: .leading)
                .foregroundStyle(.secondary)

            Slider(value: value, in: range, step: 1) { editing in
                if !editing { onCommit() }
            }
            .tint(tint)

            Text("\(Int(value.wrappedValue.rounded()))\(suffix)")
                .font(.callout.monospaced())
                .frame(width: 48, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}

private struct AlphaCheckerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 8
            let cols = Int((size.width / tile).rounded(.up))
            let rows = Int((size.height / tile).rounded(.up))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isDark = (row + col).isMultiple(of: 2)
                    let rect = CGRect(x: CGFloat(col) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    context.fill(
                        Path(rect),
                        with: .color(isDark ? Color.gray.opacity(0.22) : Color.gray.opacity(0.10))
                    )
                }
            }
        }
    }
}
