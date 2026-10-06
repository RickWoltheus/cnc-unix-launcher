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
