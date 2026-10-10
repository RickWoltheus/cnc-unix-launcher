import struct
import sys
from pathlib import Path

body = bytearray(512)
body[:2] = b'MZ'
struct.pack_into('<I', body, 0x3c, 0x80)
body[0x80:0x84] = b'PE\0\0'
struct.pack_into('<HHIIIHH', body, 0x84, 0x8664, 0, 0, 0, 0, 240, 0x22)
struct.pack_into('<H', body, 0x98, 0x20b)
Path(sys.argv[1]).write_bytes(body + sys.argv[2].encode())
