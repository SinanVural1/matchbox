# GLSL dialect reference

The `.glsl` half: file structure, the two GLSL styles, Flame's built-in functions, and patterns known to work. The dialect rules that cause silent compile failures are summarised in `SKILL.md`.

## Legacy dialect rules learned in this repo

The sv_ shaders are legacy style (no `#version`). Flame's legacy compiler is stricter than a desktop GLSL 1.20 compiler in places:

- **No integer `clamp`, and avoid integer `%` and bitwise operators.** Do integer-like maths in float: `clamp(floor(sqrt(float(samples)) + 0.5), 1.0, 4.0)`, `mod(x, 2.0)`.
- **Loop bounds must be compile-time constants.** Loop to a constant maximum and `break` on the real count:

  ```glsl
  for (int i = 0; i < 4; i++) {
      if (float(i) >= n) break;
      ...
  }
  ```
- **Reserved words as names fail with no line number** (`out`, `in`, `half`, `sample`, `filter`, `layout`, `input`, `output`, `patch`, `active`, `common`, ...). `layout` is the one most likely to come up as a control name; `sv_Digital_Screen` uses `screen_layout`.
- **Structs, `out` parameters and global non-const variables assigned in `main()` all work**, and are used by `sv_Triangle_Mosaic` and `sv_Digital_Screen`.
- **Samplers as function parameters:** avoided so far. Branch on a float selector inside a helper instead.
- **`#extension` lines go first**, before any declaration (comments are fine above them).

## GLSL File Structure

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

## Complete Matchbox API Reference

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

## Known Working Shader Patterns

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

In pixel units, the pattern the sv_ shaders use is a linear ramp one pixel wide, centred on the edge, divided by the sample count when supersampling:

```glsl
float sd  = /* signed distance in image pixels, negative inside */;
float cov = clamp(0.5 - sd / aaWidth, 0.0, 1.0);   // aaWidth = 1.0 / n
```

Two shapes that share an edge each get 0.5 there, so they sum to one with no seam. Over a whole convex shape this ramp adds `pi * w^2 / 12` to its area, which matters when the shape is only a pixel or two wide (see `sv_Digital_Screen`'s compensation).

### Building blocks used across the sv_ shaders

- **Hashes:** `hash12` and `hash22` (Dave Hoskins' sine-free hashes), as in `sv_Voronoi_Scatter`.
- **Variation and Evolution:** Variation offsets the hash key (`id + vec2(variation * 127.1, variation * 311.7)`) to pick a new random set; Evolution animates randoms smoothly by putting them on sine waves (`sin(evolution + 2 * PI * hash)`). Keep anything that defines layout (cell centres) out of Variation if the user expects it to stay put.
- **Supersampling:** a fixed n x n grid of sub-pixel offsets from a popup of 1, 4, 9 or 16, never random offsets, which leave grain.
- **Hue shift:** rotate about the grey axis (`c * cos a + cross(k, c) * sin a + k * dot(k, c) * (1 - cos a)`, `k = vec3(0.57735)`), which keeps the channel mean, instead of an HSV round trip.
- **Half-pixel offset:** `(gl_FragCoord.xy - 0.5) / res` helps general `GL_LINEAR` resampling, but don't use it when the shader must read exact values at pixel centres (depth, data passes).

### Blend modes via adsk_getBlendedValue

```glsl
// Declare at top of file
vec4 adsk_getBlendedValue(int BlendType, vec4 srcColor, vec4 dstColor);

// Use in main()
int blend_type = 0; // 0 = Add
vec4 blended = adsk_getBlendedValue(blend_type, src, dst);
```
