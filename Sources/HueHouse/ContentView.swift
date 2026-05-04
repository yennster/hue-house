import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            HueLiquidBackground()

            VStack(spacing: 16) {
                HeaderView()

                if store.canControlLights {
                    LightControlView()
                } else {
                    PairingView()
                }
            }
            .padding(18)
        }
        .foregroundStyle(HueTheme.primaryText(colorScheme))
        .tint(HueTheme.controlTint(colorScheme))
        .symbolRenderingMode(.monochrome)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                HueTopToolbarMenu()
                    .environmentObject(store)

                Button {
                    Task { await store.refreshLights() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!store.canControlLights || store.isWorking)
                .buttonStyle(SiriGlassButtonStyle(tone: .quiet, compact: true))
            }
        }
        .alert("Hue House", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

private struct HueTopToolbarMenu: View {
    @EnvironmentObject private var store: HueStore
    @AppStorage(HueAppStorage.appearanceModeKey) private var appearanceModeRawValue = HueAppearanceMode.system.rawValue

    var body: some View {
        Menu {
            Section("Target") {
                Picker("Room or Zone", selection: $store.selectedGroupID) {
                    ForEach(store.availableGroups) { group in
                        Label(
                            "\(group.name) · \(store.lightCount(in: group))",
                            systemImage: group.systemImage
                        )
                        .tag(group.id)
                    }
                }
            }

            Section("Gradients") {
                ForEach(HueGradientPreset.all) { preset in
                    Button {
                        store.selectedGradientID = preset.id
                        Task { await store.applySelectedGradient() }
                    } label: {
                        Label(
                            preset.title,
                            systemImage: store.selectedGradientID == preset.id ? "checkmark.circle.fill" : "sparkles"
                        )
                    }
                    .disabled(!store.canControlLights || store.isWorking || store.selectedGroupLights.isEmpty)
                }

                Button {
                    Task { await store.applySelectedGradient() }
                } label: {
                    Label("Apply \(store.selectedGradient.title)", systemImage: "wand.and.stars")
                }
                .disabled(!store.canControlLights || store.isWorking || store.selectedGroupLights.isEmpty)
            }

            Section("Quick Color") {
                ForEach(HuePreset.rowPresets) { preset in
                    Button {
                        Task { await store.applyPresetToAll(preset) }
                    } label: {
                        Label(preset.title, systemImage: preset.systemImage)
                    }
                    .disabled(!store.canControlLights || store.isWorking || store.lights.isEmpty)
                }
            }

            Section("Appearance") {
                Picker("Mode", selection: $appearanceModeRawValue) {
                    ForEach(HueAppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode.rawValue)
                    }
                }
            }

            Section("Bridge") {
                Button {
                    Task { await store.discoverBridges() }
                } label: {
                    Label("Discover Bridge", systemImage: "dot.radiowaves.left.and.right")
                }
                .disabled(store.isWorking)

                Button {
                    Task { await store.pairBridge() }
                } label: {
                    Label("Pair Bridge", systemImage: "link")
                }
                .disabled(!store.canAttemptPairing || store.isWorking)

                Button {
                    Task { await store.refreshLights() }
                } label: {
                    Label("Refresh Lights", systemImage: "arrow.clockwise")
                }
                .disabled(!store.canControlLights || store.isWorking)

                Button(role: .destructive) {
                    store.forgetBridge()
                } label: {
                    Label("Forget Bridge", systemImage: "xmark.circle")
                }
                .disabled(!store.canControlLights || store.isWorking)
            }
        } label: {
            HStack(spacing: 8) {
                ToolbarPaletteGlyph(colors: store.selectedGradient.colors)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Hue Controls")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                    Text(store.canControlLights ? store.selectedGroup.name : "Bridge Setup")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .disabled(store.isWorking && !store.canControlLights)
    }
}

private struct ToolbarPaletteGlyph: View {
    let colors: [HueGradientColor]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HuePaletteStrip(colors: colors)
            .frame(width: 28, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(HueTheme.hairline(colorScheme, opacity: 0.28), lineWidth: 0.75)
            }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(HueAppStorage.appearanceModeKey) private var appearanceModeRawValue = HueAppearanceMode.system.rawValue

    var body: some View {
        HStack(spacing: 14) {
            SiriAppGlyph(systemImage: "lightbulb.2.fill")
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hue House")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text(store.statusLine)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(HueTheme.secondaryText(colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            AppearancePicker(selection: $appearanceModeRawValue)

            if store.isWorking {
                ProgressView()
                    .controlSize(.small)
                    .tint(HueTheme.controlTint(colorScheme))
            }

            if store.canControlLights {
                Button {
                    Task { await store.refreshLights() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isWorking)
                .buttonStyle(SiriGlassButtonStyle(tone: .standard, compact: true))

                Button(role: .destructive) {
                    store.forgetBridge()
                } label: {
                    Label("Forget", systemImage: "xmark.circle")
                }
                .disabled(store.isWorking)
                .buttonStyle(SiriGlassButtonStyle(tone: .destructive, compact: true))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .hueGlass(cornerRadius: 26, tint: HueTheme.glassTint(colorScheme, opacity: 0.07), interactive: true)
    }
}

private struct AppearancePicker: View {
    @Binding var selection: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HueAppearanceMode.allCases) { mode in
                Button {
                    selection = mode.rawValue
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 32, height: 24)
                        .foregroundStyle(foregroundColor(for: mode))
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(backgroundColor(for: mode))
                        }
                }
                .buttonStyle(.plain)
                .help("\(mode.title) appearance")
                .accessibilityLabel("\(mode.title) appearance")
            }
        }
        .padding(3)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(HueTheme.hairline(colorScheme, opacity: 0.18), lineWidth: 0.75)
        }
        .fixedSize()
        .help("Appearance")
    }

    private func foregroundColor(for mode: HueAppearanceMode) -> Color {
        guard selection == mode.rawValue else {
            return HueTheme.secondaryText(colorScheme)
        }

        return colorScheme == .dark ? .black : .white
    }

    private func backgroundColor(for mode: HueAppearanceMode) -> Color {
        guard selection == mode.rawValue else {
            return .clear
        }

        return HueTheme.primaryText(colorScheme)
    }
}

