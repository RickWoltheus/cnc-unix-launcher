import AppKit
import SwiftUI

struct ModInfo: Identifiable {
    let id: String
    let title: String
    let version: String
}

@MainActor
final class LauncherModel: ObservableObject {
    @Published var engine = false
    @Published var steam = false
    @Published var assets = false
    @Published var baseEngine = false
    @Published var baseAssets = false
    @Published var selectedGame = "vanilla"
    @Published var selectedMod = "rotr"
    @Published var installedMods: Set<String> = []
    @Published var busy = false
    @Published var status = "Ready to set up Zero Hour"
    @Published var output = ""
    @Published var fullscreen = UserDefaults.standard.object(forKey: "fullscreen") as? Bool ?? true {
        didSet { UserDefaults.standard.set(fullscreen, forKey: "fullscreen") }
    }
    @Published var maximumGraphics = true
    @Published var showModConsent = false
    @Published var updateURL: URL?
    @Published var updateStatus = "Engine and mods use reviewed, pinned versions."
    let catalog: [ModInfo]

    init() {
        let url = Bundle.main.resourceURL!.appendingPathComponent("manifests/mods.tsv")
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        catalog = text.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 3 else { return nil }
            return ModInfo(id: String(fields[0]), title: String(fields[1]), version: String(fields[2]))
        }
    }

    var gameEngineReady: Bool { selectedGame == "base" ? baseEngine : engine }
    var gameAssetsReady: Bool { selectedGame == "base" ? baseAssets : assets }
    var selectedModInfo: ModInfo? { catalog.first { $0.id == selectedMod } }

    let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/GeneralsX Launcher")
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
        perform(["engine", "steam"], success: "Ready for Steam sign-in. Click Download Steam game.")
    }

    func installMod() {
        perform(["mod"], success: "Mod installed. Gameplay compatibility is experimental.", profile: selectedMod)
    }

    private func perform(_ actions: [String], success: String, profile: String? = nil) {
        guard !busy else { return }
        busy = true
        output = ""
        let script = backend
        let chosenProfile = profile ?? selectedGame
        Task {
            defer { busy = false; refresh() }
            do {
                for action in actions {
                    status = action == "mod" ? "Installing mod data…" : "Installing \(action)…"
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
            } catch {
                status = "Installation stopped"
                output += "\n" + error.localizedDescription
            }
        }
    }

    func downloadAssets() {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let command = root.appendingPathComponent("Download Steam Game.command")
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
            NSWorkspace.shared.open(command)
            status = "Sign in in Terminal. Click Refresh after Steam finishes."
        } catch {
            status = error.localizedDescription
        }
    }

    func play(_ profile: String) {
        let script = backend
        let screen = NSScreen.main
        let width = fullscreen ? Int((screen?.frame.width ?? 1440) * (screen?.backingScaleFactor ?? 2)) : 1280
        let height = fullscreen ? Int((screen?.frame.height ?? 900) * (screen?.backingScaleFactor ?? 2)) : 720
        let arguments = ["launch", profile, fullscreen ? "-fullscreen" : "-win",
                         "-xres", String(width), "-yres", String(height)]
        Task {
            do {
                if maximumGraphics {
                    let game = profile == "base" ? "base" : "vanilla"
                    _ = try await Task.detached { try Self.run(script, arguments: ["graphics", game]) }.value
                }
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
                        if finished.terminationStatus != 0 {
                            self.output = (try? String(contentsOf: launcherLog, encoding: .utf8)) ?? "Could not read launcher log."
                        }
                        self.refresh()
                    }
                }
                try process.run()
                status = "Launching selected game… Logs are in your installation folder."
            } catch {
                status = error.localizedDescription
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

struct LauncherView: View {
    @StateObject private var model = LauncherModel()

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "gamecontroller.fill").font(.system(size: 34)).foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("GeneralsX Launcher").font(.largeTitle.bold())
                    Text("Generals & Zero Hour on Apple Silicon").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { model.refresh() }
                    .disabled(model.busy)
                    .accessibilityIdentifier("refresh")
            }
            GroupBox("Set up your game") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Requires macOS 15+ and the selected game owned on Steam. The Ultimate Collection includes both; Remastered Collection does not.")
                        .fixedSize(horizontal: false, vertical: true)
                    Picker("Game", selection: $model.selectedGame) {
                        Text("Zero Hour").tag("vanilla")
                        Text("Generals").tag("base")
                    }.pickerStyle(.segmented)
                    HStack {
                        Label(model.gameEngineReady ? "Engine installed" : "Engine needed", systemImage: model.gameEngineReady ? "checkmark.circle.fill" : "circle")
                        Label(model.steam ? "SteamCMD installed" : "SteamCMD needed", systemImage: model.steam ? "checkmark.circle.fill" : "circle")
                        Label(model.gameAssetsReady ? "Game files ready" : "Game files needed", systemImage: model.gameAssetsReady ? "checkmark.circle.fill" : "circle")
                    }.font(.callout)
                    HStack {
                        Button("1. Install engine & SteamCMD") { model.prepare() }
                            .accessibilityIdentifier("install-engine")
                        Button("2. Download Steam game") { model.downloadAssets() }
                            .disabled(!model.steam)
                            .accessibilityIdentifier("download-game")
                    }
                    Text("Steam opens in Terminal for password and Steam Guard entry. Credentials never enter this launcher. SteamCMD requires Rosetta; the game runs natively.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(8)
            }
            GroupBox("Play") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Toggle("Fullscreen", isOn: $model.fullscreen)
                            .accessibilityIdentifier("fullscreen")
                        Toggle("Apply maximum graphics on launch", isOn: $model.maximumGraphics)
                    }
                    Text("Fullscreen uses your display resolution; windowed mode uses 1280×720. Maximum graphics may reduce performance on older Macs.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(model.selectedGame == "base" ? "Play Generals" : "Play Zero Hour", systemImage: "play.fill") { model.play(model.selectedGame) }
                            .buttonStyle(.borderedProminent).disabled(!model.gameEngineReady || !model.gameAssetsReady)
                            .accessibilityIdentifier("play-game")
                    }
                    if model.selectedGame == "vanilla" {
                        HStack {
                            Picker("Mod", selection: $model.selectedMod) {
                                ForEach(model.catalog) { mod in Text(mod.title).tag(mod.id) }
                            }
                            .accessibilityIdentifier("mod-picker")
                            Button(model.installedMods.contains(model.selectedMod) ? "Play mod" : "Install mod") {
                                if model.installedMods.contains(model.selectedMod) { model.play(model.selectedMod) }
                                else { model.showModConsent = true }
                            }.disabled(!model.engine || !model.assets)
                                .accessibilityIdentifier("mod-action")
                            if model.installedMods.contains(model.selectedMod) {
                                Button("Repair") { model.showModConsent = true }.disabled(!model.engine || !model.assets)
                            }
                        }
                        Text("\(model.selectedModInfo?.version ?? "") · Experimental: installer data verified, gameplay not tested.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Mods install separately and share Zero Hour settings and saves. Use distinct save names for each mod.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            HStack {
                if model.busy { ProgressView().controlSize(.small) }
                Text(model.status).textSelection(.enabled)
            }
            HStack {
                Button("Check for updates") { model.checkUpdates() }
                    .accessibilityIdentifier("check-updates")
                if let url = model.updateURL { Link("Download update", destination: url) }
                Text(model.updateStatus).font(.caption).foregroundStyle(.secondary)
            }
            if !model.output.isEmpty {
                ScrollView { Text(model.output).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    .frame(height: 110)
            }
            HStack {
                Button("Open installation folder") { NSWorkspace.shared.open(model.root) }
                Link("Buy on Steam", destination: URL(string: "https://store.steampowered.com/app/2732960/")!)
                Spacer()
                Text("Community launcher · not affiliated with EA or Valve").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        }
        .frame(width: 760, height: 800)
        .disabled(model.busy)
        .task { model.refresh() }
        .alert("Install \(model.selectedModInfo?.title ?? "mod")?", isPresented: $model.showModConsent) {
            Button("Install") { model.installMod() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Downloads the mod's data from GenLauncher’s public HTTP mirror. Every file is checked against a pinned SHA-256 recorded from the mirror, not signed by the publisher. Allow up to 8 GB extra per mod. Windows binaries and optional mod videos are excluded. Gameplay compatibility is experimental; no game or mod files are bundled here.")
        }
    }
}

@main
struct GeneralsXLauncherApp: App {
    var body: some Scene {
        WindowGroup { LauncherView() }
            .windowResizability(.contentSize)
    }
}
