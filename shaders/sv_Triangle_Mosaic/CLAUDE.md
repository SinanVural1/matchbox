# sv_Triangle_Mosaic

Notes and decisions for this shader. The shared framework is in the root `CLAUDE.md` and the matchbox skill; this file only records what is specific to this shader and why.

## Purpose

A triangle mosaic that can also transition from Front to Back tile by tile, driven by a matte or a built-in wipe. Tiles shrink, fade, spin, or flip over on a hinge or in place.

## Status

- Rebuilt from scratch at the user's request (old setups were explicitly not a concern). The rebuild was confirmed working in Flame.
- **Not yet confirmed in Flame:** the Flat-mode fix below (added with the README), the `.glsl.p` icon, and use as a Timeline transition.
- Published: README, icon, ZIP. Not on logik-matchbook.org.

## Structure

- **One lattice for every shape.** A square grid cut along a diagonal, then sheared: half a cell for Equilateral and Isosceles (Stretch changes the height), none for Right. Diagonal (Same, Alternating, Random, Four-Way) applies to Right only, because only the short diagonal of the sheared cell gives equilateral and isosceles triangles.
- **Tiles can leave their cell.** Per-tile size, rotation, offset and the flips move tiles over their neighbours, so each sample walks up to 7x7 cells, early-outs on a conservative reach, undoes each tile's motion, and keeps the two highest tiles by priority (transition progress plus a tiny hash tie-break).
- **Corner specks.** Six triangles meet at a vertex, so the top two alone left the background showing through. A running total of coverage from all tiles sets how much background shows; the top two only set the colour.
- **Flips** use an oblique axis so a 180-degree turn lands on a whole triangle: Hinge lands on the neighbour across the edge (the parallelogram completion), Card lands on itself with two corners swapped. Perspective is per tile, with a camera a few tile sizes above and at least twice the tile's height away, so the enlargement is capped at 2x and stays within the search reach.
- **The reverse face shows Back from where the point lands**, so a finished flip is exactly Back in place.

## Decisions

- **Progress 0 and 1 must be clean.** Progress 0 equals the untouched mosaic and Progress 1 equals Back exactly. Edges, bevel and colour variation fade by `1 - t`. Verified to 0/255 for Hinge, Card, Shrink and Fade under Linear, Radial and Random wipes, in both fills.
- **Flat fill resolves into Back as tiles land** (`smoothstep(0.5, 1.0, t)` on the reverse face). Without it a Flat transition ended on a flat-colour mosaic of Back. Found while making the icon; the earlier end-frame test had only used Image fill.
- **Flat fill averages seven points** over each triangle, because a single centre read flickers on moving footage.
- **Size is in pixels with `ResDependent="Width"`**, a compromise: pixels are easier to picture, and the resolution dependence should keep the pattern when the resolution changes. The user wasn't sure which they wanted; this needs confirming in Flame.
- **Wipe modes:** Matte uses the matte value directly as progress; Matte Wipe sweeps Progress through the matte, white first. Follow Wipe tips tiles the way the wave travels, against the matte gradient for the matte modes.
- **Luma Scale is continuous through 0.** The old version jumped as soon as it left 0.

## Open items

- The XML sets `SupportsTransition="True"` and `TimelineUseBack="True"` with Front, Back and Matte inputs. Autodesk's transition sample uses four inputs (Outgoing, Incoming and their mattes), so Timeline use may need a different input layout. In Batch it works as a normal node.
- Shrink defaults to 1, so it combines with Flip unless set to 0. Documented in the README, not changed.
- Hinge flips on Right triangles don't land exactly on the neighbour, because those neighbours are not mirror images.
- Flips are the slowest mode; speed at 4K was never measured.
