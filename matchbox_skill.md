# Matchbox Shader Skill — Autodesk Flame
> Context document for Claude Code. Load at the start of every Matchbox shader session.

---

## 1. What is a Matchbox Shader

A Matchbox shader is a GLSL fragment shader that runs inside Autodesk Flame. Every shader consists of exactly two files:

- `ShaderName.glsl` — the GLSL fragment shader logic
- `ShaderName.xml` — the UI definition (parameters, inputs, layout)

Both files must share the same base name. Flame loads them as a pair.

---

## 2. GLSL File Structure

### Mandatory uniforms (always declare these first)

```glsl
uniform float adsk_result_w;   // output width in pixels
uniform float adsk_result_h;   // output height in pixels
```

### Standard texture inputs

```glsl
uniform sampler2D front;       // primary image input (required)
uniform sampler2D back;        // secondary image input (optional)
uniform sampler2D matte;       // matte input — defaults to white if unconnected
uniform sampler2D selective;   // selective input — defaults to white if unconnected
```

### UV coordinate pattern (use in every main())

```glsl
void main(void)
{
  vec2 res = vec2(adsk_result_w, adsk_result_h);
  vec2 uv  = gl_FragCoord.xy / res.xy;
  // uv is now normalised 0.0–1.0 across the image
}
```

### Output

```glsl
gl_FragColor = vec4(result.rgb, alpha);
```

### Matte / selective blend pattern

Matte controls *where* the effect applies. Selective further limits it. The canonical blend at the end of main():

```glsl
float matte = texture2D(matte, uv).r;
float sel   = texture2D(selective, uv).r;

gl_FragColor = mix(in1, vec4(result.rgb, 1.0), matte * sel);
```

Matte drives the effect area but does NOT clip the output — the unaffected areas show the original `front` input.

### Autodesk built-in functions (declare before use)

```glsl
// Curve evaluation
float adskEvalDynCurves(int curve, float x);          // single curve
vec3  adskEvalDynCurves(ivec3 curve, vec3 x);         // RGB triple curve

// Colour space conversion
vec3 adsk_rgb2hsv(vec3 rgb);
vec3 adsk_hsv2rgb(vec3 hsv);

// Luminance
float adsk_getLuminance(vec3 rgb);

// Blend modes
vec4 adsk_getBlendedValue(int BlendType, vec4 srcColor, vec4 dstColor);

// Z-depth decoding
float adsk_mergeHalvesInFloat(vec3 h);
```

These are provided by Flame's runtime. Declare the signature only — do not implement them.

### Two GLSL styles — legacy vs modern

Flame supports two distinct GLSL coding styles. **Do not mix them in the same file.**

**Legacy style** (used in community shaders, ak_ series):
```glsl
// No version directive
uniform float adsk_result_w, adsk_result_h;
uniform sampler2D front;
// ...
void main(void) {
  vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
  gl_FragColor = vec4(result, 1.0);
}
```

**Modern style** (used in Autodesk sample shaders — Blending, Curves, Accumulate, DecodeZDepthHQ):
```glsl
#version 430
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform AdskUniformBlock {
  float adsk_result_w, adsk_result_h;
};
layout(binding = 3) uniform sampler2D front;
layout(binding = 2) uniform UniformBlock {
  float myParam;
};

void main() {
  vec2 coords = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
  fragColor = vec4(result, 1.0);
}
```

**Recommendation:** Use legacy style for new shaders unless there is a specific reason to use modern. The community ecosystem and reference shaders are predominantly legacy style and it is simpler to maintain.

### Action environment compatibility

For shaders that need to run in Flame's Action node (3D compositing environment), the GLSL must use the built-in functions above rather than custom implementations of colour space or blending logic. Reference `ak_colorcompress.glsl` as the canonical Action-compatible template.

---

## 3. XML File Structure

### Root element — ShaderNodePreset

```xml
<?xml version="1.0" encoding="utf-8"?>
<ShaderNodePreset
    SupportsAdaptiveDegradation="False"
    SupportsAction="True"
    SupportsTransition="False"
    SupportsTimeline="True"
    TimelineUseBack="False"
    MatteProvider="False"
    DefaultIsNoOp="True"
    CommercialUsePermitted="True"
    ShaderType="Matchbox"
    SoftwareVersion="2018.3.0"
    LimitInputsToTexture="True"
    Version="1"
    Description="Short description of what the shader does"
    Name="Display Name in Flame">
```

