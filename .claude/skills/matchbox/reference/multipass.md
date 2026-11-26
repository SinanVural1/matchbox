# Multi-pass, mipmaps and render targets

Shaders with more than one pass, intermediate buffers, mip levels and multiple outputs.

## Multi-Pass Shaders

A single Matchbox shader can run multiple GLSL passes sequentially. Each pass is a separate `<Shader>` block in the XML with an incremented `Index`, and a corresponding numbered GLSL file.

### File naming for multi-pass

```
ShaderName.01.glsl   ← Pass 1
ShaderName.02.glsl   ← Pass 2
ShaderName.03.glsl   ← Pass 3
ShaderName.04.glsl   ← Pass 4 (final output)
ShaderName.xml       ← single XML defining all passes
```

A dot and a two-digit number. This is what shaders that load in Flame use: Autodesk's `TransitionShader.01.glsl` to `.03.glsl`, and `Ls_Airglow.01.glsl` to `.17.glsl`. An earlier version of this reference said `ShaderName_1.glsl`, which no working sample uses. A single-pass shader is just `ShaderName.glsl`.

### XML structure — multiple Shader blocks

```xml
<!-- Pass 1 — fixed output size, intermediate result -->
<Shader ClearColor="0, 0, 0, 0" GridSubdivision="1"
        OutputBitDepth="Float16" OutputWidth="500" OutputHeight="500" Index="1">
    <!-- uniforms for pass 1 -->
</Shader>

<!-- Pass 2 — receives pass 1 result -->
<Shader OutputBitDepth="Float16" Index="2">
    <Uniform ... Type="sampler2D" Name="adsk_results_pass1"></Uniform>
    <!-- other uniforms -->
</Shader>

<!-- Pass 3 — receives pass 2 result -->
<Shader OutputBitDepth="Float16" Index="3">
    <Uniform ... Type="sampler2D" Name="adsk_results_pass2"></Uniform>
</Shader>

<!-- Pass 4 — final output, receives front input + pass 3 result -->
<Shader ClearColor="0, 0, 0, 0" GridSubdivision="1"
        OutputBitDepth="Output" Index="4">
    <Uniform Index="0" NoInput="Error" InputType="Front" ... Name="front"></Uniform>
    <Uniform ... Type="sampler2D" Name="adsk_results_pass3"></Uniform>
</Shader>
```

**Pass chaining rules:**
- Pass N reads previous pass result as `adsk_results_passN-1` (no Index, no InputType)
- Only the final pass uses `OutputBitDepth="Output"` — intermediate passes use `Float16` or `Float32`
- A user input is declared, with its `Index` and `InputType`, in the pass that first reads it. A later pass that reads the same input repeats the declaration with a `<Duplicate>` child, without UI attributes. `Ls_Airglow` declares its Strength input (Index 2) in pass 2 and duplicates it in passes 3 to 17
- Pass dimensions can be fixed (`OutputWidth`/`OutputHeight`) or inherit from output resolution
- `ClearColor="0, 0, 0, 0"` clears the buffer before rendering that pass

### In GLSL — accessing pass results

```glsl
// Modern style — pass N reads result of pass N-1
layout(binding = 3) uniform sampler2D adsk_results_pass1;  // in pass 2
layout(binding = 3) uniform sampler2D adsk_results_pass2;  // in pass 3
layout(binding = 4) uniform sampler2D adsk_results_pass3;  // alongside front in pass 4

// Pass dimensions are available in AdskUniformBlock
layout(binding = 1) uniform AdskUniformBlock {
  float adsk_result_w, adsk_result_h;
  float adsk_results_pass1_w, adsk_results_pass1_h;  // fixed-size pass dimensions
};
```

### Parameter duplication across passes

A uniform defined in one pass can be reused in another pass using `<Duplicate>` — this avoids repeating the UI definition and keeps both passes in sync:

