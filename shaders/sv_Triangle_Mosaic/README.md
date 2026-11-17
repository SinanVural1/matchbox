# Triangle Mosaic

A Matchbox shader for Autodesk Flame that turns the frame into a mosaic of triangles, and can transition from one image to another tile by tile: tiles shrink, fade, spin, or flip over to reveal the next shot.

Use it for mosaic and stained-glass looks, geometric textures, or as a transition driven by your own matte or by a built-in wipe. The node can also output a matte of the tiles, their edges, a gradient inside each tile, a random grey per tile, or each tile's transition progress.

**[Download the shader (ZIP)](https://github.com/SinanVural1/matchbox/raw/main/shaders/sv_Triangle_Mosaic/sv_Triangle_Mosaic.zip)**

## Installation

1. Download and unzip the shader.
2. Keep `sv_Triangle_Mosaic.glsl` and `sv_Triangle_Mosaic.xml` together in the same folder. Flame loads them as a pair, and `sv_Triangle_Mosaic.glsl.p` gives it a preview icon in Flame's browser.
3. In Batch, add a Matchbox node and browse to that folder to load **Triangle Mosaic**.

Developed for Flame 2027.1.

## Inputs and outputs

| Socket | Use |
|---|---|
| Front | The image the mosaic is made from. Required. |
| Back | The image revealed by the transition, and shown through any gaps between tiles. Optional; black when not connected. |
| Matte | Drives the transition when **Wipe** is set to Matte or Matte Wipe. Optional. |
| Result | The mosaic, part-way through the transition if one is running. |
| Matte output | Tile coverage, edges, a gradient inside each tile, a random grey per tile, or transition progress. Set with **Matte** on the Output page. |

## Workflow

### As a mosaic

1. **Connect Front.**
2. **Choose the shape and size** on the Grid page: Equilateral, Isosceles or Right triangles, and **Size** in pixels.
3. **Pick the fill** on the Look page. **Flat** gives each tile one colour, averaged over the tile. **Image** keeps the picture inside each tile, which shows off rotated or scaled tiles.
4. **Break up the grid** with Scale, Rotation and Offset Variance, and add Colour Variation, Edges and Bevel to taste.

### As a transition

1. **Connect Front (the outgoing shot) and Back (the incoming shot).**
2. **Choose a Wipe** on the Transition page:
   - **Matte**: connect a matte, and its value is each tile's progress. Black tiles stay put, white tiles have finished, grey tiles are part-way. Animate the matte to drive the transition.
   - **Matte Wipe**: animate **Progress** from 0 to 1, and it sweeps through the matte's values, white areas first.
   - **Linear**, **Radial**, **Random**: built-in wipes. Animate **Progress** from 0 to 1.
3. **Choose how the tiles go**: **Shrink**, **Fade** and **Spin** can be combined, or set **Flip** to Hinge or Card.
4. **Shape the wave** with **Softness** (how many tiles are in motion at once) and **Spread** (a random delay per tile).

Progress 0 is always the untouched mosaic and Progress 1 is always a clean Back, with no edges or tile colours left over.

## Controls: Grid page

### Shape

| Control | Default | What it does |
|---|---|---|
| Shape | Equilateral | **Equilateral**, **Isosceles** or **Right** triangles. |
| Stretch | 1 | Height of the triangles relative to their width. Isosceles and Right only. At 1, Isosceles matches Equilateral. |
| Diagonal | Same | Right only. How each square of the grid is cut: all the same way, **Alternating**, at **Random**, or **Four-Way** into four triangles along both diagonals. |
| Size | 80 | Width of a tile in pixels. It scales with the resolution, so the pattern holds when the resolution changes. |
| Rotation | 0 | Rotation of the whole grid, in degrees. |

### Position

| Control | Default | What it does |
|---|---|---|
| Grid Centre | 0.5, 0.5 | Origin of the grid. Drag the axis in the viewer. |
| Action Coords | Off | Read Grid Centre and Wipe Centre as Action coordinates (pixels from the image centre), so you can paste tracker data onto them. |

### Tiles

| Control | Default | What it does |
|---|---|---|
| Tile Scale | 1 | Size of every tile relative to its place in the grid. Below 1 opens gaps that show Back. |
| Scale Variance | 0 | Random size change per tile, up to this fraction either way. |
| Rotation Variance | 0 | Random rotation per tile, up to this many degrees either way. |
| Offset Variance | 0 | Random shift per tile, as a fraction of tile size. |
| Luma Scale | 0 | Sizes tiles by brightness. Positive shrinks dark tiles, negative shrinks bright ones. |

### Random

| Control | Default | What it does |
|---|---|---|
| Variation | 0 | Picks a new set of random values for every tile. Whole numbers give unrelated results. |
| Evolution | 0 | Animate it to make the random size, rotation and offset drift smoothly. |
| Dropout | 0 | Fraction of tiles removed at random, showing Back. |

## Controls: Look page

### Fill

| Control | Default | What it does |
|---|---|---|
| Fill | Flat | **Image**: each tile carries its piece of the picture. **Flat**: each tile is one colour, averaged over the tile so it doesn't flicker on moving footage. |
| Hue, Saturation, Brightness | 0 | Random colour change per tile, up to this much either way. Hue is in degrees. |

### Edges

| Control | Default | What it does |
|---|---|---|
| Draw Edges | On | Paint lines along the tile borders. The Edges matte works whether this is on or off. |
| Edge Width | 0.03 | Full width of the lines, as a fraction of tile size. |
| Edge Softness | 0.01 | Falloff on each side of the lines, as a fraction of tile size. |
| Edge Colour | Black | Colour of the lines. |

### Bevel and Light

| Control | Default | What it does |
|---|---|---|
| Bevel | 0 | A raised-tile look: borders facing the light brighten, borders facing away darken. 0 is off. |
| Bevel Width | 0.1 | Width of the bevel, as a fraction of tile size. |
| Light Angle | 135 | Direction the light comes from: 0 from the right, 90 from above. Used by the bevel and the flip shading. |
| Light Height | 45 | Height of the light above the frame, in degrees. Lower gives stronger shading. |

## Controls: Transition page

### Wipe

| Control | Default | What it does |
|---|---|---|
| Wipe | None | What drives each tile from Front to Back: **Matte**, **Matte Wipe**, **Linear**, **Radial** or **Random**. See the transition workflow above. |
| Progress | 0 | Animate from 0 to 1 to run the wipe. Not used by Wipe: Matte, where the matte itself is the progress. |
| Softness | 0.3 | Width of the band of tiles in motion. Small values move a narrow line of tiles, large values move most of them at once. |
| Spread | 0 | Random delay per tile, so the wipe breaks up instead of moving as a clean line. |
| Wipe Angle | 0 | Direction of the Linear wipe: 0 moves left to right, 90 bottom to top. |
| Wipe Centre | 0.5, 0.5 | Centre of the Radial wipe. |

### Motion

| Control | Default | What it does |
|---|---|---|
| Shrink | 1 | How much a tile shrinks over its transition. 1 shrinks it away to nothing. Set it to 0 when using Flip. |
| Fade | 0 | How much a tile fades out over its transition. |
| Spin | 0 | Degrees a tile spins over its transition. |

### Flip

| Control | Default | What it does |
|---|---|---|
| Flip | Off | **Hinge**: the tile folds over one edge onto its neighbour, its underside showing Back. **Card**: the tile turns over in place, Front on one side and Back on the other. |
| Flip Angle | 180 | Degrees a tile turns. 180 lands it face down, showing Back. |
| Direction | Follow Wipe | Which way tiles turn. **Follow Wipe** tips them the way the wipe travels, like falling dominoes. With a matte, that's from its bright areas toward its dark ones. **Random** and **Against Wipe** are the alternatives. |
| Shading | 0.6 | How much a turning tile darkens as it faces away from the light. |
| Highlight | 0.3 | A glint as a turning tile passes through the angle that reflects the light. |
| Perspective | 0.5 | Makes turning tiles read as 3D: the side lifting toward camera grows. 0 is flat. |

## Controls: Output page

| Control | Default | What it does |
|---|---|---|
| Matte | Tile Coverage | What the matte output carries: **Tile Coverage** (white where tiles are), **Edges**, **Tile Gradient** (white at each tile's centre, black at its border), **Tile ID** (a random grey per tile), or **Progress** (each tile's transition progress). |
| Falloff | 1 | Shapes the Tile Gradient. 1 is linear, above 1 tightens the bright centre, below 1 widens it. |
| Samples | 1 | Samples per pixel (1, 4, 9 or 16). Borders are already anti-aliased at 1; more samples smooth the picture inside rotated and flipping tiles. Higher is slower. |
| Debug | Off | Shows **Front**, **Back** or **Matte** as they arrive, to check the wiring, or **Tile ID** or **Progress** in grey. |

## Tips

- **Grade tiles individually.** Set Matte to Tile ID and use it in a colour corrector or keyer downstream to pick out random tiles.
- **Check the wave before rendering.** Set Debug to Progress to see the transition as greys, black to white, without the image in the way.
- **Draw your own wipe.** With Wipe set to Matte, any animated matte works: a ramp, a paint stroke, a key. Soften it to widen the band of tiles in motion.
- **Hinge flips land on the next tile**, so they read best with Direction on Follow Wipe and a Softness of 0.3 or more.
- **Speed.** Flips are the slowest mode, and render time grows with Samples. Work at 1 and raise it for the final render.

## How it works

Every triangle tiling here is a square grid cut along a diagonal and then sheared: half a cell for equilateral and isosceles triangles, not at all for right triangles. Because tiles can grow, turn and fold over their neighbours, the shader checks the tiles near each pixel. For each one it undoes that tile's motion to see whether the tile now covers the pixel, then draws the two closest to camera, one over the other. The flips are true rotations about an edge or a centre line, with optional perspective, so a tile that finishes its turn lands exactly in place.

## Author

Sinan Vural

## License

Released under the [MIT License](https://github.com/SinanVural1/matchbox/blob/main/LICENSE). You're free to use, modify and share this shader, including on commercial work, as long as the copyright notice is kept.