Set `SupportsAction="True"` if the shader should work inside Action nodes.

### Shader element

```xml
<Shader GridSubdivision="1" OutputBitDepth="Output" Index="1">
  <!-- all Uniform elements go here -->
</Shader>
```

---

## 4. Uniform Types and XML Patterns

### Texture input — Front (required)

```xml
<Uniform
    Index="0"
    NoInput="Error"
    InputType="Front"
    DisplayName="Source"
    Mipmaps="False"
    GL_TEXTURE_WRAP_T="GL_REPEAT"
    GL_TEXTURE_WRAP_S="GL_REPEAT"
    GL_TEXTURE_MAG_FILTER="GL_NEAREST"
    GL_TEXTURE_MIN_FILTER="GL_NEAREST"
    Type="sampler2D"
    Name="front">
</Uniform>
```

`NoInput="Error"` makes the input mandatory. Use `NoInput="White"` or `NoInput="Black"` for optional inputs.

### Texture input — Matte (optional)

```xml
<Uniform
    Index="2"
    NoInput="White"
    InputType="Matte"
    DisplayName="Matte"
    Mipmaps="False"
    GL_TEXTURE_WRAP_T="GL_REPEAT"
    GL_TEXTURE_WRAP_S="GL_REPEAT"
    GL_TEXTURE_MAG_FILTER="GL_LINEAR"
    GL_TEXTURE_MIN_FILTER="GL_LINEAR"
    Type="sampler2D"
    Name="matte">
</Uniform>
```

### Texture input — Selective (optional)

```xml
<Uniform
    Index="1"
    NoInput="White"
    InputType="Selective"
    DisplayName="Selective"
    Mipmaps="False"
    GL_TEXTURE_WRAP_T="GL_REPEAT"
    GL_TEXTURE_WRAP_S="GL_REPEAT"
    GL_TEXTURE_MAG_FILTER="GL_LINEAR"
    GL_TEXTURE_MIN_FILTER="GL_LINEAR"
    Type="sampler2D"
    Name="selective">
</Uniform>
```

Texture inputs must use sequential Index values starting at 0. Front is always Index="0".

### Float slider

```xml
<Uniform
    ResDependent="None"
    Max="100.0"
    Min="0.0"
    Default="50.0"
    Inc="1.0"
    ToolTip="Brief description"
    Row="0"
    Col="0"
    Page="0"
    DisplayName="Parameter Name"
    Type="float"
    Name="param_name">
</Uniform>
```

### Boolean toggle

```xml
<Uniform
    Page="0"
    Row="1"
    Col="0"
    DisplayName="Enable Feature"
    Type="bool"
    Name="enable_feature"
    Default="True">
</Uniform>
```

### Popup menu (int with ValueType="Popup")

Use for blend mode selectors or any discrete choice list:

```xml
<Uniform
    Default="0"
    ValueType="Popup"
    ToolTip="Choose blend mode"
    Row="0"
    Col="0"
    Page="0"
    Type="int"
    DisplayName="Blend Mode"
    Name="blend_mode">
    <PopupEntry Title="Add"        Value="0"></PopupEntry>
    <PopupEntry Title="Subtract"   Value="1"></PopupEntry>
    <PopupEntry Title="Multiply"   Value="2"></PopupEntry>
    <PopupEntry Title="Screen"     Value="17"></PopupEntry>
    <PopupEntry Title="Overlay"    Value="18"></PopupEntry>
    <PopupEntry Title="Difference" Value="19"></PopupEntry>
</Uniform>
```

The `Value` in each PopupEntry is the integer passed to `adsk_getBlendedValue()`. Full blend mode value table:

| Name | Value | Name | Value |
|---|---|---|---|
| Add | 0 | Subtract | 1 |
| Multiply | 2 | Soft Light | 13 |
| Hard Light | 14 | Pin Light | 15 |
| Screen | 17 | Overlay | 18 |
| Difference | 19 | Exclusion | 20 |
| Max/Lighten | 29 | Min/Darken | 30 |
| Lighter Color | 33 | Linear Light | 37 |
| Linear Burn | 10 | Spotlight | 11 |
| Ps Linear Light | 32 | No Blending | -1 |

### Curve widget (int / ivec2 / ivec3 / ivec4)

A curve widget automatically spans 2 columns — the `Row` value and column name are ignored for placement.

