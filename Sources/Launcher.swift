import AppKit
import SwiftUI

struct LauncherView: View {
    @StateObject private var model = LauncherModel()
    @State private var step = 0
    @State private var showDetails = false
    @State private var playAfterModInstall = false
    private var accent: Color { model.game.color }
    private let steps = ["Choose game", "Prepare Mac", "Steam download", "Play"]

    var body: some View {
        ZStack {
            CommandBackground()
            VStack(spacing: 0) {
                header
                HStack(spacing: 0) {
                    gameSidebar
                    VStack(spacing: 0) {
                        stepper
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                screen
                                if let recovery = model.recovery { recoveryPanel(recovery) }
                                if model.busy { loadingPanel }
                                if showDetails && !model.output.isEmpty {
                                    Text(model.output).font(.system(size: 11, design: .monospaced))
                                        .textSelection(.enabled).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(CommandTheme.panel)
                                }
                            }.padding(.horizontal, 36).padding(.vertical, 28)
                        }
                    }
                }
                footer
            }
        }
        .frame(width: 1200, height: 790)
        .environment(\.gameAccent, accent)
        .preferredColorScheme(.dark)
        .tint(accent)
        .task { model.refresh() }
        .onChange(of: model.gameAssetsReady) { _, ready in
            if ready && model.canEnterStep(3) { step = 3 }
            else { validateCurrentStep() }
        }
        .onChange(of: model.gameEngineReady) { _, ready in
            if ready && model.canEnterStep(3) { step = 3 }
            else { validateCurrentStep() }
        }
        .onChange(of: model.steam) { _, _ in advanceAfterPreparation() }
        .onChange(of: model.selectedGame) { _, _ in step = 0; model.recovery = nil; model.refresh() }
        .onChange(of: model.busy) { _, busy in if !busy { advanceAfterPreparation() } }
        .task(id: step) {
            if step == 2 {
                while !Task.isCancelled {
                    model.refresh()
                    try? await Task.sleep(for: .seconds(3))
                }
            }
        }
        .alert("Install \(model.selectedModInfo?.title ?? "mod")?", isPresented: $model.showModConsent) {
            Button(playAfterModInstall ? "Install & Play" : "Install") { model.installMod(andPlay: playAfterModInstall) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This optional community mod needs up to 8 GB of space. Its data downloads come from GenLauncher’s HTTP mirror and are checked against pinned file hashes. Mod gameplay support is experimental. Your regular game stays separate.")
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 28)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("COMMAND & CONQUER").font(.system(size: 23, weight: .black)).tracking(4)
                    Text("NATIVE MAC COMMAND CENTER").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(CommandTheme.muted)
                }
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(Color.green).frame(width: 5, height: 5)
                Text("APPLE SILICON").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(CommandTheme.muted)
            }
        }.padding(.horizontal, 36).padding(.vertical, 24)
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                Button {
                    if model.canEnterStep(index) { step = index }
                } label: {
                    HStack(spacing: 9) {
                        ZStack {
                            Circle().stroke(index <= step ? accent : CommandTheme.line, lineWidth: 1).frame(width: 26, height: 26)
                            if index != step && model.stepComplete(index) { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                            else { Text("\(index + 1)").font(.system(size: 11, weight: .bold)) }
                        }
                        Text(steps[index].uppercased()).font(.system(size: 10, weight: .bold)).tracking(1)
                    }.foregroundStyle(index <= step ? accent : CommandTheme.muted)
                }.buttonStyle(.plain).disabled(!model.canEnterStep(index))
                    .help(model.stepHelp(index)).accessibilityIdentifier("step-\(index)")
                if index < 3 { Rectangle().fill(CommandTheme.line).frame(height: 1).padding(.horizontal, 18) }
            }
        }.padding(.horizontal, 36).padding(.vertical, 18).background(Color.black.opacity(0.2))
    }

    @ViewBuilder private var screen: some View {
        switch step {
        case 0: chooseGame
        case 1: prepareMac
        case 2: steamDownload
        default: playScreen
        }
    }

    private var gameSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR COLLECTION").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(CommandTheme.muted)
                .padding(.bottom, 10)
            ForEach(GameInfo.catalog) { game in
                Button { model.selectedGame = game.id } label: {
                    HStack(spacing: 12) {
                        Text(game.emblem).font(.system(size: 17, weight: .black))
                            .frame(width: 46, height: 46)
                            .foregroundStyle(game.color)
                            .background(game.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(game.title).font(.system(size: 13, weight: .bold))
                            Text(game.engine).font(.system(size: 10)).foregroundStyle(CommandTheme.muted)
                        }
                        Spacer(minLength: 0)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(model.selectedGame == game.id ? game.color.opacity(0.10) : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(model.selectedGame == game.id ? game.color : .clear, lineWidth: 1))
                }.buttonStyle(.plain).disabled(model.busy || model.gameRunning || model.externalInstallRunning)
                    .accessibilityIdentifier("game-\(game.id)")
            }
            Spacer()
            Text("NATIVE ENGINES").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(accent)
            Text("More games will join the collection as their engine support is ready.")
                .font(.system(size: 11)).foregroundStyle(CommandTheme.muted).fixedSize(horizontal: false, vertical: true)
            Link("Bugs & feature requests", destination: URL(string: "https://github.com/RickWoltheus/generalsx-mac-launcher/issues")!)
                .font(.system(size: 11)).accessibilityIdentifier("github-issues")
            Link(destination: URL(string: "https://ko-fi.com/ricklemore")!) {
                Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(accent, in: RoundedRectangle(cornerRadius: 8))
            }.accessibilityIdentifier("support-kofi")
        }.padding(20).frame(width: 230).background(Color.black.opacity(0.25))
    }

    private var chooseGame: some View {
        VStack(alignment: .leading, spacing: 24) {
            BriefingTitle(eyebrow: model.game.subtitle, title: model.game.title.uppercased(), subtitle: model.game.summary)
            HStack(spacing: 22) {
                Text(model.game.emblem).font(.system(size: 48, weight: .black)).foregroundStyle(accent)
                    .frame(width: 110, height: 110).background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 9) {
                    Text("POWERED BY \(model.game.engine.uppercased())").font(.system(size: 12, weight: .bold)).tracking(1.5).foregroundStyle(accent)
                    Text(model.game.isClassic ? "A native OpenRA experience using your owned Steam assets. Rules, balance and missions can differ from the original releases." : "A native engine for your owned Steam game. No Windows VM or paid compatibility software.")
                        .font(.system(size: 14)).foregroundStyle(CommandTheme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(CommandTheme.panel)
            Text(model.selectedGame == "ra" ? "Own Red Alert and Command & Conquer on Steam. OpenRA also needs C&C’s desert tileset; setup downloads both owned games." : "Own this game on Steam through The Ultimate Collection. The Remastered Collection is not the asset source for this setup.")
                .font(.system(size: 13)).foregroundStyle(CommandTheme.muted).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("CONTINUE →") {
                    if model.canEnterStep(3) { step = 3 }
                    else if model.canEnterStep(2) { step = 2 }
                    else if model.canEnterStep(1) { step = 1 }
                }.buttonStyle(CommandButton()).disabled(!model.canEnterStep(1)).accessibilityIdentifier("setup-continue")
                Link("Find it on Steam", destination: steamStore).font(.system(size: 12)).padding(.leading, 12)
            }
            if !model.systemSupported {
                Text("This launcher needs an Apple Silicon Mac running macOS 15 or later.").foregroundStyle(accent)
            }
        }
    }

    private var prepareMac: some View {
        VStack(alignment: .leading, spacing: 22) {
            BriefingTitle(eyebrow: "Step 2", title: "We’ll handle the setup.", subtitle: "No Homebrew, Windows install or paid compatibility software needed.")
            ReadinessRow(title: "Native game engine", detail: "A verified Apple Silicon build of \(model.game.engine).", ready: model.gameEngineReady)
            ReadinessRow(title: "Steam downloader", detail: "Valve’s tool downloads the game you own.", ready: model.steam)
            if !model.busy {
                Button(model.gameEngineReady && model.steam ? "CONTINUE TO STEAM →" : "PREPARE MY MAC →") {
                    if model.canEnterStep(2) { step = model.canEnterStep(3) ? 3 : 2 }
                    else { model.prepare() }
                }.buttonStyle(CommandButton()).disabled(!model.canEnterStep(1)).accessibilityIdentifier("install-engine")
            }
        }
    }

    private var steamDownload: some View {
        VStack(alignment: .leading, spacing: 24) {
            BriefingTitle(eyebrow: "Step 3", title: "Bring your Steam copy.", subtitle: "One sign-in, then Steam downloads and checks your game files.")
            VStack(alignment: .leading, spacing: 20) {
                instruction(number: "1", title: "Sign in locally", detail: "A Terminal window opens for Steam. Enter your password and Steam Guard there.")
                instruction(number: "2", title: "Let the download finish", detail: "Wait for Steam’s success message. It can take a few minutes.")
                instruction(number: "3", title: "Come back and play", detail: "This launcher checks automatically and moves to Play when your files are ready.")
            }.padding(24).background(CommandTheme.panel).clipShape(RoundedRectangle(cornerRadius: 5))
            HStack {
                Button(model.steamSessionRunning ? "STEAM IS OPEN" : "SIGN IN TO STEAM →") { model.downloadAssets() }
                    .buttonStyle(CommandButton()).disabled(!model.canEnterStep(2) || model.steamSessionRunning || model.externalInstallRunning).accessibilityIdentifier("download-game")
                Button("Check my download") { model.refresh() }.buttonStyle(.plain).padding(.leading, 15)
                if model.steamSessionRunning {
                    Button("Return to Steam window") { model.returnToSteamWindow() }.buttonStyle(.plain).padding(.leading, 10)
                }
            }
            VStack(alignment: .leading, spacing: 9) {
                Label(model.steamGuidance.title, systemImage: model.steamDownloadStatus == "complete" ? "checkmark.circle.fill" : "person.badge.key.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                Text(model.steamGuidance.detail).font(.system(size: 12)).foregroundStyle(CommandTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Recover your Steam account or password", destination: URL(string: "https://help.steampowered.com/en/wizard/HelpWithLogin")!)
                    .font(.system(size: 11))
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(CommandTheme.panel)
            Text("Your password never enters this launcher. If Steam cannot find the game, check the account and that you own Ultimate Collection rather than Remastered.")
                .font(.system(size: 12)).foregroundStyle(CommandTheme.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func instruction(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Text(number).font(.system(size: 22, weight: .black)).foregroundStyle(accent).frame(width: 25)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail).font(.system(size: 13)).foregroundStyle(CommandTheme.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var playScreen: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center) {
                BriefingTitle(eyebrow: model.activeNeedsInstall ? "Ready to install" : "Ready to deploy", title: model.activeTitle, subtitle: model.selectedModInfo?.summary ?? "Your game is ready. Choose your mode and take command.")
                Spacer()
                Button(model.gameRunning ? "GAME RUNNING" : (model.activeNeedsInstall ? "INSTALL & PLAY →" : "PLAY →")) {
                    if model.activeNeedsInstall {
                        playAfterModInstall = true
                        model.showModConsent = true
                    } else { model.play(model.activeProfile) }
                }
                    .buttonStyle(CommandButton()).disabled(!model.canEnterStep(3))
                    .accessibilityIdentifier("play-game")
            }
            HStack(spacing: 24) {
                Toggle("Fullscreen", isOn: $model.fullscreen).accessibilityIdentifier("fullscreen")
                if !model.game.isClassic {
                    Picker("Graphics", selection: $model.maximumGraphics) {
                        Text("Balanced").tag(false); Text("Maximum").tag(true)
                    }.pickerStyle(.menu).frame(width: 200)
                }
                Spacer()
                Button("Set up another game") { step = 0 }.buttonStyle(.plain).foregroundStyle(CommandTheme.muted)
            }.font(.system(size: 12)).disabled(model.gameRunning || model.busy)
            if model.selectedGame == "vanilla" { modLibrary }
            Text(model.gameRunning ? "Save and quit normally before switching games or installing a mod." : (model.game.isClassic ? "OpenRA uses its own graphics settings. Windowed mode starts at 1280×720; fullscreen follows your desktop." : "Windowed mode uses 1280×720. Balanced graphics is recommended for a smooth first match."))
                .font(.system(size: 11)).foregroundStyle(CommandTheme.muted)
        }
    }

    private var modLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CHOOSE WHAT TO PLAY").font(.system(size: 11, weight: .bold)).tracking(2)
                Spacer()
                Text("OPTIONAL COMMUNITY MODS").font(.system(size: 9)).tracking(1.5).foregroundStyle(CommandTheme.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button { model.selectedMod = "vanilla" } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack {
                                CommandTheme.panel
                                Image(systemName: "flame.fill").font(.system(size: 36)).foregroundStyle(accent)
                            }.frame(width: 140, height: 100)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Zero Hour").font(.system(size: 12, weight: .bold)).frame(height: 30, alignment: .topLeading)
                                Text("ORIGINAL GAME").font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(accent)
                            }.padding(12).frame(width: 140, alignment: .leading)
                        }.background(CommandTheme.panel).clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(model.selectedMod == "vanilla" ? accent : CommandTheme.line, lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityIdentifier("mod-vanilla")
                    ForEach(model.catalog) { mod in
                        Button { model.selectedMod = mod.id } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                ModArtwork(mod: mod).frame(width: 140, height: 100).clipped()
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(mod.title).font(.system(size: 12, weight: .bold)).frame(height: 30, alignment: .topLeading)
                                    Text(model.installedMods.contains(mod.id) ? "INSTALLED" : "AVAILABLE")
                                        .font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(accent)
                                }.padding(12).frame(width: 140, alignment: .leading)
                            }.background(CommandTheme.panel).clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(model.selectedMod == mod.id ? accent : CommandTheme.line, lineWidth: 1))
                        }.buttonStyle(.plain).accessibilityIdentifier("mod-\(mod.id)")
                    }
                }.padding(1)
            }.disabled(model.busy || model.gameRunning)
            if let mod = model.selectedModInfo {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(mod.summary).font(.system(size: 13))
                        HStack {
                            Text("\(mod.version) · Experimental support").font(.system(size: 10)).foregroundStyle(CommandTheme.muted)
                            if let url = mod.homepage { Link("Mod page & artwork credits", destination: url).font(.system(size: 10)) }
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private var loadingPanel: some View {
        HStack(spacing: 16) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.status).font(.system(size: 13, weight: .semibold))
                Text("Downloads are checked before installation. Existing game files stay safe.")
                    .font(.system(size: 11)).foregroundStyle(CommandTheme.muted)
            }
            Spacer()
        }.padding(18).background(CommandTheme.panel).clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func recoveryPanel(_ advice: RecoveryAdvice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(advice.title, systemImage: "exclamationmark.triangle").font(.system(size: 14, weight: .bold)).foregroundStyle(accent)
            Text(advice.message).font(.system(size: 12)).foregroundStyle(CommandTheme.muted).fixedSize(horizontal: false, vertical: true)
            Button("Show details") { showDetails = true }.buttonStyle(.plain).font(.system(size: 12))
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(CommandTheme.panel)
    }

    private var footer: some View {
        HStack {
            Menu("Help") {
                Button("Repair game engine") { model.prepare() }
                Button("Check Steam files") { step = 2 }
                Button("Repair selected mod") { playAfterModInstall = false; model.showModConsent = true }.disabled(model.selectedModInfo == nil || model.selectedGame == "base")
                Button("Open installation folder") { NSWorkspace.shared.open(model.root) }
                Link("Game ownership on Steam", destination: steamStore)
                Link("Bugs & feature requests", destination: URL(string: "https://github.com/RickWoltheus/generalsx-mac-launcher/issues")!)
            }.menuStyle(.borderlessButton).frame(width: 70).disabled(model.busy || model.gameRunning)
            Button(showDetails ? "Hide details" : "Details") { showDetails.toggle() }.buttonStyle(.plain)
            Spacer()
            Text(model.updateStatus).lineLimit(1).font(.system(size: 10)).foregroundStyle(CommandTheme.muted)
            if let url = model.updateURL { Link("Download update", destination: url).font(.system(size: 11)) }
            Button("Check updates") { model.checkUpdates() }.buttonStyle(.plain).font(.system(size: 11)).accessibilityIdentifier("check-updates")
        }.padding(.horizontal, 36).padding(.vertical, 18).background(Color.black.opacity(0.25))
    }

    private var steamStore: URL { URL(string: "https://store.steampowered.com/app/\(model.game.steamID)/")! }

    private func advanceAfterPreparation() {
        if model.canEnterStep(3) { step = 3 }
        else if step == 1 && model.canEnterStep(2) { step = 2 }
        else { validateCurrentStep() }
    }

    private func validateCurrentStep() {
        guard !model.busy && !model.gameRunning else { return }
        if step == 3 && !model.canEnterStep(3) { step = model.canEnterStep(2) ? 2 : 1 }
        if step == 2 && !model.canEnterStep(2) { step = 1 }
        if step == 1 && !model.canEnterStep(1) { step = 0 }
    }
}

@main
struct GeneralsXLauncherApp: App {
    var body: some Scene {
        WindowGroup { LauncherView() }
            .windowResizability(.contentSize)
    }
}
