#!/usr/bin/env python3
"""svg-to-ico.py SOURCE.svg OUTPUT.ico

Renders the app icon to a single 256x256 PNG via rsvg-convert, then wraps
it in a minimal ICO container by hand (no Pillow dependency - MSYS2's
UCRT64 repo doesn't carry it, and this is the only place in the build that
would need it). A PNG-compressed ICO frame is valid on Windows Vista+,
which covers every realistic install target, so no BMP/multi-size
fallback is generated.
"""

import shutil
import struct
import subprocess
import sys

SIZE = 256


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} SOURCE.svg OUTPUT.ico")

    source, output = sys.argv[1], sys.argv[2]

    rsvg_convert = shutil.which("rsvg-convert")
    if rsvg_convert is None:
        sys.exit("rsvg-convert not found on PATH")

    png = subprocess.run(
        [rsvg_convert, "-w", str(SIZE), "-h", str(SIZE), source],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout

    # ICO: 6-byte header, one 16-byte directory entry, then the raw PNG.
    header = struct.pack("<HHH", 0, 1, 1)
    entry = struct.pack(
        "<BBBBHHII",
        0,  # width (0 = 256)
        0,  # height (0 = 256)
        0,  # palette colors
        0,  # reserved
        1,  # color planes
        32,  # bits per pixel
        len(png),
        6 + 16,  # offset: right after header + this one entry
    )

    with open(output, "wb") as f:
        f.write(header)
        f.write(entry)
        f.write(png)


if __name__ == "__main__":
    main()
