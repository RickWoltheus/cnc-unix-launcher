import SwiftUI

struct GameInfo: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let engine: String
    let steamID: String
    let directory: String
    let hex: String
    let emblem: String
    let summary: String

    var logoURL: URL { URL(string: "https://cdn.akamai.steamstatic.com/steam/apps/\(steamID)/logo.png")! }
    var isClassic: Bool { engine == "OpenRA" }
    var color: Color {
        let value = UInt32(hex, radix: 16) ?? 0xEFAD40
        return Color(red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    static let catalog: [GameInfo] = {
        guard let root = Bundle.main.resourceURL,
              let text = try? String(contentsOf: root.appendingPathComponent("manifests/games.tsv"), encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let row = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard row.count == 9 else { return nil }
            return GameInfo(id: row[0], title: row[1], subtitle: row[2], engine: row[3], steamID: row[4],
                            directory: row[5], hex: row[6], emblem: row[7], summary: row[8])
        }
    }()
}

private struct GameAccentKey: EnvironmentKey {
    static let defaultValue = CommandTheme.amber
}

extension EnvironmentValues {
    var gameAccent: Color {
        get { self[GameAccentKey.self] }
        set { self[GameAccentKey.self] = newValue }
    }
}
