# Setup issues and recovery

The launcher addresses the following setup failures. This is not a claim that it
fixes every engine or mod bug.

| Report or failure | Launcher behavior |
| --- | --- |
| [Animated menu crash, GeneralsX #347](https://github.com/fbraz3/GeneralsX/issues/347) | Uses `-noshellmap` for every profile. Actual match crashes can still occur. |
| [Pink textures from missing base assets](https://github.com/fbraz3/GeneralsX/wiki/Fixing-Magenta-Textures-in-Zero-Hour) | Requires the Steam manifest and mandatory game/shared archives, and sets the asset paths explicitly for each profile. An incomplete download cannot unlock Play. |
| [Mods loading vanilla due to wrong paths](https://www.reddit.com/r/commandandconquer/comments/chwvti/need_some_help_with_rise_of_the_reds_mod/) | Separate mod folders, `.gib` activation, and one selected profile feed the single Play action. The forum reports describe Windows installs; this is the corresponding path/activation prevention in the Mac launcher. |
| [Stock AI overriding ShockWave AI, #335](https://github.com/fbraz3/GeneralsX/issues/335) | Preserves stock loose AI scripts under a disabled suffix before layering mod files. The End of Days' own loose AI scripts remain active. |
| Missing native runtime libraries | Readiness checks detect missing core libraries. The backend can restore the verified engine before launch; the UI also offers engine repair. |
| DXVK HUD shader limitation in the pinned macOS wrapper | Forces the HUD off. Source: upstream `scripts/build/macos/bundle-macos-zh.sh`. |
| Corrupt or changed downloads | Requires pinned SHA-256 values and preserves the prior installation on failure. Verified cached downloads are reused. |
| Settings edits while a game is running | Blocks installation/settings changes; backs up the original options before applying graphics presets. |
| Steam sign-in failure | Displays guidance for password/account errors, Steam Guard, expired codes, rate limits, no license, connection problems and interrupted downloads. |
| Stale Steam session after interruption | Checks the installer PID and session kind. A dead session is shown as incomplete rather than permanently downloading. |

Steam output passes through the local Terminal. `steam-status.sh` retains only
an allowlisted status label and never stores or forwards raw sign-in output to
the GUI. Passwords and Steam Guard codes go directly to Valve's client. Automated
tests exercise representative error lines, not real authentication attempts.

The stepper uses validated state, not visited-page history. Preparation must
finish before Steam, and files must pass readiness checks before Play. Existing
verified installations can skip setup. Unsupported platforms, active downloads,
failed sign-in and switching to an unprepared game keep later steps locked.

Engine crashes, save-game failures, multiplayer bugs and Windows-only mod engine
features cannot all be fixed by an installer. Mod support remains experimental.