private struct PairingView: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var isManualIPAddressVisible = false

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect Your Bridge")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Hue House searches the network your Mac is using, then pairs after you press the bridge button.")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(HueTheme.secondaryText(colorScheme))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Automatic Discovery", systemImage: "wifi")
                        .font(.system(.title3, design: .rounded).weight(.semibold))

                    Text("Scanning \(store.localDiscoveryDescription), then checking Philips Hue discovery.")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(HueTheme.secondaryText(colorScheme))

                    Button {
                        Task { await store.discoverBridges() }
                    } label: {
                        Label(
                            store.isWorking ? "Searching Current Network" : "Find Hue Bridge",
                            systemImage: "dot.radiowaves.left.and.right"
                        )
                        .frame(minWidth: 190)
                    }
                    .disabled(store.isWorking)
                    .buttonStyle(SiriGlassButtonStyle(tone: .prominent))

                    if !HueBridgeClient.normalizedHost(from: store.bridgeHost).isEmpty {
                        Label("Selected \(HueBridgeClient.normalizedHost(from: store.bridgeHost))", systemImage: "checkmark.circle.fill")
                            .font(.system(.callout, design: .rounded))
                            .foregroundStyle(HueTheme.secondaryText(colorScheme))
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await store.pairBridge() }
                    } label: {
                        Label("Pair Bridge", systemImage: "link")
                            .frame(minWidth: 126)
                    }
                    .buttonStyle(SiriGlassButtonStyle(tone: .prominent))
                    .disabled(!store.canAttemptPairing || store.isWorking)

                    Text(store.pairingHint)
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(HueTheme.secondaryText(colorScheme))
                        .lineLimit(2)
                }

                Divider()
                    .overlay(HueTheme.hairline(colorScheme, opacity: 0.16))

                DisclosureGroup(isExpanded: $isManualIPAddressVisible) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Use this only if automatic discovery cannot see your bridge.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(HueTheme.secondaryText(colorScheme))

                        TextField("Bridge IP address", text: $store.bridgeHost)
                            .font(.system(.body, design: .monospaced))
                            .siriTextFieldChrome()
                            .disabled(store.isWorking)
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Manual IP address", systemImage: "number")
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(HueTheme.primaryText(colorScheme))

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                Label("Hue Bridges", systemImage: "network")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(HueTheme.primaryText(colorScheme))

                if store.discoveredBridges.isEmpty {
                    if store.isWorking {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(HueTheme.controlTint(colorScheme))
                            Text("Searching \(store.localDiscoveryDescription)")
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(HueTheme.secondaryText(colorScheme))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ContentUnavailableView(
                            store.hasAttemptedDiscovery ? "No Bridge Found" : "Ready to Search",
                            systemImage: store.hasAttemptedDiscovery ? "network.slash" : "dot.radiowaves.left.and.right",
                            description: Text(store.hasAttemptedDiscovery ? "Make sure this Mac is on the same Wi-Fi network as the Hue Bridge." : "Hue House will search automatically from this Mac's current network.")
                        )
                        .foregroundStyle(HueTheme.secondaryText(colorScheme))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ForEach(store.discoveredBridges) { bridge in
                        let isSelected = HueBridgeClient.normalizedHost(from: store.bridgeHost) == bridge.internalIPAddress

                        Button {
                            store.selectBridge(bridge)
                        } label: {
                            HStack {
                                Image(systemName: "network")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bridge.internalIPAddress)
                                        .font(.system(.body, design: .rounded).weight(.medium))
                                    Text(bridge.id)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(HueTheme.secondaryText(colorScheme))
                                }
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                                    .foregroundStyle(isSelected ? HueTheme.primaryText(colorScheme) : HueTheme.tertiaryText(colorScheme))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .hueGlass(cornerRadius: 18, tint: HueTheme.glassTint(colorScheme, opacity: 0.08), interactive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 290)
        }
        .padding(24)
        .hueGlass(cornerRadius: 30, tint: HueTheme.glassTint(colorScheme, opacity: 0.06))
        .task {
            await store.discoverBridgesIfNeeded()
        }
    }
}