**Single luma curve (int):**
```xml
<Uniform
    Max="1000000"
    Min="-1000000"
    Default="0"
    Inc="1"
    Row="0"
    Col="0"
    Page="0"
    Type="int"
    DisplayName="Luma Curve"
    Name="lumaCurve"
    CurveBackground="2"
    ValueType="Curve">
</Uniform>
```

**RGB curves (ivec3) — three curves in one widget:**
```xml
<Uniform
    Inc="1"
    Row="0"
    Col="0"
    Page="0"
    Type="ivec3"
    DisplayName="RGB Curves"
    Name="colorCurves"
    CurveBackground="1"
    ValueType="Curve"
    CurveWrapArround="1"
    CurveMinY="-1"
    CurveMaxY="1"
    CurveShape="6">
    <SubUniform Max="1000000" Min="-1000000" Default="0"
        CurveName="Red"   CurveR="255" CurveG="0"   CurveB="0">
    </SubUniform>
    <SubUniform Max="1000000" Min="-1000000" Default="0"
        CurveName="Green" CurveR="0"   CurveG="255" CurveB="0">
    </SubUniform>
    <SubUniform Max="1000000" Min="-1000000" Default="0"
        CurveName="Blue"  CurveR="0"   CurveG="0"   CurveB="255">
    </SubUniform>
</Uniform>
```

**Curve widget attributes:**

| Attribute | Values | Notes |
|---|---|---|
| `CurveBackground` | 0=grey, 1=hue gradient, 2=luma gradient | Visual background of the curve editor |
| `CurveWrapArround` | 0=independent ends, 1=connected ends | 1 mimics Batch Colour Curves node |
| `CurveShape` | 0=linear low→high, 1=linear high→low, 2=S, 3=inverse S, 4=constant max, 5=constant min, 6=constant mid | Default curve shape on init |
| `CurveMinX/MaxX` | float | X axis range (default 0.0–1.0) |
| `CurveMinY/MaxY` | float | Y axis range (default 0.0–1.0) |

**In GLSL — evaluating curves:**
```glsl
// Forward declarations (required)
vec3  adskEvalDynCurves(ivec3 curve, vec3 x);   // for ivec3 RGB curves
float adskEvalDynCurves(int curve, float x);     // for single int curve

// Usage — evaluate all 3 RGB curves at once
vec3 gain = adskEvalDynCurves(colorCurves.rgb, vec3(hue));
source = source * (gain + 1.0);

// Usage — evaluate single luma curve
float newLum = adskEvalDynCurves(lumaCurve, lum);
```

### Colour picker (vec3)

```xml
<Uniform
    Type="vec3"
    ValueType="Colour"
    Action3DWidget="False"
    IconType="None"
    DisplayName="Color"
    ChannelName="color_ref"
    Inc="0.01"
    Row="0"
    Col="0"
    Page="0"
    Name="color_param">
    <SubUniform ResDependent="None" Min="-1000.0" Max="1000.0" Default="1.0"></SubUniform>
    <SubUniform ResDependent="None" Min="-1000.0" Max="1000.0" Default="1.0"></SubUniform>
    <SubUniform ResDependent="None" Min="-1000.0" Max="1000.0" Default="1.0"></SubUniform>
</Uniform>
```

### Colour Wheel widget (vec3)

Takes up a full column. Passes HSV-style values: angle (hue), intensity1, intensity2.

```xml
<Uniform
    Inc="0.1"
    Row="0"
    Col="0"
    Page="0"
    IconType="None"
    ValueType="ColourWheel"
    Type="vec3"
    DisplayName="Colour Wheel"
    Name="colourWheel"
    HueShift="False"
    AngleName="Hue"
    IntensityName1="Gain"
    IntensityName2="Mix">
    <SubUniform ResDependent="None" Max="1000.0"  Min="-1000.0" Default="0.0"></SubUniform>
    <SubUniform ResDependent="None" Max="1000.0"  Min="-1000.0" Default="0.0"></SubUniform>
    <SubUniform ResDependent="None" Max="100.0"   Min="0.0"     Default="100.0"></SubUniform>
</Uniform>
```

**Variants:** `ValueType="ColourWheelRGBOffset"` (default 0.0), `ValueType="ColourWheelRGBSlope"` (default 1.0), `ValueType="ColourWheelRGBPower"` (default 1.0) — these pass direct RGB values rather than HSV.

