#!/usr/bin/env python3
"""zipalign replacement: stored entries start on 4-byte boundaries, stored .so libraries on 16 KiB boundaries."""
import sys, zipfile

def align(src, dst):
    with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w") as zout:
        for info in zin.infolist():
            data = zin.read(info.filename)
            new = zipfile.ZipInfo(info.filename, info.date_time)
            new.external_attr = info.external_attr
            new.compress_type = info.compress_type
            new.extra = b""
            if info.compress_type == zipfile.ZIP_STORED:
                boundary = 16384 if info.filename.endswith(".so") else 4
                header = 30 + len(info.filename.encode("utf-8"))
                pad = (-(zout.fp.tell() + header)) % boundary
                new.extra = b"\x00" * pad
            zout.writestr(new, data, compress_type=info.compress_type, compresslevel=6)

if __name__ == "__main__":
    align(sys.argv[1], sys.argv[2])
