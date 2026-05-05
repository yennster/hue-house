import HueKit
import SwiftUI

struct HueMenuBarView: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(HueAppStorage.hidesDockIconKey) private var hidesDockIcon = false

    @State private var brightness: Double = 100
    @State private var isEditingBrightness = false

    private var brightnessDisabled: Bool {
        store.selectedGroupLights.filter(\.supportsDimming).isEmpty || store.isWorking
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if store.canControlLights {
                connectedBody
            } else {
                disconnectedBody
            }

            Divider()
            settings
            Divider()
            footer
        }
        .frame(width: 320)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var settings: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Settings")
            Toggle(isOn: $hidesDockIcon) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hide Dock icon")
                        .font(.system(.callout, design: .rounded))
                    Text("Run from the menu bar only")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            HuePaletteStrip(colors: store.selectedGradient.colors)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Hue House")
                    .font(.system(.headline, design: .rounded))
                Text(store.canControlLights
                     ? "\(store.lights.count) lights · \(store.selectedGroup.name)"
                     : "Bridge not connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var connectedBody: some View {
        Section {
            Picker("Room", selection: $store.selectedGroupID) {
                ForEach(store.availableGroups) { group in
                    Label(group.name, systemImage: group.systemImage).tag(group.id)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }

        Divider()

        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Power")
            HStack(spacing: 4) {
                Button {
                    Task { await store.setAllLights(on: true) }
                } label: {
                    Label("All On", systemImage: "power.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MenuRowButtonStyle())
                .disabled(store.lights.isEmpty || store.isWorking)

                Button {
                    Task { await store.setAllLights(on: false) }
                } label: {
                    Label("All Off", systemImage: "power.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MenuRowButtonStyle())
                .disabled(store.lights.isEmpty || store.isWorking)
            }
            .padding(.horizontal, 7)

            HStack(spacing: 8) {
                Image(systemName: "sun.min")
                    .foregroundStyle(.secondary)

                Slider(value: $brightness, in: 1...100, step: 1) { editing in
                    isEditingBrightness = editing
                    if !editing {
                        Task { await store.setAllLights(brightness: brightness) }
                    }
                }
                .controlSize(.small)
                .disabled(brightnessDisabled)

                Text("\(Int(brightness.rounded()))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .onAppear { brightness = store.selectedGroupBrightness }
            .onChange(of: store.selectedGroupID) { _, _ in
                brightness = store.selectedGroupBrightness
            }
            .onChange(of: store.selectedGroupBrightness) { _, newValue in
                if !isEditingBrightness { brightness = newValue }
            }
        }

        Divider()

        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Gradients")
            VStack(spacing: 0) {
                ForEach(store.availableGradients) { preset in
                    Button {
                        store.selectedGradientID = preset.id
                        Task { await store.applySelectedGradient() }
                    } label: {
                        HStack(spacing: 10) {
                            HuePaletteStrip(colors: preset.colors)
                                .frame(width: 36, height: 18)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            Text(preset.title)
                                .font(.system(.callout, design: .rounded))
                            Spacer()
                            if store.selectedGradientID == preset.id {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                    .buttonStyle(MenuRowButtonStyle())
                    .disabled(store.isWorking || store.selectedGroupLights.isEmpty)
                }
            }
            .padding(.horizontal, 7)
            .padding(.bottom, 4)
        }

        Divider()

        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Quick Color")
            HStack(spacing: 6) {
                ForEach(HuePreset.rowPresets) { preset in
                    QuickColorButton(
                        preset: preset,
                        disabled: store.lights.isEmpty || store.isWorking
                    ) {
                        Task { await store.applyPresetToAll(preset) }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var disconnectedBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connect a Hue Bridge to control your lights from the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                openMainWindow()
            } label: {
                Label("Open Hue House", systemImage: "wifi.router.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Button {
                Task { await store.refreshLights() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(MenuRowButtonStyle())
            .disabled(!store.canControlLights || store.isWorking)

            Spacer(minLength: 0)

            Button {
                openMainWindow()
            } label: {
                Text("Open App")
            }
            .buttonStyle(MenuRowButtonStyle())

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
            }
            .buttonStyle(MenuRowButtonStyle())
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 7)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.top, 6)
    }

    private func openMainWindow() {
        // If the main window is still around (just hidden / behind other apps),
        // bring it forward. Otherwise SwiftUI needs to be asked explicitly to
        // create a new one — `NSApp.windows` is empty after the last main
        // window was closed and just calling `activate` won't restore it.
        if let existing = NSApp.windows.first(where: { $0.canBecomeMain }) {
            existing.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct HueMenuBarLabel: View {
    @EnvironmentObject private var store: HueStore

    var body: some View {
        Image(systemName: store.canControlLights ? "lightbulb.2.fill" : "lightbulb.slash")
            .symbolRenderingMode(.monochrome)
    }
}

private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuRowButtonStyleBody(configuration: configuration)
    }
}

private struct MenuRowButtonStyleBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isHighlighted ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(backgroundFill)
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1.0 : 0.4)
            .onHover { hovering in
                guard isEnabled else { return }
                isHovering = hovering
            }
    }

    private var isHighlighted: Bool {
        isEnabled && (isHovering || configuration.isPressed)
    }

    private var backgroundFill: Color {
        guard isEnabled else { return .clear }
        if configuration.isPressed { return Color.accentColor.opacity(0.85) }
        if isHovering { return Color.accentColor }
        return .clear
    }
}

private struct QuickColorButton: View {
    let preset: HuePreset
    let disabled: Bool
    let action: () -> Void
    @State private var isHovering = false

    private var presetColor: Color {
        switch preset {
        case .warm: Color(red: 1.0, green: 0.74, blue: 0.43)
        case .cool: Color(red: 0.78, green: 0.92, blue: 1.0)
        case .red: Color(red: 0.93, green: 0.27, blue: 0.27)
        case .green: Color(red: 0.34, green: 0.79, blue: 0.40)
        case .blue: Color(red: 0.30, green: 0.55, blue: 0.96)
        case .none: Color.clear
        }
    }

    private var isActive: Bool { isHovering && !disabled }

    var body: some View {
        Button(action: action) {
            Image(systemName: preset.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 22)
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isActive ? presetColor : Color.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(preset.title)
        .disabled(disabled)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }
}