### 3D Position widget (vec3)

```xml
<Uniform
    Inc="1.0"
    Row="0"
    Col="0"
    Page="0"
    Action3DWidget="False"
    IconType="None"
    ValueType="Position"
    Type="vec3"
    DisplayName="Rotation XYZ"
    Name="rotation">
    <SubUniform ResDependent="None" Max="180.0" Min="-180.0" Default="0.0"></SubUniform>
    <SubUniform ResDependent="None" Max="180.0" Min="-180.0" Default="0.0"></SubUniform>
    <SubUniform ResDependent="None" Max="180.0" Min="-180.0" Default="0.0"></SubUniform>
</Uniform>
```

Used to place a draggable icon directly on the viewer. Coordinates are in normalised 0.0–1.0 space on the image canvas.

```xml
<Uniform
    Inc="0.001"
    Page="0"
    Row="0"
    Col="0"
    DisplayName="Control Point"
    Type="vec2"
    IconType="Axis"
    IconDefaultState="True"
    Name="control_point">
    <SubUniform ResDependent="None" Max="100000.0" Min="-100000.0" Default="0.5"></SubUniform>
    <SubUniform ResDependent="None" Max="100000.0" Min="-100000.0" Default="0.5"></SubUniform>
</Uniform>
```

**Important coordinate note:** The icon position is passed in 0.0–1.0 normalised space. To convert to pixel coordinates in GLSL: `vec2 pixel_pos = control_point * vec2(adsk_result_w, adsk_result_h);`

---

## 5. UI Layout System

Parameters are placed on a grid using `Row`, `Col`, and `Page` attributes.

- `Page` — zero-indexed tab pages. Use multiple pages for complex shaders.
- `Row` — vertical position within a column, zero-indexed
- `Col` — column within a page, zero-indexed

Column and page labels are defined at the bottom of the XML:

```xml
<Page Name="Main" Page="0">
    <Col Name="Controls" Col="0" Page="0"></Col>
    <Col Name="Advanced" Col="1" Page="0"></Col>
</Page>
<Page Name="Colors" Page="1">
    <Col Name="Face" Col="0" Page="1"></Col>
</Page>
```

**Layout rules:**
- Two parameters must not share the same Row/Col/Page combination — this causes UI overlap
- vec2 positioners occupy two rows (the X and Y sub-values each take a row)
- Curve widgets are wide — place them in their own column
- Maximum practical rows per column is around 5–6 before the UI becomes crowded

---

## 6. Known Working Shader Patterns

### Selectives — matte drives effect origin, not clipping

The matte input controls where an effect *starts from* but the result bleeds outside the matte boundary. This is intentional Flame behaviour. To implement:

```glsl
// In GLSL — sample matte as a driver, not a hard clip
float matte_val = texture2D(matte, uv).r;
float effect_strength = param_strength * matte_val;
// apply effect using effect_strength, then output full result
gl_FragColor = vec4(result, 1.0);
```

### Anti-aliasing with SDFs

Hard `true/false` geometry tests create jagged edges. Use signed distance fields + smoothstep instead:

```glsl
float dist = /* signed distance to edge */;
float aa   = smoothstep(0.0, 1.0 / adsk_result_w, dist);
```

### Blend modes via adsk_getBlendedValue

```glsl
// Declare at top of file
vec4 adsk_getBlendedValue(int BlendType, vec4 srcColor, vec4 dstColor);

// Use in main()
int blend_type = 0; // 0 = Add
vec4 blended = adsk_getBlendedValue(blend_type, src, dst);
```

### Temporal accumulation (frame blending over time)

Flame provides a special built-in for accumulating results across frames:

```xml
<!-- In XML — declare the accumulation texture (no Index, no InputType) -->
<Uniform
    Mipmaps="False"
    GL_TEXTURE_WRAP_T="GL_CLAMP_TO_EDGE"
    GL_TEXTURE_WRAP_S="GL_CLAMP_TO_EDGE"
    GL_TEXTURE_MAG_FILTER="GL_LINEAR"
    GL_TEXTURE_MIN_FILTER="GL_LINEAR"
    Type="sampler2D"
    Name="adsk_accum_texture">
</Uniform>
```

