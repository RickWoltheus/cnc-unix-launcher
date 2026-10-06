# Verification before release

No build, tests, GUI launch, or fresh installation has been run for this launcher.
The user asked to defer testing. Do not mark a release verified until these
checks have actually passed.

1. Run shell syntax checks and the backend checks in `tests/backend.sh`.
2. Build the app with `bash scripts/build.sh` and verify the ad-hoc signature.
3. On an Apple Silicon Mac, launch the app from a path containing spaces and
   confirm setup progress remains responsive.
4. Install into a fresh user account with no Homebrew or existing GeneralsX
   files. Verify engine download and SteamCMD bootstrap.
5. Sign into Steam locally. Verify a wrong password and a Steam Guard challenge
   do not appear in GUI output or project logs.
6. Confirm a Steam account without Zero Hour produces the ownership error and
   does not enable Play.
7. Download Zero Hour, validate shared assets, and play/save/load a skirmish.
8. Install ROTR, play Russia/ECA skirmishes, and verify AI builds units.
9. Return to unmodded Zero Hour and confirm it still works.
10. Repeat engine and mod install; interrupt a download and retry; confirm corrupt
    archives fail verification without replacing a previous working installation.
11. Test windowed/fullscreen on a Retina display and an external monitor.
12. Confirm the packaged ZIP contains only launcher source resources, manifests,
    and the launcher executable, with no assets, credentials, local paths or logs.

The checksum pins in `manifests/rotr.tsv` were recorded from downloaded archives
that matched the public mirror's MD5 ETags and sizes. No independent publisher
signature was available. Keep this qualification in public documentation.
