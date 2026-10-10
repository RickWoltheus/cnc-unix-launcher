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
    var isCompatibility: Bool { engine == "Wine" }
    var isSage: Bool { Self.sageIDs.contains(id) }
    var compatibilityDetail: String { isSage ? Self.sageCopy["detail", default: "Experimental C&C 3 support."] : "Free Wine + cnc-ddraw runs the original Windows game. Experimental: campaign, graphics and Steam launch behavior still need gameplay testing. On Apple Silicon, Wine runs through Rosetta 2." }
    var compatibilityPreparation: String { isSage ? Self.sageCopy["prepare", default: "Requires macOS Tahoe 26+."] : "Pinned Wine 11.0 + cnc-ddraw; Rosetta is checked before Steam sign-in." }
    var compatibilityPlayNote: String { isSage ? Self.sageCopy["play", default: "Gameplay validation pending."] : "Experimental Wine support. Windowed mode uses 1280×720 upscaling; fullscreen uses borderless cnc-ddraw. Tiberian Sun includes Firestorm in its menu. CnCNet is not installed by this launcher yet." }
    private static let sageIDs: Set<String> = {
        guard let root = Bundle.main.resourceURL, let text = try? String(contentsOf: root.appendingPathComponent("manifests/compatibility.tsv"), encoding: .utf8) else { return [] }
        return Set(text.split(separator: "\n").compactMap { line in
            let row = line.split(separator: "\t").map(String.init)
            return row.count == 5 && row[4] == "sage" ? row[0] : nil
        })
    }()
    private static let sageCopy: [String: String] = {
        guard let root = Bundle.main.resourceURL, let data = try? Data(contentsOf: root.appendingPathComponent("resources/sage.json")),
              let copy = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return copy["macos"] ?? [:]
    }()
    var usesGeneralsGraphics: Bool { engine == "GeneralsX" }
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