```glsl
// In GLSL (modern style) — adsk_accum_no_prev_frame is injected by Flame
layout(binding = 1) uniform AdskUniformBlock {
  float adsk_result_w, adsk_result_h;
  bool adsk_accum_no_prev_frame;  // true on first frame
};
layout(binding = X) uniform sampler2D adsk_accum_texture;

void main() {
  vec4 current  = texture(input1, coords);
  vec4 previous = adsk_accum_no_prev_frame ? current
                  : texture(adsk_accum_texture, coords);
  fragColor = mix(previous, current, weight);
}
```

Also set `SupportsAdaptiveDegradation="True"` in the XML root for temporal shaders.



```glsl
float lwidth = max(1.0 / adsk_result_w, 1.0 / adsk_result_h);
```

---

## 7. Sinan's Shader Library

Current shaders, each in its own folder under `~/GitHub/matchbox/shaders/` (for example `shaders/sv_Hypot/sv_Hypot.glsl`):

| File | Description |
|---|---|
| `sv_Hexagon_Mosaic` | Honeycomb tessellation mosaic with AA, rotation, luma scaling |
| `sv_Triangle_Mosaic` | Triangle tessellation mosaic with AA, rotation, luma scaling |
| `sv_Polyhedra` | 3D regular polyhedra renderer with camera, colour, blend mode controls |
| `sv_Voronoi_Scatter` | Voronoi-distributed texture patch scattering with icon positioners |
| `sv_Directional_Blur` | Directional blur with falloff, sample count, matte-driven selective |
| `sv_Hypot` | Two-input hypot blend mode with strength control |
| `sv_Promist` | Pro-Mist analog filter emulation — blooms/darkens the blacks |
| `sv_Lightning` | Animated lightning bolt with branch controls and curve-driven pointiness |
| `sv_Depth_Temporal_Stabilizer` | Two-point temporal stabilizer for ML depth maps, with Near/Far and Range output modes |

---

## 8. Reference Files

These files in the repo are canonical references — consult before implementing UI patterns:

| File | Reference for |
|---|---|
| `ak_colorcompress.glsl/.xml` | Action-compatible GLSL, colour picker, curve widget (legacy style) |
| `ak_slice.xml` | 2D positioner icon pattern |
| `ak_vibrance.glsl` | Selective + matte blend pattern, Flame blend modes |
| `Blending.xml/.glsl` | Full blend mode popup with all Value integers, modern GLSL style |
| `Curves.xml/.glsl` | Curve widget — single, RGB triple, all CurveBackground/Shape options |
| `ColourWheel.xml` | ColourWheel, ColourWheelRGBOffset/Slope/Power widgets |
| `Accumulate.xml/.glsl` | Temporal accumulation pattern, adsk_accum_texture |
| `BuildList.xml` | Minimal popup menu example |
| `CubeMapSampler.xml` | samplerCube texture type, vec3 Position widget |
| `DecodeZDepthHQ.glsl` | Z-depth decoding, adsk_mergeHalvesInFloat |

---

## 10. Multi-Pass Shaders

A single Matchbox shader can run multiple GLSL passes sequentially. Each pass is a separate `<Shader>` block in the XML with an incremented `Index`, and a corresponding numbered GLSL file.

### File naming for multi-pass

```
ShaderName_1.glsl   ← Pass 1
ShaderName_2.glsl   ← Pass 2
ShaderName_3.glsl   ← Pass 3
ShaderName_4.glsl   ← Pass 4 (final output)
ShaderName.xml      ← single XML defining all passes
```

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
- Only the final pass (or the first) uses `Index="0"` with `InputType="Front"` for user-connected inputs
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

## 11. Texture Grid

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

---

## 12. Conditional UI

Parameters can be shown or hidden based on the value of another parameter:

```xml
<!-- Controller parameter -->
<Uniform Row="1" Col="1" Page="0" Default="True"
         Type="bool" DisplayName="Proportional" Name="propBlur">
</Uniform>

<!-- Hidden when propBlur is True -->
<Uniform ... Type="vec2" DisplayName="Amount" Name="blurAmount"
         UIConditionSource="propBlur"
         UIConditionValue="True"
         UIConditionType="Hide">
</Uniform>

<!-- Hidden when propBlur is False -->
<Uniform ... Type="float" DisplayName="Amount" Name="propBlurAmount"
         UIConditionSource="propBlur"
         UIConditionValue="False"
         UIConditionType="Hide">
</Uniform>
```

