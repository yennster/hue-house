import HueKit
import SwiftUI

struct BridgeView: View {
    @EnvironmentObject private var store: HueStore
    @AppStorage(HueAppStorage.appearanceModeKey) private var appearanceMode = "system"
    @State private var manualHost: String = ""
    @State private var isManualVisible = false

    var body: some View {
        Form {
            if store.canControlLights {
                connectedSection
            } else {
                pairingSection
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearanceMode) {
                    Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                    Label("Light", systemImage: "sun.max.fill").tag("light")
                    Label("Dark", systemImage: "moon.fill").tag("dark")
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Bridge")
        .task {
            await store.discoverBridgesIfNeeded()
        }
    }

    @ViewBuilder
    private var connectedSection: some View {
        Section("Connected") {
            LabeledContent("Address") {
                Text(HueBridgeClient.normalizedHost(from: store.bridgeHost))
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Lights") {
                Text("\(store.lights.count)")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Groups") {
                Text("\(store.groups.count)")
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            Button {
                Task { await store.refreshLights() }
            } label: {
                Label("Refresh Lights", systemImage: "arrow.clockwise")
            }
            .disabled(store.isWorking)

            Button {
                Task { await store.discoverBridges() }
            } label: {
                Label("Re-Discover Bridges", systemImage: "dot.radiowaves.left.and.right")
            }
            .disabled(store.isWorking)

            Button(role: .destructive) {
                store.forgetBridge()
            } label: {
                Label("Forget Bridge", systemImage: "xmark.circle")
            }
            .disabled(store.isWorking)
        }

        if !store.skippedLightIDs.isEmpty {
            Section {
                Button {
                    store.resetSkippedLights()
                } label: {
                    Label("Reset \(store.skippedLightIDs.count) skipped lights", systemImage: "arrow.uturn.backward")
                }
            } footer: {
                Text("Lights that errored earlier this session are being skipped.")
            }
        }
    }

    @ViewBuilder
    private var pairingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connect Your Bridge")
                    .font(.title2.weight(.semibold))
                Text("Hue House searches the Wi-Fi network this device is on, then pairs after you press the bridge button.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }

        Section("Discovery") {
            Button {
                Task { await store.discoverBridges() }
            } label: {
                Label(
                    store.isWorking ? "Searching…" : "Find Hue Bridge",
                    systemImage: "dot.radiowaves.left.and.right"
                )
            }
            .disabled(store.isWorking)

            if !store.discoveredBridges.isEmpty {
                ForEach(store.discoveredBridges) { bridge in
                    let isSelected = HueBridgeClient.normalizedHost(from: store.bridgeHost) == bridge.internalIPAddress
                    Button {
                        store.selectBridge(bridge)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bridge.internalIPAddress)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(bridge.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } else if store.hasAttemptedDiscovery {
                Text("No bridge found. Make sure this device is on the same Wi-Fi network.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            Button {
                Task { await store.pairBridge() }
            } label: {
                Label("Pair Bridge", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canAttemptPairing || store.isWorking)
        } footer: {
            Text(store.pairingHint)
        }

        Section {
            DisclosureGroup("Manual IP address", isExpanded: $isManualVisible) {
                TextField("192.168.1.x", text: $store.bridgeHost)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } footer: {
            Text("Use this only if automatic discovery cannot see your bridge.")
        }
    }
}
