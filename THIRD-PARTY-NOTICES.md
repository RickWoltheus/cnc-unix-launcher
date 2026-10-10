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
  They are not bundled into the launcher download. See [community credits](docs/community.md)
  and [compatibility notices](manifests/compatibility-notice.txt) for sources and
  relevant attribution.
- **SteamCMD:** proprietary Valve software, downloaded separately from Valve.
- **Game assets and branding:** belong to EA and their respective rights holders.
  A legally owned Steam copy is required. Original game data is not provided by
  this repository or release. Game branding visible in UI screenshots is not
  relicensed under the launcher's MIT license.
- **Optional ClamAV:** installed separately and retains its own license; see
  [the ClamAV project](https://github.com/Cisco-Talos/clamav).

Keep the relevant notices when redistributing the launcher or third-party parts.

## C&C 3 and Red Alert 3 compatibility runtime

Mac profiles download pinned original archives from athei/wine-build and
athei/mtld3d. Wine is LGPL; mtld3d uses the zlib license. Sources and notices
are linked in [the runtime notice](manifests/sage-notice.txt). The upstream Wine
bundle also contains open-source DXMT and proprietary Apple D3DMetal
Redistributables, with their supplied licenses retained. Downloading this bundle
is separate from the launcher release; runtime archives and EA game files are
not packaged in our app ZIP. No paid CrossOver application is installed.

Windows Steam comes from Valve’s official bootstrap. Valve manages subsequent
client and game updates outside the launcher’s pinned download/scanner coverage.
The project-owned MIT browser helper preserves Valve’s original executable and
uses CPU rendering and single-process mode for Wine compatibility; that reduces
browser process isolation. Its source, license, rebuild instructions and checksum
are included. Microsoft DirectX DLLs are extracted locally from owned Steam game
installer CABs, never redistributed. See [setup](docs/cnc3.md) and
[security scope](docs/security.md).
