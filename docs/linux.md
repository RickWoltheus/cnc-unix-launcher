# Linux preview

Linux keeps its own PySide6 UI; macOS keeps SwiftUI. Both read the same setup
policy, Steam guidance, mod catalog, graphics presets and installer backend.
The Linux view mirrors the four-step flow and one selected-profile Play action.

## Supported target

The first target is x86_64 Ubuntu 24.04+ / Debian 12+ desktops (glibc 2.36 or newer) with Vulkan-capable GPU
drivers. GeneralsX uses pinned 1.0.2 Flatpak bundles; C&C and Red Alert use pinned OpenRA
release-20250330 AppImages extracted during setup, with no FUSE dependency.
ARM Linux and Steam Deck-specific controller integration are not supported.
The launcher itself is distributed as a standalone archive, outside Flatpak;
Generals engines run inside Flatpak with explicit access to the installation folder.
OpenRA runs from its extracted runtime with its own managed support folder.

## Install

Extract `CnC-Unix-Launcher-linux-x86_64.tar.gz`, then run:

```sh
bash ./CnCUnixLauncher/start-launcher.sh
```

The startup script checks glibc and Qt's host desktop libraries, then offers an
Ubuntu/Debian package installation if libraries are missing. Use `--check` for
a read-only preflight. Opening the binary directly bypasses this check.

Choose a game and follow the stepper. If Linux dependencies are missing,
Prepare Linux opens a local terminal to install Flatpak, curl, file and Valve's
32-bit runtime support using your distribution's package manager. It can ask
for your administrator password. Steam sign-in uses a separate local terminal;
neither password is read by the GUI.

Automatic dependency setup targets Ubuntu/Debian-based desktops. On other
distributions, install those dependencies through the package manager first.
The native Vulkan driver remains the responsibility of the host distribution;
the launcher does not replace GPU drivers. NVIDIA Flatpak driver extensions
must match the host driver.

A supported desktop terminal is required for dependency setup and Steam sign-in:
`x-terminal-emulator`, GNOME Terminal, Konsole, Xfce Terminal or xterm. Minimal
systems can install `xterm` through their package manager. Headless servers,
musl-based distributions and Linux ARM are outside this package's target.

## Paths and differences

Data defaults to `${XDG_DATA_HOME:-~/.local/share}/generalsx-launcher/` and can be
overridden by `GX_INSTALL_ROOT`. Game settings/saves live in
`user-data/GeneralsX/Generals/` or `user-data/GeneralsX/GeneralsZH/` inside that
folder. The launch adapter passes the same XDG data path into Flatpak. Mod
profiles share Zero Hour saves; use distinct save names.

Linux dependency installation may require an administrator password; per-user
engine installation does not. Reflinks are used when the filesystem supports
them, otherwise files are copied. Archive readiness handles case differences
in Steam filenames on case-sensitive filesystems.

For Steam prompts, return to the terminal through your desktop's taskbar.
Unlike macOS, reliably focusing a particular terminal across X11/Wayland and
desktop environments is not available through one standard API. A separate, modeless Steam setup guide requests an always-on-top window so
status and recovery instructions remain visible beside the console. Stacking
depends on the window manager, especially on Wayland. The guide never takes
passwords or Steam Guard codes, and blocks Play until validation completes.
Closing it leaves the terminal session running; reopen it from Help.

Updates remain manual. Check updates finds newer Linux archives; Download update
opens the release page. Game/mod upgrades come from reviewed launcher manifests.

## Build and headless checks

For a reproducible x86_64 Linux build using Docker:

```sh
docker build --platform linux/amd64 -t gx-launcher-linux-test -f linux/Dockerfile.test .
docker run --rm --platform linux/amd64 -v "$PWD:/project" gx-launcher-linux-test python3 tests/linux-ui.py
docker run --rm --platform linux/amd64 -v "$PWD:/project" gx-launcher-linux-test bash tests/backend.sh
docker run --rm --platform linux/amd64 -v "$PWD:/project" gx-launcher-linux-test bash linux/build.sh
docker run --rm --platform linux/amd64 -v "$PWD:/project" gx-launcher-linux-test bash tests/linux-x11.sh
```

The archive lands in `dist/`. Developer installs can use a virtual environment
and `linux/requirements.txt`, then `python3 linux/app.py`.

The Qt package retains dynamically loaded shared libraries and Python distribution
license notices; see `linux/THIRD-PARTY.md`. No engine, game data or mod archives
are bundled in the launcher release.

Container/offscreen checks do not prove a real desktop, terminal handoff, Flatpak
sandbox operation or GPU rendering. Those require a Linux desktop VM/machine.
Real game launches require the user's explicit request.

## Experimental original Windows games

Red Alert 2, Yuri’s Revenge and Tiberian Sun / Firestorm use pinned Wine 11.0
WoW64 and cnc-ddraw, not a native engine or Steam Proton. Prepare Linux opens
a local terminal to install Wine’s system libraries when needed; on Ubuntu/Debian
it installs the distribution Wine package for dependencies, then uses the separately
pinned runtime for games. Other distributions require equivalent packages.

See [compatibility setup](compatibility-games.md). CnCNet is not integrated.
No Linux gameplay or GPU compatibility has been verified for these entries.

## Experimental C&C 3 development profiles

C&C 3 and Kane’s Wrath use the native Linux Steam client and its Proton runtime,
not the 2D Wine/cnc-ddraw installer. This platform exception preserves Steam’s
owned install, prefix, saves, updates and first-run dependency handling. Flatpak
Steam integration is deferred. Enable Proton 11 in each game’s Compatibility
properties, install the English game and launch once in Steam. The launcher checks
the configured Proton selection, installed Proton, Steam download state and the
versioned executable referenced by the game’s English SkuDef.

Use **Open Steam setup** in Prepare Linux, then **Open Steam install** in the
download step. Credentials stay in Valve’s client. No SteamCMD password window
is used for these two games on Linux. See [C&C 3 setup](cnc3.md).
