"""Synthetic empty MIX/MEG containers for headless source validation; no EA content."""
from pathlib import Path
import struct
import sys

resources, root = map(Path, sys.argv[1:])
folder = root / "Remastered"
(folder / "steamapps").mkdir(parents=True, exist_ok=True)
(folder / "steamapps/appmanifest_1213210.acf").write_text('"AppState"\n{\n"StateFlags" "4"\n}\n')
for name in (resources / "manifests/tdhd-required.txt").read_text().splitlines():
    dest = folder / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    if name.endswith(".MEG"):
        dest.write_bytes(struct.pack("<IIIIII", 0xFFFFFFFF, 0x3F7D70A4, 24, 0, 0, 0))
    else:
        # One synthetic entry ensures old MIX format is unambiguous.
        dest.write_bytes(struct.pack("<HI", 1, 1) + struct.pack("<III", 0x12345678, 0, 1) + b"x")
print("Synthetic Remastered headers created; no game data.")
