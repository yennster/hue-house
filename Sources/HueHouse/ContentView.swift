import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: HueTab = .lights

    var body: some View {
        ZStack {
            HueLiquidBackground()

            VStack(spacing: 16) {
                HeaderView()

                if store.canControlLights {
                    HueTabBar(selection: $selectedTab, badges: tabBadges, tabs: visibleTabs)
                }

                Group {
                    switch effectiveTab {
                    case .lights:
                        LightControlView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .bridge:
                        BridgeTabView()
                            .frame(maxWidth: .infinity)
                    }
                }
                .transition(.opacity)
            }
            .padding(18)
        }
        .foregroundStyle(HueTheme.primaryText(colorScheme))
        .tint(HueTheme.controlTint(colorScheme))
        .symbolRenderingMode(.monochrome)
        .alert(
            store.errorAlert?.title ?? "",
            isPresented: Binding(
                get: { store.errorAlert != nil },
                set: { if !$0 { store.errorAlert = nil } }
            ),
            presenting: store.errorAlert
        ) { _ in
            Button("OK", role: .cancel) {
                store.errorAlert = nil
            }
        } message: { alert in
            Text(alert.message)
        }
        .onChange(of: store.canControlLights) { _, canControl in
            if !canControl { selectedTab = .bridge }
        }
        .onAppear {
            if !store.canControlLights { selectedTab = .bridge }
        }
        .animation(.snappy(duration: 0.18), value: effectiveTab)
    }

    private var effectiveTab: HueTab {
        store.canControlLights ? selectedTab : .bridge
    }

    private var visibleTabs: [HueTab] {
        store.canControlLights ? HueTab.allCases : [.bridge]
    }

    private var tabBadges: [HueTab: String] {
        var badges: [HueTab: String] = [:]
        if store.canControlLights {
            badges[.lights] = "\(store.lights.count)"
        }
        return badges
    }
}

enum HueTab: Hashable, CaseIterable {
    case lights, bridge

    var title: String {
        switch self {
        case .lights: return "Lights"
        case .bridge: return "Bridge"
        }
    }

    var systemImage: String {
        switch self {
        case .lights: return "lightbulb.2.fill"
        case .bridge: return "wifi.router.fill"
        }
    }
}

private struct HueTabBar: View {
    @Binding var selection: HueTab
    let badges: [HueTab: String]
    let tabs: [HueTab]
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tab.title)
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                        if let badge = badges[tab] {
                            Text(badge)
                                .font(.system(.caption2, design: .rounded).weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(HueTheme.primaryText(colorScheme).opacity(selection == tab ? 0.18 : 0.10))
                                )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selection == tab ? HueTheme.primaryText(colorScheme) : HueTheme.secondaryText(colorScheme))
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(HueTheme.primaryText(colorScheme).opacity(colorScheme == .dark ? 0.14 : 0.08))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(HueTheme.hairline(colorScheme, opacity: 0.22), lineWidth: 0.75)
                                }
                                .matchedGeometryEffect(id: "selectedTab", in: indicator)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HueTheme.hairline(colorScheme, opacity: 0.18), lineWidth: 0.75)
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
                        .labelStyle(.iconOnly)
                }
                .help("Refresh lights")
                .disabled(store.isWorking)
                .buttonStyle(SiriGlassButtonStyle(tone: .quiet, compact: true))
            }

            AppearancePicker(selection: $appearanceModeRawValue)
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

private struct BridgeTabView: View {
    @EnvironmentObject private var store: HueStore

    var body: some View {
        if store.canControlLights {
            BridgeDetailView()
        } else {
            PairingView()
        }
    }
}

private struct BridgeDetailView: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                SiriAppGlyph(systemImage: "wifi.router.fill")
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                    Text(HueBridgeClient.normalizedHost(from: store.bridgeHost))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(HueTheme.secondaryText(colorScheme))
                    Text(store.statusLine)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(HueTheme.tertiaryText(colorScheme))
                        .lineLimit(2)
                }

                Spacer()
            }

            Divider().overlay(HueTheme.hairline(colorScheme, opacity: 0.16))

            VStack(alignment: .leading, spacing: 10) {
                Text("Bridge Actions")
                    .siriSectionTitle()

                HStack(spacing: 10) {
                    Button {
                        Task { await store.refreshLights() }
                    } label: {
                        Label("Refresh Lights", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isWorking)
                    .buttonStyle(SiriGlassButtonStyle(tone: .standard))

                    Button {
                        Task { await store.discoverBridges() }
                    } label: {
                        Label("Re-Discover", systemImage: "dot.radiowaves.left.and.right")
                    }
                    .disabled(store.isWorking)
                    .buttonStyle(SiriGlassButtonStyle(tone: .quiet))

                    Spacer()

                    Button(role: .destructive) {
                        store.forgetBridge()
                    } label: {
                        Label("Forget Bridge", systemImage: "xmark.circle")
                    }
                    .disabled(store.isWorking)
                    .buttonStyle(SiriGlassButtonStyle(tone: .destructive))
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hueGlass(cornerRadius: 30, tint: HueTheme.glassTint(colorScheme, opacity: 0.06))
    }
}

private struct PairingView: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var isManualIPAddressVisible = false

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ContentUnavailableView(
                            store.hasAttemptedDiscovery ? "No Bridge Found" : "Ready to Search",
                            systemImage: store.hasAttemptedDiscovery ? "network.slash" : "dot.radiowaves.left.and.right",
                            description: Text(store.hasAttemptedDiscovery ? "Make sure this Mac is on the same Wi-Fi network as the Hue Bridge." : "Hue House will search automatically from this Mac's current network.")
                        )
                        .foregroundStyle(HueTheme.secondaryText(colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
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
