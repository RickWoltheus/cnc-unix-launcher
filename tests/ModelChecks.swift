import Foundation

@main
struct ModelChecks {
    @MainActor static func main() {
        let model = LauncherModel()
        precondition(model.catalog.count == 5)
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
        for mod in model.catalog {
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
        precondition(GameInfo.catalog.count == 4)
        for id in ["cnc", "ra"] {
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
        print("Model selection and recovery checks passed. No windows, sign-in or game launches.")
    }
}
