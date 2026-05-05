import Foundation

public struct HueAutomationService: Sendable {
    public init() {}

    public func fetchResources() async throws -> (lights: [HueLight], groups: [HueLightGroup]) {
        let client = try currentClient()

        async let fetchedLights = client.fetchLights()
        async let fetchedGroups = client.fetchGroups()

        let lights = try await fetchedLights.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let groups = try await fetchedGroups.sorted {
            if $0.kindTitle == $1.kindTitle {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.kindTitle < $1.kindTitle
        }

        return (lights, groups)
    }

    public func setPower(on: Bool, groupID: String?) async throws -> String {
        let (lights, groups) = try await fetchResources()
        let targetGroup = try resolveGroup(id: groupID, groups: groups)
        let targetLights = lightsForGroup(targetGroup, allLights: lights)

        guard !targetLights.isEmpty else {
            throw HueAppError.bridgeRejected("No lights were found in \(targetGroup.name).")
        }

        let client = try currentClient()
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for light in targetLights {
                taskGroup.addTask {
                    try await client.setLight(id: light.id, on: on)
                }
            }

            try await taskGroup.waitForAll()
        }

        return "\(on ? "Turned on" : "Turned off") \(lightCountLabel(targetLights.count)) in \(targetGroup.name)."
    }

    public func applyGradient(_ preset: HueGradientPreset, groupID: String?) async throws -> String {
        let (lights, groups) = try await fetchResources()
        let targetGroup = try resolveGroup(id: groupID, groups: groups)
        let targetLights = lightsForGroup(targetGroup, allLights: lights)

        guard !targetLights.isEmpty else {
            throw HueAppError.bridgeRejected("No lights were found in \(targetGroup.name).")
        }

        let client = try currentClient()
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for (index, light) in targetLights.enumerated() {
                taskGroup.addTask {
                    try await client.applyGradient(
                        preset,
                        to: light,
                        index: index,
                        total: targetLights.count
                    )
                }
            }

            try await taskGroup.waitForAll()
        }

        return "Applied \(preset.title) to \(lightCountLabel(targetLights.count)) in \(targetGroup.name)."
    }

    public func availableGroups() async throws -> [(group: HueLightGroup, lightCount: Int)] {
        let (lights, groups) = try await fetchResources()

        return ([HueLightGroup.allLights] + groups).map { group in
            (group, lightsForGroup(group, allLights: lights).count)
        }
    }

    private func currentClient() throws -> HueBridgeClient {
        let host = HueBridgeClient.normalizedHost(
            from: UserDefaults.standard.string(forKey: HueAppStorage.bridgeHostKey) ?? ""
        )

        guard !host.isEmpty else {
            throw HueAppError.missingBridgeHost
        }

        guard let applicationKey = KeychainStore.read() else {
            throw HueAppError.missingApplicationKey
        }

        return HueBridgeClient(host: host, applicationKey: applicationKey)
    }

    private func resolveGroup(id: String?, groups: [HueLightGroup]) throws -> HueLightGroup {
        guard let id, id != HueLightGroup.allLightsID else {
            return .allLights
        }

        if let group = groups.first(where: { $0.id == id }) {
            return group
        }

        throw HueAppError.bridgeRejected("That Hue room or zone is no longer available.")
    }

    private func lightsForGroup(_ group: HueLightGroup, allLights: [HueLight]) -> [HueLight] {
        allLights.filter { group.contains($0) }
    }

    private func lightCountLabel(_ count: Int) -> String {
        count == 1 ? "1 light" : "\(count) lights"
    }
}
