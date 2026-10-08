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

## Separate Steam setup guide — 2026-10-07

Both launchers now open a modeless companion guide before the local SteamCMD
terminal. It shows shared account/Steam Guard/file guidance, errors and a separate
validation phase, while keeping all password/code entry in Valve's console.
Closing the guide hides only the guide. Continue to Play stays disabled until
asset validation finishes; retry is blocked while a Steam session is active.

- Mac app and model checks passed. `tests/steam-guide.sh` constructed the actual
  native panel without showing it and checked floating/nonactivating behavior,
  visibility on app deactivation and validation/startup gates. AppKit initialization
  aborted inside the sandbox; the same check passed outside it.
- Eleven Linux state/widget checks passed with fake statuses, including live guide
  updates, no credential fields, safe retry, completion and duplicate-start blocking.
- The packaged Linux guide was displayed on virtual X11 beside a focused synthetic
  console. Guide updates retained console focus and the guide stayed visible.
- Installer checks with cached engine/mod files and fake Steam responses passed.
  A no-subscription response with exit code zero remains an ownership error;
  validation no longer overwrites it. A later success for another required Steam
  title cannot erase a missing-license error in the same session.
- Shared parser tests still retain only a status enum, including recovery after a
  corrected Steam Guard response. No real Steam authentication or game was started.

Linux stacking remains a window-manager request; real Wayland/X11 desktop behavior
needs interactive validation. The Mac binary is still ad-hoc signed, not notarized.

## C&C Unix Launcher, native mods and online preparation — 2026-10-07

Renamed the product and release archives to C&C Unix Launcher 0.2.0. Branding,
release endpoints and asset names come from `manifests/product.tsv`. Existing
bundle/preferences identifiers and managed installation paths are preserved.
Public links target `RickWoltheus/cnc-unix-launcher`; the repository has not been
published. Request a mod opens a prefilled issue draft, not an automatic post.

Added Combined Arms 1.09 for C&C/Red Alert and Tiberian Dawn HD playtest-20260222
for C&C. Actual publisher ARM64 Mac runtimes and x86_64 Linux AppImages were
installed into disposable folders. Synthetic MIX and MEG files were validated
by their native headless utilities. Dummy launchers verified isolated profile,
mod identity and display arguments. Fake Steam clients checked the required
app IDs: C&C/RA for Combined Arms and Remastered Collection for TDHD. Missing
assets use the same separate Steam guide, with a native-profile readiness gate.
No EA data was downloaded by the agent for these tests.

Local online preparation validates files. OpenRA hosting is explicit opt-in and
updates only local AdvertiseOnline/DiscoverNatDevices settings, with a backup;
player settings, server password and graphics settings were preserved. Router
and firewall settings were not changed, and no game or online authentication was
started. Browser approval remains in the engine. The hosting marker means local
preparation only, not working NAT or a successfully joined match.

Mac funding copy explains the actual **€0 project budget** and lack of
Developer ID signing/notarization. It links Apple's published US$99 annual
membership/local pricing and graphical first-launch instructions. No membership
purchase, enrollment or certificate creation was attempted.

## Experimental Wine profiles and community funding — 2026-10-07

Added Red Alert 2, Yuri’s Revenge and Tiberian Sun / Firestorm entries to both
frontends. These use Wine, not native engines. Actual pinned Wine 11.0 packages
for macOS and Linux and cnc-ddraw 7.1.0.0 were installed into disposable roots.
The real Wine binaries returned `wine-11.0`; no prefix was initialized and no
Windows game executable was run.

`tests/compatibility.sh` passed on both platforms with synthetic asset files,
fake Steam and `GX_LAUNCH_WRAPPER`: Steam IDs/Windows platform arguments,
per-game gates, working-folder/prefix isolation, windowed/fullscreen INI merging,
INI/SAV preservation after a simulated Steam manifest update, damaged executable
rejection and blocking installation during a tracked Wine launch. This checks
integration mechanics, not the contents of actual Steam depots, GPU rendering,
audio, original campaign behavior, Firestorm selection or save/load compatibility.
CnCNet preparation is explicitly disabled for Wine profiles.

The shared case-insensitive asset lookup and Steam manifest readiness helpers
now serve Generals, OpenRA, native mods and Wine. Existing backend/status/model
checks passed. The actual OpenRA/native-mod utilities again passed synthetic
archive import, corruption and progress-preservation checks with dummy launches.

