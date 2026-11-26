# XML schema reference

The `.xml` half of a Matchbox shader: the root element, inputs, every control type, layout, and conditional UI. The rules that make a shader fail silently are in `SKILL.md`; this file is the full reference.

## What a Matchbox shader is

A Matchbox shader is a GLSL fragment shader that runs inside Autodesk Flame. Every shader consists of exactly two files:

- `ShaderName.glsl` — the GLSL fragment shader logic
- `ShaderName.xml` — the UI definition (parameters, inputs, layout)

Both files must share the same base name. Flame loads them as a pair.

---

## XML File Structure

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

## Uniform Types and XML Patterns

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

### 2D positioner — axis icon (vec2)

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

**Action Coords pattern (used in every sv_ shader with axes):** a bool `action_coords` lets the user paste Action tracker data, which is in pixels from the image centre:

```glsl
vec2 p = action_coords ? control_point + 0.5 * res : control_point * res;
```

With it on, Flame still draws the axis icon from the raw channel values as if they were 0-1, so the icon lands off screen. The shader cannot move the icon; draw its own marker (a ring) to show where the point really is.

---

## UI Layout System

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
- vec2 positioners occupy two rows (the X and Y sub-values each take a row). Confirmed in Flame: two axes on adjacent rows looked wrong, rows 0 and 2 looked right.
- Curve widgets are wide — place them in their own column
- Maximum practical rows per column is around 5–6 before the UI becomes crowded
- Six columns on one page fits (the widest sample shaders, such as `nob_trigrade`, use six)
- Give a mode selector its own column rather than squeezing it between other controls

---

## Conditional UI

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

## UIConditionInvert

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

## ResDependent — Resolution-Relative Parameters

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

`sv_Triangle_Mosaic` and `sv_Digital_Screen` use `ResDependent="Width"` for sizes in pixels. That they rescale correctly when the resolution changes has not been checked in Flame yet.

---

## Input Socket Colouring

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

## MatteProvider

```xml
<ShaderNodePreset ... MatteProvider="True" ...>
```

Gives the node a matte output and sends `gl_FragColor.a` to it, while RGB stays on the main output. Confirmed in Flame by `sv_Depth_Temporal_Stabilizer` (matte = inverted depth) and `sv_Voronoi_Scatter` (matte chosen with a popup).

- Alpha no longer carries the source's alpha unless you write it there. When adding a matte output to an existing shader, offer a "Source Alpha" choice so the old behaviour stays available.
- A node has one matte output. If a shader can produce several mattes, add a popup to choose which one it carries.

---

## Depth Input Type

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

Exception: when the shader reads depth at tracked, sub-pixel positions, `GL_NEAREST` makes the reading jump at pixel boundaries and adds flicker. `sv_Depth_Temporal_Stabilizer` uses `GL_LINEAR` for that reason; with matching input and output resolutions it still reads exact values at pixel centres.
