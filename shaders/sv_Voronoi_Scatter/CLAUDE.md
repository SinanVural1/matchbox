# sv_Voronoi_Scatter

Notes and decisions for this shader. The shared framework is in the root `CLAUDE.md` and the matchbox skill; this file only records what is specific to this shader and why.

## Purpose

Splits the frame into Voronoi cells and fills each with a patch of the source, each with its own random rotation, scale, offset and colour. Can also act as a matte generator: edges, a gradient inside each cell, or both.

## Status

- Fixes and all four Look-page features confirmed working in Flame by the user.
- Published: README, `.glsl.p` icon (sunset stained glass, rendered from a numpy port of the shader), ZIP. The icon has not been checked in Flame's browser.
- Not on logik-matchbook.org.

## Structure

- `cellSeed(id, cellSize)` hashes the grid ID only, so only Scatter and Evolution (channel name `Seed`) move cell centres.
- Everything a cell shows hashes `cellKey = id + varOffset`, `varOffset = vec2(variation * 127.1, variation * 311.7)`.
- Pass 1: nearest centre over a 5x5 search. A centre can sit half a cell outside its grid square at full Scatter, so 3x3 is not enough; a brute-force check matched on every pixel at 5x5.
- Pass 2: exact distance to the nearest border, `(dj^2 - d1^2) / (2 * gap)` over the neighbours, plus the neighbour across that edge (`seedE`, `idE`) and `minHalfGap` for the circular gradient.
- `getSample` returns colour with alpha already set to the chosen matte. Supersampling is a fixed n x n grid (1, 4, 9, 16), not random offsets, which left grain.

## Decisions

- **Variation never moves cells.** The user tested that changing Variation must keep cell shapes fixed and only reshuffle contents. An early version hashed the centres with Variation too; fixed.
- **Scale Variance defaults to 0.2**, so Variation visibly resizes patches at default settings. This was explained to the user and left as is; changing the default to 0 was offered, not requested.
- **Fill Mode Mirror** is the default because mirrored repeats join without hard seams when the patch is smaller than its cell.
- **Border Softness, Edge Width and Edge Softness are fractions of cell size**, measured from the true border distance, so bands keep an even width along each edge and scale with Density.
- **Cell gradient** is `edge / (edge + d1)`: 0 on every border, about 1 at the centre, rings following the cell outline. Circular uses `1 - d1 / minHalfGap`.
- **Hue variation** rotates about the grey axis, which keeps the channel mean, instead of an HSV round trip.
- **Channel names are kept from the original** (for example `Seed`) so animation curves in old setups still connect.
- **One matte output, chosen with the Matte popup**: Source Alpha (default, same as before the matte existed), Edges, Cell Gradient, Edges + Gradient.

## Open items

- Speed: two 5x5 passes per sample, so 16 samples is slow on big frames. Not reported as a problem.
- Ideas offered but not built: other distance metrics (diamond, box cells), per-cell mirroring, a matte input to limit the effect, a grid transform.
