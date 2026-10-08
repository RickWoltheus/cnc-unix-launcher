# C&C Unix Launcher v0.3.0 — community preview

A guided Mac and Linux launcher for owned Steam C&C games: OpenRA for C&C/Red Alert,
GeneralsX for Generals/Zero Hour, and experimental Wine profiles for Red Alert 2,
Yuri’s Revenge and Tiberian Sun/Firestorm. Includes curated community mods and
credits with direct maintainer support links.

Downloads use pinned hashes. **Help → Security & downloads** adds optional local
ClamAV scans before installation, with local reports and blocked/incomplete scan
handling. No files are uploaded to a scanning service. See [security controls and
limits](https://github.com/RickWoltheus/cnc-unix-launcher/blob/main/docs/security.md).
Checksum checks, code review and antivirus do not guarantee malware-free software.

Mac: Apple Silicon, macOS 15+, ad-hoc signed and unnotarized. Download the ZIP,
extract and move **C&C Unix Launcher.app** to Applications. Use **Privacy & Security
→ Open Anyway** if macOS blocks its first open. Linux: x86_64 Ubuntu 24.04+/Debian
12+, glibc 2.36+, with required desktop/graphics libraries; extract the archive and
run **bash CnCUnixLauncher/start-launcher.sh**. Dependencies install in a local terminal.

This is a development preview. Headless checks and scanner integration checks
passed; platform/game/mod compatibility has not been exhaustively validated.
Wine entries remain experimental. C&C 3/Kane’s Wrath, Red Alert 3/Uprising and the
other 3D titles are deferred. Original game assets, mod archives and credentials
are not included. Own the selected game on Steam; sign in only in Valve’s local console.
