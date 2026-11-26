# sv_Promist

Notes and decisions for this shader. The shared framework is in the root `CLAUDE.md` and the matchbox skill; this file only records what is specific to this shader and why.

## Purpose

Emulates a Black Pro-Mist filter. Samples a golden-angle spiral of radius Blur with a Gaussian weight, then mixes the result in by Mix (a percentage). `SupportsAction="True"`.

## Status

- **Unfinished.** Lives in `wip/`, with a WORK IN PROGRESS line in its header. Move it to `shaders/` only once it passes the validator, the user has confirmed it in Flame, and it has a README, icon and ZIP.
- Written before this repo had its current rules. Only renamed, moved into its own folder, and given the licence header and the "Contact" line in its description; its code and UI have not been worked on since.
- In use by the user before then, but not re-checked in Flame after those changes (comments only, so no behaviour change is expected).
- No README, icon or ZIP yet. Not on logik-matchbook.org.

## Notes

- The XML description says "Highlight Bloom", but the code accumulates `max(threshold - luma, 0)`, which responds to shadows below the threshold rather than highlights. Black Pro-Mist does lift shadows, so this may be intended; confirm with the user before changing either.
- Samples is an int with a hard loop bound of 1000.

## Validator findings (6)

- `Tooltip` instead of `ToolTip`. See the note in `wip/sv_Directional_Blur/CLAUDE.md`.
