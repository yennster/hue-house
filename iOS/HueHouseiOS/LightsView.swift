import HueKit
import SwiftUI

struct LightsView: View {
    @EnvironmentObject private var store: HueStore
    @State private var isRefreshSpinning = false
    @State private var groupBrightness: Double = 100
    @State private var hasSyncedGroupBrightness = false

    private var groupBrightnessDisabled: Bool {
        store.selectedGroupLights.filter(\.supportsDimming).isEmpty || store.isWorking
    }

    private func syncGroupBrightnessFromStore() {
        groupBrightness = store.selectedGroupBrightness
        hasSyncedGroupBrightness = true
    }

    var body: some View {
        Group {
            if store.canControlLights {
                content
            } else {
                ContentUnavailableView(
                    "No Bridge Connected",
                    systemImage: "wifi.router",
                    description: Text("Switch to the Bridge tab to pair your Hue Bridge.")
                )
            }
        }
        .navigationTitle("Lights")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        isRefreshSpinning = true
                        await store.refreshLights()
                        isRefreshSpinning = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshSpinning ? 360 : 0))
                        .animation(
                            isRefreshSpinning
                                ? .linear(duration: 0.7).repeatForever(autoreverses: false)
                                : .easeOut(duration: 0.2),
                            value: isRefreshSpinning
                        )
                }
                .disabled(store.isWorking)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            Section {
                Picker("Room or Zone", selection: $store.selectedGroupID) {
                    ForEach(store.availableGroups) { group in
                        Label(
                            "\(group.name) · \(store.lightCount(in: group))",
                            systemImage: group.systemImage
                        )
                        .tag(group.id)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                let anyOn = store.selectedGroupLights.contains { $0.isOn }
                Toggle(isOn: Binding(
                    get: { anyOn },
                    set: { newValue in
                        Task { await store.setAllLights(on: newValue) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Lights")
                            .font(.body.weight(.medium))
                        Text(anyOn ? "On" : "Off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.green)
                .disabled(store.selectedGroupLights.isEmpty || store.isWorking)

                HStack(spacing: 12) {
                    Image(systemName: "sun.min")
                        .foregroundStyle(.secondary)

                    Slider(value: $groupBrightness, in: 1...100, step: 1) { editing in
                        if !editing {
                            Task { await store.setAllLights(brightness: groupBrightness) }
                        }
                    }
                    .tint(.green)

                    Text("\(Int(groupBrightness.rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
                .disabled(groupBrightnessDisabled)
            }

            Section("Lights in \(store.selectedGroup.name)") {
                if store.selectedGroupLights.isEmpty {
                    Text("No lights in this group.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.selectedGroupLights) { light in
                        NavigationLink(value: light.id) {
                            LightRowView(light: light)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await store.refreshLights()
        }
        .onAppear { syncGroupBrightnessFromStore() }
        .onChange(of: store.selectedGroupID) { _, _ in syncGroupBrightnessFromStore() }
        .onChange(of: store.selectedGroupBrightness) { _, _ in
            if !hasSyncedGroupBrightness { syncGroupBrightnessFromStore() }
        }
        .navigationDestination(for: String.self) { id in
            if let light = store.lights.first(where: { $0.id == id }) {
                LightDetailView(light: light)
            }
        }
    }
}

private struct LightRowView: View {
    @EnvironmentObject private var store: HueStore
    let light: HueLight

    private var isUnreachable: Bool { store.skippedLightIDs.contains(light.id) }

    private var lightCircleColor: Color {
        guard light.isOn else { return Color.secondary.opacity(0.12) }
        if let xy = light.color?.xy {
            let brightness = max(0.3, light.brightness / 100)
            let rgb = HueGradientColor.sRGB(fromXY: xy.x, y: xy.y, relativeBrightness: brightness)
            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        }
        // Warm white for color-temperature or dimmable-only lights
        return Color(red: 1.0, green: 0.88, blue: 0.55)
    }

    private var lightIconForeground: Color {
        guard light.isOn else { return .secondary }
        // White icon on colored backgrounds; dark icon on warm white
        return light.color != nil ? Color.white.opacity(0.85) : Color(white: 0.15)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(lightCircleColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )

                Image(systemName: light.isOn ? "lightbulb.led.fill" : "lightbulb.led")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(lightIconForeground)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(light.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if isUnreachable {
                        Text("Unreachable")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.22)))
                            .foregroundStyle(.orange)
                    }
                }
                Text(light.detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { light.isOn },
                set: { newValue in
                    Task { await store.setLight(light.id, on: newValue) }
                }
            ))
            .labelsHidden()
            .tint(.green)
            .disabled(isUnreachable || store.isWorking)
        }
        .foregroundStyle(.primary)
        .opacity(isUnreachable ? 0.55 : 1.0)
    }
}
