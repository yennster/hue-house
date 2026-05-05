import SwiftUI

struct HueMenuBarView: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(HueAppStorage.hidesDockIconKey) private var hidesDockIcon = false

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
            HStack(spacing: 8) {
                menuButton(title: "All On", systemImage: "power.circle.fill") {
                    Task { await store.setAllLights(on: true) }
                }
                .disabled(store.lights.isEmpty || store.isWorking)

                menuButton(title: "All Off", systemImage: "power.circle") {
                    Task { await store.setAllLights(on: false) }
                }
                .disabled(store.lights.isEmpty || store.isWorking)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }

        Divider()

        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Gradients")
            VStack(spacing: 4) {
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
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isWorking || store.selectedGroupLights.isEmpty)
                }
            }
            .padding(.bottom, 4)
        }

        Divider()

        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Quick Color")
            HStack(spacing: 6) {
                ForEach(HuePreset.rowPresets) { preset in
                    Button {
                        Task { await store.applyPresetToAll(preset) }
                    } label: {
                        Image(systemName: preset.systemImage)
                            .frame(maxWidth: .infinity, minHeight: 24)
                            .help(preset.title)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.lights.isEmpty || store.isWorking)
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
        HStack(spacing: 8) {
            Button {
                Task { await store.refreshLights() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(!store.canControlLights || store.isWorking)

            Spacer()

            Button {
                openMainWindow()
            } label: {
                Text("Open App")
            }
            .buttonStyle(.borderless)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
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

    private func menuButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}

struct HueMenuBarLabel: View {
    @EnvironmentObject private var store: HueStore

    var body: some View {
        Image(systemName: store.canControlLights ? "lightbulb.2.fill" : "lightbulb.slash")
            .symbolRenderingMode(.monochrome)
    }
}
