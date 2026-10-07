C&C Unix Launcher 0.2.0 adds a themed native game library, Combined Arms and Tiberian Dawn HD profiles, mod requests through GitHub, and local online setup. Existing data and preferences survive the rename.

Install C&C and Red Alert through OpenRA, and native Generals and Zero Hour on Apple Silicon macOS or x86_64 Linux using your own Steam account, with optional Rise of the Reds, ShockWave, ShockWave Chaos, Contra and The End of Days data installations. Both interfaces have a themed game sidebar and use the same guided setup, validation and Steam guidance resources.

This development preview passed Mac headless build/installer checks and windowed Zero Hour/ROTR menu launches. Linux model/offscreen UI, installer-adapter and packaged-resource checks passed in OrbStack; real Linux desktop/GPU and fresh Steam sign-in tests remain pending. Classic-game imports passed with synthetic data and the actual OpenRA utilities on both platforms; owned Steam assets and classic gameplay remain unverified. Base-game runtime and full mod gameplay remain unverified. Launcher replacement is manual, and engine/mod upgrades use reviewed manifests.

Download **CnC-Unix-Launcher-macOS-arm64.zip**, extract it and move **C&C Unix Launcher.app** to Applications. Requires Apple Silicon, macOS 15+, and Steam ownership of the selected game; The Ultimate Collection includes both games, while Remastered does not. For the unnotarized preview, use **System Settings → Privacy & Security → Open Anyway** after the first blocked launch.

On Linux, extract **CnC-Unix-Launcher-linux-x86_64.tar.gz** and run **bash CnCUnixLauncher/start-launcher.sh**. The preview targets Ubuntu/Debian-based x86_64 desktops with Vulkan-capable drivers; dependency setup can ask for an administrator password in a local terminal.

See the [README](https://github.com/RickWoltheus/cnc-unix-launcher#readme) for setup, checksum verification, mod limitations and update behavior. No game assets or mod archives are bundled.

This volunteer project has a €0 budget. Apple Developer Program membership is currently unfunded; the Mac preview lacks Developer ID signing and notarization. See the README or Why macOS warns for graphical first-launch instructions. Online browser approval/firewall prompts and gameplay remain user-tested steps; local preparation does not prove a match works.