private struct LightControlView: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            GradientControlPanel()
                .frame(width: 320)

            VStack(spacing: 12) {
                LightToolbar()

                if store.lights.isEmpty {
                    ContentUnavailableView(
                        "No Lights Found",
                        systemImage: "lightbulb.slash",
                        description: Text("Hue House is paired, but the bridge did not return any light resources.")
                    )
                    .foregroundStyle(HueTheme.secondaryText(colorScheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .hueGlass(cornerRadius: 24, tint: HueTheme.glassTint(colorScheme, opacity: 0.05))
                } else if store.selectedGroupLights.isEmpty {
                    ContentUnavailableView(
                        "No Lights in \(store.selectedGroup.name)",
                        systemImage: "square.3.layers.3d.slash",
                        description: Text("Choose another room or zone from Gradient Studio.")
                    )
                    .foregroundStyle(HueTheme.secondaryText(colorScheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .hueGlass(cornerRadius: 24, tint: HueTheme.glassTint(colorScheme, opacity: 0.05))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(store.selectedGroupLights) { light in
                                LightRow(light: light)
                                    .environmentObject(store)
                            }
                        }
                        .padding(3)
                    }
                    .scrollIndicators(.visible)
                }
            }
        }
    }
}

private struct GradientControlPanel: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.colorScheme) private var colorScheme

    private var selectedGroupLightCount: Int {
        store.selectedGroupLights.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Gradient Studio", systemImage: "paintpalette.fill")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text("\(selectedGroupLightCount) lights selected")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(HueTheme.secondaryText(colorScheme))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Group")
                    .siriSectionTitle()

                Picker("Group", selection: $store.selectedGroupID) {
                    ForEach(store.availableGroups) { group in
                        Label(
                            "\(group.name) · \(store.lightCount(in: group))",
                            systemImage: group.systemImage
                        )
                        .tag(group.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .buttonStyle(SiriGlassButtonStyle(tone: .quiet, fullWidth: true))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Palettes")
                    .siriSectionTitle()

                ForEach(HueGradientPreset.all) { preset in
                    GradientPresetButton(
                        preset: preset,
                        isSelected: store.selectedGradientID == preset.id
                    ) {
                        store.selectedGradientID = preset.id
                        Task { await store.applySelectedGradient() }
                    }
                    .disabled(store.isWorking || selectedGroupLightCount == 0)
                }
            }

            Spacer(minLength: 0)

            Button {
                Task { await store.applySelectedGradient() }
            } label: {
                Label("Apply \(store.selectedGradient.title)", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SiriGlassButtonStyle(tone: .prominent, fullWidth: true))
            .controlSize(.large)
            .disabled(store.isWorking || selectedGroupLightCount == 0)
        }
        .padding(18)
        .hueGlass(cornerRadius: 30, tint: HueTheme.glassTint(colorScheme, opacity: 0.07))
    }
}

