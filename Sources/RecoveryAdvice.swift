import Foundation

struct RecoveryAdvice {
    let title: String
    let message: String

    static func forMessage(_ text: String) -> RecoveryAdvice {
        let message = text.lowercased()
        if message.contains("no subscription") || message.contains("license") {
            return RecoveryAdvice(title: "Steam could not find your game", message: "Sign in with the account that owns Generals or Zero Hour. The Ultimate Collection includes them; Remastered does not. You do not need an extra subscription.")
        }
        if message.contains("checksum mismatch") {
            return RecoveryAdvice(title: "The download did not match", message: "Retry the installation. If it fails again, check for a launcher update. We keep the previous installation and never bypass the file check.")
        }
        if message.contains("no space left") {
            return RecoveryAdvice(title: "Your Mac needs more space", message: "Free at least 8 GB for a game or mod, then retry. Your existing installation has been kept.")
        }
        if message.contains("steam files are incomplete") || message.contains("steam assets") {
            return RecoveryAdvice(title: "Steam has not finished installing", message: "Return to Steam sign-in and repeat the download. Steam checks and repairs the files. Wait for the success message before playing.")
        }
        if message.contains("vk_error") || message.contains("library not loaded") || message.contains("dyld") {
            return RecoveryAdvice(title: "The graphics runtime needs repair", message: "Quit the game, then choose Repair game engine in Help. The launcher restores its verified runtime libraries.")
        }
        if message.contains("already running") || message.contains("quit the game") {
            return RecoveryAdvice(title: "Close your current game first", message: "Save and quit normally, then retry. The launcher will not replace files while a game is running.")
        }
        if message.contains("installation or steam download") {
            return RecoveryAdvice(title: "Your installation is still running", message: "Wait for the download or repair to finish, then play. We keep the game closed while its files are changing.")
        }
        if message.contains("could not resolve") || message.contains("failed to connect") || message.contains("curl:") {
            return RecoveryAdvice(title: "The download server is unavailable", message: "Check your internet connection and retry. Verified files are reused, so you will not need to download everything again.")
        }
        return RecoveryAdvice(title: "We could not finish that step", message: "Retry once. If it still fails, open Details below and share the error text. Your existing game data remains in place.")
    }
}
