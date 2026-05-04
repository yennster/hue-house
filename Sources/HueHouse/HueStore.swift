import Foundation

@MainActor
final class HueStore: ObservableObject {
    @Published var bridgeHost: String {
        didSet { UserDefaults.standard.set(bridgeHost, forKey: HueAppStorage.bridgeHostKey) }
    }
    @Published var discoveredBridges: [HueBridgeDiscovery] = []
    @Published var lights: [HueLight] = []
    @Published var groups: [HueLightGroup] = []
    @Published var selectedGroupID = HueLightGroup.allLightsID
    @Published var selectedGradientID = HueGradientPreset.fallback.id
    @Published var isWorking = false
    @Published var errorAlert: HueErrorAlert?
    @Published var hasAttemptedDiscovery = false
    @Published var customGradients: [HueGradientPreset] = [] {
        didSet { persistCustomGradients() }
    }

    /// Lights that returned errors (typically HTTP 429) during the current
    /// session. Skipped for the remainder of the session so gradient applies
    /// don't waste time on a bulb the bridge keeps refusing. Cleared when the
    /// user forgets the bridge or relaunches the app.
    @Published private(set) var skippedLightIDs: Set<String> = []

    var localDiscoveryDescription: String {
        HueBridgeClient.localDiscoveryDescription()
    }

    private var applicationKey: String? {
        didSet {
            if let applicationKey {
                try? KeychainStore.save(applicationKey)
            } else {
                try? KeychainStore.delete()
            }
        }
    }

    init() {
        bridgeHost = UserDefaults.standard.string(forKey: HueAppStorage.bridgeHostKey) ?? ""
        applicationKey = KeychainStore.read()
        if let data = UserDefaults.standard.data(forKey: HueAppStorage.customGradientsKey),
           let decoded = try? JSONDecoder().decode([HueGradientPreset].self, from: data) {
            customGradients = decoded
        }
    }

    var availableGradients: [HueGradientPreset] {
        HueGradientPreset.all + customGradients
    }

    func addCustomGradient(title: String, css: String) throws -> HueGradientPreset {
        let parsedColors = try HueCSSGradient.parse(css)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? defaultCustomTitle() : trimmedTitle
        let preset = HueGradientPreset(
            id: "custom-\(UUID().uuidString)",
            title: resolvedTitle,
            subtitle: "Imported · \(parsedColors.count) stops",
            brightness: 78,
            fallbackMirek: 300,
            colors: parsedColors,
            isCustom: true
        )
        customGradients.append(preset)
        selectedGradientID = preset.id
        return preset
    }

    func removeCustomGradient(id: String) {
        customGradients.removeAll { $0.id == id }
        if selectedGradientID == id {
            selectedGradientID = HueGradientPreset.fallback.id
        }
    }

    private func defaultCustomTitle() -> String {
        let existing = customGradients.compactMap { preset -> Int? in
            guard preset.title.hasPrefix("Custom ") else { return nil }
            return Int(preset.title.dropFirst("Custom ".count))
        }
        let next = (existing.max() ?? 0) + 1
        return "Custom \(next)"
    }

    private func persistCustomGradients() {
        let defaults = UserDefaults.standard
        guard !customGradients.isEmpty else {
            defaults.removeObject(forKey: HueAppStorage.customGradientsKey)
            return
        }
        if let data = try? JSONEncoder().encode(customGradients) {
            defaults.set(data, forKey: HueAppStorage.customGradientsKey)
        }
    }

    var canControlLights: Bool {
        !normalizedBridgeHost.isEmpty && applicationKey != nil
    }

    var canAttemptPairing: Bool {
        !normalizedBridgeHost.isEmpty
    }

    var statusLine: String {
        if canControlLights {
            let count = lights.count
            let lightLabel = count == 1 ? "1 light" : "\(count) lights"
            let groupLabel = groups.count == 1 ? "1 group" : "\(groups.count) groups"
            return "Connected to \(normalizedBridgeHost) · \(lightLabel) · \(groupLabel)"
        }

        if normalizedBridgeHost.isEmpty {
            return "No bridge connected"
        }

        return "Bridge selected: \(normalizedBridgeHost)"
    }

    var pairingHint: String {
        if normalizedBridgeHost.isEmpty {
            return "Hue House can usually find the bridge from your Mac's current network."
        }

        return "Press the physical bridge button first if pairing asks for it."
    }

    private var normalizedBridgeHost: String {
        HueBridgeClient.normalizedHost(from: bridgeHost)
    }

    var availableGroups: [HueLightGroup] {
        [HueLightGroup.allLights] + groups
    }

    var selectedGroup: HueLightGroup {
        availableGroups.first { $0.id == selectedGroupID } ?? HueLightGroup.allLights
    }

    var selectedGradient: HueGradientPreset {
        availableGradients.first { $0.id == selectedGradientID } ?? .fallback
    }

    var selectedGroupLights: [HueLight] {
        lights(in: selectedGroupID)
    }

    func selectBridge(_ bridge: HueBridgeDiscovery) {
        bridgeHost = bridge.internalIPAddress
    }

    func discoverBridges() async {
        await run("Could not discover Hue Bridges.") {
            hasAttemptedDiscovery = true
            discoveredBridges = try await HueBridgeClient.discoverBridges()

            if bridgeHost.isEmpty, let firstBridge = discoveredBridges.first {
                bridgeHost = firstBridge.internalIPAddress
            }
        }
    }

    func discoverBridgesIfNeeded() async {
        guard !canControlLights, !hasAttemptedDiscovery else { return }
        await discoverBridges()
    }

