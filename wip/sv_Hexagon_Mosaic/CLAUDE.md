# sv_Hexagon_Mosaic

Notes and decisions for this shader. The shared framework is in the root `CLAUDE.md` and the matchbox skill; this file only records what is specific to this shader and why.

## Purpose

A hexagonal mosaic: each hexagon takes the source colour at its centre, with size, rotation, offset, a luminance-driven size and a border.

## Status

- **Unfinished.** Lives in `wip/`, with a WORK IN PROGRESS line in its header. Move it to `shaders/` only once it passes the validator, the user has confirmed it in Flame, and it has a README, icon and ZIP.
- Written before this repo had its current rules. Only renamed, moved into its own folder, and given the licence header and the "Contact" line in its description; its code and UI have not been worked on since.
- In use by the user before then, but not re-checked in Flame after those changes (comments only, so no behaviour change is expected).
- No README, icon or ZIP yet. Not on logik-matchbook.org.

## Notes

- It is the sibling of the old Triangle Mosaic, with the same controls (Size in pixels, Offset X/Y, Luma Scale, Border Thickness). When the user asked to rework the mosaics they said to start with Triangle Mosaic, which was rebuilt from scratch with an engine meant to be reusable here (per-tile transforms, two-highest-tile compositing, transitions, edges, bevel, matte output). Whether and when to rebuild this one is still the user's call.
- Expect the same problems the old Triangle Mosaic had: size in pixels without resolution dependence, a single centre sample per tile (flicker on moving footage), and a Luma Scale that may jump as it leaves 0. Check before reusing any of it.

## Validator findings (8)

- `Tooltip` instead of `ToolTip`, and the Front sampler has no `InputType`. See the note in `wip/sv_Directional_Blur/CLAUDE.md` on how serious this is.
