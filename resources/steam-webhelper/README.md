# Steam browser compatibility helper

This project-owned MIT helper forwards Steam's original browser executable
arguments with `--disable-gpu --single-process`. It uses Win32 CreateProcess,
waits for the original child and returns that child's exit code. It does not
handle credentials, write logs, make network requests or modify EA game code.

The approach follows the published Wine workaround in
[notpop/steam-on-m1-wine](https://github.com/notpop/steam-on-m1-wine/blob/main/wrapper/src/steamwebhelper-wrapper.c)
and [DXMT issue 141](https://github.com/3Shain/dxmt/issues/141). Single-process
Chromium reduces browser process isolation; this is a Wine compatibility measure,
not a security enhancement. Steam authentication still uses Valve's original
client/browser code. Wine remains unsandboxed.

The original Valve executable is retained as `steamwebhelper.cnc-original.exe`.
Installation validates this bundled helper's SHA-256 and optional scanner before
copying it. The installer preserves the original on repeat runs, recognizes its
previous helper by recorded SHA and refreshes the original after Steam updates.
Valve's originals and Steam files are never redistributed by this project.

Rebuild with `bash scripts/build-steam-helper.sh` using MinGW-w64's x86_64 GCC.
The script removes linker timestamps and records the output hash in
`manifests/steam-webhelper.sha256`. End users need no compiler. Source is in
`main.c`; the packaged `.exe` is built from that source.