    func pairBridge() async {
        await run("Could not pair with the Hue Bridge.") {
            let client = HueBridgeClient(host: normalizedBridgeHost)
            let key = try await client.createApplicationKey()
            applicationKey = key
            try await refreshResourcesWithoutSpinner()
        }
    }

    func refreshLightsIfReady() async {
        guard canControlLights else { return }
        await refreshLights()
    }

    func refreshLights() async {
        await run("Could not refresh lights.") {
            try await refreshResourcesWithoutSpinner()
        }
    }

    func setAllLights(on: Bool) async {
        let lightIDs = lights.map(\.id)
        await run("Could not update all lights.") {
            let client = try currentClient()
            for id in lightIDs {
                try await client.setLight(id: id, on: on)
            }
            try await refreshResourcesWithoutSpinner()
        }
    }

    func setLight(_ id: String, on: Bool) async {
        await run("Could not update the light.") {
            let client = try currentClient()
            try await client.setLight(id: id, on: on)
            updateCachedLight(id: id) { light in
                light.on = HueOnState(on: on)
            }
        }
    }

    func setLight(_ id: String, brightness: Double) async {
        await run("Could not update brightness.") {
            let client = try currentClient()
            try await client.setLight(id: id, brightness: brightness)
            updateCachedLight(id: id) { light in
                light.dimming = HueDimming(brightness: brightness, minDimLevel: light.dimming?.minDimLevel)
            }
        }
    }

    func applyPreset(_ preset: HuePreset, to id: String) async {
        guard preset != .none else { return }
        await run("Could not apply preset.") {
            let client = try currentClient()
            try await client.applyPreset(preset, to: id)
            try await refreshResourcesWithoutSpinner()
        }
    }

    func applyPresetToAll(_ preset: HuePreset) async {
        guard preset != .none else { return }
        let lightIDs = lights.map(\.id)
        await run("Could not apply preset to all lights.") {
            let client = try currentClient()
            for id in lightIDs {
                try await client.applyPreset(preset, to: id)
            }
            try await refreshResourcesWithoutSpinner()
        }
    }

    func applySelectedGradient() async {
        let targetLights = selectedGroupLights
        let gradient = selectedGradient

        await run("Could not apply gradient.") {
            guard !targetLights.isEmpty else {
                throw HueAppError.bridgeRejected("No lights were found in \(selectedGroup.name).")
            }

            let client = try currentClient()

            // The Hue Bridge accepts ~10 writes/sec. Cap concurrency to stay
            // under that ceiling and rely on the client's automatic 429 retry
            // for transient overruns.
            let maxConcurrent = min(4, targetLights.count)
            let total = targetLights.count

            let failures: [(HueLight, Error)] = await withTaskGroup(
                of: (HueLight, Error?).self
            ) { group in
                var iterator = targetLights.enumerated().makeIterator()
                var inFlight = 0

                func enqueueNext() {
                    guard let next = iterator.next() else { return }
                    inFlight += 1
                    group.addTask {
                        do {
                            try await client.applyGradient(
                                gradient,
                                to: next.element,
                                index: next.offset,
                                total: total
                            )
                            return (next.element, nil)
                        } catch {
                            return (next.element, error)
                        }
                    }
                }

                for _ in 0..<maxConcurrent { enqueueNext() }

                var collected: [(HueLight, Error)] = []
                while inFlight > 0, let result = await group.next() {
                    inFlight -= 1
                    if let error = result.1 {
                        collected.append((result.0, error))
                    }
                    enqueueNext()
                }
                return collected
            }

            try await refreshResourcesWithoutSpinner()

            if !failures.isEmpty {
                throw HueAppError.partialGradient(
                    failed: failures.map(\.0.name),
                    total: total,
                    underlying: failures.first?.1
                )
            }
        }
    }

    func forgetBridge() {
        bridgeHost = ""
        applicationKey = nil
        discoveredBridges = []
        hasAttemptedDiscovery = false
        lights = []
        groups = []
        selectedGroupID = HueLightGroup.allLightsID
        selectedGradientID = HueGradientPreset.fallback.id
    }

    func lights(in groupID: String) -> [HueLight] {
        guard let group = availableGroups.first(where: { $0.id == groupID }) else {
            return lights
        }

        return lights.filter { group.contains($0) }
    }

    func lightCount(in group: HueLightGroup) -> Int {
        lights(in: group.id).count
    }

    private func refreshResourcesWithoutSpinner() async throws {
        let client = try currentClient()

        async let fetchedLights = client.fetchLights()
        async let fetchedGroups = client.fetchGroups()

        lights = try await fetchedLights.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        groups = try await fetchedGroups.sorted {
            if $0.kindTitle == $1.kindTitle {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.kindTitle < $1.kindTitle
        }

        if !availableGroups.contains(where: { $0.id == selectedGroupID }) {
            selectedGroupID = HueLightGroup.allLightsID
        }
    }

    private func currentClient() throws -> HueBridgeClient {
        guard let applicationKey else {
            throw HueAppError.missingApplicationKey
        }

        return HueBridgeClient(host: normalizedBridgeHost, applicationKey: applicationKey)
    }

    private func updateCachedLight(id: String, change: (inout HueLight) -> Void) {
        guard let index = lights.firstIndex(where: { $0.id == id }) else { return }
        change(&lights[index])
    }

    private func run(_ fallbackMessage: String, operation: () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }

        do {
            try await operation()
        } catch {
            let detail = HueAppError.detail(for: error)
            errorAlert = HueErrorAlert(
                title: HueAppError.formatted(fallbackMessage),
                message: detail
            )
        }
    }
}

struct HueErrorAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
