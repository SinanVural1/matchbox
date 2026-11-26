# Matchbox shader development — Autodesk Flame

GLSL/XML Matchbox shaders for Flame. Target: Flame 2027.1 on Rocky Linux.

## Where the instructions live

- **This file:** the project, its conventions and its workflow. Loaded in every session.
- **The `matchbox` skill** (`.claude/skills/matchbox/`): the Matchbox framework, meaning the XML rules, the GLSL dialect, debugging, UI patterns, the API reference, and the scripts for validating, testing and icons. **Load it before writing or editing any `.glsl` or `.xml`.** Its reference files are authoritative; read the one a task needs rather than working from memory.
- **`shaders/<name>/CLAUDE.md`:** that shader's purpose, decisions and their reasons, what the user has confirmed in Flame, what they have rejected, and open items. Loaded when working in that folder. Read it before changing the shader, and update it in the same change whenever a decision is made or reversed.
- **`CLAUDE.local.md`** (gitignored): personal details and the publishing checklist.
- `matchbox_skill.md` at the root is a stub kept so old links work. Don't add to it.

## Repo layout

```
shaders/sv_Name/            one folder per finished shader
  sv_Name.glsl, sv_Name.xml   the shader pair
  sv_Name.glsl.p              preview icon for Flame's browser
  README.md                   the GitHub page
  sv_Name.zip                 download: glsl, xml, .p, README, LICENSE
  CLAUDE.md                   notes and decisions
.claude/skills/matchbox/    the framework skill, its references and scripts
wip/sv_Name/                unfinished shaders, same layout without README, icon or ZIP
LICENSE                     MIT, with sv_Polyhedra excluded
samples/                    other authors' shaders, local only (gitignored)
```

## Shader library

| Shader | What it does | State |
|---|---|---|
| `sv_Depth_Temporal_Stabilizer` | Two-point temporal stabilizer for ML depth maps, with Near/Far and Range outputs | Published, on Logik |
| `sv_Voronoi_Scatter` | Voronoi cells filled with source patches; edges, cell gradient matte, colour variation | Published |
| `sv_Triangle_Mosaic` | Triangle mosaic with per-tile transforms and a matte or wipe driven Front-to-Back transition | Published |
| `sv_Digital_Screen` | RGB subpixel display look, nine layouts, reference matching | Published |
| `sv_Hexagon_Mosaic` | Honeycomb mosaic with rotation and luma scaling | WIP |
| `sv_Polyhedra` | 3D regular polyhedra renderer (Shadertoy-derived, not MIT) | WIP |
| `sv_Directional_Blur` | Directional blur with falloff, limited by a matte | WIP |
| `sv_Hypot` | Two-input hypot blend with strength | WIP |
| `sv_Promist` | Pro-Mist filter emulation | WIP |
| `sv_Lightning` | Animated lightning bolt with branches and a width curve | WIP |

"Published" means the shader is in `shaders/` with its README, icon and ZIP on GitHub. "WIP" means it is in `wip/`: written before the current rules, still failing the validator on old patterns, and marked unfinished in its header and in `wip/README.md`. Fix those when the shader is next worked on. When one is finished, `git mv` it to `shaders/`, change the link in its header, remove the WORK IN PROGRESS line and its entry in `wip/README.md`, and follow the publishing checklist.

## Conventions

- **Names:** folders and files are `sv_Camel_Case_Name`. The XML `Name` (what Flame shows) has no prefix, for example `Name="Digital Screen"`.
- **Header:** every `.glsl` starts with the shader name, `Copyright (c) 2026 Sinan Vural. MIT License.` and its GitHub folder link. `sv_Polyhedra` instead states it follows the terms of its Shadertoy original.
- **Description:** the XML `Description` ends with the contact line from `CLAUDE.local.md`.
- Shader and XML share a basename: `name.glsl` + `name.xml`.
- Metric units for any physical quantity. Pixel sizes use `ResDependent="Width"` so they follow the resolution.
- No emojis in code comments or UI strings.
- Comment the *why* — the maths, or the Flame-specific constraint — not the syntax.
- Keep channel names stable across changes where possible, so animation in existing setups still connects. When the user says old setups don't matter, rebuilding from scratch is fine.

## Workflow

1. Load the `matchbox` skill and read the shader's `CLAUDE.md`.
2. Make the change.
3. Validate: `python3 .claude/skills/matchbox/scripts/validate_matchbox.py shaders/<name>/<name>`, or `--all shaders` for every finished shader (`--all wip` for the unfinished ones).
4. Compile and check it in the WebGL harness (see the skill's `reference/testing.md`). That proves the GLSL compiles under a stricter dialect and lets the maths be measured, but only Flame can confirm the shader loads and renders.
5. Tell the user what to check in Flame, and wait for them to confirm it before calling it done.
6. Record decisions in the shader's `CLAUDE.md`.
7. Commit or push only when the user asks.

## Never commit

- `CLAUDE.local.md`, `.claude/launch.json`, `.DS_Store` files, `samples/`, `.vscode/`.
- Personal details beyond what the user has already made public in the repo.
