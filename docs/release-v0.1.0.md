Install C&C and Red Alert through OpenRA, and native Generals and Zero Hour on Apple Silicon macOS or x86_64 Linux using your own Steam account, with optional Rise of the Reds, ShockWave, ShockWave Chaos, Contra and The End of Days data installations. Both interfaces have a themed game sidebar and use the same guided setup, validation and Steam guidance resources.

This development preview passed Mac headless build/installer checks and windowed Zero Hour/ROTR menu launches. Linux model/offscreen UI, installer-adapter and packaged-resource checks passed in OrbStack; real Linux desktop/GPU and fresh Steam sign-in tests remain pending. Classic-game imports passed with synthetic data and the actual OpenRA utilities on both platforms; owned Steam assets and classic gameplay remain unverified. Base-game runtime and full mod gameplay remain unverified. Launcher replacement is manual, and engine/mod upgrades use reviewed manifests.

Download **GeneralsX-Launcher-macOS-arm64.zip**, extract it and move **GeneralsX Launcher.app** to Applications. Requires Apple Silicon, macOS 15+, and Steam ownership of the selected game; The Ultimate Collection includes both games, while Remastered does not. For the unnotarized preview, use **System Settings → Privacy & Security → Open Anyway** after the first blocked launch.

On Linux, extract **GeneralsX-Launcher-linux-x86_64.tar.gz** and run **bash GeneralsXLauncher/start-launcher.sh**. The preview targets Ubuntu/Debian-based x86_64 desktops with Vulkan-capable drivers; dependency setup can ask for an administrator password in a local terminal.

See the [README](https://github.com/RickWoltheus/generalsx-mac-launcher#readme) for setup, checksum verification, mod limitations and update behavior. No game assets or mod archives are bundled.
