# C&C 3 and Kane’s Wrath — experimental development support

These profiles are not included in the published v0.3.0 download. C&C 3 and
Red Alert 3 were tested by the user on macOS 26 with excellent performance;
RA3 also ran well at Ultra High settings. Kane’s Wrath and Linux gameplay
remain unverified. This is original Windows-game compatibility, using owned
Steam assets.

## Mac

Requires Apple Silicon, macOS 15+, Rosetta 2 and an owned Steam copy of the game.
The installer pins [athei’s free Wine build](https://github.com/athei/wine-build)
and [mtld3d](https://github.com/athei/mtld3d), which renders DirectX 9 through
Metal. The Wine bundle also includes DXMT and Apple’s proprietary D3DMetal for
other DirectX paths. Their supplied licenses are retained; the whole bundle is
not open source. No paid compatibility application is required. Older 2D game
runtimes remain separate.

1. Select the game and choose **Prepare my Mac**. Archives pass SHA-256 and the
   optional local scan before extraction. Preparation opens no game or Wine prefix.
2. Download your owned English Steam game. Password/Steam Guard go only into
   Valve’s separate SteamCMD terminal.
3. Choose windowed mode for the first launch, then **Play**. A floating launch
   guide explains working-copy preparation, Wine setup and Windows Steam startup.
4. Leave Steam’s updater open until it finishes. Sign in in Valve’s window if
   requested. The launcher asks Steam to start this game; if its library remains
   visible after updates finish, select this game and click Steam’s **Play** once.
   Use the guide’s **Open Steam** button to return to the matching environment.
5. macOS may ask about microphone access when the game initializes audio/voice
   chat. Choose Allow only if you want voice chat; the launcher does not record
   audio or grant permissions. The guide hides when the game process starts.

The launcher extracts the required Microsoft DirectX helpers locally from the
owned game’s installer CABs. Those DLLs are never included in launcher releases.
Graphics quality is configured in the game. The guide contains fixed progress
labels and optional-permission advice; it does not inspect login fields or
claim it can observe whether you answered a macOS permission prompt.

New prefixes and saves live under `compatibility/<game>/metal/prefix`.
Existing tested `mtld3d-test/prefix` paths are retained. Migration from an older
Wine prefix copies it locally and leaves the source in place. Runtime repair
retains prefixes and keeps the older compatibility runtime available.

A project-owned MIT helper starts Steam’s original browser with CPU rendering
and single-process mode, reducing browser process isolation. No sign-in inputs
or raw browser arguments are logged. Valve manages client/game updates outside
the pinned archive and optional-scanner coverage. Wine is not a security sandbox.

To switch games, use the launcher so it selects the matching Wine environment.

## Linux

Requires the native distribution Steam client on an x86_64 Linux desktop with
working Vulkan graphics drivers. Flatpak Steam is not integrated yet. Steam
manages Proton, its runtime downloads, first-run dependencies, updates and saves.
Our optional archive scanner does not inspect Steam-managed downloads.

1. Install/open Steam from your distribution and sign in in Valve’s UI.
2. Select the game in this launcher, then **Open Steam setup**.
3. In Steam’s game **Properties → Compatibility**, enable **Proton 11**. Install
   the English game and start it once from Steam to finish Proton/first-run setup.
4. Return to the launcher and let its readiness check finish. It recognizes the
   default Steam library and external libraries listed by Steam. Play stays
   locked until Proton is selected and installed, Steam reports a completed game
   download and the startup configuration points to a present Windows executable.
5. **Play** calls Steam with the selected windowed/fullscreen and resolution
   arguments. Steam retains ownership of its game files and compatibility prefix;
   the launcher waits for the actual game process to close, leaving Steam running.

Use Steam’s **Verify integrity of game files** for repair and its own Downloads
page for updates. Launcher releases do not update Steam-managed Proton.

## Limits and remaining manual checks

- English startup configurations only in this first integration.
- No curated C&C 3 mods or automated C&C:Online installation yet.
- Runtime checks and synthetic fixtures are not gameplay validation.
- Test launch, intro video/audio/input, campaign, skirmish, save/load, windowed and
  fullscreen, normal quit and a second launch on each platform.
- For Kane’s Wrath also test Global Conquest and whether its Steam edition requires
  a separately installed Tiberium Wars copy/registration in this runtime.
- Check Steam integration/ownership behavior on Mac. A versioned executable and
  startup configuration being present does not prove Steam startup will succeed.
- Retest RA2/Yuri and native Generals/OpenRA after preparing C&C 3.

## Provenance

Both Mac archive hashes match GitHub’s published asset digests and were checked
locally. The installer uses the same checksum/scan gate as existing downloads.
See [runtime notices](../manifests/sage-notice.txt) and
[security scope](security.md). Wine prefixes are not a security sandbox.

[Valve’s Proton releases](https://github.com/ValveSoftware/Proton/releases) include
recent fixes for C&C 3/Kane’s Wrath. [BattleLab](https://github.com/C-C-Online-2-0/BattleLab)
and [OpenCnCOnline](https://github.com/xan105/CnC-Online) document the distinction
between EA launchers and the versioned game executable; they are research
references, not additional executable downloads in this PR.
