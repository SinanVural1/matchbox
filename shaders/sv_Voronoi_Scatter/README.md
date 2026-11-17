# Voronoi Scatter

A Matchbox shader for Autodesk Flame that breaks the frame into organic, polygonal Voronoi cells and fills each one with a patch of your source image, each with its own random rotation, scale and colour.

Use it for stained-glass and mosaic looks, broken-glass and crystal transitions, cellular textures, or as a matte generator: the node can output the cell edges, a gradient inside every cell, or both.

**[Download the shader (ZIP)](https://github.com/SinanVural1/matchbox/raw/main/shaders/sv_Voronoi_Scatter/sv_Voronoi_Scatter.zip)**

## Installation

1. Download and unzip the shader.
2. Keep `sv_Voronoi_Scatter.glsl` and `sv_Voronoi_Scatter.xml` together in the same folder. Flame loads them as a pair, and `sv_Voronoi_Scatter.glsl.p` gives it a preview icon in Flame's browser.
3. In Batch, add a Matchbox node and browse to that folder to load **Voronoi Scatter**.

Developed for Flame 2027.1.

## Inputs and outputs

| Socket | Use |
|---|---|
| Source | The image the cells are filled from. Required. |
| Result | The cell pattern, filled from the source. |
| Matte output | Your choice of the source's alpha, the cell edges, a gradient inside each cell, or edges and gradient together. Set with **Matte** on the Look page. |

## Workflow

1. **Connect a source.** Anything with interesting texture works: a plate, a gradient, a noise pattern.
2. **Choose the source patch.** Turn on **Show Source**, then drag the **Corner A** and **Corner B** axes in the viewer to frame the part of the source you want the cells filled from. A red outline shows the patch. Turn Show Source off again before rendering.
3. **Shape the cells** with **Density** (how many) and **Scatter** (how irregular). At Scatter 0 the cells are a regular square grid.
4. **Fill the cells.** Use **Fill Scale**, **Scale Variance** and **Max Rotation** to size and turn the patch inside each cell, and raise **Source Offset** so each cell shows a different part of the patch instead of the same image repeated.
5. **Add the look** on the Look page: edge lines, colour variation per cell, and the matte output.
6. **Pick a version you like** with **Variation**, and animate **Evolution** to make the cells move.

## Controls: Main page

### Source

| Control | Default | What it does |
|---|---|---|
| Corner A, Corner B | 0, 0 and 1, 1 | Opposite corners of the source patch, from 0 to 1 across the frame. Either corner can be on either side. |
| Show Source | Off | Outline the source patch in red. |

### Cells

| Control | Default | What it does |
|---|---|---|
| Density | 10 | Number of cells across the longer side of the frame. |
| Scatter | 0.5 | How far cell centres wander from a regular grid. 0 gives square cells. |
| Border Softness | 0 | Blends neighbouring cells across their shared border. The width is a fraction of cell size, and the blend stays an even width along each edge. |
| Variation | 0 | Reshuffles each cell's random rotation, scale, source offset and colour. The cells keep their shape. Whole numbers give unrelated results. |
| Evolution | 1 | Moves the cell centres. Animate it for organic motion. |

### Fill

| Control | Default | What it does |
|---|---|---|
| Fill Scale | 1 | Size of the patch inside each cell, relative to the cell. |
| Scale Variance | 0.2 | Random variation in patch size per cell. |
| Max Rotation | 0 | Maximum random rotation of the patch per cell, in degrees. |
| Source Offset | 0 | Shifts each cell to a random point in the patch, so cells stop showing the same image. 0 is off, 1 covers the whole patch. |
| Fill Mode | Mirror | How the patch repeats when it's smaller than its cell. Mirror joins the copies without hard seams; Repeat tiles them as they are. |

### Quality

| Control | Default | What it does |
|---|---|---|
| Samples | 1 | Samples per pixel (1, 4, 9 or 16) for smoother cell borders. Higher is slower. |

## Controls: Look page

### Edges

| Control | Default | What it does |
|---|---|---|
| Draw Edges | Off | Paint lines along the cell borders. The edge matte works whether this is on or off. |
| Edge Width | 0.05 | Full width of the lines, as a fraction of cell size, so they scale with Density. |
| Edge Softness | 0.01 | Falloff on both sides of the lines, as a fraction of cell size. |
| Edge Colour | Black | Colour of the lines. |

### Matte

| Control | Default | What it does |
|---|---|---|
| Matte | Source Alpha | What the matte output carries: **Source Alpha** (the source's own alpha), **Edges** (white lines on black), **Cell Gradient** (white at each cell's centre, falling to black at its border), or **Edges + Gradient** (the gradient with black lines). |
| Gradient Shape | Cell Shape | **Cell Shape** rings follow each cell's outline. **Circular** uses round rings from the centre, black outside the largest circle that fits the cell. |
| Falloff | 1 | Shapes the gradient. 1 is linear, above 1 tightens the bright centre, below 1 widens it. |

### Colour Variation

| Control | Default | What it does |
|---|---|---|
| Hue | 0 | Random hue shift per cell, up to this many degrees either way. |
| Saturation | 0 | Random saturation change per cell, up to this fraction either way. |
| Brightness | 0 | Random brightness change per cell, up to this fraction either way. |

## Tips

- **Use the matte to grade the cells.** Set Matte to Cell Gradient and feed the matte output into a colour corrector to darken cells toward their edges, or use Edges to grade only the lines.
- **Get edges without drawing them.** Leave Draw Edges off and set Matte to Edges to get the lines as a separate matte for compositing.
- **Avoid a repeated look.** If every cell looks the same, raise Source Offset and Max Rotation, or add some Colour Variation.
- **Speed.** Rendering time grows with Samples. Work at 1 and raise it for the final render.

## How it works

Each cell has a centre point, placed on a grid and moved away from it by Scatter and Evolution. Every pixel belongs to the nearest centre, which gives the Voronoi pattern. For each pixel, the shader also measures the exact distance to its cell's nearest border, which it uses for the edge lines, the soft borders and the cell gradient, so all three keep an even width all the way round each cell.

## Author

Sinan Vural

## License

Released under the [MIT License](https://github.com/SinanVural1/matchbox/blob/main/LICENSE). You're free to use, modify and share this shader, including on commercial work, as long as the copyright notice is kept.
