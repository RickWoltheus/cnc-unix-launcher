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

## Experimental C&C 3 runtime

The C&C 3 profiles download pinned original Sikarugir Wine and Template archives
on macOS. Installation retains the D9VK license and extracts the open-source
runtime libraries, GStreamer and Kosmickrisp driver. It does not install
Sikarugir’s SDK/launcher/Creator or Apple’s proprietary D3DMetal. Component
licenses and source links are listed in [sage-notice.txt](manifests/sage-notice.txt);
these downloads are not bundled or relicensed in launcher releases. On Linux,
the user installs Valve’s proprietary Steam client and Steam manages Proton
and its component licenses. [Proton source](https://github.com/ValveSoftware/Proton).

The project-owned Steam browser helper is MIT-licensed, with its C source and
rebuild instructions packaged alongside the executable. Its Wine compatibility
approach follows [notpop/steam-on-m1-wine](https://github.com/notpop/steam-on-m1-wine).
Valve’s original browser executable is backed up locally and is never bundled
in this project’s releases. Single-process Chromium reduces browser process
isolation; see [the C&C 3 guide](docs/cnc3.md).
