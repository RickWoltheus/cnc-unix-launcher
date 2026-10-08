# Working on this launcher

Keep two native frontends: SwiftUI in `Sources/` for macOS and PySide6 in
`linux/` for Linux. Match their four-step flow, visual hierarchy, Steam guidance,
validation, selected-profile behavior and update handling. When changing user
behavior, update both frontends and their tests in the same change. If a platform
cannot support a behavior, document the exception in `docs/linux.md`.

Keep community credits and direct maintainer support links in
`resources/community.json`. Add credits when introducing a runtime or mod,
linking its contributor/team page. Verify donation URLs against the project's
published funding links; record their source and verification date. Do not invent
fundraising accounts, donation records or promises to redistribute support.
Regenerate `docs/community.md` with `scripts/community-docs.py --write` after
reviewing the preview; `--check` verifies it. Both frontends use the same links.

Keep installation and repair behavior in `scripts/backend.sh`; OS-specific
commands belong in `scripts/platform-macos.sh` or `scripts/platform-linux.sh`.
Read branding and release names from `manifests/product.tsv`. Preserve legacy
data paths and bundle/preferences identifiers when renaming. Native classic mods
use `manifests/native-mods.tsv` and pinned `native-packages.tsv`; only Steam may
supply their original assets. Online preparation may edit local settings; router
discovery is explicit opt-in and no account/firewall/router action is automatic.
Read game metadata/themes from `manifests/games.tsv`. Keep OpenRA import and
launch behavior in `scripts/classic.sh`; its Steam asset mappings and required
files come from the pinned upstream release, with attribution in manifests.
Wine profiles use `scripts/compatibility.sh` and pinned packages in manifests.
Keep original Steam downloads separate from per-profile working copies and Wine
prefixes. These profiles stay experimental until authorized gameplay checks pass;
CnCNet preparation is disabled until implemented. Do not replace owned executables
with downloaded EA binaries. Runtime installation must not initialize a prefix or
open Wine configuration windows. Dummy launches skip Wine entirely.
Never use OpenRA content-download mirrors as a fallback for Steam ownership.
Keep Steam credentials in the separate local console. Both UIs must provide a
modeless guide from shared Steam copy/stages; status updates must not steal typing
focus. The guide receives sanitized labels, never raw Steam output or secret inputs.
Reuse the shared manifests, graphics presets, setup policy and Steam guidance
resources. Add shared business rules there rather than copying them into a view.
Do not replace SwiftUI or introduce a cross-platform UI rewrite as routine work.

Run headless tests by default. Real game launches require the user's explicit
request in the current session. Fixture tests must use `GX_LAUNCH_WRAPPER` so
automatic repair cannot accidentally invoke an actual game. Do not run real
Steam authentication in captured tool output; credentials belong only in the
local interactive Steam window. Retain only allowlisted Steam status labels.

Never commit or package game data, mod archives, Steam credentials or saves.
Download owned game data only through the user's Steam account. Add mod versions
only after checking their public source, files and checksums; keep untested
gameplay labeled experimental. Keep the existing macOS setup working when adding
Linux behavior. Do not modify Claude/Codex global settings or authentication.

Read `docs/verification.md` before reporting validation. Distinguish headless
checks from real desktop, sign-in, GPU and gameplay tests. Publication still
requires approval of its concrete public text under the session's conventions.
