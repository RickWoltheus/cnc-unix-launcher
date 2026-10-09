# C&C 3 and Kane’s Wrath — experimental development support

These profiles are being prepared in a development PR. They are not included in
v0.3.0. No campaign, skirmish, video playback, graphics or multiplayer success
has been established by the headless tests. Red Alert 3/Uprising are follow-up
work, after the C&C 3 graphics path has been tested.

## Mac

Requires Apple Silicon, macOS Tahoe 26+, Rosetta 2 and an owned Steam copy of the
selected game. The launcher keeps its existing macOS 15 minimum for older games.
The [Sikarugir documentation](https://github.com/Sikarugir-App/Sikarugir) specifies
Apple Silicon/Tahoe for D9VK. This integration uses the separately pinned
WS12WineSikarugir11.0_1 engine and D9VK/Kosmickrisp libraries from Template-1.0.21.
It does not replace the working 2D Wine runtime.

1. Select **C&C 3: Tiberium Wars** or **Kane’s Wrath**.
2. Choose **Prepare my Mac**. Runtime archives pass SHA-256 and the optional local
   scan before extraction. Preparation opens no game and creates no Wine prefix.
3. Choose **Sign in to Steam**. Enter password/Guard only in the local SteamCMD
   terminal. This downloads your owned game in English; no replacement EA binary
   is downloaded from GitHub or mod sites.
4. Choose windowed mode for the first manual test, then **Play**. The launcher
   copies Steam files into a per-game working folder, initializes that game’s own
   Wine prefix and installs D9VK DLLs. It then installs/opens Valve’s official
   Windows Steam client inside that profile and starts the game through Steam.
   Sign in only in Valve’s window if requested. SteamCMD alone cannot satisfy
   this edition’s Steam API authentication. First-time client updates may take
   several minutes. Graphics quality stays in the game.

Prefixes and saves are under `compatibility/cnc3/prefix` and
`compatibility/kw/prefix` in the installation folder. Updating the owned Steam
copy refreshes the working game copy while retaining the prefix. Runtime repair
retains both game prefixes and does not upgrade Red Alert 2’s runtime.

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

## Limits and manual checks before merging

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
