# Verification before release

## Passed on 2026-10-06

Headless validation ran on an Apple M3 Pro, macOS 26.0.1. No launcher window,
Steam sign-in, or game was started. Existing game installations and preferences
were left untouched; installer checks used disposable folders with spaces in
their names and synthetic base-game fixtures.

- `bash tests/backend.sh`: asset readiness and corrupted-header detection;
  graphics merge preserves unrelated options and backs up original settings;
  repeated merges remain stable; concurrent installer locks reject another run.
- `bash scripts/build.sh`: native ARM64 app compiled successfully.
- `codesign --verify --deep --strict`: ad-hoc app signature verified.
- `plutil -lint`: app metadata passed validation.
- `bash tests/install.sh ENGINE_ZIP STEAMCMD_TAR ROTR_DOWNLOAD_FOLDER`: actual
  engine and SteamCMD extraction, repeated installs, all ROTR checksum pins,
  separate mod-folder activation, preservation of stock AI scripts, corrupt mod
  rejection and repair. A dummy executable verified profile environment variables
  and launch flags without invoking the engine. A dummy SteamCMD verified
  argument construction and rejected incomplete assets and invalid usernames.
- `bash tests/network.sh`: fresh engine and SteamCMD downloads and their pinned
  checksums; a live ROTR mirror file; deliberate checksum mismatch rejected
  before replacing an existing installation. Install lock cleaned up on failure.
- ZIP inventory: launcher executable, metadata, scripts, license and manifests
  only. No game/mod archives or credentials. Compiled binary string inspection
  found no personal build path or Steam username.

The cached installer check requires your own existing engine ZIP, SteamCMD
bootstrap, and ROTR downloads; those fixtures are not committed to this repo.

## Expanded catalog and GUI checks on 2026-10-06

`tests/catalog.sh` passed using the actual base Generals engine ZIP and all five
mods' pinned data downloads. It checked base-engine extraction, base Steam app
ID selection, each mod's install and repeat-install, separate folders, stock
AI preservation, and launch parameters through dummy launchers. The End of Days'
own loose AI scripts were verified after installation. Windows binaries,
optional movies and duplicated EA movies were excluded from the new mod packages.

The native GUI was opened with the user's explicit authorization for a windowed
end-to-end test. Its Install button installed the engine and SteamCMD using the
verified local cache. Existing, owned Steam assets were copied into the new
managed installation; a fresh Steam authentication/download was not repeated.
The Fullscreen checkbox was switched off through Accessibility automation.
Play Zero Hour reached the 1280×720 main menu and exited normally when the user
closed it. The ROTR Install confirmation and installation succeeded through the
GUI; Play mod reached the mod-specific 1280×720 menu with a captured screenshot.

Automated input into the SDL game menu did not reliably navigate to a match.
Actual match behavior, save/load and base-game runtime remain unverified unless
separately recorded below. The user was asked to run a short manual skirmish.
Screenshots remain local in /tmp/gx-e2e and are not bundled in the release.

The launcher checks this repository's GitHub releases for newer launcher ZIPs.
Self-replacement is manual; engine and mod changes require reviewed manifest
updates in a newer launcher. No silent upstream upgrades are enabled.

## Guided UI and Steam validation

The command-center redesign loaded promotional mod thumbnails in the native UI.
It has one Play action driven by the highlighted game/mod; selecting an uninstalled
mod offers Install & Play with explicit confirmation. No game was launched while
validating this redesign.

`tests/model.sh` passed selection routing, per-game step prerequisites, unsupported
platform handling, active-download blocking, failed-sign-in blocking and recovery
guidance checks. `tests/steam-status.sh` passed representative password/account,
Steam Guard, rate-limit, license and connection status lines, retaining only a
status enum. Installer integration tests exercised failed password and no-license
responses through a dummy Steam client. These do not replace real Steam sign-in
testing.

A fresh temporary installation was opened in the native GUI. Accessibility checks
confirmed Steam Download and Play had `AXEnabled=false`; Continue remained enabled
for the valid default game choice. No Steam client or game was started in this check.

## Linux preview validation

The separate PySide6 Linux interface mirrors the SwiftUI command-center flow.
Installer business logic remains in one backend with small OS adapters. Both
frontends read the same setup policy, Steam guidance, recovery guidance, mod
manifests and graphics presets. `CLAUDE.md` requires synchronized behavior changes.

OrbStack's Linux VM ran an isolated x86_64 Debian container. Seven model/offscreen
widget tests passed: gated steps, per-game readiness, failed-sign-in blocking,
single Play routing, graphics locking and shared guidance. The backend checks
passed using actual Linux Flatpak bundles and the Linux SteamCMD bootstrap;
Flatpak services and Steam authentication were replaced by local fixtures.
Case-sensitive archive readiness and Linux settings paths were also checked.

