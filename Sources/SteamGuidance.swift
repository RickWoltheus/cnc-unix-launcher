import Foundation

struct SteamGuidance: Decodable, Sendable {
    let title: String
    let detail: String

    private static let messages: [String: SteamGuidance] = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("resources/steam-guidance.json"),
              let data = try? Data(contentsOf: url),
              let messages = try? JSONDecoder().decode([String: SteamGuidance].self, from: data) else { return [:] }
        return messages
    }()

    static func forStatus(_ status: String) -> SteamGuidance {
        messages[status] ?? messages["idle"] ?? SteamGuidance(title: "Check the Steam window", detail: "Complete sign-in and wait for Steam to finish checking your game.")
    }
}
