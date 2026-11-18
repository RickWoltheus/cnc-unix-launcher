# Third-party notices

The original C&C Unix Launcher code is covered by the [MIT License](LICENSE).
That license does not relicense the projects it downloads, original game assets,
or third-party files included with the package.

- **OpenRA import mappings and required-file lists:** derived from OpenRA's
  Steam installer definitions, licensed GPL-3.0-or-later. Attribution and the
  license text are in [manifests/OpenRA-NOTICE.txt](manifests/OpenRA-NOTICE.txt)
  and [manifests/OpenRA-COPYING.txt](manifests/OpenRA-COPYING.txt).
- **Linux Qt/PySide6/Shiboken and PyInstaller:** retain their applicable licenses.
  See [linux/THIRD-PARTY.md](linux/THIRD-PARTY.md), bundled `licenses/`, and the
  retained package metadata. Qt libraries are dynamically linked and unmodified.
- **Downloaded engines, runtimes and mods:** retain their publishers' licenses.
  Apart from the Vanilla Conquer runtime below, they are not bundled into the launcher download. See [community credits](docs/community.md)
  and [compatibility notices](manifests/compatibility-notice.txt) for sources and
  relevant attribution.
- **Bundled Vanilla Conquer and SDL2:** Vanilla Conquer is GPL-3.0-or-later with
  the additional terms in its upstream `License.txt`; SDL2 uses the zlib license.
  They run as separate executables, without linking into the MIT launcher.
  Pinned corresponding source archives, the build script, checksums and licenses
  are included under `resources/original-runtime/` in the packaged resources.
  The engine package contains no EA game data. Build sources are recorded in
  [manifests/original-sources.tsv](manifests/original-sources.tsv).
- **SteamCMD:** proprietary Valve software, downloaded separately from Valve.
- **Game assets and branding:** belong to EA and their respective rights holders.
  A legally owned Steam copy is required. Original game data is not provided by
  this repository or release. Game branding visible in UI screenshots is not
  relicensed under the launcher's MIT license.
- **Optional ClamAV:** installed separately and retains its own license; see
  [the ClamAV project](https://github.com/Cisco-Talos/clamav).

Keep the relevant notices when redistributing the launcher or third-party parts.

## C&C 3 and Red Alert 3 compatibility runtime

New Mac installs download the pinned, unmodified Mach9 Wine bundle from
athei/mach9: Wine (LGPL) with mtld3d, DXMT (zlib), FEX, Mesa (MIT),
vkd3d-proton and GStreamer (LGPL). Sources and notices are linked in
[the runtime notice](manifests/sage-notice.txt). Earlier installs used the
athei/wine-build cx-26.3.0-7 bundle, which also contained proprietary Apple
D3DMetal; it is no longer downloaded. Runtime archives and EA game files are
not packaged in our app ZIP. No paid CrossOver application is installed.

## Download mirror

When a publisher removes a pinned open-source file, the launcher falls back to an
unmodified copy in this repository's `download-mirror` release, accepted only with
the same SHA-256. That release also holds the corresponding source archives and
lists each file's license; see [pinned downloads](docs/downloads.md). Valve
installers and mod files are never mirrored.

Windows Steam comes from Valve’s official bootstrap. Valve manages subsequent
client and game updates outside the launcher’s pinned download/scanner coverage.
The project-owned MIT browser helper preserves Valve’s original executable and
uses CPU rendering and single-process mode for Wine compatibility; that reduces
browser process isolation. Its source, license, rebuild instructions and checksum
are included. Microsoft DirectX DLLs are extracted locally from owned Steam game
installer CABs, never redistributed. See [setup](docs/cnc3.md) and
[security scope](docs/security.md).
