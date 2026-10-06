# GeneralsX Launcher for Mac

A native Mac launcher that installs GeneralsX, downloads your own Zero Hour
files through Steam, and optionally installs Rise of the Reds.

**Development preview. Headless installer checks pass; GUI and Steam sign-in
testing remain pending.** The app builds for ARM64 and its ad-hoc signature
verifies. Engine/SteamCMD downloads, ROTR installation and repair, settings
backups, and launch arguments have been checked without starting the game.
See [verification.md](docs/verification.md) for the evidence and remaining checks.

## Requirements

- Apple Silicon Mac with macOS 15 or later.
- Zero Hour owned on the Steam account you sign in with. The Ultimate Collection
  includes it. **The Remastered Collection does not.**
- About 12 GB free for the engine, downloads, game files, and optional ROTR.
- Internet access and your Steam password/Steam Guard. Enter credentials only in
  the local SteamCMD Terminal window.

End users do not need Homebrew, Xcode, a compiler, CrossOver, or a VM. SteamCMD
requires Apple's free Rosetta; the game engine runs natively as ARM64.

## Install and play

When a verified release is available:

1. Download `GeneralsX-Launcher-macOS-arm64.zip` from this repository's releases.
2. Extract it, and move **GeneralsX Launcher.app** to Applications.
3. Open the app. For the unnotarized preview, use **System Settings → Privacy &
   Security → Open Anyway** after the first blocked launch. You can alternatively
   remove quarantine from the app you downloaded:

   ```sh
   xattr -dr com.apple.quarantine "/Applications/GeneralsX Launcher.app"
   ```

4. Click **Install engine & SteamCMD**.
5. Click **Download Steam game**. SteamCMD opens in Terminal. Sign in and wait
   for the download to finish, then click **Refresh** in the launcher.
6. Click **Play Zero Hour**. Fullscreen uses your current display's resolution.
7. Optionally click **Install Rise of the Reds**, review its download source,
   then use its Play button.

The app pins GeneralsX 1.0.2 and ROTR 1.87 Public Build 2.0. Installing the engine
again repairs it; it does not silently upgrade to an untested upstream version.
SteamCMD updates itself using Valve's normal bootstrap.

## Files and privacy

The launcher installs into `~/Library/Application Support/GeneralsX Launcher/`:

```text
engine/          GeneralsX app and bundled runtime libraries
steamcmd/        Valve's downloader
GeneralsZH/      Your Steam game installation
RiseOfTheReds/   Separate game installation with ROTR archives
downloads/      Verified download cache
logs/           Game launch logs
```

No EA game assets, mod archives, engine binaries, credentials, or user saves are
included in this repository or its launcher archive. Downloads go directly to
each user's machine. Steam authentication runs in SteamCMD; this app never
reads the password or Steam Guard code. Valve may cache authentication locally
using its own client behavior. The launcher adds no analytics.

GeneralsX stores settings and saves in its upstream user-data folder,
`~/Library/Application Support/GeneralsX/GeneralsZH/`. Both game profiles share
that folder. Name mod saves clearly and load them only with the matching mod.
Maximum graphics backs up `Options.ini` as `Options.before-launcher.ini` before
changing it. Turning off the launcher's checkbox stops applying the preset; it
does not reset already saved options. Change those in the game or restore the
backup while the game is closed.

## Download verification

The engine ZIP and SteamCMD bootstrap must match pinned SHA-256 hashes before
extraction. Valve's bootstrap URL can change; an unexpected update stops the
installation until the checksum is reviewed and updated here.

ROTR comes from the public file mirror listed in the GenLauncher catalog. This
mirror serves HTTP. Every mod archive must match a SHA-256 recorded from the
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
bash scripts/backend.sh steam
bash scripts/backend.sh steam-login
bash scripts/backend.sh rotr
bash scripts/backend.sh launch vanilla -fullscreen -xres 1920 -yres 1080
```

## Credits and license

- [GeneralsX](https://github.com/fbraz3/GeneralsX) provides the native engine.
- [Valve SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) downloads
  owned game files.
- [SWR Productions / Rise of the Reds](https://www.moddb.com/mods/rise-of-the-reds)
  provides the mod.
- [GenLauncher catalog](https://github.com/p0ls3r/GenLauncherModsData) provides
  the mod's download source.

This launcher's original code is MIT-licensed. Downloaded software and data
retain their respective licenses. This is a community project, not an official
EA, Valve, SWR Productions, or GeneralsX product.