`UIConditionSource` = name of the controlling uniform. `UIConditionValue` = the value at which the condition fires. `UIConditionType="Hide"` hides the parameter when the condition is met. This enables mutually exclusive parameter groups.

---

## 13. ResDependent — Resolution-Relative Parameters

Float and vec2 uniforms can scale their values relative to the output resolution:

```xml
<!-- Scales relative to output width -->
<Uniform ResDependent="Width" Max="10000.0" Min="0.0" Default="0.0"
         Type="float" Name="blurRadius">
</Uniform>

<!-- vec2 with independent axis scaling -->
<Uniform Type="vec2" Name="blurAmount">
    <SubUniform ResDependent="Width"  Max="10000.0" Min="0.0" Default="0.0"></SubUniform>
    <SubUniform ResDependent="Height" Max="10000.0" Min="0.0" Default="0.0"></SubUniform>
</Uniform>
```

Values: `"None"` (absolute), `"Width"` (relative to output width), `"Height"` (relative to output height). Use `ResDependent="Width"` for blur radii and other pixel-count parameters so they behave consistently across resolutions.

---

## 14. OutputBitDepth Options

| Value | Meaning |
|---|---|
| `"Output"` | Match Flame's current output bit depth (use on final pass) |
| `"Float16"` | 16-bit float — standard for intermediate passes |
| `"Float32"` | 32-bit float — use for Z-depth or high-precision intermediates |

Set intermediate passes to `Float16` unless precision demands `Float32`. Only the final pass should use `"Output"`.

---

## 9. Known Pitfalls

- **Multi-pass file naming:** Files must be named `ShaderName_1.glsl`, `ShaderName_2.glsl` etc. — underscore and number suffix, not dot. Flame uses this convention to associate passes with the XML.
- **Parameter duplication:** A `<Duplicate>` uniform in a later pass shares its value with the same-named uniform defined earlier. Do not add UI attributes (Row, Col, Page) to duplicated uniforms — they have no UI.
- **Intermediate pass bit depth:** Never set intermediate passes to `OutputBitDepth="Output"` — only the final pass should use this. Use `Float16` for intermediates.
- **Conditional UI:** `UIConditionType="Hide"` hides the parameter when the condition is met, not when it isn't. The logic is: hide this parameter when `UIConditionSource` equals `UIConditionValue`.
- **Coordinate space mismatch:** Icon positioners return 0.0–1.0 normalised values, not pixel coordinates. Always multiply by resolution before using in pixel-space calculations.
- **UI overlap:** Two uniforms at the same Row/Col/Page will silently overlap in the UI. Always check layout before adding parameters.
- **Action compatibility:** Standard GLSL from Shadertoy will not run in Action without adaptation. Use `adsk_rgb2hsv`, `adsk_hsv2rgb`, and `adsk_getBlendedValue` instead of custom implementations.
- **Curve widget placement:** Curve widgets automatically span 2 columns — Row and column name are ignored. Plan column layout accordingly.
- **ColourWheel placement:** Takes up a full column — Row value is disregarded.
- **Do not mix GLSL styles:** Legacy (no `#version`) and modern (`#version 430` with `layout` bindings) must not be mixed in the same file. Default to legacy for new shaders.
- **Boolean GLSL:** Flame's GLSL dialect may have restrictions on bitwise operations. See `ak_vibrance.glsl` for the `modi_func`/`and_func` workaround.
- **Shadertoy ports:** Replace `iResolution` → `vec2(adsk_result_w, adsk_result_h)`. Remove `iTime` or replace with an animatable `uniform float`.
- **Half-pixel offset for filtering:** When using GL_LINEAR filtered sampling: `vec2 coords = (gl_FragCoord.xy - 0.5) / vec2(adsk_result_w, adsk_result_h);`
- **NbExecutions vs multi-pass:** Use `NbExecutions` for separable operations on the same data (horizontal/vertical blur). Use multiple `<Shader>` blocks for operations that need different input sizes or independent user inputs.
- **Unused socket placeholder:** If Matte must be at Index="2" for correct Timeline/Action wiring, insert an unused placeholder at Index="1" with `InputColor="86,86,86"` and `NoInput="Black"`.

---

## 15. Complete Matchbox API Reference

All functions must be forward-declared before use. Declare the signature only — never implement them.