```xml
<!-- Pass 2 defines the parameter with UI -->
<Uniform ... Row="0" Col="0" Page="0" Type="float" Name="softness">
</Uniform>

<!-- Pass 3 reuses it silently — no UI shown, value shared -->
<Uniform Type="float" Name="softness">
    <Duplicate></Duplicate>
</Uniform>
```

---

## OutputBitDepth Options

| Value | Meaning |
|---|---|
| `"Output"` | Match Flame's current output bit depth (use on final pass) |
| `"Float16"` | 16-bit float — standard for intermediate passes |
| `"Float32"` | 32-bit float — use for Z-depth or high-precision intermediates |

Set intermediate passes to `Float16` unless precision demands `Float32`. Only the final pass should use `"Output"`.

---

## NbExecutions — Multi-Execution Passes

A single `<Shader>` block can execute multiple times, with each execution receiving the previous execution's result. Alternative to multiple `<Shader>` blocks for separable operations (e.g. horizontal then vertical blur in one file).

### XML

```xml
<Shader NbExecutions="2" OutputBitDepth="Output" Index="1">
    <Uniform Index="0" NoInput="Error" InputType="Front" ...
             Type="sampler2D" Name="frontTex"></Uniform>
    <Uniform ... Type="sampler2D" Name="adsk_results_pass1"></Uniform>
</Shader>
```

### GLSL

```glsl
layout(binding = 1) uniform AdskUniformBlock {
  float adsk_result_w, adsk_result_h;
  int adsk_result_execution;   // 0-based execution index
};

layout(binding = 3) uniform sampler2D frontTex;
layout(binding = 4) uniform sampler2D adsk_results_pass1;

void main() {
  bool firstExecution = adsk_result_execution == 0;
  vec2 inv = vec2(1.0) / vec2(adsk_result_w, adsk_result_h);

  // switch direction per execution
  vec2 uv_delta = firstExecution
    ? vec2(inv.x, 0.0)    // horizontal
    : vec2(0.0, inv.y);   // vertical

  // read from original input on first execution, previous result otherwise
  vec4 frag = firstExecution
    ? texture(frontTex, uv)
    : texture(adsk_results_pass1, uv);
}
```

---

## Mipmap Settings

```xml
<!-- Trilinear (smooth) -->
<Uniform Mipmaps="True"
         GL_TEXTURE_MAG_FILTER="GL_LINEAR"
         GL_TEXTURE_MIN_FILTER="GL_LINEAR_MIPMAP_LINEAR"
         Type="sampler2D" Name="front_smooth">
</Uniform>

<!-- Nearest (blocky) -->
<Uniform Mipmaps="True"
         GL_TEXTURE_MAG_FILTER="GL_LINEAR"
         GL_TEXTURE_MIN_FILTER="GL_NEAREST_MIPMAP_NEAREST"
         Type="sampler2D" Name="front_blocky">
</Uniform>
```

Standard (no mipmaps): `Mipmaps="False"` with `GL_TEXTURE_MIN_FILTER="GL_LINEAR"`.

Mipmaps work on user inputs (Autodesk's `Mipmaps` sample, `sv_Digital_Screen`'s Front) and on pass results (`Ls_Airglow` reads `adsk_results_pass1` with `Mipmaps="True"`).

### Reading a chosen mip level

- **Legacy GLSL** (no `#version`, which is what the sv_ shaders use): `textureLod` doesn't exist. Enable the extension on the first line of code, before anything that isn't a comment or preprocessor line, and use `texture2DLod`:

  ```glsl
  #extension GL_ARB_shader_texture_lod : enable
  vec4 c = texture2DLod(front, uv, lod);
  ```

  This is how `Ls_Airglow`, `crok_scribble` and `sv_Digital_Screen` do it.
- **Modern GLSL** (`#version 430`): `textureLod(sampler, uv, lod)`.

Level `n` is the image averaged over `2^n` pixels, so a region `w` pixels wide is level `log2(w)`. With `GL_LINEAR_MIPMAP_LINEAR`, half a level less is a good match, because linear filtering already reaches into the next texel.

