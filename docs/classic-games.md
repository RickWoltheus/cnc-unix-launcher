# C&C and Red Alert: Original or OpenRA

The sidebar keeps separate **Original (Vanilla Conquer)** and **OpenRA** options.
Original mode uses the native original engine, rules and campaigns. OpenRA
reimagines the games with different rules, balance and missions, and keeps its
existing mod catalog. Settings, saves and imported content are separate.

Original mode is experimental. The pinned upstream README does not officially
support Ultimate Collection data; this launcher prepares that owned Steam
layout rather than downloading replacement data. Both original engines reached
their intro movies on an Apple Silicon Mac. Full campaign, expansion, save/load,
audio and network compatibility still need gameplay checks.

Choose an Original sidebar entry and use Prepare. The bundled native engine
requires no compiler or Homebrew on the player's Mac. Existing owned Steam files
are imported automatically; otherwise use the usual guided Steam download.
Red Alert Original only needs Red Alert's Steam download, whereas OpenRA Red
Alert additionally needs C&C's desert tileset.

Original files live under `original-cnc-original/` or `original-ra-original/`,
with writable settings and saves in `user/`. Red Alert's `MAIN1.MIX` through
`MAIN4.MIX` are copied to `allied/`, `soviet/`, `counterstrike/` and `aftermath/`
as `MAIN.MIX`. The raw Steam downloads stay unchanged. OpenRA content stays in
`openra-support/`. Original multiplayer is not automated or tested here.

## OpenRA

The launcher installs pinned OpenRA **release-20250330** for Tiberian Dawn and
Red Alert. Mac uses the official universal disk image's ARM64 runtime; Linux
extracts the official x86_64 AppImage, avoiding a FUSE requirement. Both include
their .NET runtime; users do not need a .NET SDK or compiler.

OpenRA modernizes rules, balance, UI and missions. It is not the original Windows
executable or a promise of complete original campaign/expansion parity. Multiplayer
requires compatible OpenRA releases/mods; original Windows clients cannot join.
Generals and Zero Hour continue to use GeneralsX, with mods offered only for Zero Hour.

OpenRA's pinned Steam installer mappings document
support for the English Ultimate Collection data used here:

- [C&C Steam mapping](https://github.com/OpenRA/OpenRA/blob/release-20250330/mods/cnc-content/installer/steam.yaml)
- [Red Alert Steam mapping](https://github.com/OpenRA/OpenRA/blob/release-20250330/mods/ra-content/installer/steam.yaml)
- [Vanilla Conquer asset support](https://github.com/TheAssemblyArmada/Vanilla-Conquer#running)

## Setup

Select the game in the sidebar, continue to Prepare, and install the engine and
Steam downloader. Sign in only in the local terminal. The launcher downloads:

| Selected game | Owned Steam download |
| --- | --- |
| C&C / Tiberian Dawn | 2229830 |
| Red Alert | 2229840, plus C&C 2229830 for OpenRA's required desert tileset |

Steam sources go to `TiberianDawn/` and `RedAlert/` inside the existing managed
installation root. After download, OpenRA's **headless Utility** extracts MIX
containers (including encrypted archives); the launcher copies plain archives.
Music and campaign briefing videos are imported when present. Aftermath content
is required for OpenRA Red Alert; Counterstrike music is imported when present.
Missing optional content is reported in Details. English Steam data is the tested
mapping target; other language variants have not been validated.

Only the user's Steam client downloads EA data. There is no fallback to an
OpenRA game-data mirror. Imported files go to `openra-support/Content/`; settings,
saves, maps and OpenRA logs live beneath `openra-support/`. Existing Generals
settings and installations retain their paths. Imported content is replaced
only after all required files pass validation. A failed import preserves the
previous content. Required imported files are hashed and checked before Play.

Display mode is translated to OpenRA arguments: windowed uses 1280×720 and
fullscreen uses the desktop resolution. OpenRA has its own graphics settings;
Generals graphics presets do not modify them. Close the game normally before
switching titles or installing anything.

For an existing managed Steam copy, repair/import without a game launch:

```sh
bash scripts/backend.sh import-classic cnc
bash scripts/backend.sh import-classic ra
```

Linux still needs working desktop/graphics drivers. The AppImage contains its
native libraries and managed runtime; a headless import passing does not prove
that SDL/OpenGL rendering works on a user's GPU.

## Verification

`tests/classic.sh` creates synthetic MIX archives, uses the actual OpenRA Utility
for extraction, and uses `GX_LAUNCH_WRAPPER` for every launch. It checks music,
videos, expansion files, per-game readiness, windowed/fullscreen arguments,
corrupt-content rejection and preservation after a failed import. It contains
no copyrighted assets, uses no Steam credentials and starts no game.

Actual Steam downloads, real game assets and gameplay for these two integrations
remain unverified until an explicitly requested interactive test.

The manual GitHub build workflow runs the Linux check against downloaded, pinned
engine releases. Locally, run it in the existing test container:

```sh
docker run --rm --platform linux/amd64 -v "$PWD:/project" gx-launcher-linux-test bash tests/classic-linux.sh
```

## Additional native mods

Combined Arms 1.09 uses its own OpenRA runtime and cloned, owned RA/C&C content.
Tiberian Dawn HD playtest-20260222 uses an isolated runtime and owned Steam
Remastered Collection assets. The latter requires app 1213210 and potentially
40 GB of disk space; it is a separate license from Ultimate Collection.

TDHD's managed source mapping points directly at the private Remastered folder.
A small launcher-created ZIP marker selects that source; it contains no EA data.
No real Steam library manifest is modified. Settings and user progress remain
outside the runtime bundle and are preserved on repair. Source MIX/MEG containers
must pass the mod runtime's headless reader before a profile is marked complete.
Runtime and data upgrades stay pinned and manual. Full gameplay and performance
for both integrations remain unverified.

Run `bash tests/native-linux.sh` in the Linux verification container to download
pinned runtimes and check both mods with synthetic data, fake Steam and dummy
launchers. It does not authenticate, change a router/firewall or start a game.
