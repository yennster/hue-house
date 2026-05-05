import HueKit
import SwiftUI

struct LightsView: View {
    @EnvironmentObject private var store: HueStore

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
                    Task { await store.refreshLights() }
                } label: {
                    Image(systemName: "arrow.clockwise")
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
                HStack(spacing: 12) {
                    Button {
                        Task { await store.setAllLights(on: true) }
                    } label: {
                        Label("All On", systemImage: "power.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        Task { await store.setAllLights(on: false) }
                    } label: {
                        Label("All Off", systemImage: "power.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(store.lights.isEmpty || store.isWorking)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: light.isOn ? "lightbulb.led.fill" : "lightbulb.led")
                .font(.title3)
                .foregroundStyle(light.isOn ? .yellow : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(light.name)
                        .font(.body.weight(.medium))
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
        .opacity(isUnreachable ? 0.55 : 1.0)
    }
}
