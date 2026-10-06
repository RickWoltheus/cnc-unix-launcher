import AppKit
import SwiftUI

@MainActor
final class LauncherModel: ObservableObject {
    @Published var engine = false
    @Published var steam = false
    @Published var assets = false
    @Published var rotr = false
    @Published var busy = false
    @Published var status = "Ready to set up Zero Hour"
    @Published var output = ""
    @Published var fullscreen = true
    @Published var maximumGraphics = true
    @Published var showModConsent = false

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
                engine = result.contains("engine=ready")
                steam = result.contains("steam=ready")
                assets = result.contains("assets=ready")
                rotr = result.contains("rotr=ready")
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func prepare() {
        perform(["engine", "steam"], success: "Ready for Steam sign-in. Click Download Steam game.")
    }

    func installROTR() {
        perform(["rotr"], success: "Rise of the Reds is ready.")
    }

    private func perform(_ actions: [String], success: String) {
        guard !busy else { return }
        busy = true
        output = ""
        let script = backend
        Task {
            defer { busy = false; refresh() }
            do {
                for action in actions {
                    status = action == "rotr" ? "Installing Rise of the Reds…" : "Installing \(action)…"
                    let text = try await Task.detached {
                        try Self.run(script, arguments: [action]) { chunk in
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
            /bin/bash \(Self.shellQuote(backend.path)) steam-login
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
        let width = Int((screen?.frame.width ?? 1440) * (screen?.backingScaleFactor ?? 2))
        let height = Int((screen?.frame.height ?? 900) * (screen?.backingScaleFactor ?? 2))
        let arguments = ["launch", profile, fullscreen ? "-fullscreen" : "-win",
                         "-xres", String(width), "-yres", String(height)]
        Task {
            do {
                if maximumGraphics {
                    _ = try await Task.detached { try Self.run(script, arguments: ["graphics"]) }.value
                }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [script.path] + arguments
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                process.terminationHandler = { finished in
                    Task { @MainActor in
                        self.status = finished.terminationStatus == 0 ? "Game closed." : "Game stopped with an error. Open the installation folder and check logs/\(profile).log."
                        self.refresh()
                    }
                }
                try process.run()
                status = "Launching \(profile == "rotr" ? "Rise of the Reds" : "Zero Hour")… Logs are in your installation folder."
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

struct LauncherView: View {
    @StateObject private var model = LauncherModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "gamecontroller.fill").font(.system(size: 34)).foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("GeneralsX Launcher").font(.largeTitle.bold())
                    Text("Zero Hour on Apple Silicon").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { model.refresh() }
                    .disabled(model.busy)
            }
            GroupBox("Set up your game") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Requires macOS 15+ and Zero Hour owned on Steam. The Ultimate Collection includes it; Remastered Collection does not.")
                    HStack {
                        Label(model.engine ? "Engine installed" : "Engine needed", systemImage: model.engine ? "checkmark.circle.fill" : "circle")
                        Label(model.steam ? "SteamCMD installed" : "SteamCMD needed", systemImage: model.steam ? "checkmark.circle.fill" : "circle")
                        Label(model.assets ? "Game files ready" : "Game files needed", systemImage: model.assets ? "checkmark.circle.fill" : "circle")
                    }.font(.callout)
                    HStack {
                        Button("1. Install engine & SteamCMD") { model.prepare() }
                        Button("2. Download Steam game") { model.downloadAssets() }
                            .disabled(!model.steam)
                    }
                    Text("Steam opens in Terminal for password and Steam Guard entry. Credentials never enter this launcher. SteamCMD requires Rosetta; the game runs natively.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            GroupBox("Play") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Toggle("Fullscreen", isOn: $model.fullscreen)
                        Toggle("Apply maximum graphics on launch", isOn: $model.maximumGraphics)
                    }
                    Text("Uses your display resolution. Maximum graphics may reduce performance on older Macs.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Play Zero Hour", systemImage: "play.fill") { model.play("vanilla") }
                            .buttonStyle(.borderedProminent).disabled(!model.engine || !model.assets)
                        Button(model.rotr ? "Play Rise of the Reds" : "Install Rise of the Reds") {
                            if model.rotr { model.play("rotr") } else { model.showModConsent = true }
                        }.disabled(!model.engine || !model.assets)
                    }
                    Text("ROTR 1.87 Public Build 2.0 installs separately. Zero Hour and ROTR share user settings and saves; name mod saves clearly.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            HStack {
                if model.busy { ProgressView().controlSize(.small) }
                Text(model.status).textSelection(.enabled)
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
        .padding(24).frame(width: 760)
        .disabled(model.busy)
        .task { model.refresh() }
        .alert("Install Rise of the Reds?", isPresented: $model.showModConsent) {
            Button("Install") { model.installROTR() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Downloads about 1.5 GB from GenLauncher’s public HTTP mirror. Every file is checked against a pinned SHA-256, but these pins were recorded from the mirror, not signed by the mod publisher. Allow up to 5 GB extra disk space. No game or mod files are bundled in this launcher.")
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
