# Depth Temporal Stabilizer

A Matchbox shader for Autodesk Flame that removes the frame-to-frame flicker from machine-learning depth maps.

Relative depth models such as Depth Anything V2 (for example, running in Flame's ML Inference node) don't output a fixed scale. Each frame can come out slightly brighter, darker or more contrasty than the last, so the depth map pumps over time even when nothing in the shot moves. This shader locks the map down using two points you choose: on every frame it measures the depth at those points and rescales the whole map so they always read the values you set.

**[Download the shader (ZIP)](https://github.com/SinanVural1/matchbox/raw/main/shaders/sv_depth_temporal_stabilizer/sv_depth_temporal_stabilizer.zip)**

## Video introduction

Watch the walkthrough where the shader was introduced:

[![Video introduction to the Depth Temporal Stabilizer](https://img.youtube.com/vi/5Ctu55gq2Ec/maxresdefault.jpg)](https://www.youtube.com/live/5Ctu55gq2Ec)

## Installation

1. Download and unzip the shader.
2. Keep `sv_depth_temporal_stabilizer.glsl` and `sv_depth_temporal_stabilizer.xml` together in the same folder. Flame loads them as a pair, and `sv_depth_temporal_stabilizer.glsl.p` gives it a preview icon in Flame's browser.
3. In Batch, add a Matchbox node and browse to that folder to load **Depth Temporal Stabilizer**.

Developed for Flame 2027.1.

## Inputs and outputs

| Socket | Colour | Use |
|---|---|---|
| Depth Map | Red | The raw depth model output. Required. |
| Original | Green | Optional. The original plate, so you can view it with F2 while placing points. The shader never reads it. |
| Result | | The stabilized depth. |
| Matte output | | The inverted result (1 minus the result), in the style of Flame's native key outputs. |

**Feed the shader the raw model output**, before any inversion, gamma or falloff curve. The correction relies on the model's native output, and any curve applied first breaks it.

## Workflow

1. **Connect the depth.** Plug the raw depth model output into the red Depth Map input. Optionally connect the original plate to the green Original input.
2. **Choose two points.** Pick two surfaces at clearly different depths that stay visible for the whole shot, such as a near wall and a distant building. Avoid depth edges, where a small drift moves the sample onto a different surface.
3. **Place the points.** Either drag the Point 1 and Point 2 axes in the viewer, or paste tracker data onto them (see [Using tracker data](#using-tracker-data)).
4. **Check placement.** Turn on **Show Markers**. A red ring marks Point 1 and a green ring marks Point 2, drawn at the size of the sample area. Scrub the shot and make sure each ring stays on one surface.
5. **Set the targets.** Target 1 and Target 2 are the values the depth map will always read at the two points. Either:
   - keep the raw scale: on a good reference frame, use the colour picker in the Front view (F1) to read the depth at each point and type those values in, or
   - remap to a range you choose: the defaults of 0.9 and 0.1 put Point 1 near white and Point 2 near black.
6. **Choose an output mode** (see [Output modes](#output-modes)).
7. **Turn off Show Markers before rendering.** The rings are drawn into the result.

### Using tracker data

Paste Action tracker curves onto the Point 1 and Point 2 channels and turn on **Action Coords**. Action reports positions in pixels from the image centre, and this setting tells the shader to read them that way.

With Action Coords on, the axes in the viewer will sit far off screen, because the viewer reads the values as 0 to 1. This is expected. Use Show Markers to see where the points really are.

## Controls

| Control | Default | What it does |
|---|---|---|
| Point 1, Point 2 | 0.25, 0.5 and 0.75, 0.5 | Where the depth is sampled. 0 to 1 across the frame when dragging the axes, or pixels with Action Coords on. |
| Target 1, Target 2 | 0.9, 0.1 | The values the depth map will read at Point 1 and Point 2 on every frame. Swapping the targets, or the points, inverts the map. |
| Min Separation | 0.1 | How far apart the two samples must read, as a fraction of their depth (0.1 is 10%). If the points come closer than this, the correction fades toward a flat map instead of exploding. Raise it if close points give harsh contrast. |
| Action Coords | Off | Read the points as Action tracker pixels, with the origin at the image centre. |
| Show Markers | Off | Draw the sample areas: red for Point 1, green for Point 2. |
| Sample Radius | 8 | Size of the area averaged at each point, in pixels. Large enough to smooth out model noise, small enough to stay on one surface. |
| Mode | Distance | How the stabilized depth is output (see below). |

### Output modes

| Mode | Output | Controls |
|---|---|---|
| Distance | The stabilized depth, unchanged. | None. |
| Near/Far | The depth between Near and Far, remapped to 0 to 1. | **Near** goes to black, **Far** goes to white. **Falloff** shapes the ramp: 1 is linear, above 1 puts more detail toward Far, below 1 toward Near. |
| Range | White at a chosen depth, black elsewhere. Useful directly as a matte. | **Depth** is the value that returns white, **Range** is the width of the fully white band, and **Falloff** softens both edges. |

## How it works

Relative depth models produce depth that is correct up to an unknown scale and offset, and both can change from frame to frame:

```
model output = a * true depth + b        (a and b vary per frame)
```

Two points are enough to solve for `a` and `b`. On each frame, the shader averages the depth around each point (`s1`, `s2`), then remaps the whole frame so those points land on your targets (`T1`, `T2`):

```
result = (depth - s1) * (T1 - T2) / (s1 - s2) + T1
```

If the two samples get too close to each other, that division becomes unstable. Below the Min Separation limit, the correction fades smoothly toward zero instead.

## Limitations

- **The two points are held at fixed values.** The shader assumes the real depth at each point stays roughly constant over the shot. If the camera moves strongly toward or away from a point, the shader still forces it to its target, which flattens that real change in depth.
- **Points that converge in depth.** A single frame can't tell a deliberate swap of the points from noise. If the two samples come within Min Separation of each other and cross, the map fades through flat and can invert on those frames. Keep the points well apart in depth.
- **Large depth offsets.** Min Separation assumes depth values start somewhere near zero. On a map where every value sits far from zero, such as 1000 plus or minus 5, the points may always look too close together and the output stays flat. Typical depth model output is fine.
- **Matte output in Distance mode is not clamped.** Depth above 1 gives a negative matte value, and depth below 0 gives a value above 1. Near/Far and Range modes always stay between 0 and 1.
- **Batch only.** The shader is not set up for use inside Action.

## Author

Sinan Vural
