# Linux preview

Linux keeps its own PySide6 UI; macOS keeps SwiftUI. Both read the same setup
policy, Steam guidance, mod catalog, graphics presets and installer backend.
The Linux view mirrors the four-step flow and one selected-profile Play action.

## Supported target

The first target is x86_64 Ubuntu/Debian-based desktops with Vulkan-capable GPU
drivers. The upstream GeneralsX engines are the pinned 1.0.2 Flatpak bundles.
ARM Linux and Steam Deck-specific controller integration are not supported.
The launcher itself is distributed as a standalone archive, outside Flatpak;
the game engines run inside Flatpak with explicit access to the installation folder.

## Install

Extract `GeneralsX-Launcher-linux-x86_64.tar.gz`, then run:

```sh
./GeneralsXLauncher/GeneralsXLauncher
```

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
desktop environments is not available through one standard API. The GUI still
shows the shared sign-in guidance and blocks Play until validation completes.

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
