# GeneralsX Launcher

Native macOS and Linux launchers for Command & Conquer, Red Alert, Generals and
Zero Hour. They install OpenRA or GeneralsX, download your owned files through
Steam, and install five curated Zero Hour mods. A game sidebar changes the
theme and setup state for the selected title. macOS uses SwiftUI; Linux has a separate Qt/PySide6 interface
with the same guided flow.

Enjoy the launcher? [Support its development on Ko-fi](https://ko-fi.com/ricklemore).
Support is optional; the launcher stays free and open source.

**Development preview. Headless installer checks pass; full gameplay and fresh
Steam sign-in testing remain pending.** The app builds for ARM64 and its ad-hoc signature
verifies. Engine/SteamCMD downloads, ROTR installation and repair, settings
backups, and launch arguments have been checked without starting the game.
See [verification.md](docs/verification.md) for the evidence and remaining checks.

## Requirements

- Apple Silicon Mac with macOS 15 or later.
- The selected game owned on your Steam account. The Ultimate Collection
  includes it. **The Remastered Collection does not.**
- About 8 GB free per game and up to 8 GB per optional mod. Allow 40 GB to install everything.
- Internet access and your Steam password/Steam Guard. Enter credentials only in
  the local SteamCMD Terminal window.

End users do not need Homebrew, Xcode, a compiler, CrossOver, or a VM. SteamCMD
requires Apple's free Rosetta; the game engine runs natively as ARM64.

**Linux preview:** x86_64 Ubuntu 24.04+ / Debian 12+ desktops with Vulkan-capable drivers
and glibc 2.36 or newer. Intel Macs, macOS 14 and ARM Linux are not supported by these packages.
The Linux archive bundles Python and Qt. Generals engines use upstream Flatpak
bundles; OpenRA uses extracted AppImages with its runtime included. Prepare Linux guides installation of Flatpak and SteamCMD's 32-bit
dependencies in a local terminal. See [Linux setup and validation](docs/linux.md).
Linux headless/offscreen checks have passed; real desktop, sign-in, Flatpak
sandbox and GPU/gameplay tests remain pending.

## Install and play on macOS

When a verified release is available:

1. Download [GeneralsX-Launcher-macOS-arm64.zip](https://github.com/RickWoltheus/generalsx-mac-launcher/releases/download/v0.1.0/GeneralsX-Launcher-macOS-arm64.zip).
2. Extract it, and move **GeneralsX Launcher.app** to Applications.
3. Open the app. For the unnotarized preview, use **System Settings → Privacy &
   Security → Open Anyway** after the first blocked launch. You can alternatively
   remove quarantine from the app you downloaded:

   ```sh
   xattr -dr com.apple.quarantine "/Applications/GeneralsX Launcher.app"
   ```

4. Choose a game in the sidebar and click **Continue**. C&C and Red Alert use
   OpenRA with modernized gameplay; Generals and Zero Hour use GeneralsX.
5. Click **Prepare my Mac**. The launcher installs the native engine and Steam downloader.
6. Click **Sign in to Steam**. A separate **Steam setup guide** opens beside
   Terminal and follows the password, Steam Guard, download and validation steps.
   Enter credentials only in Valve’s local console. The guide does not store
   passwords/codes or display raw Steam output. Let validation finish, then continue
   to Play. Use **Help → Show Steam guide** to reopen it; closing it does not stop Steam.
7. Select **Zero Hour** or a mod in **Choose what to play**. The one big **Play**
   button always launches your highlighted selection. For a new mod it becomes
   **Install & Play**, with a download confirmation first.

The app pins GeneralsX 1.0.2, OpenRA release-20250330 and the mod versions below. Installing the engine
again repairs it; it does not silently upgrade to an untested upstream version.
SteamCMD updates itself using Valve's normal bootstrap.

## Install and play on Linux

Extract `GeneralsX-Launcher-linux-x86_64.tar.gz` and run:

```sh
bash ./GeneralsXLauncher/start-launcher.sh
```

The startup script checks desktop libraries before opening the UI and offers
installation on Ubuntu/Debian. Follow the same four-step setup. If your Linux tools are missing, the launcher
opens a terminal for package installation and then continues engine preparation.
Enter administrator and Steam passwords only in their respective local terminals.
Vulkan drivers must be installed through the host distribution.

## Bugs and feature requests

Use [GitHub Issues](https://github.com/RickWoltheus/generalsx-mac-launcher/issues)
or **Bugs & feature requests** in the launcher. Include your OS version, CPU/GPU,
launcher version, selected game/mod and steps to reproduce. Share relevant error
messages after removing personal information; never post Steam credentials or game assets.

The four-step setup checks prerequisites before unlocking Steam or Play. Existing
verified installations can skip completed steps. Steam sign-in guidance updates
for password errors, Steam Guard, expired codes, rate limits, missing ownership,
connection errors and interrupted downloads. Only a status label reaches the GUI;
credentials stay in Valve's local client. See [issue-handling.md](docs/issue-handling.md).

The mod cards load promotional thumbnails from URLs in the publisher-linked
GenLauncher catalog. Images are fetched at runtime, with placeholders offline;
they are not bundled in this repository or release. Each mod links to its page
for artwork credit and more information.

Sidebar game logos load from the selected game's official Steam artwork CDN.
The logos belong to their respective owners, are not bundled in the release,
and fall back to text emblems when artwork is unavailable.

## Classic games

C&C and Red Alert use owned English Ultimate Collection assets through OpenRA.
OpenRA changes rules, balance and missions; it is not the original Windows game.
Red Alert setup also downloads your owned C&C copy for the required desert tileset.
These integrations passed synthetic import checks; real Steam asset/gameplay tests
remain pending. See [classic game setup](docs/classic-games.md).

## Mods and updates

| Mod | Pinned version |
| --- | --- |
| Rise of the Reds | 1.87 Public Build 2.0 |
| ShockWave | 1.201 GenLauncher Fix 1 |
| ShockWave Chaos | 49 |
| Contra | 10.0.2 Beta 2 Patch 1 |
| The End of Days | 0.98.6 Patch 11 |

These are well-known mods, not a measured popularity ranking. Their installation,
repeat-install, checksum and launch-argument checks passed headlessly. Gameplay
compatibility is **experimental**. The installer excludes Windows binaries,
font replacements, backups, optional mod videos and duplicated EA movie files.
Mods requiring Windows engine patches can have missing features under GeneralsX.

**Check for updates** checks this repository's GitHub releases and links to a
newer launcher ZIP. For this preview, download it, quit the launcher and games,
and replace the app. Game data remains outside the app. Self-replacement is not
automatic. Engine/mod upgrades come through reviewed launcher releases and their
pinned manifests; rerun engine installation or mod installation after updating.
Repeating **Download Steam game** runs Steam's own update and validation.

## Files and privacy

The launcher installs into `~/Library/Application Support/GeneralsX Launcher/`:

```text
engine/          GeneralsX app and bundled runtime libraries
engine-base/     Base Generals engine and runtime
steamcmd/        Valve's downloader
Generals/        Your Steam base Generals installation
GeneralsZH/      Your Steam game installation
RiseOfTheReds/   Separate game installation with ROTR archives
mods/            Other separate mod installations
downloads/      Verified download cache
logs/           Game launch logs
```

No EA game assets, mod archives, engine binaries, credentials, or user saves are
included in this repository or its launcher archive. Downloads go directly to
each user's machine. Steam authentication runs in SteamCMD; this app never
reads the password or Steam Guard code. Valve may cache authentication locally
using its own client behavior. The launcher adds no analytics.

GeneralsX stores settings and saves in its upstream user-data folder,
`~/Library/Application Support/GeneralsX/GeneralsZH/`. All Zero Hour mod profiles
share that folder. Base Generals uses the sibling `Generals` user-data folder.
Name mod saves clearly and load them only with the matching mod.
Maximum graphics backs up `Options.ini` as `Options.before-launcher.ini` before
changing it. Turning off the launcher's checkbox stops applying the preset; it
does not reset already saved options. Change those in the game or restore the
backup while the game is closed.

Balanced graphics uses high detail with 2× anti-aliasing and 8× anisotropic
filtering. Maximum uses 8× anti-aliasing and 16× filtering. Both preserve unrelated
options and the original backup. Use Help to repair the engine or selected mod.

## Download verification

The engine ZIP and SteamCMD bootstrap must match pinned SHA-256 hashes before
extraction. Valve's bootstrap URL can change; an unexpected update stops the
installation until the checksum is reviewed and updated here.

Mods come from the public mirrors listed in the GenLauncher catalog. These
mirrors serve HTTP. Every mod data file must match a SHA-256 recorded from the
previously installed files. Those pins prevent changed downloads from being
accepted, but are **not publisher signatures** and do not establish independent
authenticity of the original mirror contents. The launcher asks for consent
before this optional download and never runs the mod's Windows executables.

Failed installs preserve the previous engine or mod folder. Re-running setup
reuses checksum-verified downloads. Downloads can take several minutes.

## Troubleshooting

- **No subscription:** Steam accepted the login but did not find the required
  license. Check the account and Zero Hour ownership. No extra subscription is
  required when you purchased the game.
- **Rosetta required:** review Apple's installation agreement in Terminal.
- **Checksum mismatch:** do not bypass the check. The upstream file changed or
  the transfer was corrupted; retry or wait for a reviewed manifest update.
- **Pink textures or missing voices:** repeat the Steam download with validation.
  The Steam `ZH_Generals` directory contains shared base-game files.
- **Already running:** quit the current match normally before switching profiles
  or changing graphics settings.
- **Installer lock after interruption:** confirm no installer or Steam download
  is running, then remove `.install-lock` in the installation folder and retry.
- **Low FPS:** turn off applying maximum graphics and lower quality/resolution
  in the game. 8× anti-aliasing at Retina resolution can be expensive.
- **Launch failure:** open the installation folder and inspect `logs/vanilla.log`
  or `logs/rotr.log`.

## Build from source

Install Xcode or Apple's command line tools, then:

```sh
xcode-select --install
bash scripts/build.sh
```

Output: `dist/GeneralsX Launcher.app` and
`dist/GeneralsX-Launcher-macOS-arm64.zip`. The app is ad-hoc signed and is not
notarized. No Apple Developer subscription is needed to build it locally.

The UI is SwiftUI; the installer uses macOS's Bash, curl, ditto, tar, and shasum.
Both the app and command-line workflow call the same backend:

```sh
bash scripts/backend.sh engine
bash scripts/backend.sh engine base
bash scripts/backend.sh steam
bash scripts/backend.sh steam-login
bash scripts/backend.sh steam-login base
bash scripts/backend.sh rotr
bash scripts/backend.sh mod shockwave
bash scripts/backend.sh launch vanilla -fullscreen -xres 1920 -yres 1080
bash scripts/backend.sh launch base -win -xres 1280 -yres 720
```

Tests use dummy launchers by default. Never start real games unless the person
using the machine explicitly asks for a game launch or an end-to-end game test.

For Linux builds and offscreen tests, use the commands in [docs/linux.md](docs/linux.md).
`CLAUDE.md` requires behavior changes to update both native frontends. Installation,
checksums, mod activation, Steam status parsing, setup prerequisites and guidance
resources are shared; platform adapters contain the OS-specific commands.

## Credits and license

- [GeneralsX](https://github.com/fbraz3/GeneralsX) provides the Generals engines.
- [OpenRA](https://www.openra.net/) provides the native C&C and Red Alert engines.
  Its Steam import mappings retain GPL-3.0-or-later attribution in `manifests/`.
- [Valve SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) downloads
  owned game files.
- [SWR Productions / Rise of the Reds](https://www.moddb.com/mods/rise-of-the-reds)
  provides the mod.
- [GenLauncher catalog](https://github.com/p0ls3r/GenLauncherModsData) provides
  the mod's download source.

This launcher's original code is MIT-licensed. Downloaded software and data
retain their respective licenses. This is a community project, not an official
EA, Valve, SWR Productions, or GeneralsX product.
