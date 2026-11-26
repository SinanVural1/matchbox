#!/usr/bin/env python3
"""
Write a Flame preview icon (.glsl.p) from an image.

Usage:
    python3 write_p.py <in.png> <out.glsl.p> [preview_4x.png]
    python3 write_p.py --raw <rgba.bin> <W> <H> <out.glsl.p> [preview_4x.png]

--raw takes the bytes a WebGL page got from gl.readPixels (RGBA, bottom row
first), as uploaded through serve.py. The image is centre-cropped to the icon
aspect and resized to 126 x 92 with a Lanczos filter. The optional preview is
the icon at 4x with nearest-neighbour scaling, for showing the user.

The format is in reference/icons.md. The file is read back and compared after
writing.
"""
import struct
import sys

import numpy as np
from PIL import Image

W, H = 126, 92


def load(args):
    if args[0] == "--raw":
        raw, rw, rh = args[1], int(args[2]), int(args[3])
        a = np.frombuffer(open(raw, "rb").read(), np.uint8).reshape(rh, rw, 4)
        return Image.fromarray(np.ascontiguousarray(a[::-1, :, :3]), "RGB"), args[4:]
    return Image.open(args[0]).convert("RGB"), args[1:]


def fit(img):
    iw, ih = img.size
    target = W / H
    if iw / ih > target:
        cw = round(ih * target)
        img = img.crop(((iw - cw) // 2, 0, (iw - cw) // 2 + cw, ih))
    else:
        ch = round(iw / target)
        img = img.crop((0, (ih - ch) // 2, iw, (ih - ch) // 2 + ch))
    return img.resize((W, H), Image.LANCZOS)


def write_p(icon, path):
    rgb = np.asarray(icon, np.uint8)
    stride = (W * 3 + 3) // 4 * 4
    rows = np.zeros((H, stride), np.uint8)
    rows[:, :W * 3] = rgb.reshape(H, W * 3)
    header = struct.pack(">IfHHH", 0xFAF00000, 1.1, W, H, 0x82) + b"\xff" * 26
    with open(path, "wb") as f:
        f.write(header)
        f.write(rows[::-1].tobytes())  # bottom row first
    data = open(path, "rb").read()
    back = np.frombuffer(data[40:], np.uint8).reshape(H, stride)[:, :W * 3]
    ok = len(data) == 40 + H * stride and (back.reshape(H, W, 3)[::-1] == rgb).all()
    print("%s: %d bytes, read back %s" % (path, len(data), "ok" if ok else "MISMATCH"))
    return ok


if __name__ == "__main__":
    img, rest = load(sys.argv[1:])
    icon = fit(img)
    ok = write_p(icon, rest[0])
    if len(rest) > 1:
        icon.resize((W * 4, H * 4), Image.NEAREST).save(rest[1])
    sys.exit(0 if ok else 1)
