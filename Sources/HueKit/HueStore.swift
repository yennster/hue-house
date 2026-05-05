import Foundation

@MainActor
public final class HueStore: ObservableObject {
    @Published public var bridgeHost: String {
        didSet { UserDefaults.standard.set(bridgeHost, forKey: HueAppStorage.bridgeHostKey) }
    }
    @Published public var discoveredBridges: [HueBridgeDiscovery] = []
    @Published public var lights: [HueLight] = []
    @Published public var groups: [HueLightGroup] = []
    @Published public var selectedGroupID = HueLightGroup.allLightsID
    @Published public var selectedGradientID = HueGradientPreset.fallback.id
    @Published public var isWorking = false
    @Published public var errorAlert: HueErrorAlert?
    @Published public var hasAttemptedDiscovery = false
    @Published public var customGradients: [HueGradientPreset] = [] {
        didSet { persistCustomGradients() }
    }

    /// Lights that returned errors (typically HTTP 429) during the current
    /// session. Skipped for the remainder of the session so gradient applies
    /// don't waste time on a bulb the bridge keeps refusing. Cleared when the
    /// user forgets the bridge or relaunches the app.
    @Published public private(set) var skippedLightIDs: Set<String> = []

    public var localDiscoveryDescription: String {
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

    public init() {
        bridgeHost = UserDefaults.standard.string(forKey: HueAppStorage.bridgeHostKey) ?? ""
        applicationKey = KeychainStore.read()
        if let data = UserDefaults.standard.data(forKey: HueAppStorage.customGradientsKey),
           let decoded = try? JSONDecoder().decode([HueGradientPreset].self, from: data) {
            customGradients = decoded
        }
    }

    public var availableGradients: [HueGradientPreset] {
        HueGradientPreset.all + customGradients
    }

    public func addCustomGradient(title: String, css: String) throws -> HueGradientPreset {
        let parsedColors = try HueCSSGradient.parse(css)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? defaultCustomTitle() : trimmedTitle
        let countLabel = parsedColors.count == 1 ? "1 color" : "\(parsedColors.count) colors"
        let preset = HueGradientPreset(
            id: "custom-\(UUID().uuidString)",
            title: resolvedTitle,
            subtitle: "Imported · \(countLabel)",
            brightness: 78,
            fallbackMirek: 300,
            colors: parsedColors,
            isCustom: true
        )
        customGradients.append(preset)
        selectedGradientID = preset.id
        return preset
    }

    public func removeCustomGradient(id: String) {
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

    public var canControlLights: Bool {
        !normalizedBridgeHost.isEmpty && applicationKey != nil
    }

    public var canAttemptPairing: Bool {
        !normalizedBridgeHost.isEmpty
    }

    public var statusLine: String {
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

    public var pairingHint: String {
        if normalizedBridgeHost.isEmpty {
            return "Hue House can usually find the bridge from your Mac's current network."
        }

        return "Press the physical bridge button first if pairing asks for it."
    }

    private var normalizedBridgeHost: String {
        HueBridgeClient.normalizedHost(from: bridgeHost)
    }

    public var availableGroups: [HueLightGroup] {
        [HueLightGroup.allLights] + groups
    }

    public var selectedGroup: HueLightGroup {
        availableGroups.first { $0.id == selectedGroupID } ?? HueLightGroup.allLights
    }

    public var selectedGradient: HueGradientPreset {
        availableGradients.first { $0.id == selectedGradientID } ?? .fallback
    }

    public var selectedGroupLights: [HueLight] {
        lights(in: selectedGroupID)
    }

    public func selectBridge(_ bridge: HueBridgeDiscovery) {
        bridgeHost = bridge.internalIPAddress
    }

    public func discoverBridges() async {
        await run("Could not discover Hue Bridges.") {
            hasAttemptedDiscovery = true
            discoveredBridges = try await HueBridgeClient.discoverBridges()

            if bridgeHost.isEmpty, let firstBridge = discoveredBridges.first {
                bridgeHost = firstBridge.internalIPAddress
            }
        }
    }

    public func discoverBridgesIfNeeded() async {
        guard !canControlLights, !hasAttemptedDiscovery else { return }
        await discoverBridges()
    }

    public func pairBridge() async {
        await run("Could not pair with the Hue Bridge.") {
            let client = HueBridgeClient(host: normalizedBridgeHost)
            let key = try await client.createApplicationKey()
            applicationKey = key
            try await refreshResourcesWithoutSpinner()
        }
    }

    public func refreshLightsIfReady() async {
        guard canControlLights else { return }
        await refreshLights()
    }

    public func refreshLights() async {
        await run("Could not refresh lights.") {
            try await refreshResourcesWithoutSpinner()
        }
    }

    public func setAllLights(on: Bool) async {
        let candidates = selectedGroupLights
        await run("Could not update all lights.") {
            try await self.runBatchUpdate(over: candidates) { client, light, _, _ in
                try await client.setLight(id: light.id, on: on)
            }
        }
    }

    public func setLight(_ id: String, on: Bool) async {
        await runSingleLightUpdate(on: id) {
            let client = try self.currentClient()
            try await client.setLight(id: id, on: on)
            self.updateCachedLight(id: id) { light in
                light.on = HueOnState(on: on)
            }
        }
    }

    public func setLight(_ id: String, brightness: Double) async {
        await runSingleLightUpdate(on: id) {
            let client = try self.currentClient()
            try await client.setLight(id: id, brightness: brightness)
            self.updateCachedLight(id: id) { light in
                light.dimming = HueDimming(brightness: brightness, minDimLevel: light.dimming?.minDimLevel)
            }
        }
    }

    /// Updates a light's color from sRGB components. `alphaPercent` (0…100) is
    /// treated as the bulb's brightness; values <= 0 turn the bulb off rather
    /// than rejecting the request (Hue requires brightness >= 1).
    public func setLight(
        _ id: String,
        red: Double,
        green: Double,
        blue: Double,
        alphaPercent: Double? = nil
    ) async {
        await runSingleLightUpdate(on: id) {
            let client = try self.currentClient()

            if let alphaPercent, alphaPercent <= 0 {
                try await client.setLight(id: id, on: false)
                self.updateCachedLight(id: id) { light in
                    light.on = HueOnState(on: false)
                }
                return
            }

            try await client.setLight(
                id: id,
                red: red,
                green: green,
                blue: blue,
                brightness: alphaPercent
            )
            let converted = HueGradientColor.fromSRGB(red: red, green: green, blue: blue)
            self.updateCachedLight(id: id) { light in
                light.on = HueOnState(on: true)
                light.color = HueColor(xy: HueXY(x: converted.x, y: converted.y))
                if let alphaPercent {
                    light.dimming = HueDimming(
                        brightness: max(1, min(100, alphaPercent)),
                        minDimLevel: light.dimming?.minDimLevel
                    )
                }
            }
        }
    }

    public func applyPreset(_ preset: HuePreset, to id: String) async {
        guard preset != .none else { return }
        await runSingleLightUpdate(on: id) {
            let client = try self.currentClient()
            try await client.applyPreset(preset, to: id)
            try await self.refreshResourcesWithoutSpinner()
        }
    }

    public func applyPresetToAll(_ preset: HuePreset) async {
        guard preset != .none else { return }
        let candidates = lights
        await run("Could not apply preset to all lights.") {
            try await self.runBatchUpdate(over: candidates) { client, light, _, _ in
                try await client.applyPreset(preset, to: light.id)
            }
        }
    }

    public func applySelectedGradient() async {
        let candidates = selectedGroupLights
        let groupName = selectedGroup.name
        let gradient = selectedGradient

        await run("Could not apply gradient.") {
            guard !candidates.isEmpty else {
                throw HueAppError.bridgeRejected("No lights were found in \(groupName).")
            }
            try await self.runBatchUpdate(over: candidates) { client, light, index, total in
                try await client.applyGradient(gradient, to: light, index: index, total: total)
            }
        }
    }

    /// Shared driver for "act on every (or every selected) light" flows. Lights
    /// already in `skippedLightIDs` are filtered out, the operation runs with
    /// capped concurrency, per-light failures are collected and added to the
    /// skip list, and an alert is raised only for *new* failures.
    private func runBatchUpdate(
        over candidates: [HueLight],
        maxConcurrent: Int = 4,
        operation: @escaping @Sendable (HueBridgeClient, HueLight, Int, Int) async throws -> Void
    ) async throws {
        guard !candidates.isEmpty else { return }

        let skipSnapshot = skippedLightIDs
        let targetLights = candidates.filter { !skipSnapshot.contains($0.id) }
        let previouslySkippedCount = candidates.count - targetLights.count

        guard !targetLights.isEmpty else {
            throw HueAppError.bridgeRejected(
                "All target lights were skipped earlier this session. Reset the skip list to try again."
            )
        }

        let client = try currentClient()
        let total = targetLights.count
        let concurrent = min(maxConcurrent, total)

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
                        try await operation(client, next.element, next.offset, total)
                        return (next.element, nil)
                    } catch {
                        return (next.element, error)
                    }
                }
            }

            for _ in 0..<concurrent { enqueueNext() }

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

        for (light, _) in failures {
            skippedLightIDs.insert(light.id)
        }

        try await refreshResourcesWithoutSpinner()

        if !failures.isEmpty {
            throw HueAppError.partialGradient(
                failed: failures.map(\.0.name),
                total: candidates.count,
                underlying: failures.first?.1,
                previouslySkipped: previouslySkippedCount
            )
        }
    }