private struct GradientPresetButton: View {
    let preset: HueGradientPreset
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HuePaletteStrip(colors: preset.colors)
                    .frame(width: 62, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(HueTheme.hairline(colorScheme, opacity: 0.26), lineWidth: 0.9)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    Text(preset.subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(HueTheme.secondaryText(colorScheme))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? HueTheme.primaryText(colorScheme) : HueTheme.tertiaryText(colorScheme))
            }
            .padding(11)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .hueGlass(
                cornerRadius: 20,
                tint: HueTheme.glassTint(colorScheme, opacity: isSelected ? 0.12 : 0.045),
                interactive: true
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LightToolbar: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Task { await store.setAllLights(on: true) }
            } label: {
                Label("All On", systemImage: "power.circle.fill")
            }
            .disabled(store.lights.isEmpty || store.isWorking)
            .buttonStyle(SiriGlassButtonStyle(tone: .standard, compact: true))

            Button {
                Task { await store.setAllLights(on: false) }
            } label: {
                Label("All Off", systemImage: "power.circle")
            }
            .disabled(store.lights.isEmpty || store.isWorking)
            .buttonStyle(SiriGlassButtonStyle(tone: .quiet, compact: true))

            Spacer()

            Picker("Preset", selection: Binding(
                get: { HuePreset.none },
                set: { preset in
                    guard preset != .none else { return }
                    Task { await store.applyPresetToAll(preset) }
                }
            )) {
                ForEach(HuePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 154)
            .disabled(store.lights.isEmpty || store.isWorking)
            .buttonStyle(SiriGlassButtonStyle(tone: .quiet, compact: true))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .hueGlass(cornerRadius: 24, tint: HueTheme.glassTint(colorScheme, opacity: 0.055), interactive: true)
    }
}

private struct LightRow: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.colorScheme) private var colorScheme
    let light: HueLight

    @State private var brightness: Double = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: light.isOn ? "lightbulb.led.fill" : "lightbulb.led")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(light.isOn ? HueTheme.primaryText(colorScheme) : HueTheme.tertiaryText(colorScheme))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(light.name)
                        .font(.system(.headline, design: .rounded))
                    Text(light.detailLine)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(HueTheme.secondaryText(colorScheme))
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { light.isOn },
                    set: { newValue in
                        Task { await store.setLight(light.id, on: newValue) }
                    }
                ))
                .toggleStyle(.switch)
                .tint(HueTheme.controlTint(colorScheme))
                .labelsHidden()
                .disabled(store.isWorking)
            }

            HStack(spacing: 12) {
                Image(systemName: "sun.min")
                    .foregroundStyle(HueTheme.secondaryText(colorScheme))

                Slider(value: $brightness, in: 1...100, step: 1) { editing in
                    if !editing {
                        Task { await store.setLight(light.id, brightness: brightness) }
                    }
                }
                .disabled(!light.supportsDimming || store.isWorking)
                .tint(HueTheme.controlTint(colorScheme))

                Text("\(Int(brightness.rounded()))%")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(HueTheme.secondaryText(colorScheme))
                    .frame(width: 46, alignment: .trailing)
            }

            HStack(spacing: 8) {
                ForEach(HuePreset.rowPresets) { preset in
                    Button {
                        Task { await store.applyPreset(preset, to: light.id) }
                    } label: {
                        Label(preset.title, systemImage: preset.systemImage)
                    }
                    .disabled(!light.canApply(preset) || store.isWorking)
                    .buttonStyle(SiriGlassButtonStyle(tone: .quiet, compact: true))
                }
            }
        }
        .padding(14)
        .hueGlass(cornerRadius: 22, tint: HueTheme.glassTint(colorScheme, opacity: light.isOn ? 0.10 : 0.04), interactive: true)
        .onAppear {
            brightness = light.brightness
        }
        .onChange(of: light.brightness) { _, newValue in
            brightness = newValue
        }
    }
}
