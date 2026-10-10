import Foundation

struct SteamGuidance: Decodable, Sendable {
    let title: String
    let detail: String
    let stage: Int
    let error: Bool

    private static let messages: [String: SteamGuidance] = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("resources/steam-guidance.json"),
              let data = try? Data(contentsOf: url),
              let messages = try? JSONDecoder().decode([String: SteamGuidance].self, from: data) else { return [:] }
        return messages
    }()

    static func forStatus(_ status: String) -> SteamGuidance {
        messages[status] ?? messages["idle"] ?? SteamGuidance(title: "Check the Steam window", detail: "Complete sign-in and wait for Steam to finish checking your game.", stage: 0, error: false)
    }
}

struct SteamGuideCopy: Decodable {
    let title: String
    let securityTitle: String
    let securityDetail: String
    let visibilityDetail: String
    let stages: [String]
    let showLabel: String
    let retryLabel: String
    let continueLabel: String
    let helpLabel: String
    let terminalLabel: String

    static let shared: SteamGuideCopy = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("resources/steam-guide.json"),
           let data = try? Data(contentsOf: url),
           let copy = try? JSONDecoder().decode(SteamGuideCopy.self, from: data) { return copy }
        return SteamGuideCopy(title: "Steam setup guide", securityTitle: "Credentials stay in Terminal",
                              securityDetail: "Enter credentials in Valve’s local SteamCMD console. The launcher does not store passwords or codes.",
                              visibilityDetail: "Guide resources are missing. Reinstall the launcher to restore the full instructions.",
                              stages: ["Account", "Steam Guard", "Game files"], showLabel: "Show Steam guide", retryLabel: "Retry sign-in",
                              continueLabel: "Continue to Play", helpLabel: "Steam account help", terminalLabel: "Return to Terminal")
    }()
}

struct GameLaunchGuide: Decodable {
    let copy: SteamGuideCopy
    let phases: [String: SteamGuidance]
    let permission: String?
    let library: String

    static let shared: GameLaunchGuide = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("resources/launch-guide.json"),
           let data = try? Data(contentsOf: url),
           let copies = try? JSONDecoder().decode([String: GameLaunchGuide].self, from: data),
           let copy = copies["macos"] { return copy }
        return GameLaunchGuide(copy: SteamGuideCopy.shared, phases: [:], permission: nil,
                               library: "Reinstall the launcher to restore the game launch guide.")
    }()
    func guidance(_ phase: String) -> SteamGuidance {
        phases[phase] ?? phases["preparing"] ?? SteamGuidance.forStatus("idle")
    }
}