The standalone Linux archive built successfully and its packaged `--self-check`
validated native Qt imports, shared resources and shell syntax without opening
windows or launching games. An offscreen UI screenshot was captured locally.
The packaged Qt/X11 window also rendered on Xvfb's virtual desktop with unfinished
steps locked and networking disabled. The `xvfb-run` wrapper stalled before
launching under emulation; a direct ready-display check succeeded, and the
reproducible `tests/linux-x11.sh` uses that direct path. Missing X11 libraries
found during packaging were added to the build environment and collected into
the standalone archive. LGPL/GPL texts and Qt attribution accompany the package.
The macOS model/backend/status checks and native build still passed after sharing
these resources and separating the OS adapters.

These checks do not establish real Linux desktop terminal handoff, Flatpak
sandbox operation, GPU rendering or game/mod compatibility. See `docs/linux.md`
for the supported target and the remaining desktop tests. No game was started.

## Still pending before calling the release fully verified

1. Re-run automated checks on a clean Apple Silicon Mac.
2. Validate Gatekeeper's first-open flow on an internet-downloaded app.
3. On an Apple Silicon Mac, launch the app from a path containing spaces and
   confirm setup progress remains responsive.
4. Install into a fresh user account with no Homebrew or existing GeneralsX
   files. Verify engine download and SteamCMD bootstrap.
5. Sign into Steam locally. Verify a wrong password and a Steam Guard challenge
   do not appear in GUI output or project logs.
6. Confirm a Steam account without Zero Hour produces the ownership error and
   does not enable Play.
7. Download Zero Hour, validate shared assets, and play/save/load a skirmish.
8. Install ROTR, play Russia/ECA skirmishes, and verify AI builds units.
9. Return to unmodded Zero Hour and confirm it still works.
10. Repeat engine and mod install; interrupt a download and retry; confirm corrupt
    archives fail verification without replacing a previous working installation.
11. Test windowed/fullscreen on a Retina display and an external monitor.
12. Confirm the packaged ZIP contains only launcher source resources, manifests,
    and the launcher executable, with no assets, credentials, local paths or logs.

The checksum pins in `manifests/rotr.tsv` were recorded from downloaded archives
that matched the public mirror's MD5 ETags and sizes. No independent publisher
signature was available. Keep this qualification in public documentation.
# Fresh Linux dependency check

The packaged binary failed on a minimal Debian 12 container with
`ImportError: libGL.so.1: cannot open shared object file`. The new
`start-launcher.sh --check` reports missing GL/EGL, Wayland and Xcb libraries
before importing Qt, and prints the Ubuntu/Debian installation command.
Installing that library list in the disposable container made the preflight
pass. The standard build container also passed preflight, packaged self-check,
seven UI/state tests and the virtual X11 launcher smoke test. These checks did
not sign in to Steam or start a game.

## Classic engines and sidebar — 2026-10-07

Added C&C/Tiberian Dawn and Red Alert using OpenRA release-20250330. Vanilla
Conquer's documented Ultimate Collection limitation ruled it out for this
Steam-only integration. Both native UIs read `manifests/games.tsv`, display a
sidebar with original text emblems, change themes by selection and keep game
readiness independent. Generals and Zero Hour retain their existing engine,
asset paths, settings and Zero Hour mod selection.

- Actual official Mac DMG and both Linux AppImages downloaded and SHA-256 pinned.
  Mac engine installation copied the ARM64 runtime; Linux AppImage extraction
  required no FUSE mount. No engine window was opened.
- `tests/classic.sh /tmp/gx-classic-mac` passed using actual OpenRA Utility with
  synthetic MIX containers: nested expansion/music/video extraction, required
  content readiness, hash verification, display argument routing, failed-import
  preservation and malformed copied/extracted archive rejection.
- The same tests passed in an x86_64 OrbStack container using the actual Linux
  OpenRA utilities. Steam login/download arguments were tested with a fake client;
  successful RA setup requested both owned Steam titles, and a no-subscription
  failure retained the shared `no-license` status. No real authentication occurred.
- Swift model selection/gates and Linux's nine model/widget tests passed. Linux
  previews captured all four themes offscreen. Packaged self-check, startup
  dependency preflight and virtual X11 launcher window checks passed.
- Mac app compiled, passed metadata validation and ad-hoc signature verification.

These checks validate integration mechanics, not original campaign completeness,
owned Steam data compatibility or GPU gameplay. C&C/Red Alert interactive testing
remains pending explicit authorization. OpenRA has modernized gameplay and its
own multiplayer protocol; these integrations are not original Windows clients.

## Sidebar logos — 2026-10-07

Both frontends now load transparent game logos from Steam's artwork CDN, keyed
by the shared game catalog's Steam IDs. Text emblems remain available offline.
The artwork stays outside the repository and release packages. The Linux sidebar
was inspected offscreen using all four fetched logos; its nine existing UI/state
checks, packaged self-check and virtual X11 launcher smoke test passed. The Mac
app rebuilt and its ad-hoc signature verified. Only the launcher was reopened;
no game or Steam sign-in was started.
