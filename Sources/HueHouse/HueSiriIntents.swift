import AppIntents
import Foundation
import HueKit

struct HueGroupAppEntity: AppEntity {
    static let defaultQuery = HueGroupEntityQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Hue Room or Zone")

    let id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "Kind")
    var kindTitle: String

    @Property(title: "Light Count")
    var lightCount: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(kindTitle) · \(lightCount == 1 ? "1 light" : "\(lightCount) lights")"
        )
    }

    static var allLights: HueGroupAppEntity {
        HueGroupAppEntity(
            id: HueLightGroup.allLightsID,
            name: "All Lights",
            kindTitle: "Home",
            lightCount: 0
        )
    }

    init(id: String, name: String, kindTitle: String, lightCount: Int) {
        self.id = id
        self.name = name
        self.kindTitle = kindTitle
        self.lightCount = lightCount
    }

    init(group: HueLightGroup, lightCount: Int) {
        self.init(
            id: group.id,
            name: group.name,
            kindTitle: group.kindTitle,
            lightCount: lightCount
        )
    }
}

struct HueGroupEntityQuery: EntityQuery {
    func entities(for identifiers: [HueGroupAppEntity.ID]) async throws -> [HueGroupAppEntity] {
        let entities = await suggestedEntitiesSafely()
        return entities.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HueGroupAppEntity] {
        try await HueAutomationService()
            .availableGroups()
            .map { HueGroupAppEntity(group: $0.group, lightCount: $0.lightCount) }
    }

    private func suggestedEntitiesSafely() async -> [HueGroupAppEntity] {
        do {
            return try await suggestedEntities()
        } catch {
            return [.allLights]
        }
    }
}

enum HueSiriGradient: String, AppEnum {
    case aurora
    case solstice
    case lagoon
    case garden
    case ember
    case opal

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Hue Gradient")
    static let caseDisplayRepresentations: [HueSiriGradient: DisplayRepresentation] = [
        .aurora: "Aurora Veil",
        .solstice: "Solstice Glass",
        .lagoon: "Midnight Lagoon",
        .garden: "Glass Garden",
        .ember: "Ember Bloom",
        .opal: "Opal Mist"
    ]

    var preset: HueGradientPreset {
        HueGradientPreset.all.first { $0.id == rawValue } ?? .fallback
    }
}

struct TurnHueLightsOnIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Hue Lights On"
    static let description = IntentDescription("Turns on the Hue lights in a room, zone, or the whole house.")
    static let openAppWhenRun = false

    @Parameter(title: "Room or Zone")
    var group: HueGroupAppEntity?

    func perform() async throws -> some IntentResult {
        let message = try await HueAutomationService().setPower(on: true, groupID: group?.id)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct TurnHueLightsOffIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Hue Lights Off"
    static let description = IntentDescription("Turns off the Hue lights in a room, zone, or the whole house.")
    static let openAppWhenRun = false

    @Parameter(title: "Room or Zone")
    var group: HueGroupAppEntity?

    func perform() async throws -> some IntentResult {
        let message = try await HueAutomationService().setPower(on: false, groupID: group?.id)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct ApplyHueGradientIntent: AppIntent {
    static let title: LocalizedStringResource = "Apply Hue Gradient"
    static let description = IntentDescription("Applies a built-in Hue House gradient to a room, zone, or the whole house.")
    static let openAppWhenRun = false

    @Parameter(title: "Gradient")
    var gradient: HueSiriGradient?

    @Parameter(title: "Room or Zone")
    var group: HueGroupAppEntity?

    func perform() async throws -> some IntentResult {
        let selectedGradient = (gradient ?? .aurora).preset
        let message = try await HueAutomationService().applyGradient(selectedGradient, groupID: group?.id)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct HueHouseShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor {
        .blue
    }

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnHueLightsOnIntent(),
            phrases: [
                "Turn on \(.applicationName)",
                "Turn on the lights with \(.applicationName)",
                "Turn on \(\.$group) with \(.applicationName)"
            ],
            shortTitle: "Lights On",
            systemImageName: "lightbulb.fill"
        )

        AppShortcut(
            intent: TurnHueLightsOffIntent(),
            phrases: [
                "Turn off \(.applicationName)",
                "Turn off the lights with \(.applicationName)",
                "Turn off \(\.$group) with \(.applicationName)"
            ],
            shortTitle: "Lights Off",
            systemImageName: "lightbulb.slash"
        )

        AppShortcut(
            intent: ApplyHueGradientIntent(),
            phrases: [
                "Set \(.applicationName) to \(\.$gradient)",
                "Apply \(\.$gradient) with \(.applicationName)",
                "Apply a gradient to \(\.$group) with \(.applicationName)"
            ],
            shortTitle: "Apply Gradient",
            systemImageName: "wand.and.stars"
        )
    }
}
