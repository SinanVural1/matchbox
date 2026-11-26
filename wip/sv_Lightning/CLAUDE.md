# sv_Lightning

Notes and decisions for this shader. The shared framework is in the root `CLAUDE.md` and the matchbox skill; this file only records what is specific to this shader and why.

## Purpose

Procedural lightning between a Start Point and an End Point (axes), with width, glow, wiggle, detail and branches. A curve widget on its own page shapes the width along the bolt.

## Status

- **Unfinished.** Lives in `wip/`, with a WORK IN PROGRESS line in its header. Move it to `shaders/` only once it passes the validator, the user has confirmed it in Flame, and it has a README, icon and ZIP.
- Written before this repo had its current rules. Only renamed, moved into its own folder, and given the licence header and the "Contact" line in its description; its code and UI have not been worked on since.
- In use by the user before then, but not re-checked in Flame after those changes (comments only, so no behaviour change is expected).
- No README, icon or ZIP yet. Not on logik-matchbook.org.

## Notes

- Animation comes from `adsk_time` times the Speed control, so it moves on its own over frames.
- It is the only shader here with a Curve widget (Width Profile, on the Profile page). Curve widgets span two columns; see the skill's XML reference.

## Validator findings (10)

- Eight self-closing `<Uniform ... />` elements. The root rules say a `<Uniform>` needs an explicit closing tag; check this one first if the shader ever fails to load.
- `Tooltip` instead of `ToolTip`. See the note in `wip/sv_Directional_Blur/CLAUDE.md`.
