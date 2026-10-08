import Foundation

@main
struct ModelChecks {
    @MainActor static func main() {
        let model = LauncherModel()
        precondition(model.catalog.count == 7)
        precondition(model.activeProfile == "vanilla")
        precondition(!model.activeNeedsInstall)
        precondition(model.canEnterStep(1))
        precondition(!model.canEnterStep(2))
        precondition(!model.canEnterStep(3))
        model.engine = true
        precondition(!model.canEnterStep(2))
        model.steam = true
        precondition(model.canEnterStep(2))
        precondition(!model.canEnterStep(3))
        for mod in model.availableMods {
            model.selectedMod = mod.id
            precondition(model.activeProfile == mod.id)
            precondition(model.activeNeedsInstall)
            model.installedMods.insert(mod.id)
            precondition(!model.activeNeedsInstall)
        }
        model.selectedGame = "base"
        precondition(model.activeProfile == "base")
        precondition(model.selectedModInfo == nil)
        precondition(!model.activeNeedsInstall)
        model.selectedGame = "vanilla"
        model.selectedMod = "vanilla"
        precondition(model.activeProfile == "vanilla")
        model.assets = true
        model.steamDownloadStatus = "downloading"
        precondition(!model.gameAssetsReady)
        model.steamDownloadStatus = "complete"
        precondition(model.gameAssetsReady)
        precondition(model.canEnterStep(3))
        model.steamSessionRunning = true
        precondition(!model.canEnterStep(3))
        model.steamSessionRunning = false
        model.externalInstallRunning = true
        precondition(!model.canEnterStep(3))
        model.externalInstallRunning = false
        model.steamDownloadStatus = "no-license"
        precondition(!model.canEnterStep(3))
        model.steamDownloadStatus = "wrong-password"
        precondition(!model.canEnterStep(3))
        model.steamDownloadStatus = "complete"
        model.busy = true
        precondition(!model.canEnterStep(2))
        model.busy = false
        let unsupported = LauncherModel(systemSupported: false)
        precondition(!unsupported.canEnterStep(1))
        model.selectedGame = "base"
        precondition(!model.canEnterStep(2))
        model.baseEngine = true
        precondition(model.canEnterStep(2))
        precondition(!model.canEnterStep(3))
        model.baseAssets = true
        precondition(model.canEnterStep(3))
        precondition(SteamGuidance.forStatus("wrong-password").title == "Steam rejected the password")
        precondition(SteamGuidance.forStatus("no-license").title == "This Steam account does not own the game")
        precondition(RecoveryAdvice.forMessage("ERROR No subscription").title == "Steam could not find your game")
        precondition(RecoveryAdvice.forMessage("Checksum mismatch").title == "The download did not match")
        precondition(RecoveryAdvice.forMessage("VK_ERROR_INCOMPATIBLE_DRIVER").title == "The graphics runtime needs repair")
        precondition(GameInfo.catalog.count == 7)
        for id in ["cnc", "ra", "ra2", "yuri", "ts"] {
            model.selectedGame = id
            precondition(model.activeProfile == id)
            precondition(model.selectedModInfo == nil)
            precondition(!model.activeNeedsInstall)
            precondition(!model.canEnterStep(2))
            model.classicEngines.insert(id)
            precondition(model.canEnterStep(2))
            precondition(!model.canEnterStep(3))
            model.classicAssets.insert(id)
            precondition(model.canEnterStep(3))
        }
        model.selectedGame = "cnc"
        precondition(Set(model.availableMods.map(\.id)) == ["combined-arms", "tdhd"])
        model.selectedMod = "tdhd"
        precondition(model.activeProfile == "tdhd")
        precondition(model.activeNeedsInstall)
        model.steamTarget = "tdhd"
        precondition(!model.canEnterStep(2))
        model.nativeEngines.insert("tdhd")
        precondition(model.canEnterStep(2))
        precondition(!model.canEnterStep(3))
        model.installedMods.insert("tdhd")
        precondition(model.canEnterStep(3))
        precondition(ProductInfo.shared.name == "C&C Unix Launcher")
        precondition(ProductInfo.shared.modRequestURL(game: "C&C").absoluteString.contains("template=mod-request.md"))
        model.applyWineSession("running")
        precondition(model.gameRunning)
        model.applyWineSession("stopping")
        precondition(model.gameRunning)
        model.applyWineSession("idle")
        precondition(!model.gameRunning)
        model.gameRunning = true
        model.applyWineSession("idle")
        precondition(model.gameRunning) // A native game is not cleared by idle Wine services.
        model.gameRunning = false
        precondition(CommunityInfo.shared?.projects.contains { $0.name == "GeneralsX" } == true)
        precondition(CommunityInfo.shared?.supportLinks.contains { $0.url.absoluteString == "https://ko-fi.com/gcenx" } == true)
        print("Model selection and recovery checks passed. No windows, sign-in or game launches.")
    }
}