Community credits and funding copy are shared JSON resources. Both frontends
show a coffee-button tooltip and community/donation window. The manual onward-
donation ledger starts empty; no transfer, receipt, incoming balance or percentage
was fabricated. Documentation generation checks credit coverage for every
catalogued mod, ledger entries and that the public document matches the resources.
The UI links each project’s contributor/team page rather than claiming an
exhaustive hand-maintained list of individual upstream authors.

Fifteen Linux state/offscreen widget checks passed, including a populated
**in-memory fixture** donation display. No fixture donation was written to the
actual ledger. The expanded sidebar scrolls within the 1200×790 window.
Mac compiled and decoded the shared credits/ledger in model checks; its ad-hoc
signature and metadata passed. Linux packaging, self-check and virtual X11
launcher/Steam-guide checks passed. The guide used a focused synthetic console.
No real Steam sign-in, game, multiplayer connection or donation occurred.

Both archives are local development artifacts. Public repository/release
publication remains pending; the public-document links become reachable when
that repository is published. Existing user installations/settings were untouched.

## Wine game-close detection — 2026-10-07

Observed the user's closed Red Alert 2 session with its game process exiting,
while `start.exe`, the launcher shell and Wine services persisted. The old running
marker tracked the shell alone and therefore remained active. A regression using
POSIX sleep fixtures reproduced this incorrect helper-only running state before
changing the implementation.

The backend now identifies game executables in their exact managed profile paths,
ignoring Wine services and exiting/zombie processes. It monitors the selected game
and releases only its owned launch helper after closure. Startup remains tracked,
failed launches retain their exit status, and marker cleanup checks ownership.
No shared Wine server or unrelated application is terminated.

`tests/wine-lifecycle.sh` passed on macOS and Linux: a living helper alone is idle,
a real fixture process is active, closing it unlocks the session, lingering helpers
are released, and startup failure code 7 is preserved. Mac also checked a Wine-style
Windows path with spaces; the Linux emulation fixture uses its own ELF executable
path because OrbStack prepends the emulated executable to spoofed argv values.
All fixture executables are POSIX sleep, not Windows game binaries.

Both UIs reconcile shared Wine-session status; native-game tracking is preserved.
Swift model checks and sixteen Linux state/widget checks passed. Mac app rebuilt
and its ad-hoc signature verified. Linux package self-check and virtual launcher/
Steam-guide checks passed. The new backend reported `wine_session=idle` against
the user's already-closed session while its old helpers were still present.
No game was launched or keyboard/mouse input sent during this fix.

## Red Alert 2 manual-test build — 2026-10-07

The user authorized live game testing, then asked to take over those checks.
Before that handoff, direct launches failed with stale Wine-prefix services;
stopping only the RA2 prefix's server allowed a windowed game to reach its menu.
The running process was detected correctly. Captures also showed the legacy menu
occupying only part of the requested window, with input not matching its visible
coordinates. The screenshot's speed 6 corresponds to saved GameSpeed=0.

Added prefix-scoped cleanup before launch and after game exit. Cleanup is bounded,
blocks another launch while stopping, and treats no existing Wine server as an
already-clean state. Fake-server lifecycle tests cover the cleanup calls, prefix
isolation, stopping gates and the no-server exit code on Mac and Linux.

RA2/Yuri profiles apply one-time safe defaults to their working copy: GameSpeed=2
(displayed as speed 4), stretched movies, and a Mac-only menu/activation adjustment.
Original Steam files stay unchanged; INIs have backups. The marker lives outside
the game copy so later Steam refreshes do not overwrite the player's new choices.
Mac Wine fullscreen dimensions now use logical coordinates; native engine
resolution handling stays unchanged.

Mac synthetic installer checks validated default values and backups; Swift model
checks passed. Sixteen Linux UI/state checks, fake-process/fake-server regressions,
packaging and packaged self-check passed. Both local archives rebuilt.
These checks validate configuration and lifecycle mechanics. **The menu adjustment,
keyboard/mouse behavior, movie skipping and speed in a real match await the user's
manual test.** No further live game interaction occurred after that request.

## Top-left menu follow-up — 2026-10-07

