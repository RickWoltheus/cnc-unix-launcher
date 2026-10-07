import AppKit

@main
struct SteamGuideChecks {
    @MainActor static func main() {
        _ = NSApplication.shared
        let model = LauncherModel(systemSupported: true)
        let guide = SteamGuideWindow()
        let panel = guide.makePanel(model: model, onContinue: {})
        precondition(panel.level == .floating)
        precondition(!panel.hidesOnDeactivate)
        precondition(panel.styleMask.contains(.nonactivatingPanel))
        precondition(!panel.isVisible && !panel.isKeyWindow)
        model.engine = true
        model.steam = true
        model.assets = true
        model.steamDownloadStatus = "validating"
        precondition(!model.canEnterStep(3))
        precondition(model.steamGuidance.stage == 2)
        model.steamDownloadStatus = "complete"
        precondition(model.canEnterStep(3))
        model.steamStarting = true
        precondition(!model.gameAssetsReady)
        precondition(model.steamGuidance.stage == 0)
        panel.close()
        print("Native Steam guide is floating, nonactivating, retained on deactivation, and validation gates passed. No visible windows, Steam or games started.")
    }
}
