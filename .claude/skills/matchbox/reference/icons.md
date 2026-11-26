# Preview icons (.glsl.p)

Flame shows `<name>.glsl.p` next to `<name>.glsl` as the shader's thumbnail in its browser. The format below was worked out from 350 sample icons, checked by decoding three of them pixel for pixel against their PNGs, and confirmed in Flame with `sv_Depth_Temporal_Stabilizer`'s icon.

## Format

| Part | Contents |
|---|---|
| Header, 40 bytes, big-endian | `0xFAF00000` (u32), `1.1` (f32, bytes `3f8ccccd`), width `126` (u16), height `92` (u16), `0x0082` (u16), then 26 bytes of `0xFF` |
| Pixels | 8-bit RGB, rows stored bottom row first, each row padded to a multiple of 4 bytes (378 bytes padded to 380) |
| Total | 35,000 bytes for 126 x 92 |

126 x 92 is the size most samples use.

## Making one

```bash
python3 .claude/skills/matchbox/scripts/write_p.py frame.png shaders/<name>/<name>.glsl.p preview_4x.png
python3 .claude/skills/matchbox/scripts/write_p.py --raw upload.bin 512 512 shaders/<name>/<name>.glsl.p preview_4x.png
```

The script centre-crops to the icon aspect, resizes with Lanczos, writes the file, and reads it back to check.

**Render the icon from the shader itself:** in the WebGL harness, draw a source image into `frontImg`, render at about 4x the icon size, `PUT` the `gl.readPixels` bytes to `/upload.bin` on `serve.py`, then run `write_p.py --raw` on them. Show the user the 4x preview before committing.

## What makes a good icon

- It has to read at 126 x 92. A pattern that looks right at full size can turn to mush or moire when scaled down: Digital Screen's raw subpixels did, so its icon shows a fine screen with a magnifier loupe over it.
- A simple, saturated source image (a sunset, a gradient with a sun) works better than a busy plate.
- For a transition, show it mid-way so both images and the motion are visible.
- 8-bit icons clip above 1. A shader whose correct output is brighter than 1 (compensated subpixels) needs settings or a mode that stays in range for the icon.
