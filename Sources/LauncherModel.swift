import AppKit
import SwiftUI

struct ModInfo: Identifiable {
    let id: String
    let title: String
    let version: String
    let imageURL: URL?
    let homepage: URL?
    let summary: String
    var games: [String] = ["vanilla"]
    var native = false
    var source = "vanilla"
}

@MainActor
final class LauncherModel: ObservableObject {
    @Published var engine = false
    @Published var steam = false
    @Published var assets = false
    @Published var baseEngine = false
    @Published var baseAssets = false
    @Published var classicEngines: Set<String> = []
    @Published var classicAssets: Set<String> = []
    @Published var selectedGame = "vanilla"
    @Published var selectedMod = "vanilla"
    @Published var installedMods: Set<String> = []
    @Published var nativeEngines: Set<String> = []
    @Published var steamTarget: String?
    @Published var requestNativeSteam = false
    private var pendingNativePlay = false
    @Published var busy = false
    @Published var gameRunning = false
    @Published var recovery: RecoveryAdvice?
    @Published var steamDownloadStatus = "idle"
    @Published var steamSessionRunning = false
    @Published var steamStarting = false
    @Published var steamLaunchError: String?
    private var steamStartDeadline: Date?
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
        let zhMods: [ModInfo] = text.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 3 else { return nil }
            let artwork = media[String(fields[0])] ?? ["", "", "", "An optional Zero Hour mod."]
            return ModInfo(id: String(fields[0]), title: String(fields[1]), version: String(fields[2]),
                           imageURL: URL(string: artwork[1]), homepage: URL(string: artwork[2]), summary: artwork[3])
        }
        let nativeURL = Bundle.main.resourceURL!.appendingPathComponent("manifests/native-mods.tsv")
        let nativeText = (try? String(contentsOf: nativeURL, encoding: .utf8)) ?? ""
        let nativeMods: [ModInfo] = nativeText.split(separator: "\n").compactMap { line in
            let row = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard row.count == 10 else { return nil }
            return ModInfo(id: row[0], title: row[1], version: row[3], imageURL: URL(string: row[8]), homepage: URL(string: row[7]),
                           summary: row[9], games: row[2].split(separator: ",").map(String.init), native: true, source: row[6])
        }
        catalog = zhMods + nativeMods

    }

    var game: GameInfo { GameInfo.catalog.first { $0.id == selectedGame } ?? GameInfo.catalog.last! }
    var availableMods: [ModInfo] { catalog.filter { $0.games.contains(selectedGame) } }
    var steamProfile: String { steamTarget ?? selectedGame }
    var steamTitle: String { catalog.first { $0.id == steamProfile }?.title ?? game.title }
    var gameEngineReady: Bool { if let target = steamTarget { return nativeEngines.contains(target) }; return game.isClassic ? classicEngines.contains(selectedGame) : (selectedGame == "base" ? baseEngine : engine) }
    var gameAssetsReady: Bool {
        let ready = steamTarget.map { installedMods.contains($0) } ?? (game.isClassic ? classicAssets.contains(selectedGame) : (selectedGame == "base" ? baseAssets : assets))
        return ready && !steamStarting && !steamSessionRunning && !externalInstallRunning && ["idle", "complete"].contains(steamDownloadStatus)
    }
    var selectedModInfo: ModInfo? { availableMods.first { $0.id == selectedMod } }
    var activeProfile: String { selectedModInfo?.id ?? selectedGame }
    var activeTitle: String { selectedModInfo?.title.uppercased() ?? game.title.uppercased() }
    var activeNeedsInstall: Bool { selectedModInfo != nil && !installedMods.contains(selectedMod) }
    var steamGuidance: SteamGuidance { SteamGuidance.forStatus(steamStarting ? "waiting" : steamDownloadStatus) }

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
        ["platform": systemSupported, "selected": GameInfo.catalog.contains { $0.id == selectedGame },
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
                classicEngines = Set(["cnc", "ra"].filter { states.contains("\($0)_engine=ready") })
                classicAssets = Set(["cnc", "ra"].filter { states.contains("\($0)_assets=ready") })
                nativeEngines = Set(catalog.filter { $0.native && states.contains("native_engine_\($0.id)=ready") }.map(\.id))
                installedMods = Set(catalog.filter { states.contains("\($0.id)=ready") }.map(\.id))
                steamDownloadStatus = states.first(where: { $0.hasPrefix("steam_download_\(steamProfile)=") })?.components(separatedBy: "=").last ?? "idle"
                steamSessionRunning = states.contains("steam_session_\(steamProfile)=active")
                if steamSessionRunning || (steamStartDeadline.map { Date() >= $0 } ?? false) {
                    steamStarting = false
                    steamStartDeadline = nil
                }
                externalInstallRunning = states.contains("install=busy")
                if steamDownloadStatus == "incomplete" && !gameAssetsReady {
                    recovery = RecoveryAdvice.forMessage("Steam files are incomplete")
                }
                if pendingNativePlay, let profile = steamTarget, installedMods.contains(profile), canEnterStep(3) {
                    pendingNativePlay = false
                    play(profile)
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
                let endpoint = ProductInfo.shared.releasesAPI
                let (data, response) = try await URLSession.shared.data(from: endpoint)
                guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                if http.statusCode == 404 { updateStatus = "No public launcher release is available yet."; return }
                guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
                let releases = try JSONDecoder().decode([LauncherRelease].self, from: data)
                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ProductInfo.shared.version
                guard let latest = releases.first(where: { !$0.draft && $0.assets.contains { $0.name == ProductInfo.shared.macArchive } }) else {
                    updateStatus = "No downloadable launcher release is available yet."; return
                }
                let version = latest.tag_name.hasPrefix("v") ? String(latest.tag_name.dropFirst()) : latest.tag_name
                if version.compare(current, options: .numeric) == .orderedDescending {
                    updateURL = ProductInfo.shared.releaseURL(latest.tag_name)
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
        perform([selectedModInfo?.native == true ? "native-mod" : "mod"], success: "Mod installed. Gameplay compatibility is experimental.", profile: selectedMod, playAfterInstall: andPlay)
    }

    private func perform(_ actions: [String], success: String, profile: String? = nil, playAfterInstall: Bool = false, extra: [String] = []) {
        guard !busy else { return }
        busy = true
        recovery = nil
        output = ""
        let script = backend
        let chosenProfile = profile ?? selectedGame
        Task {
            var completed = false
            var needsNativeSteam = false
            defer {
                busy = false
                refresh()
                if needsNativeSteam { requestNativeSteam = true }
                if completed && playAfterInstall { play(chosenProfile) }
            }
            do {
                for action in actions {
                    switch action {
                    case "mod", "native-mod": status = "Installing your selected mod…"
                    case "engine": status = "Preparing the native game engine…"
                    case "online-prepare": status = "Checking local online setup…"
                    default: status = "Preparing Steam sign-in…"
                    }
                    let text = try await Task.detached {
                        try Self.run(script, arguments: [action, chosenProfile] + extra) { chunk in
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
                output += "\n" + error.localizedDescription
                if error.localizedDescription.contains("NATIVE_ASSETS_REQUIRED"), catalog.contains(where: { $0.id == chosenProfile && $0.native }) {
                    nativeEngines.insert(chosenProfile)
                    steamTarget = chosenProfile
                    pendingNativePlay = playAfterInstall
                    needsNativeSteam = true
                    status = "Native runtime prepared. Sign in to Steam for the required owned assets."
                } else {
                    status = "Installation stopped"
                    recovery = RecoveryAdvice.forMessage(error.localizedDescription)
                }
            }
        }
    }

    func downloadAssets() {
        guard canEnterStep(2) && !steamSessionRunning && !externalInstallRunning && !steamStarting else { return }
        recovery = nil
        steamLaunchError = nil
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let command = root.appendingPathComponent("Download Steam \(steamTitle).command")
            let content = """
            #!/bin/bash
            export GX_INSTALL_ROOT=\(Self.shellQuote(root.path))
            /bin/bash \(Self.shellQuote(backend.path)) steam-login \(Self.shellQuote(steamProfile))
            result=$?
            printf '\\nReturn to C&C Unix Launcher. The Steam guide checks progress automatically.\\n'
            read -r -p 'Press Return to close.'
            exit "$result"
            """
            try content.write(to: command, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: command.path)
            guard NSWorkspace.shared.open(command) else { throw NSError(domain: "GeneralsXLauncher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open the Steam sign-in window."]) }
            steamStarting = true
            steamStartDeadline = Date().addingTimeInterval(15)
            steamDownloadStatus = "waiting"
            status = "Sign in in Terminal. The Steam guide stays visible while you type."
        } catch {
            steamStarting = false
            steamLaunchError = error.localizedDescription
            status = error.localizedDescription
        }
    }

    func selectProfile(_ id: String) {
        guard !busy && !gameRunning && !steamSessionRunning && !externalInstallRunning && !steamStarting else { return }
        selectedMod = id
        steamTarget = nil
        pendingNativePlay = false
        refresh()
    }

    func prepareOnline(hosting: Bool) {
        guard canEnterStep(3) && !activeNeedsInstall else { return }
        perform(["online-prepare"], success: "Local online setup prepared. Authentication and a real match still happen in the game.",
                profile: activeProfile, extra: [hosting ? "host" : "join"])
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
                let game = ["base", "cnc", "ra"].contains(profile) || catalog.contains { $0.id == profile && $0.native } ? profile : "vanilla"
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