Don't rely on the bias argument of `texture2D(s, uv, bias)` for a fixed blur: the base level comes from screen-space derivatives, which jump wherever the UV is piecewise constant (for example a per-cell lookup), and leave artefacts along cell borders.

---

## Multi-Render-Target Output

A single pass can write to multiple output textures simultaneously using `OutputNbResults`:

### XML

```xml
<Shader OutputNbResults="2" OutputNbLevels="10"
        OutputBitDepth="Output" Index="1">
    <!-- adsk_results_pass1   → first output of pass 1  -->
    <!-- adsk_results_pass1_1 → second output of pass 1 -->
    <Uniform ... Type="sampler2D" Name="adsk_results_pass1"></Uniform>
    <Uniform ... Type="sampler2D" Name="adsk_results_pass1_1"></Uniform>
</Shader>
```

`OutputNbResults="2"` creates two output targets. `OutputNbLevels="10"` defines custom mipmap levels for those targets. Subsequent passes access the multiple outputs as `adsk_results_passN` and `adsk_results_passN_1`, `adsk_results_passN_2`, etc.

### GLSL — writing to multiple targets

```glsl
// Instead of single output:
layout(location = 0) out vec4 fragData[2];

void main() {
  fragData[0] = vec4(minValue);   // first render target
  fragData[1] = vec4(maxValue);   // second render target
}
```

### Custom mipmap levels in GLSL

The current mip level is injected by Flame:

```glsl
layout(binding = 1) uniform AdskUniformBlock {
  float adsk_result_w, adsk_result_h;
  int adsk_result_level_pass1;   // current mip level being rendered (0 = full res)
};

// Use textureLod() to sample a specific mip level
float v = textureLod(adsk_results_pass1, uv, float(prev_level)).r;
```

---

## Texture Grid

Flame can pack multiple textures into a single grid texture for efficient multi-image lookups. This is distinct from regular texture inputs.

### XML — declare the grid texture (no Index, no InputType)

```xml
<Uniform
    InputColor="67, 77, 83"
    Mipmaps="False"
    GL_TEXTURE_WRAP_T="GL_CLAMP_TO_EDGE"
    GL_TEXTURE_WRAP_S="GL_CLAMP_TO_EDGE"
    GL_TEXTURE_MAG_FILTER="GL_LINEAR"
    GL_TEXTURE_MIN_FILTER="GL_LINEAR"
    Type="sampler2D"
    Name="adsk_texture_grid">
</Uniform>
```

### GLSL — fetching a tile from the grid

```glsl
layout(binding = 3) uniform sampler2D adsk_texture_grid;

// Tile index layout (example 3x3):
// 6 - 7 - 8
// 3 - 4 - 5
// 0 - 1 - 2  (0 = bottom-left)

vec2 getTilePosition(vec2 gridSize, vec2 tileSize, int tileNum) {
    ivec2 nbTiles = ivec2(gridSize) / ivec2(tileSize);
    vec2 tile = vec2(mod(float(tileNum), float(nbTiles.x)),
                    float(tileNum / nbTiles.x));
    return tile * tileSize;
}

vec4 fetchInTile(vec2 gridSize, vec2 tileSize,
                 vec2 tilePosition, vec2 positionInTile) {
    // prevent sampling across tile borders
    if (any(greaterThan(positionInTile, tileSize - vec2(1.5))) ||
        any(greaterThan(vec2(0.5), positionInTile)))
        return vec4(0.0);
    vec2 positionInGrid = (tilePosition + positionInTile) / gridSize;
    return texture(adsk_texture_grid, positionInGrid);
}
```

The pass 1 fixed output size (`OutputWidth`/`OutputHeight`) defines the tile size. Pass dimensions are accessible as `adsk_results_pass1_w` / `adsk_results_pass1_h` in the `AdskUniformBlock`.