    /// Clears the in-memory skip list so previously-failing lights are tried again.
    public func resetSkippedLights() {
        skippedLightIDs.removeAll()
    }

    /// Runs a single-light operation. If the light is already in the session
    /// skip list the call is a silent no-op. On error the light is added to
    /// the skip list and a brief alert names the bulb instead of dumping the
    /// raw bridge error string.
    private func runSingleLightUpdate(
        on lightID: String,
        operation: () async throws -> Void
    ) async {
        guard !skippedLightIDs.contains(lightID) else { return }

        isWorking = true
        defer { isWorking = false }

        do {
            try await operation()
        } catch {
            skippedLightIDs.insert(lightID)
            let lightName = lights.first(where: { $0.id == lightID })?.name ?? "this light"
            errorAlert = HueErrorAlert(
                title: "\(lightName) is unreachable.",
                message: "Skipping it for the rest of this session."
            )
        }
    }

    public func forgetBridge() {
        bridgeHost = ""
        applicationKey = nil
        discoveredBridges = []
        hasAttemptedDiscovery = false
        lights = []
        groups = []
        selectedGroupID = HueLightGroup.allLightsID
        selectedGradientID = HueGradientPreset.fallback.id
        skippedLightIDs.removeAll()
    }

    public func lights(in groupID: String) -> [HueLight] {
        guard let group = availableGroups.first(where: { $0.id == groupID }) else {
            return lights
        }

        return lights.filter { group.contains($0) }
    }

    public func lightCount(in group: HueLightGroup) -> Int {
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

public struct HueErrorAlert: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let message: String
}
