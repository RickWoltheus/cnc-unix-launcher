import AppKit
import SwiftUI

@MainActor
final class SteamGuideWindow: NSObject, NSWindowDelegate {
    private(set) var panel: NSPanel?
    private var timer: Timer?

    func makePanel(model: LauncherModel, onContinue: @escaping () -> Void) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 600),
                            styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = SteamGuideCopy.shared.title
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: SteamGuideView(model: model, onContinue: onContinue))
        return panel
    }

    func show(model: LauncherModel, onContinue: @escaping () -> Void) {
        if panel == nil {
            panel = makePanel(model: model, onContinue: onContinue)
            if let frame = NSScreen.main?.visibleFrame, let panel {
                panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 16,
                                             y: frame.maxY - panel.frame.height - 16))
            }
        }
        panel?.orderFrontRegardless()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak model] _ in
            Task { @MainActor in model?.refresh() }
        }
    }

    func close() { panel?.close() }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        panel = nil
    }
}

struct SteamGuideView: View {
    @ObservedObject var model: LauncherModel
    let onContinue: () -> Void
    private let copy = SteamGuideCopy.shared
    private var guidance: SteamGuidance {
        SteamGuidance.forStatus(model.gameAssetsReady ? "complete" : (model.steamStarting ? "waiting" : model.steamDownloadStatus))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "lock.shield.fill").foregroundStyle(model.game.color)
                Text(copy.title).font(.system(size: 20, weight: .bold))
            }
            Text(model.steamTitle).font(.system(size: 12)).foregroundStyle(CommandTheme.muted)
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.securityTitle).font(.system(size: 13, weight: .semibold))
                Text(copy.securityDetail).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(CommandTheme.panel)
            HStack(spacing: 12) {
                ForEach(Array(copy.stages.enumerated()), id: \.offset) { index, title in
                    VStack(spacing: 6) {
                        Image(systemName: model.gameAssetsReady || index < guidance.stage ? "checkmark.circle.fill" : "circle")
                        Text(title).font(.system(size: 10))
                    }.frame(maxWidth: .infinity)
                        .foregroundStyle(index == guidance.stage || model.gameAssetsReady ? model.game.color : CommandTheme.muted)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(model.steamLaunchError == nil ? guidance.title : "Steam Terminal could not open")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(model.game.color)
                Text(model.steamLaunchError ?? guidance.detail).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            }.accessibilityIdentifier("steam-guide-status")
            Spacer(minLength: 0)
            Text(copy.visibilityDetail).font(.system(size: 11)).foregroundStyle(CommandTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(copy.terminalLabel) { model.returnToSteamWindow() }.buttonStyle(.plain)
                Spacer()
                if model.gameAssetsReady {
                    Button(copy.continueLabel, action: onContinue).buttonStyle(.borderedProminent)
                        .disabled(!model.canEnterStep(3))
                } else if guidance.error || model.steamLaunchError != nil {
                    Button(copy.retryLabel) { model.downloadAssets() }.buttonStyle(.borderedProminent)
                        .disabled(!model.canEnterStep(2) || model.steamSessionRunning || model.externalInstallRunning || model.steamStarting)
                }
            }.font(.system(size: 12))
            Link(copy.helpLabel, destination: URL(string: "https://help.steampowered.com/en/wizard/HelpWithLogin")!)
                .font(.system(size: 11))
        }.padding(20).frame(width: 420, height: 600).background(CommandTheme.background)
            .preferredColorScheme(.dark).tint(model.game.color)
    }
}
