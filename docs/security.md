# Sources, downloads and security

C&C Unix Launcher coordinates third-party engines, SteamCMD and community mods.
It does not guarantee that every dependency is malware-free. Its current controls
are meant to make downloads inspectable, reject unexpected bytes and optionally
check them with a local antivirus scanner before installation.

## Where software comes from

| Component | Source and verification |
| --- | --- |
| Generals / Zero Hour engine | Pinned GeneralsX publisher releases; SHA-256 before installation. |
| C&C / Red Alert | Pinned OpenRA publisher releases; SHA-256 before installation. |
| Combined Arms / Tiberian Dawn HD | Pinned mod-project releases; SHA-256 before installation. |
| Wine / cnc-ddraw | Pinned packages from the credited projects; SHA-256 before installation. |
| SteamCMD bootstrap | Valve’s HTTPS CDN; pinned SHA-256. Valve’s updater handles later versions. |
| Generals community mods | Data files listed in reviewed manifests, obtained from the GenLauncher catalog’s community HTTP mirror; SHA-256 before installation. No downloaded Windows mod installer is run. |
| Optional ClamAV | Installed separately through Homebrew, the official Mac package or the Linux distribution. FreshClam obtains and validates official definitions. |

Package URLs and hashes live in `manifests/` and the platform adapters. Every
fresh download and verified cache hit passes the shared download gate. A mismatch
stops the install. A pinned hash is this project's record of expected content;
it is not an independent publisher signature or proof that content is benign.
In particular, the HTTP mod mirror’s bytes cannot be substituted without failing
the hash, but the original provenance still depends on the catalog and maintainers.

Owned game assets come only from the player's Steam account. They are not included
in source or releases. SteamCMD is proprietary Valve software, not open source.
Steam credentials and Guard codes are entered in Valve’s separate local console;
the launcher receives allowlisted progress/error labels, not credential input.
Valve may maintain its own login cache and logs outside this launcher’s reporting.

## Optional local scans

Open **Help → Security & downloads** in either launcher:

1. Install ClamAV if wanted. This step opens a local terminal. On Mac, an existing
   Homebrew installation can install it; otherwise the official ClamAV download
   page opens for graphical package installation. Ubuntu/Debian setup uses apt.
2. Update virus definitions in the local terminal. They are stored in the launcher’s
   `security/clamav-db` folder rather than changing an existing scanner config.
   The first download may use several hundred MB. The distribution may separately
   run its own update service; the launcher uses standalone `clamscan`.
3. Enable **Scan downloads locally before installation**. The setting is passed to
   both GUI jobs and local terminal jobs. Disabled scanning still verifies hashes.

Scans happen after the SHA check and before install/extraction, including before
Linux AppImage extraction executes an AppImage or Wine installation runs its
version check. Cached inputs are scanned again rather than silently reusing a
result from older definitions. A cache-only scan is also available from the sheet.

Nothing is uploaded to VirusTotal or another scanning service. The option scans
custom download/cache files, not original Steam installations, Wine prefixes,
saves, logs or credentials. SteamCMD's own updates/downloads and package-manager
installation of ClamAV are outside the launcher’s download gate.

Missing definitions, definitions not checked within seven days, scanner errors,
reported skipped/encrypted files and scan-limit alerts stop the selected install.
Files larger than the supported scan-size ceiling are not marked clean. A detected
hash stays blocked even if scanning is later disabled. Review the report with the
project/maintainer before treating it as a false positive; the UI does not provide
an automatic detection bypass.

Reports include time, filename, SHA-256, scanner/database version and outcome in
`security/scans.tsv`; detailed output is in `security/reports/`. No automatic file
removal or upload occurs. A successful result is **no known threats detected within
scanner limits**, not a safety certificate. Some file formats cannot be fully
interpreted by antivirus tools; data files can also exploit bugs in their readers.
See [ClamAV’s scanner documentation](https://docs.clamav.net/manual/Usage/Scanning.html)
and [signed definition updates](https://docs.clamav.net/manual/Usage/SignatureManagement.html).

## What this does not protect against

- A malicious or compromised publisher whose artifact is deliberately accepted
  into a new reviewed manifest. Reviewing changes and checking provenance matter.
- Unknown malware, antivirus false positives/negatives, parser bugs or content
  outside the scanner’s supported formats and size limits.
- Malicious software already running on the player's machine or an altered local
  installation. An installation hash/scan does not continuously monitor it.
- File access by third-party engines. They run with the user's privileges. A Wine
  prefix separates settings and saves; it is not a security sandbox.

Mac builds are ad-hoc signed and unnotarized because the project has a €0 budget.
Some verified runtimes have quarantine flags cleared for compatibility. Neither
that operation nor an ad-hoc signature certifies third-party safety. No global
Gatekeeper, XProtect or firewall setting is disabled.

## Review and verification

On 2026-10-08 a separate read-only security subagent reviewed download provenance,
hash checks, extraction, command construction, credential handling, update behavior
and the scanner feature. It found no remaining confirmed release-blocking security
issue after a Linux terminal scan-setting propagation defect was fixed and tested.
This was a launcher code review, not an independent audit of every upstream binary.

Synthetic checks cover hash-before-scan order, cache rescans, detection blocking,
stale definitions, scanner errors, coverage limits, and GUI/terminal preference
propagation. A real ClamAV instance in a disposable Linux container downloaded and
validated official signatures, accepted a harmless clean fixture and blocked the
harmless EICAR antivirus test file before installation. No game or malicious program
was executed. Mac scanner installation and real desktop definition-update handoff
still require user validation; headless tests do not prove those desktop flows.

CI actions are pinned to commit hashes. Linux build wheels use a hash-locked
requirements file. Package-manager dependencies and upstream runtime auto-updaters
retain their own trust and update mechanisms. Release archives contain the launcher
and its resources, not Steam assets, mod archives, credentials or virus databases.

Report a suspected security problem privately to the maintainer before posting
sensitive details publicly. Never attach Steam passwords, login caches, private
keys or unredacted credential logs to an issue.