```glsl
//--- Colour Management ---
float adskEvalDynCurves(int curve, float x);
vec2  adskEvalDynCurves(ivec2 curve, vec2 x);
vec3  adskEvalDynCurves(ivec3 curve, vec3 x);
vec4  adskEvalDynCurves(ivec4 curve, vec4 x);

// Scene linear ↔ Cineon log
vec3 adsk_scene2log(vec3 lin);
vec3 adsk_log2scene(vec3 log);

// RGB ↔ HSV
vec3 adsk_rgb2hsv(vec3 rgb);
vec3 adsk_hsv2rgb(vec3 hsv);

// RGB ↔ YUV
vec3 adsk_rgb2yuv(vec3 rgb);
vec3 adsk_yuv2rgb(vec3 yuv);

// Luminance
vec3  adsk_getLuminanceWeights();
float adsk_getLuminance(vec3 color);

// Shadows / Highlights / Midtones blending weights
// pixel = luminance value, halfPoint = 50% crossover point
// Midtones = 1.0 - adsk_shadows(...) - adsk_highlights(...)
float adsk_highlights(float pixel, float halfPoint);
float adsk_shadows(float pixel, float halfPoint);

//--- Blending ---
vec4 adsk_getBlendedValue(int blendType, vec4 srcColor, vec4 dstColor);

//--- Camera (for lighting passes) ---
vec3 adsk_getCameraSpacePosition(vec2 frag_uv, float linear_depth);

//--- Z-depth ---
float adsk_mergeHalvesInFloat(vec3 h);
```

---

## 16. NbExecutions — Multi-Execution Passes

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

## 17. Input Socket Colouring

Texture inputs have a coloured socket on the Matchbox node.

| InputType | Socket colour |
|---|---|
| `"Front"` | Red |
| `"Back"` | Green |
| `"Matte"` | Blue |
| _(not set)_ | Light grey |

```xml
<!-- Named type -->
<Uniform Index="0" InputType="Front" ... Type="sampler2D" Name="front"></Uniform>

<!-- Custom RGB (0–255) — used when InputType absent -->
<Uniform Index="3" InputColor="0,0,0" ... Type="sampler2D" Name="depth"></Uniform>
```

`InputType` always overrides `InputColor`. To create a gap (placeholder socket):

```xml
<Uniform Index="1" NoInput="Black" DisplayName="Not Used"
         InputColor="86,86,86" ... Type="sampler2D" Name="unused"></Uniform>
```

---

## 18. MatteProvider

```xml
<ShaderNodePreset ... MatteProvider="True" ...>
```

Tells Flame this shader's output can be used as a matte source by downstream nodes. Use for shaders whose primary purpose is generating a mask rather than a colour result.

---

## 19. Mipmap Settings

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

Standard (no mipmaps): `Mipmaps="False"` with `GL_TEXTURE_MIN_FILTER="GL_LINEAR"`. Use `textureLod(sampler, uv, lod)` in GLSL to manually select a mip level.

---

## 20. Action Lights API

For shaders inside Action that need scene lighting. All functions forward-declared only.

```glsl
bool adsk_getLightHasAmbient();
void adsk_getLightAmbient(out vec3 colour);

int  adsk_getLightNbPoints();
void adsk_getLightPoint(int i, out vec3 colour, out vec3 position);

int  adsk_getLightNbSpots();
void adsk_getLightSpot(int i, out vec3 colour, out vec3 position,
                       out vec3 dir, out float spreadCosinus);

int  adsk_getLightNbDirectionals();
void adsk_getLightDirectional(int i, out vec3 colour, out vec3 position, out vec3 dir);

int  adsk_getLightNbRectAreas();
void adsk_getLightRectArea(int i, out vec3 colour, out vec3 position,
                           out vec3 xaxis, out vec3 yaxis);

int  adsk_getLightNbEllipsoidAreas();
void adsk_getLightEllipsoidArea(int i, out vec3 colour, out vec3 position,
                                out vec3 xaxis, out vec2 yaxis);

vec3 adsk_getCameraSpacePosition(vec2 frag_uv, float linear_depth);
```

vec3 adsk_getCameraSpacePosition(vec2 frag_uv, float linear_depth);
```

Light colours are pre-multiplied by intensity. All positions are camera space. Requires albedo, depth, and normal textures as inputs. See `LightsAPI.glsl` as the reference implementation.

---

## 21. Transition Shaders

Transition shaders blend between two clips in the Timeline. They require a specific XML root configuration:

```xml
<ShaderNodePreset
    SupportsTransition="True"
    TimelineUseBack="True"
    SupportsTimeline="False"
    ...>
