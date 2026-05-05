import HueKit
import SwiftUI

struct GradientsView: View {
    @EnvironmentObject private var store: HueStore
    @State private var isImporting = false

    var body: some View {
        Group {
            if store.canControlLights {
                content
            } else {
                ContentUnavailableView(
                    "No Bridge Connected",
                    systemImage: "wifi.router",
                    description: Text("Pair your bridge first to apply gradients.")
                )
            }
        }
        .navigationTitle("Gradients")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isImporting = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .disabled(!store.canControlLights || store.isWorking)
            }
        }
        .sheet(isPresented: $isImporting) {
            ImportGradientSheet()
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
            } footer: {
                Text("\(store.selectedGroupLights.count) lights selected")
            }

            Section("Palettes") {
                ForEach(store.availableGradients) { preset in
                    GradientRow(
                        preset: preset,
                        isSelected: store.selectedGradientID == preset.id,
                        onSelect: {
                            store.selectedGradientID = preset.id
                            Task { await store.applySelectedGradient() }
                        },
                        onDelete: preset.isCustom ? {
                            store.removeCustomGradient(id: preset.id)
                        } : nil
                    )
                }
            }

            Section {
                Button {
                    Task { await store.applySelectedGradient() }
                } label: {
                    Label("Apply \(store.selectedGradient.title)", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isWorking || store.selectedGroupLights.isEmpty)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct GradientRow: View {
    let preset: HueGradientPreset
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                LinearGradient(
                    colors: preset.colors.map {
                        Color(red: $0.red, green: $0.green, blue: $0.blue)
                    },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 56, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.title).font(.body.weight(.medium))
                    Text(preset.subtitle).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
        .swipeActions(edge: .trailing) {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
