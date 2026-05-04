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
        HueGradientPreset.all.first { $0.id == selectedGradientID } ?? .fallback
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

            try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                for (index, light) in targetLights.enumerated() {
                    taskGroup.addTask {
                        try await client.applyGradient(
                            gradient,
                            to: light,
                            index: index,
                            total: targetLights.count
                        )
                    }
                }

                try await taskGroup.waitForAll()
            }

            try await refreshResourcesWithoutSpinner()
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
