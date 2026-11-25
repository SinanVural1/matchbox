# Digital Screen

A Matchbox shader for Autodesk Flame that shows an image as it looks on a display seen up close: every screen pixel is a cluster of red, green and blue subpixels, laid out as on an LCD, CRT, OLED phone or LED wall.

Use it for screen inserts and monitor comps, for close-ups of phones, TVs and LED walls, or as a graphic look. A Reference input and a two-point fit help you match the pixel pattern of a screen photographed in your plate.

**[Download the shader (ZIP)](https://github.com/SinanVural1/matchbox/raw/main/shaders/sv_Digital_Screen/sv_Digital_Screen.zip)**

## Installation

1. Download and unzip the shader.
2. Keep `sv_Digital_Screen.glsl` and `sv_Digital_Screen.xml` together in the same folder. Flame loads them as a pair, and `sv_Digital_Screen.glsl.p` gives it a preview icon in Flame's browser.
3. In Batch, add a Matchbox node and browse to that folder to load **Digital Screen**.

Developed for Flame 2027.1.

## Inputs and outputs

| Socket | Use |
|---|---|
| Front | The image to show on the screen. Required. |
| Reference | Optional. A screen to match, such as a frame of your plate. It only appears in the reference views and never changes the render. |
| Result | The image as a screen. |
| Matte output | The subpixel coverage (white on the subpixels, black in the gaps), or the source alpha. Set with **Matte** on the Output page. |

## Workflow

### As a look

1. **Connect Front** and pick a **Layout**.
2. **Set Pixel Size** in image pixels. It doesn't have to be a whole number.
3. **Shape the subpixels** with Fill, Roundness, Softness and Glow.
4. **Render it flat and corner-pin it in Action.** The pattern stays crisp and Action handles the perspective.

### Matching a screen in the plate

1. **Connect the plate to Reference**, and set **View** on the Match page to Split or Blend.
2. **Pick the Layout** that matches what you see in the reference.
3. **Turn on Show Guides** and **Fit to Points**.
4. **Place Point A and Point B** on the same spot of two screen pixels in the reference, for example the centre of a green subpixel, as far apart as you can count accurately.
5. **Enter how many screen pixels apart they are** in Pixels Across, and in Pixels Down if the points aren't on the same row. Pixel Size, Rotation and the grid origin are now set for you.
6. **Check with View: Difference.** It goes dark where the pattern lines up. If the grid lines up but red and blue are swapped (PenTile, Diamond) or alternate rows are off (Delta), turn on **Swap Phase**.
7. **Turn the view and guides off before rendering.**

## Controls: Screen page

### Layout

| Control | Default | What it does |
|---|---|---|
| Layout | RGB Stripe | **RGB Stripe**: vertical R, G, B bars, as on most LCDs. **Stacked**: R, G and B stacked in each pixel. **Delta**: the dot triads of a CRT shadow mask. **Aperture Grille**: unbroken vertical stripes. **PenTile** and **Diamond**: OLED layouts where red and blue take turns. **LED Wall**: three small dies in a dark package. **Quad RGGB** and **Quad RGBW**: a 2x2 block per pixel. |
| Pixel Size | 12 | Width of one screen pixel, in image pixels. Need not be a whole number. Scales with the resolution. |
| Pixel Aspect | 1 | Height of a screen pixel relative to its width. |
| Rotation | 0 | Rotation of the pixel grid, in degrees. |
| Colour | RGB Subpixels | **RGB Subpixels**: each subpixel lights only its own channel, as on a real screen. **Source Colour**: the layout only shapes the light, and every subpixel shows the pixel's full colour, untinted. |
| Swap Phase | Off | Flips which pixels take turns: red and blue in PenTile and Diamond, the offset rows in Delta. |

### Position

| Control | Default | What it does |
|---|---|---|
| Grid Centre | 0.5, 0.5 | Origin of the pixel grid. Drag the axis in the viewer. |
| Action Coords | Off | Read Grid Centre, Point A and Point B as Action coordinates (pixels from the image centre), so you can paste tracker data onto them. |

### Subpixels

| Control | Default | What it does |
|---|---|---|
| Fill | 0.85 | How much of its slot each subpixel fills. Lower values widen the dark gaps. |
| Roundness | 0.3 | Corner rounding. At 1, square slots become circles and tall slots become capsules. |
| Softness | 0 | Edge falloff, as a fraction of subpixel size. Edges are anti-aliased at 0. |
| Glow | 0 | Light bleeding out around each subpixel, as when a screen is shot through a lens. |
| Glow Size | 0.15 | Reach of the glow, as a fraction of pixel size. |

### Picture

| Control | Default | What it does |
|---|---|---|
| Sampling | Area | **Area**: each screen pixel shows the image averaged over its own area, so fine detail doesn't flicker. **Point**: one sample at the pixel centre. |
| Compensation | 1 | Brightens the subpixels to make up for the light lost in the gaps. At 1 the screen keeps the picture's average brightness, so with small subpixels in big gaps the subpixels go well above 1. At 0 they are never brighter than the picture. |
| Gain | 1 | Overall brightness. |
| Gap Colour | Black | Colour between the subpixels. |

## Controls: Match page

| Control | Default | What it does |
|---|---|---|
| Fit to Points | Off | Set Pixel Size, Rotation and the grid origin from Point A and Point B. Point A lands on the centre of a screen pixel. |
| Pixels Across | 10 | Screen pixels from A to B along a row. |
| Pixels Down | 0 | Screen pixels from A to B down a column. 0 when both points are on the same row. |
| Show Guides | Off | Outline every screen pixel and draw the two points. Turn off before rendering. |
| Point A, Point B | 0.4, 0.5 and 0.6, 0.5 | Two axes placed on the same spot of two screen pixels in the reference. |
| View | Off | Compare with the Reference input: **Blend**, **Split** (reference right of a yellow line), or **Difference** (dark where they match). Turn off before rendering. |
| Mix | 0.5 | Amount of reference in the Blend view. |
| Split | 0.5 | Position of the line in the Split view. |

## Controls: Imperfections page

| Control | Default | What it does |
|---|---|---|
| Dead Pixels | 0 | Fraction of screen pixels that stay dark. |
| Stuck Pixels | 0 | Fraction of screen pixels with one subpixel stuck fully on. |
| Pixel Variation | 0 | Random brightness change per screen pixel. |
| Subpixel Variation | 0 | Random brightness change per subpixel, which tints pixels at random. |
| Panel Size | 64 | Screen pixels along each side of a panel, as in the modules of an LED wall. |
| Panel Variation | 0 | Random brightness change per panel. |
| Panel Tint | 0 | Random colour shift per panel. |
| Variation | 0 | Picks a new random set of all of the above. |

## Controls: Output page

| Control | Default | What it does |
|---|---|---|
| Matte | Coverage | **Coverage**: white on the subpixels, black in the gaps, useful for grading the gaps or the glow on their own. **Source Alpha**: the Front alpha passed through. |
| Samples | 1 | Samples per pixel (1, 4, 9 or 16). Edges are already anti-aliased at 1; more helps very small or rotated pixels. |
| Debug | Off | **Front**: the input as it arrives. **Pixel Colour**: the colour each screen pixel shows, without the mask. **Mask Only**: the subpixel pattern on a white picture. |

## Tips

- **Values above 1 are expected.** With Compensation at 1, small subpixels in big gaps can go well above 1, as much as 30 for the LED Wall. That's correct in Flame's float pipeline and keeps the brightness right after a defocus or a scale down. Lower Compensation if you want display-range values.
- **No moire on odd sizes.** The subpixel edges are anti-aliased, so fractional pixel sizes and rotated grids stay clean. If a very small pattern still buzzes in motion, raise Samples.
- **Defocus after, not before.** For an out-of-focus screen, defocus the result. With Compensation at 1 it blurs back to the picture's own brightness; Glow adds light on top.
- **Grade the gaps.** Matte: Coverage gives you the subpixels as a matte, to darken the gaps or push the glow separately downstream.

## How it works

Each layout is a small set of subpixels per screen pixel, each a rounded rectangle with its own centre, size and channel. For every image pixel the shader finds its screen pixel and the eight around it, measures the exact distance to each nearby subpixel, and turns that into anti-aliased coverage, softness and glow. Each screen pixel's colour comes from a mipmap level about its own size, which averages the image over the pixel. Compensation divides by the lit area of each channel, including the small extra area the anti-aliasing adds, so the screen's average matches the picture.

## Author

Sinan Vural

## License

Released under the [MIT License](https://github.com/SinanVural1/matchbox/blob/main/LICENSE). You're free to use, modify and share this shader, including on commercial work, as long as the copyright notice is kept.
