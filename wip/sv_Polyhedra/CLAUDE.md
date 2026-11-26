# sv_Polyhedra

Notes and decisions for this shader. The shared framework is in the root `CLAUDE.md` and the matchbox skill; this file only records what is specific to this shader and why.

## Purpose

Renders regular polyhedra (type 3 to 5, Wythoff construction with barycentric controls), with per-feature colours, alphas and blend modes for faces, edges and vertices.

## Status

- **Unfinished.** Lives in `wip/`, with a WORK IN PROGRESS line in its header. Move it to `shaders/` only once it passes the validator, the user has confirmed it in Flame, and it has a README, icon and ZIP.
- Written before this repo had its current rules. Only renamed, moved into its own folder, and given the licence header and the "Contact" line in its description; its code and UI have not been worked on since.
- In use by the user before then, but not re-checked in Flame after those changes (comments only, so no behaviour change is expected).
- No README, icon or ZIP yet. Not on logik-matchbook.org.

## Licence: not MIT

- Based on a Shadertoy shader by FabriceNeyret2. Shadertoy work defaults to CC BY-NC-SA 3.0 unless its author says otherwise, which forbids commercial use and requires derived work to keep the same licence.
- So this shader is excluded from the repo's MIT licence (stated in `LICENSE`), its header says it follows the original's terms, and its XML has no `CommercialUsePermitted`. Keep it that way unless the original's page grants something else.
- Don't upload it to logik-matchbook.org without checking the original's terms.

## Notes

- The root `<ShaderNodePreset>` lacks most of the attribute set (`ShaderType`, `SoftwareVersion`, `MatteProvider`...) that the root rules call for.
- The blend modes are per feature: `Blend_Mode_Face_1`..`3`, `Blend_Mode_Edge`, `Blend_Mode_Vertex`, declared on two lines as `uniform int a, b, c;`.

## Validator findings

- It reports the five `Blend_Mode_*` uniforms as "declared in XML but absent from GLSL". That is a validator limitation: it doesn't parse several names on one `uniform` line. The shader is fine on this point.
- `Tooltip` instead of `ToolTip` throughout. See the note in `wip/sv_Directional_Blur/CLAUDE.md`.
