import HueKit
import SwiftUI

struct LightDetailView: View {
    @EnvironmentObject private var store: HueStore
    let light: HueLight

    @State private var brightness: Double = 100
    @State private var redChannel: Double = 255
    @State private var greenChannel: Double = 255
    @State private var blueChannel: Double = 255
    @State private var alphaPercent: Double = 100
    @State private var isShowingColorPicker = false
    @State private var hasSyncedColor = false

    private var isUnreachable: Bool { store.skippedLightIDs.contains(light.id) }

    private var swatchColor: Color {
        Color(
            red: redChannel / 255,
            green: greenChannel / 255,
            blue: blueChannel / 255,
            opacity: max(0.05, alphaPercent / 100)
        )
    }

    var body: some View {
        Form {
            Section("Power") {
                Toggle(isOn: Binding(
                    get: { light.isOn },
                    set: { newValue in
                        Task { await store.setLight(light.id, on: newValue) }
                    }
                )) {
                    Label(light.isOn ? "On" : "Off", systemImage: light.isOn ? "lightbulb.led.fill" : "lightbulb.led")
                }
                .tint(.green)
                .disabled(isUnreachable || store.isWorking)
            }

            if light.supportsDimming {
                Section("Brightness") {
                    HStack {
                        Image(systemName: "sun.min")
                            .foregroundStyle(.secondary)
                        Slider(value: $brightness, in: 1...100, step: 1) { editing in
                            if !editing {
                                Task { await store.setLight(light.id, brightness: brightness) }
                            }
                        }
                        Text("\(Int(brightness.rounded()))%")
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .disabled(isUnreachable || store.isWorking)
                }
            }

            if light.supportsColor {
                Section("Color") {
                    Button {
                        isShowingColorPicker = true
                    } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(swatchColor)
                                .frame(width: 44, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.secondary.opacity(0.3), lineWidth: 0.75)
                                )
                            Text("Edit color")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .disabled(isUnreachable || store.isWorking)
                    .foregroundStyle(.primary)
                }
            }

            Section("Quick Color") {
                ForEach(HuePreset.rowPresets) { preset in
                    Button {
                        Task { await store.applyPreset(preset, to: light.id) }
                    } label: {
                        Label(preset.title, systemImage: preset.systemImage)
                    }
                    .disabled(!light.canApply(preset) || isUnreachable || store.isWorking)
                }
            }

            if isUnreachable {
                Section {
                    Button("Re-enable This Light", role: .destructive) {
                        store.resetSkippedLights()
                    }
                } footer: {
                    Text("This light failed earlier this session and is being skipped. Tap to retry.")
                }
            }
        }
        .navigationTitle(light.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingColorPicker) {
            RGBAColorSheet(
                red: $redChannel,
                green: $greenChannel,
                blue: $blueChannel,
                alphaPercent: $alphaPercent,
                onCommit: applyPickedColor
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            brightness = light.brightness
            syncColorFromLight(force: true)
        }
        .onChange(of: light.brightness) { _, newValue in
            brightness = newValue
            syncColorFromLight(force: false)
        }
        .onChange(of: light.color) { _, _ in
            syncColorFromLight(force: false)
        }
        .onChange(of: light.isOn) { _, _ in
            syncColorFromLight(force: false)
        }
    }

    private func syncColorFromLight(force: Bool) {
        guard !isShowingColorPicker || force else { return }

        if let xy = light.color?.xy {
            let relative = max(0.05, light.brightness / 100)
            let rgb = HueGradientColor.sRGB(fromXY: xy.x, y: xy.y, relativeBrightness: relative)
            redChannel = rgb.red * 255
            greenChannel = rgb.green * 255
            blueChannel = rgb.blue * 255
        } else if !hasSyncedColor {
            redChannel = 255
            greenChannel = 255
            blueChannel = 255
        }

        alphaPercent = light.isOn ? max(1, min(100, light.brightness)) : 0
        hasSyncedColor = true
    }

    private func applyPickedColor() {
        let r = redChannel / 255
        let g = greenChannel / 255
        let b = blueChannel / 255
        let alpha = alphaPercent
        Task { await store.setLight(light.id, red: r, green: g, blue: b, alphaPercent: alpha) }
    }
}