```

### Inputs — always Outgoing + Incoming + their mattes

```xml
<Uniform Index="0" NoInput="Black" InputType="Front" ...
         Name="front1" DisplayName="Outgoing"></Uniform>
<Uniform Index="1" NoInput="Black" InputType="Front" ...
         Name="front2" DisplayName="Incoming"></Uniform>
<Uniform Index="2" NoInput="White" InputType="Matte" ...
         Name="matte1" DisplayName="Outgoing Matte"></Uniform>
<Uniform Index="3" NoInput="White" InputType="Matte" ...
         Name="matte2" DisplayName="Incoming Matte"></Uniform>
```

### Texture wrap for transitions

Use `GL_TEXTURE_WRAP_T="GL_MIRRORED_REPEAT"` and `GL_TEXTURE_WRAP_S="GL_MIRRORED_REPEAT"` on transition inputs — this avoids hard edges when the effect bleeds beyond the frame boundary.

### Transition mix parameter

The convention is a `float transp` (0.0–1.0) that drives the dissolve:

```glsl
// Pass 1 — dissolve outgoing into incoming
fragColor = mix(front2Color, front1Color, transp);
// transp=1.0 → full outgoing, transp=0.0 → full incoming
```

---

## 22. Temporal Sampling — Previous and Next Frames

Flame can provide the previous and next frame of any input texture automatically:

### XML — declare alongside the regular input (no Index)

```xml
<Uniform Type="sampler2D" Name="adsk_next_frame_input1"></Uniform>
<Uniform Type="sampler2D" Name="adsk_previous_frame_input1"></Uniform>
<Uniform Index="0" NoInput="Error" InputType="Front" ...
         Type="sampler2D" Name="input1"></Uniform>
```

The naming convention is `adsk_next_frame_<inputName>` and `adsk_previous_frame_<inputName>` where `<inputName>` matches the regular input's `Name` attribute.

### GLSL

```glsl
layout(binding = 2) uniform sampler2D adsk_previous_frame_input1;
layout(binding = 3) uniform sampler2D adsk_next_frame_input1;
layout(binding = 4) uniform sampler2D input1;

void main() {
  vec2 coords = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
  vec3 prev = texture(adsk_previous_frame_input1, coords).rgb;
  vec3 next = texture(adsk_next_frame_input1, coords).rgb;
  vec3 curr = texture(input1, coords).rgb;
  fragColor = vec4((prev + next + curr) / 3.0, 1.0);
}
```

---

## 23. Multi-Render-Target Output

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

## 24. UIOnly Shader — No-Op GLSL

When a shader is used purely to expose UI parameters for expressions (no image processing), the GLSL is a minimal no-op:

```glsl
#version 430
layout(location = 0) out vec4 fragColor;

// For UI-only shaders, nothing else is needed in the .glsl file
void main(void) {
  fragColor.rgba = vec4(0.0);
}
```

The XML carries all the parameter definitions. This pattern is useful for expression variable containers in Flame batch setups.

---

## 25. UIConditionInvert

The conditional UI system has an invert flag seen in production shaders:

```xml
<Uniform ... Name="blurAmount"
    UIConditionSource="propBlur"
    UIConditionValue="False"
    UIConditionInvert="False"
    UIConditionType="Hide">
</Uniform>
```

`UIConditionInvert="True"` reverses the hide logic. When `False` (default), the parameter hides when the condition matches. When `True`, it hides when the condition does not match. In practice, most shaders achieve the same result using `UIConditionInvert="False"` with opposite `UIConditionValue` values for each pair of mutually exclusive parameters.

---

## 26. Depth Input Type

Z-depth passes use a special `InputType="Depth"`:

```xml
<Uniform Index="0" InputType="Depth" NoInput="Error"
         DisplayName="Z-Depth" InputColor="67, 77, 83"
         GL_TEXTURE_MAG_FILTER="GL_LINEAR"
         GL_TEXTURE_MIN_FILTER="GL_LINEAR"
         Type="sampler2D" Name="depthTex">
</Uniform>
```

Use `GL_NEAREST` filtering (not `GL_LINEAR`) for Z-depth textures when precision is critical — linear interpolation of depth values produces incorrect results at depth discontinuities.
