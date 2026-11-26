# sv_Directional_Blur

Notes and decisions for this shader. The shared framework is in the root `CLAUDE.md` and the matchbox skill; this file only records what is specific to this shader and why.

## Purpose

A directional (smear) blur along an angle, limited by a matte. Displays in Flame as "Directional Blur Advanced".

## Status

- **Unfinished.** Lives in `wip/`, with a WORK IN PROGRESS line in its header. Move it to `shaders/` only once it passes the validator, the user has confirmed it in Flame, and it has a README, icon and ZIP.
- Written before this repo had its current rules. Only renamed, moved into its own folder, and given the licence header and the "Contact" line in its description; its code and UI have not been worked on since.
- In use by the user before then, but not re-checked in Flame after those changes (comments only, so no behaviour change is expected).
- No README, icon or ZIP yet. Not on logik-matchbook.org.

## Notes

- Weights are normalised by the kernel's theoretical sum, not by the samples that landed, so the smear decays properly near frame edges (comment in the code).
- Samples is an int with a hard loop bound of 100.

## Validator findings (8)

- `Tooltip` instead of `ToolTip` on every control, and the Front sampler has no `InputType`.
- Flame loads files with `Tooltip` (Autodesk's own transition sample uses it), so these probably only hide tooltips rather than break loading. Fix them when the shader is next worked on, not as a separate pass.
