# Working on this launcher

Keep two native frontends: SwiftUI in `Sources/` for macOS and PySide6 in
`linux/` for Linux. Match their four-step flow, visual hierarchy, Steam guidance,
validation, selected-profile behavior and update handling. When changing user
behavior, update both frontends and their tests in the same change. If a platform
cannot support a behavior, document the exception in `docs/linux.md`.

Keep installation and repair behavior in `scripts/backend.sh`; OS-specific
commands belong in `scripts/platform-macos.sh` or `scripts/platform-linux.sh`.
Read game metadata/themes from `manifests/games.tsv`. Keep OpenRA import and
launch behavior in `scripts/classic.sh`; its Steam asset mappings and required
files come from the pinned upstream release, with attribution in manifests.
Never use OpenRA content-download mirrors as a fallback for Steam ownership.
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
