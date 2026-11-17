# Pinned downloads

Every file the launcher downloads is pinned to an exact URL and SHA-256 in
`manifests/`. Pins keep untested upstream changes away from players, but
publishers delete or replace releases. In November 2026 the C&C 3/RA3 Wine
archive disappeared from its publisher, and Mac preparation failed with a 404
for everyone. Three things now keep that from reaching players again.

## Where pins live

| Manifest | Pins |
| --- | --- |
| `compatibility-packages.tsv` | Wine runtimes, cnc-ddraw, Windows Steam bootstrap |
| `engine-packages.tsv` | GeneralsX, OpenRA, SteamCMD bootstraps |
| `native-packages.tsv` | Native OpenRA mods (macOS and Linux columns) |
| `original-sources.tsv` | Vanilla Conquer and SDL2 sources for the original-engine build |
| `mods.tsv` + `<mod>.tsv` | Generals mod files |

Scripts read pins with `download_package <manifest> <id>` from
`scripts/downloads.sh`; `scripts/pins.py lint` rejects new hard-coded download URLs.
A version of `rolling` (or a date) marks an unversioned URL such as Valve's
installers, whose checksum changes whenever the publisher updates the file.

## 1. Mirror fallback

`download()` tries the publisher first, then this repository's `download-mirror`
release at `<first 12 hex digits of the SHA-256>-<cache name>`. The name follows
from the pin alone, so a launcher release also finds copies uploaded after it was
built. A file is installed only when its checksum matches; a mirror cannot
substitute different bytes. When every source answers
404/410, players see "A required download was removed" instead of a network hint.

Only pins listed in `manifests/mirror-sources.tsv` are mirrored, with their license
and corresponding source. A key ending in `-` covers every pin with that prefix.
Valve installers and mod files are never mirrored. To mirror new or bumped pins:

```sh
python3 scripts/pins.py mirror            # preview files and release notes
python3 scripts/pins.py mirror --upload   # needs gh with write access
```

Uploads go to the `download-mirror` release of the repository in
`manifests/product.tsv`, along with the source archives named in
`mirror-sources.tsv`. Re-running it uploads only what the release lacks. Copies of
earlier pins stay, with their license rows, so older launcher releases keep working.

## 2. Weekly check

`.github/workflows/pins.yml` runs every Monday and on pull requests that touch
manifests. `python3 scripts/pins.py check` fetches the first byte of every pin and
mirror, and downloads rolling pins completely to compare their checksum. It fails
when a pin has no working source, so GitHub notifies the maintainer before players
report it. A pin served only by our mirror is a warning.

## 3. Update pull requests

The same workflow runs `python3 scripts/pins.py updates --apply`. For pins on GitHub
releases, it finds the newest release on the same line, swaps the version into the
asset name, and takes its SHA-256 from GitHub's published digest. For rolling pins,
it records the changed checksum. It then opens or refreshes one pull request on
`automation/pin-updates`.

The release line is the pinned tag's shape with the same major version
(`v0.3.1` follows `v0.x`, `release-2.32.10` stays on SDL 2). Where that is wrong,
`manifests/pin-updates.tsv` holds a regular expression per key prefix, for example
Wine's stable `11.0.x` instead of development `11.y` releases.

Only changed checksums of Valve's unversioned installers are merged automatically:
the bot downloads and verifies the new file, runs the download tests and merges on
`automation/rolling-checksums`. Players get those with the next launcher release.
Release bumps wait for a person: `build.yml` runs on the PR automatically, then the
affected games need a play test, the files the PR lists as naming the old version
need updating, and the mirror needs an upload after merging.

The bot needs "Allow GitHub Actions to create and approve pull requests" in the
repository's Actions settings. GitHub turns scheduled workflows off after 60 days
without repository activity and emails the owner; one click turns them back on.

## Automated testing

| When | Workflow | What it proves |
| --- | --- | --- |
| Every pull request, push to `main`, bump PR | `build.yml` | Headless suites on macOS and Linux, app builds, and `tests/runtime-smoke.sh` on a `macos-26` runner: the pinned Mach9 runtime downloads, passes SHA-256, installs through the launcher, boots a prefix and runs Wine's D3D9 device tests through mtld3d |
| Weekly and on manifest changes | `pins.yml` | Every pin on `main` still downloads with its checksum; newer releases become a PR, which starts `build.yml` itself |
| On publish, weekly, or by tag | `release-smoke.yml` | The newest release's assets match `SHA256SUMS.txt`, the Mac app's signature verifies, the Linux package passes its self-checks, and every pin in that release's manifests still downloads |

The D3D9 step requires the test run to finish; it reports the pass/fail count but
does not gate on it, because mtld3d's own CI holds the conformance baseline.
Nothing automated starts Steam or a game: that needs a Steam sign-in and owned
game files, which never go into CI. After a runtime or engine bump, the remaining
manual step is a short play test of the affected games on a Mac with macOS 26.4+
and on Linux.
