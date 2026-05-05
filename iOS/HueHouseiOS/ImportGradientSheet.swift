import HueKit
import SwiftUI

struct ImportGradientSheet: View {
    @EnvironmentObject private var store: HueStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var input: String = ""
    @State private var parsedColors: [HueGradientColor] = []
    @State private var parseError: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Custom gradient", text: $title)
                }

                Section {
                    TextEditor(text: $input)
                        .font(.body.monospaced())
                        .frame(minHeight: 100)
                        .focused($isFocused)
                        .onChange(of: input) { _, _ in updatePreview() }
                } header: {
                    Text("Colors or CSS gradient")
                } footer: {
                    Text("Paste a CSS gradient or just type colors separated by commas — \"red, blue, yellow\", \"#833AB4, #FD1D1D, #FCB045\", or \"linear-gradient(90deg, coral, indigo)\".")
                }

                Section("Preview") {
                    if !parsedColors.isEmpty {
                        LinearGradient(
                            colors: parsedColors.map {
                                Color(red: $0.red, green: $0.green, blue: $0.blue)
                            },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text("\(parsedColors.count) color\(parsedColors.count == 1 ? "" : "s") detected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let parseError {
                        Label(parseError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Text("Type a list of colors or paste a gradient above to see a preview.")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("Import Gradient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(parsedColors.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.async { isFocused = true }
            }
        }
    }

    private func updatePreview() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parsedColors = []
            parseError = nil
            return
        }
        do {
            parsedColors = try HueCSSGradient.parse(input)
            parseError = nil
        } catch {
            parsedColors = []
            parseError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func save() {
        do {
            _ = try store.addCustomGradient(title: title, css: input)
            dismiss()
        } catch {
            parseError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
