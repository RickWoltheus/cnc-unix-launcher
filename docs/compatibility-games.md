# Original Windows games through Wine (experimental)

Select **Red Alert 2**, **Yuri’s Revenge** or **Tiberian Sun** in the sidebar.
Firestorm is included with Tiberian Sun; switch modes in the original game menu.
The existing four-step wizard installs free Wine + cnc-ddraw, downloads your
owned Steam game in the local credential console, and enables Play after file
checks. Windowed mode is recommended for the first gameplay check.

This integration has headless installer and dummy-launch checks, not gameplay
validation. Campaigns, audio, GPU rendering, save/load and the exact Steam
executable behavior still need interactive testing. CnCNet multiplayer and mods
for these games are not installed yet. GeneralsX and OpenRA remain native ports;
these new entries run original Windows executables through a compatibility layer.

## Runtime and dependencies

- macOS: WineHQ package 11.0_1 from [Gcenx](https://github.com/Gcenx/macOS_Wine_builds),
  including 32-bit WoW64 support. Apple Silicon uses Rosetta, checked by the local
  Steam setup script. No Homebrew, paid wrapper or Windows VM is required.
- Linux x86_64: Wine 11.0 WoW64 from [Kron4ek](https://github.com/Kron4ek/Wine-Builds).
  The Prepare step offers installation of the distribution Wine package for its
  system libraries. Ubuntu/Debian setup uses apt in your local terminal. Installing
  these libraries may take several hundred MB. Other distributions need equivalent
  Wine, graphics and audio libraries installed through their package manager.
- Both: [cnc-ddraw 7.1.0.0](https://github.com/FunkyFr3sh/cnc-ddraw/tree/v7.1.0.0)
  replaces DirectDraw in an isolated working copy. Wine uses `ddraw=n,b`.
  macOS defaults to GDI because this WineHQ build has no OpenGL driver. Linux
  keeps cnc-ddraw’s automatic renderer selection.

The packages are downloaded on demand and verified against pinned SHA-256 hashes.
Wine/cnc-ddraw versions change only when the launcher’s manifests are reviewed
and updated. Repair installs the pinned version; it is not a silent latest-version
upgrade. No automatic game launch occurs during preparation.

## Owned files, saves and updates

Steam IDs: RA2/Yuri’s Revenge **2229850**, Tiberian Sun/Firestorm **2229880**.
RA2 and Yuri share one Steam download but use separate working folders/prefixes.
SteamCMD supplies all original executables and assets; nothing comes from game
mirrors. No serial number, modified EA executable or Steam credential is bundled.

Under the launcher installation folder:

```text
RedAlert2/                    # original owned Steam download
TiberianSun/                  # original owned Steam download
wine-runtime/                 # pinned free runtime
cnc-ddraw/                    # pinned shim and upstream attribution
compatibility/ra2/game/        # owned working copy, INIs and *.sav
compatibility/ra2/prefix/      # created on the first explicit Play
compatibility/yuri/            # independent game copy and prefix
compatibility/ts/              # independent game copy and prefix
logs/ra2.log                  # runtime diagnostics, never Steam sign-in output
```

The default Mac root is `~/Library/Application Support/GeneralsX Launcher`;
Linux uses `${XDG_DATA_HOME:-~/.local/share}/generalsx-launcher`.
Allow additional disk space for each working copy and prefix (several GB).
Keep backups of the profile working folder before experimenting with external mods.

Use **Help → Check Steam files** to validate/update the owned download. On the
next explicit Play, a changed Steam manifest refreshes the working copy while
preserving root-level INI settings and SAV files. Saves/settings from other
launchers are not imported automatically. Original Steam files stay untouched.

## Display and troubleshooting

- The Fullscreen toggle selects borderless fullscreen through cnc-ddraw. Windowed
  mode uses a 1280×720 output window; game resolution stays under its own Video
  settings. Alt+Enter toggles modes. There is no Generals graphics-quality preset.
- If preparation fails, retry **Repair game engine**; failed downloads do not
  replace installed files. Missing Linux libraries require the dependency terminal.
- If Play fails, inspect the selected profile log through **Open installation
  folder**. No original executable is patched or replaced to bypass a failure.
  Steam-client requirements, missing registry values, audio and platform-specific
  errors may still need fixes after an authorized real gameplay test.
- Display changes back up `ddraw.ini` to `ddraw.ini.before-launcher`. Launcher-owned
  display keys are reapplied for each Play; unrelated settings are preserved.
- Online setup explains CnCNet’s pending status and disables its prepare button.
  No multiplayer account, router change or match test is performed.