The user confirmed that launch and gameplay were working, but menus still stayed
in the top-left with black space and occasional graphical glitches. The pinned
cnc-ddraw configuration enabled fixchilds=2; its own documented behavior disables
upscaling when a child window is detected. The next manual-test build overrides
that fallback with fixchilds=0 only for Mac RA2/Yuri profiles. This one-time menu
migration is separate from speed defaults and preserves current gameplay choices.
No live game interaction was performed for this follow-up. Actual menu scaling
and child-control rendering remain for the user's test.

Also corrected shared INI merging to preserve the canonical spelling supplied by
updates while removing differently cased duplicates. Previously GameSpeed became
lowercase and the game could save another GameSpeed key beside it. The new
`tests/ini-settings.sh` failed before the fix and passed afterward, covering key
case, duplicate replacement, unrelated values and original backup preservation.
Mac installer fixtures verified the game-specific menu override and canonical
speed/movie keys. Linux INI checks, sixteen UI/state checks, packaging and
packaged self-check passed. Mac rebuilt and its ad-hoc signature verified.

## Direct maintainer support links — 2026-10-08

Removed the manual onward-donation ledger and redistribution pledge at the user's
request. README and both launchers instead invite direct support for maintainers:
GeneralsX/fbraz3 through GitHub Sponsors, Gcenx through Ko-fi or PayPal, and OpenRA
hosting through Patreon. Targets were checked against each project's published
FUNDING.yml. The full project/contributor credits remain intact.

Shared support metadata includes the published source and verification date.
The documentation generator validates those links and credited recipients.
Mac resource copying now removes stale generated JSON so an older ledger cannot
remain in a rebuilt app. Both archives were checked to exclude donations.json.

Swift model/resource checks, sixteen Linux state/widget checks, Mac compilation
and ad-hoc signature verification, Linux packaging and packaged self-check passed.
The Linux UI test clicked support buttons with browser opening intercepted and
confirmed their destinations. No donation website, payment flow or game opened.

## Security review and preview packaging — 2026-10-08

A user-requested security subagent performed read-only launcher and supply-chain
reviews. No confirmed critical issue was found. Its scanner follow-up identified
a Linux terminal script that dropped GX_SCAN_DOWNLOADS; that defect was fixed,
covered by a headless test and reviewed again. The final review found no remaining
confirmed release-blocking scanner issue. This is not certification of upstream
engine/mod binaries or a malware-free guarantee.

The shared download module now performs SHA verification then optional local
ClamAV scanning before any install/extraction/execution, including cache hits.
Synthetic tests passed for scan ordering, cache rescans, prior detection blocking,
missing/stale definitions, scanner errors, encryption/limit alerts and skipped
results. The optional preference propagates through GUI and terminal jobs on both
platforms. Native Steam-guide nonactivation and credential gates still passed.

A disposable non-root Debian container installed ClamAV from the distribution,
then used the actual backend to fetch and validate official main/daily/bytecode
signatures. The actual scan path accepted a clean synthetic file and blocked the
harmless EICAR test before installation. No game or malicious program ran and
nothing was installed on the user's Mac. The EICAR fixture is generated only at
runtime so source archives do not contain its literal signature.

Eighteen Linux state/offscreen widget tests, shared backend/security tests,
hash-locked Linux packaging, packaged self-check and virtual launcher/Steam-guide
checks passed. Mac model tests, compilation, ad-hoc signature and metadata checks
passed. Package inventories included the security/download modules and excluded
original game assets, mod archives, credentials and virus databases. CI actions
are pinned to commit SHAs and Linux build wheels to recorded SHA-256 hashes.

Version 0.3.0 is a local community-preview candidate. C&C 3 and other additional
3D titles were investigated and deferred rather than exposing unvalidated entries.
Manual Mac scanner installation/definition-terminal behavior and exhaustive
platform/game/mod testing remain pending. Public publication requires the user's
review of the concrete release notes; no GitHub repository or release was created.

## Public preview publication — 2026-10-08

Published the source to `RickWoltheus/cnc-unix-launcher` and released v0.3.0 as a
public prerelease after user authorization. README includes a real Mac launcher
window capture and an offscreen Linux interface capture, with no Steam console
or game started for the screenshots. The original-code MIT license now names
C&C Unix Launcher; third-party scope and notices are explicit in the repository
and both packages. GitHub reports the repository public and recognizes MIT.

Both release archives and SHA256SUMS.txt are uploaded. GitHub's server-side asset
SHA-256 digests match the local Mac and Linux packages. The publication used the
user's personal GitHub account and personal SSH alias; global authentication
settings were not changed. This remains a community preview with the validation
limits described above.
