import AppKit
import SwiftUI

struct ModInfo: Identifiable {
    let id: String
    let title: String
    let version: String
    let imageURL: URL?
    let homepage: URL?
    let summary: String
}

@MainActor
final class LauncherModel: ObservableObject {
    @Published var engine = false
    @Published var steam = false
    @Published var assets = false
    @Published var baseEngine = false
    @Published var baseAssets = false
    @Published var selectedGame = "vanilla"
    @Published var selectedMod = "vanilla"
    @Published var installedMods: Set<String> = []
    @Published var busy = false
    @Published var gameRunning = false
    @Published var recovery: RecoveryAdvice?
    @Published var steamDownloadStatus = "idle"
    @Published var steamSessionRunning = false
    @Published var externalInstallRunning = false
    @Published var status = "Ready to set up Zero Hour"
    @Published var output = ""
    @Published var fullscreen = UserDefaults.standard.object(forKey: "fullscreen") as? Bool ?? true {
        didSet { UserDefaults.standard.set(fullscreen, forKey: "fullscreen") }
    }
    @Published var maximumGraphics = UserDefaults.standard.bool(forKey: "maximumGraphics") {
        didSet { UserDefaults.standard.set(maximumGraphics, forKey: "maximumGraphics") }
    }
    @Published var showModConsent = false
    @Published var updateURL: URL?
    @Published var updateStatus = "Engine and mods use reviewed, pinned versions."
    let catalog: [ModInfo]
    let systemSupported: Bool

