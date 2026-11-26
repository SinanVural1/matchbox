---
name: matchbox
description: Framework for writing and editing Autodesk Flame Matchbox shaders (a .glsl fragment shader plus its .xml UI file). Use before creating, changing, debugging or reviewing any Matchbox .glsl or .xml, making a preview icon, or testing a shader. Covers the XML rules that make shaders fail silently, Flame's legacy GLSL dialect, UI layout, multi-pass and mipmaps, and the validator, WebGL test harness and icon scripts.
---

# Matchbox shaders for Flame

A Matchbox shader is a GLSL fragment shader (`name.glsl`) and a UI file (`name.xml`) that Flame loads as a pair. Before changing a shader in this repo, also read its `shaders/<name>/CLAUDE.md`.

Don't guess at the schema. Each rule below was learned from a shader that failed silently, and every miss costs the user a Flame reload. When in doubt, copy the scaffolding of a shader here that loads cleanly (`sv_Digital_Screen`, `sv_Triangle_Mosaic`, `sv_Voronoi_Scatter`, `sv_Depth_Temporal_Stabilizer`).

## XML rules that bite

- **Inputs are `<Uniform>` elements, not `<Texture>`.** Declared with `Type="sampler2D"` and `InputType="Front"` (or `Back`, `Matte`), plus `Index` and `NoInput`. Indices start at 0 and run in order.
- **`<Uniform>` needs an explicit closing tag.** Self-closing `/>` is not valid here.
- **Every `<Uniform>` needs `Page`, `Row` and `Col`.** Omitting `Page` renders an empty tab with no controls and no error message.
- **The attribute is `ToolTip`**, not `Tooltip`.
- **Bool defaults are `Default="True"` / `"False"`**, not `1` / `0`.
- **Root `<ShaderNodePreset>` needs its full attribute set**, including `Name` (the display name) and `ShaderType="Matchbox"`.
- Keep roughly 5–6 rows per column. Declare every column used, inside a `<Page>` block.
- Sampler and uniform `Name` attributes must match the GLSL declarations character for character.
- **A `vec2` axis takes two rows.** Put axes on rows 0 and 2, never adjacent rows.
- **`MatteProvider="True"` sends `gl_FragColor.a` to the node's matte output.** There is one matte output; use a popup when a shader can make several mattes.

## GLSL dialect

The sv_ shaders use legacy GLSL (no `#version`). Don't mix legacy and modern styles in one file.

- Only `adsk_result_w` / `adsk_result_h` are reliable for dimensions. `adsk_input1_w/h` is not part of the API.
- **Reserved words as variable names fail to compile with no line number** (Flame reports only `CProcessShader::RenderFrame::CreateRenderGraph`): `out`, `in`, `half`, `sample`, `filter`, `layout`, `double`, `fixed`, `input`, `output`, `patch`, `active`, `common`.
- **Integer maths:** no integer `clamp`, and Flame has had trouble with bitwise ops (see `ak_vibrance`). Ordinary int comparisons and loop counters are fine. If a shader fails to compile with everything else correct, convert an int uniform to float and compare with `> 0.5`.
- **Loop bounds must be compile-time constants.** Loop to a constant maximum and `break` on the real count.
- **Reading a chosen mip level** needs `#extension GL_ARB_shader_texture_lod : enable` as the first code line and `texture2DLod`. `textureLod` only exists in modern GLSL.
- Work in 32-bit float. Depth and other data passes must not be run through a colour transform.

## Debugging a shader that produces nothing

`CreateRenderGraph` means the node failed to build; it never says why. Work in this order:

1. **Compile error:** check reserved words and syntax first.
2. **XML structure:** strip `main()` to a bare passthrough, keeping the full uniform block. If that renders, the fault is in the body; if not, it's the XML.
3. **Unbound sampler:** a texture read returning garbage while pure-geometry output still draws means the input declaration is wrong.

Build a `Debug` popup into non-trivial shaders, with a raw input passthrough as one of the modes. It separates "texture not arriving" from "maths wrong" in one step. Leave it out only when the user asks; `sv_Depth_Temporal_Stabilizer` replaced its debug modes with a markers checkbox at the user's request.

## UI conventions in this repo

- Sizes in pixels use `ResDependent="Width"`. Fractions of a cell or tile are used for widths and softness inside patterns, so they scale with density.
- Points are `vec2` axes with an **Action Coords** checkbox for pasted Action tracker data (pixels from the image centre). With it on, Flame draws the icon off screen, so the shader draws its own marker.
- Random patterns get **Variation** (a new random set; must not move what the user sees as the layout) and **Evolution** (smooth animation).
- Supersampling is a **Samples** popup of 1, 4, 9 or 16 on a fixed grid.
- Overlays (guides, markers, reference views) are off by default, and their tooltips say to turn them off before rendering.
- A mode selector that changes which controls matter gets its own column.

