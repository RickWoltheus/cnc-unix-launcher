"""Create synthetic MIX containers without any game assets."""
from pathlib import Path
import csv
import struct
import sys

resources, installation = map(Path, sys.argv[1:])


def mix(entries):
    index, content = [], bytearray()
    for name, value in entries.items():
        raw, hashed = name.upper().encode("ascii"), 0
        for offset in range(0, len(raw), 4):
            chunk = int.from_bytes(raw[offset:offset + 4].ljust(4, b"\0"), "little")
            hashed = (((hashed << 1) | (hashed >> 31)) + chunk) & 0xFFFFFFFF
        index.append(struct.pack("<III", hashed, len(content), len(value)))
        content.extend(value)
    return struct.pack("<HI", len(index), len(content)) + b"".join(index) + content


for game, directory, appid in [("cnc", "TiberianDawn", "2229830"), ("ra", "RedAlert", "2229840")]:
    rows = list(csv.reader((resources / f"manifests/openra-{game}-import.tsv").open(), delimiter="\t"))
    groups = {}
    for op, archive, source, dest in rows:
        if op == "extract":
            groups.setdefault(archive, {})[source] = dest

    def make_archive(archive):
        entries = {}
        for source, dest in groups.get(archive, {}).items():
            nested = "@content/" + dest
            entries[source] = make_archive(nested) if nested in groups else mix({"conquer.ini": b"synthetic fixture"}) if source.endswith(".mix") else b"synthetic fixture"
        return mix(entries or {"conquer.ini": b"synthetic fixture"})

    folder = installation / directory
    (folder / "steamapps").mkdir(parents=True, exist_ok=True)
    (folder / f"steamapps/appmanifest_{appid}.acf").write_text('"AppState"\n{\n"StateFlags" "4"\n}\n')
    for archive in groups:
        if not archive.startswith("@content/"):
            (folder / archive.lower()).write_bytes(make_archive(archive))
    for op, archive, source, dest in rows:
        if op == "copy":
            (folder / source.lower()).write_bytes(mix({"conquer.ini": b"synthetic fixture"}))
print("Synthetic classic Steam containers created; no EA data.")