    init(systemSupported: Bool = LauncherModel.supportedPlatform) {
        self.systemSupported = systemSupported
        let url = Bundle.main.resourceURL!.appendingPathComponent("manifests/mods.tsv")
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let mediaURL = Bundle.main.resourceURL!.appendingPathComponent("manifests/mod-media.tsv")
        let mediaText = (try? String(contentsOf: mediaURL, encoding: .utf8)) ?? ""
        var media: [String: [String]] = [:]
        for line in mediaText.split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if fields.count == 4 { media[fields[0]] = fields }
        }
        catalog = text.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 3 else { return nil }
            let artwork = media[String(fields[0])] ?? ["", "", "", "An optional Zero Hour mod."]
            return ModInfo(id: String(fields[0]), title: String(fields[1]), version: String(fields[2]),
                           imageURL: URL(string: artwork[1]), homepage: URL(string: artwork[2]), summary: artwork[3])
        }
    }

    var gameEngineReady: Bool { selectedGame == "base" ? baseEngine : engine }
    var gameAssetsReady: Bool {
        let ready = selectedGame == "base" ? baseAssets : assets
        return ready && !steamSessionRunning && !externalInstallRunning && ["idle", "complete"].contains(steamDownloadStatus)
    }
    var selectedModInfo: ModInfo? { selectedGame == "base" ? nil : catalog.first { $0.id == selectedMod } }
    var activeProfile: String { selectedGame == "base" ? "base" : selectedMod }
    var activeTitle: String { selectedGame == "base" ? "GENERALS" : (selectedModInfo?.title.uppercased() ?? "ZERO HOUR") }
    var activeNeedsInstall: Bool { selectedGame != "base" && selectedModInfo != nil && !installedMods.contains(selectedMod) }
    var steamGuidance: SteamGuidance { SteamGuidance.forStatus(steamDownloadStatus) }

    nonisolated static var supportedPlatform: Bool {
        #if arch(arm64)
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15
        #else
        return false
        #endif
    }

    func canEnterStep(_ index: Int) -> Bool {
        guard !busy && !gameRunning else { return false }
        return SetupPolicy.shared.allows(index, facts: setupFacts)
    }

    func stepComplete(_ index: Int) -> Bool {
        SetupPolicy.shared.isComplete(index, facts: setupFacts)
    }
    private var setupFacts: [String: Bool] {
        ["platform": systemSupported, "selected": ["vanilla", "base"].contains(selectedGame),
         "engine": gameEngineReady, "steam": steam, "assets": gameAssetsReady]
    }

    func stepHelp(_ index: Int) -> String {
        if !systemSupported { return "This launcher needs Apple Silicon and macOS 15 or later." }
        if index >= 2 && (!gameEngineReady || !steam) { return "Prepare your Mac before signing into Steam." }
        if index == 3 && !gameAssetsReady { return "Finish Steam sign-in and validate the game download first." }
        return "Open this step."
    }

    let root = ProcessInfo.processInfo.environment["GX_INSTALL_ROOT"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/GeneralsX Launcher")
    private var backend: URL {
        Bundle.main.resourceURL!.appendingPathComponent("scripts/backend.sh")
    }

    func refresh() {
        let script = backend
        Task {
            do {
                let result = try await Task.detached {
                    try Self.run(script, arguments: ["status"])
                }.value
                let states = Set(result.split(separator: "\n").map(String.init))
                engine = states.contains("engine=ready")
                steam = states.contains("steam=ready")
                assets = states.contains("assets=ready")
                baseEngine = states.contains("base_engine=ready")
                baseAssets = states.contains("base_assets=ready")
                installedMods = Set(catalog.filter { states.contains("\($0.id)=ready") }.map(\.id))
                steamDownloadStatus = states.first(where: { $0.hasPrefix("steam_download_\(selectedGame)=") })?.components(separatedBy: "=").last ?? "idle"
                steamSessionRunning = states.contains("steam_session_\(selectedGame)=active")
                externalInstallRunning = states.contains("install=busy")
                if steamDownloadStatus == "incomplete" && !gameAssetsReady {
                    recovery = RecoveryAdvice.forMessage("Steam files are incomplete")
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func checkUpdates() {
        updateStatus = "Checking launcher releases…"
        Task {
            do {
                let endpoint = URL(string: "https://api.github.com/repos/RickWoltheus/generalsx-mac-launcher/releases?per_page=10")!
                let (data, response) = try await URLSession.shared.data(from: endpoint)
                guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                if http.statusCode == 404 { updateStatus = "No public launcher release is available yet."; return }
                guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
                let releases = try JSONDecoder().decode([LauncherRelease].self, from: data)
                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
                guard let latest = releases.first(where: { !$0.draft && $0.assets.contains { $0.name == "GeneralsX-Launcher-macOS-arm64.zip" } }) else {
                    updateStatus = "No downloadable launcher release is available yet."; return
                }
                let version = latest.tag_name.hasPrefix("v") ? String(latest.tag_name.dropFirst()) : latest.tag_name
                if version.compare(current, options: .numeric) == .orderedDescending {
                    updateURL = URL(string: "https://github.com/RickWoltheus/generalsx-mac-launcher/releases/tag/\(latest.tag_name)")
                    updateStatus = "Launcher \(version) is available. Download the ZIP and replace this app."
                } else {
                    updateURL = nil
                    updateStatus = "Launcher \(current) is up to date."
                }
            } catch {
                updateStatus = "Could not check for updates. Try again later."
            }
        }
    }

    func prepare() {
        guard canEnterStep(1) else { return }
        perform(["engine", "steam"], success: "Ready for Steam sign-in. Click Download Steam game.")
    }

    func installMod(andPlay: Bool = false) {
        guard canEnterStep(3) && selectedModInfo != nil else { return }
        perform(["mod"], success: "Mod installed. Gameplay compatibility is experimental.", profile: selectedMod, playAfterInstall: andPlay)
    }

    private func perform(_ actions: [String], success: String, profile: String? = nil, playAfterInstall: Bool = false) {
        guard !busy else { return }
        busy = true
        recovery = nil
        output = ""
        let script = backend
        let chosenProfile = profile ?? selectedGame
        Task {
            var completed = false
            defer {
                busy = false
                refresh()
                if completed && playAfterInstall { play(chosenProfile) }
            }
            do {
                for action in actions {
                    status = action == "mod" ? "Installing your mod…" : (action == "engine" ? "Preparing the native game engine…" : "Preparing Steam sign-in…")
                    let text = try await Task.detached {
                        try Self.run(script, arguments: [action, chosenProfile]) { chunk in
                            Task { @MainActor in
                                self.output = String((self.output + chunk).suffix(12000))
                            }
                        }
                    }.value
                    output = text
                }
                status = success
                completed = true
            } catch {
                status = "Installation stopped"
                output += "\n" + error.localizedDescription
                recovery = RecoveryAdvice.forMessage(error.localizedDescription)
            }
        }
    }

    func downloadAssets() {
        guard canEnterStep(2) && !steamSessionRunning && !externalInstallRunning else { return }
        recovery = nil
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let command = root.appendingPathComponent("Download Steam \(selectedGame == "base" ? "Generals" : "Zero Hour").command")
            let content = """
            #!/bin/bash
            /bin/bash \(Self.shellQuote(backend.path)) steam-login \(Self.shellQuote(selectedGame))
            result=$?
            printf '\\nReturn to GeneralsX Launcher and click Refresh.\\n'
            read -r -p 'Press Return to close.'
            exit "$result"
            """
            try content.write(to: command, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: command.path)
            guard NSWorkspace.shared.open(command) else { throw NSError(domain: "GeneralsXLauncher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open the Steam sign-in window."]) }
            status = "Sign in in Terminal. Click Refresh after Steam finishes."
        } catch {
            status = error.localizedDescription
        }
    }

    func returnToSteamWindow() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: configuration) { _, error in
            if let error {
                Task { @MainActor in self.status = error.localizedDescription }
            }
        }
    }

    func play(_ profile: String) {
        guard canEnterStep(3) else { return }
        busy = true
        recovery = nil
        let script = backend
        let screen = NSScreen.main
        let width = fullscreen ? Int((screen?.frame.width ?? 1440) * (screen?.backingScaleFactor ?? 2)) : 1280
        let height = fullscreen ? Int((screen?.frame.height ?? 900) * (screen?.backingScaleFactor ?? 2)) : 720
        let arguments = ["launch", profile, fullscreen ? "-fullscreen" : "-win",
                         "-xres", String(width), "-yres", String(height)]
        Task {
            defer { busy = false }
            do {
                let game = profile == "base" ? "base" : "vanilla"
                let quality = maximumGraphics ? "maximum" : "balanced"
                _ = try await Task.detached { try Self.run(script, arguments: ["graphics", game, quality]) }.value
                let process = Process()
                let logDirectory = root.appendingPathComponent("logs")
                try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
                let launcherLog = logDirectory.appendingPathComponent("launcher-\(profile).log")
                FileManager.default.createFile(atPath: launcherLog.path, contents: nil, attributes: [.posixPermissions: 0o600])
                let logHandle = try FileHandle(forWritingTo: launcherLog)
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [script.path] + arguments
                process.standardOutput = logHandle
                process.standardError = logHandle
                process.terminationHandler = { finished in
                    logHandle.closeFile()
                    Task { @MainActor in
                        self.status = finished.terminationStatus == 0 ? "Game closed." : "Game stopped with an error. Open the installation folder and check logs/\(profile).log."
                        self.gameRunning = false
                        if finished.terminationStatus != 0 {
                            self.output = (try? String(contentsOf: launcherLog, encoding: .utf8)) ?? "Could not read launcher log."
                            let gameLog = logDirectory.appendingPathComponent("\(profile).log")
                            let details = (try? String(contentsOf: gameLog, encoding: .utf8)) ?? ""
                            self.recovery = RecoveryAdvice.forMessage(self.output + String(details.suffix(12000)))
                        }
                        self.refresh()
                    }
                }
                try process.run()
                gameRunning = true
                status = "Launching selected game… Logs are in your installation folder."
            } catch {
                status = error.localizedDescription
                recovery = RecoveryAdvice.forMessage(error.localizedDescription)
            }
        }
    }

    nonisolated private static func shellQuote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    nonisolated private static func run(_ script: URL, arguments: [String], onOutput: (@Sendable (String) -> Void)? = nil) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path] + arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        var text = ""
        while true {
            let data = pipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            let chunk = String(decoding: data, as: UTF8.self)
            text = String((text + chunk).suffix(12000))
            onOutput?(chunk)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "GeneralsXLauncher", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: String(text.suffix(12000))])
        }
        return String(text.suffix(12000))
    }
}

struct LauncherRelease: Decodable {
    struct Asset: Decodable { let name: String }
    let tag_name: String
    let draft: Bool
    let assets: [Asset]
}