## Pitfalls

- **Multi-pass files are `name.01.glsl`, `name.02.glsl`...**, a dot and two digits, as in Autodesk's and Ls_ samples. Not `name_1.glsl`.
- **`<Duplicate>`** in a later pass shares a uniform's value; give it no Row, Col or Page.
- **Intermediate passes** use `Float16` or `Float32`; only the final pass uses `OutputBitDepth="Output"`.
- **`UIConditionType="Hide"`** hides a control when `UIConditionSource` equals `UIConditionValue`.
- **Axis values are 0-1.** Multiply by the resolution before using them as pixels.
- **Two controls on the same Row/Col/Page overlap silently.**
- **Curve widgets span two columns, and a ColourWheel takes a whole column;** their Row is ignored.
- **Action compatibility** needs `adsk_rgb2hsv`, `adsk_hsv2rgb` and `adsk_getBlendedValue` instead of custom implementations.
- **Shadertoy ports:** `iResolution` becomes `vec2(adsk_result_w, adsk_result_h)`; `iTime` becomes `adsk_time` or an animatable uniform. Check the original's licence (Shadertoy defaults to CC BY-NC-SA 3.0).
- **Half-pixel offset** `(gl_FragCoord.xy - 0.5) / res` helps general `GL_LINEAR` resampling but moves exact reads off pixel centres; don't use it for depth or data.
- **`NbExecutions` vs passes:** `NbExecutions` for separable operations on the same data, separate `<Shader>` blocks for different sizes or inputs.
- **Unused socket placeholder:** if Matte must be at `Index="2"` for Timeline or Action wiring, put an unused input at `Index="1"` with `InputColor="86,86,86"` and `NoInput="Black"`.

## Reference files

Read the one the task needs:

| File | Covers |
|---|---|
| `reference/xml-schema.md` | Root element, inputs, every control type (sliders, popups, curves, colour, axes), layout, conditional UI, `ResDependent`, socket colours, `MatteProvider`, depth inputs |
| `reference/glsl-dialect.md` | File structure, legacy vs modern style, the full `adsk_` API, dialect rules learned here, anti-aliasing and the shared building blocks |
| `reference/multipass.md` | Passes and naming, `Duplicate`, bit depths, `NbExecutions`, mipmaps and reading mip levels, multiple render targets, texture grids |
| `reference/advanced.md` | Temporal accumulation, previous and next frames, transitions, Action lights, UI-only shaders |
| `reference/testing.md` | The validator, the WebGL harness, what to measure, and what only Flame can confirm |
| `reference/icons.md` | The `.glsl.p` preview icon format and how to render one |

## Scripts

| Script | Use |
|---|---|
| `scripts/validate_matchbox.py` | Static checks. `shaders/<name>/<name>`, a bare `sv_Name`, or `--all shaders`. |
| `scripts/webgl_harness.py` | Builds a WebGL page that compiles a shader and renders configurations. |
| `scripts/serve.py` | Local server for the harness, accepting `PUT /upload.bin` for pixel readback. |
| `scripts/write_p.py` | Writes a `.glsl.p` icon from a PNG or from harness readback. |

## Reference shaders by other authors

These live in the local, gitignored `samples/` folder (`samples/24.1_samples/` and `samples/MatchboxShaderCollection/shaders/`), not in the public repo. Consult them before implementing a UI pattern you haven't used here:

| File | Reference for |
|---|---|
| `ak_colorcompress.glsl/.xml` | Action-compatible GLSL, colour picker, curve widget (legacy style) |
| `ak_slice.xml` | 2D positioner icon pattern |
| `ak_vibrance.glsl` | Selective + matte blend pattern, Flame blend modes, bitwise workaround |
| `Blending.xml/.glsl` | Full blend mode popup with all Value integers, modern GLSL style |
| `Curves.xml/.glsl` | Curve widget: single, RGB triple, all CurveBackground/Shape options |
| `ColourWheel.xml` | ColourWheel, ColourWheelRGBOffset/Slope/Power widgets |
| `Accumulate.xml/.glsl` | Temporal accumulation, `adsk_accum_texture` |
| `BuildList.xml` | Minimal popup menu |
| `CubeMapSampler.xml` | `samplerCube`, vec3 Position widget |
| `DecodeZDepthHQ.glsl` | Z-depth decoding, `adsk_mergeHalvesInFloat` |
| `Mipmaps.xml/.glsl` | Mipmaps on a Front input |
| `TransitionShader.xml` | Timeline transition, multi-pass naming |
| `Ls_Airglow.xml` | 17 passes, mip levels with `texture2DLod`, `Duplicate` inputs |
