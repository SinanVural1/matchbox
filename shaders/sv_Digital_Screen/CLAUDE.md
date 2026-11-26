# sv_Digital_Screen

Notes and decisions for this shader. The shared framework is in the root `CLAUDE.md` and the matchbox skill; this file only records what is specific to this shader and why.

## Purpose

Shows the image as a display seen up close: each screen pixel is a set of red, green and blue subpixels laid out as on an LCD, CRT, OLED or LED wall. Used for screen inserts, close-ups of phones, monitors and LED walls, and for matching a screen photographed in a plate.

Built because none of the existing Matchbox shaders could do it: `crok_scanlines`, `crok_crt`, `crok_tv_rgb_dots`, `cr2_LED` and `crok_old_tv` all have fixed patterns or whole-pixel sizes, and all shimmer at fractional or rotated pitches.

## Status

- Confirmed working in Flame by the user, including the Reference input, Fit to Points and Source Colour.
- Published: README, `.glsl.p` icon (sunset on a fine screen with a magnifier loupe), ZIP. The icon has not been checked in Flame's browser.
- Not on logik-matchbook.org.

## Structure

- **Subpixels are rounded rectangles** with a centre, half size and channel per layout (up to four per pixel). Coverage comes from the signed distance with a ramp about a pixel wide, so fractional and rotated pitches don't shimmer or throw moire. Measured: 0.03% brightness variation across 6-pixel windows at 4.3 px rotated 7 degrees.
- **Each sample checks its screen pixel and the eight around it**, so softness and glow can cross pixel borders.
- **Area sampling reads a mip level about a screen pixel wide** with `texture2DLod`, so the Front input has `Mipmaps="True"` and the shader enables `GL_ARB_shader_texture_lod`. This is the same declaration as Autodesk's own `Mipmaps` sample.
- **Delta rows are offset by half a pixel**; PenTile and Diamond alternate red and blue by pixel parity.

## Decisions

- **Compensation divides by each channel's lit area** so the screen keeps the picture's average brightness. Within 2% for all nine layouts at 16, 7.3 and 4.3 px. The area includes `pi * w^2 / 12` for the anti-aliasing ramp (the inner and outer perimeter terms cancel); without it tiny LED dots read 17% too bright.
- **At Compensation 1, values well above 1 are correct** (up to about 30 for LED Wall). This is a float pipeline; the README explains it.
- **Glow follows the picture, not the compensated drive.** Boosting glow with compensation swamped the LED Wall.
- **Aperture Grille stripes are exactly half a pixel tall with square ends**, so the ramps of stripes above and below sum to one with no seam.
- **Source Colour mode** (user request): the layout only shapes the light and every subpixel shows the full pixel colour, untinted. Compensation then uses the total lit area. Checked: lit pixels keep the input's exact channel ratios.
- **Reference input (Back)** is for comparison only: Blend, Split and Difference views, never in the render when View is Off.
- **Fit to Points** (user request): two axes on the same spot of two screen pixels plus Pixels Across and Pixels Down set Pixel Size, Rotation and the origin, with Point A at a pixel centre. Reproduces a hand-set grid to 1/255 for points along a row and on a diagonal.
- **Swap Phase** was added because a fit cannot know which parity Point A landed on; for PenTile, Diamond and Delta exactly one setting matches.
- **Pixel Size is in pixels with `ResDependent="Width"`**, as in Triangle Mosaic.

## Open items

- Layout column on the Screen page has six controls, the maximum; the user hasn't commented on crowding.
- Mismatched Front and output resolutions would pick the wrong mip level; not tested.
