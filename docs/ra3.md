# Red Alert 3 — experimental development support

This profile is included in the v0.4.0 prerelease. The user confirmed
excellent performance at Ultra High settings on macOS 26 with mtld3d Metal
rendering. Linux gameplay remains unverified. It shares the runtime and launch
guide documented in [C&C 3 setup](cnc3.md), with its own Steam app (17480),
working copy and prefix.

1. Select **Red Alert 3** and prepare the runtime.
2. Download your owned English Steam installation using the launcher. On Linux,
   use the native Steam client and select/install Proton for this game.
3. Start in windowed mode. On Mac, complete Windows Steam sign-in in Valve's
   window if requested and allow Steam's first-run dependencies to finish.
4. Test menu input, videos/audio, campaign, skirmish, save/load and normal quit
   before relying on the profile. Online/co-op and curated mods are not configured.

The original RA3 launcher can pause while attempting to contact EA's retired
news service. Allow startup to finish; repeated Play clicks are not a fix.
[Upstream investigation](https://github.com/xan105/RA3-Launcher) documents this
behavior. This integration retains the owned executable and does not install a
replacement launcher or generate CD keys. Configuration discovery selects the
highest numeric English RA3 SkuDef and validates its referenced executable.

C&C 4 is intentionally excluded. Uprising is not included in this initial RA3
profile. Headless fixtures verify configuration selection, installer behavior and launcher
wiring. The user’s Mac gameplay test is separate from those checks.
