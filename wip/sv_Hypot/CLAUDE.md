# sv_Hypot

Notes and decisions for this shader. The shared framework is in the root `CLAUDE.md` and the matchbox skill; this file only records what is specific to this shader and why.

## Purpose

A blend mode: `sqrt(Front^2 + Back^2)` per channel, with Strength as a mix back to Back. `SupportsAction="True"`, so it can be used inside Action.

## Status

- **Unfinished.** Lives in `wip/`, with a WORK IN PROGRESS line in its header. Move it to `shaders/` only once it passes the validator, the user has confirmed it in Flame, and it has a README, icon and ZIP.
- Written before this repo had its current rules. Only renamed, moved into its own folder, and given the licence header and the "Contact" line in its description; its code and UI have not been worked on since.
- In use by the user before then, but not re-checked in Flame after those changes (comments only, so no behaviour change is expected).
- No README, icon or ZIP yet. Not on logik-matchbook.org.

## Notes

- Alpha is also combined with the hypot formula. The code comments show this was a guess rather than a decision; confirm with the user before relying on it.

## Validator findings (4)

- `Tooltip` instead of `ToolTip`, and the Back sampler has no `InputType`. See the note in `wip/sv_Directional_Blur/CLAUDE.md`.
