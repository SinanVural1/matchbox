# Advanced features

Temporal accumulation, previous and next frames, transitions, Action lights and UI-only shaders.

## Temporal accumulation (frame blending over time)

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

---

## Temporal Sampling — Previous and Next Frames

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

## Transition Shaders

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

Autodesk's `TransitionShader` sample exposes a `float transp` (displayed as "Amount", 0.0–1.0) that drives the dissolve:

```glsl
// Pass 1 — dissolve outgoing into incoming
fragColor = mix(front2Color, front1Color, transp);
// transp=1.0 → full outgoing, transp=0.0 → full incoming
```

### Not yet verified

`sv_Triangle_Mosaic` sets `SupportsTransition="True"` and `TimelineUseBack="True"` but uses Front, Back and Matte inputs and its own Progress control instead of the four-input layout above. It works in Batch; whether the Timeline wires it correctly has not been tested. Check this before relying on either layout for a new transition.

---

## Action Lights API

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

Light colours are pre-multiplied by intensity. All positions are camera space. Requires albedo, depth, and normal textures as inputs. See `LightsAPI.glsl` as the reference implementation.

---

## UIOnly Shader — No-Op GLSL

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
