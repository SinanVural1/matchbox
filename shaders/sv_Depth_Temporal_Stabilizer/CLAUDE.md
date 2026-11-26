# sv_Depth_Temporal_Stabilizer

Notes and decisions for this shader. The shared framework is in the root `CLAUDE.md` and the matchbox skill; this file only records what is specific to this shader and why.

## Purpose

Removes the frame-to-frame flicker of relative depth maps from ML models such as DepthAnything V2 run in Flame's ML Inference node. Those models are affine-invariant: each frame is `d = a * d_true + b` with a different `a` and `b`. Two tracked points with known target values fully determine `a` and `b` per frame, so the shader solves them and re-maps the whole frame.

- Feed it the raw model output, before any 1/z inversion, gamma or falloff. The affine relationship only holds in native disparity space.
- Each point is held at a fixed value for the whole shot. A strong camera move toward or away from a point gets flattened out; the README lists this as a limitation.

## Status

- Confirmed working in Flame by the user, including the `.glsl.p` icon, which was the first `.p` file made and proved the icon format.
- Published: GitHub page, ZIP, and uploaded to logik-matchbook.org by hand (not through the webhook). Intro video: https://www.youtube.com/live/5Ctu55gq2Ec (also in the XML description).

## Inputs and outputs

- **Depth Map** (Front): the raw model output.
- **Original** (Back): never read by the shader. It exists only so F2 shows the plate while placing points. Do not wire it into the maths.
- **Matte output**: `MatteProvider="True"`, alpha is `1 - stabilised depth`, like Flame's native inverted key outputs. In Distance mode nothing clamps it, so it can go below 0 or above 1; Near/Far and Range stay within 0-1.

## The solve and why it looks like this

```glsl
float den   = s1 - s2;
float limit = max(minSep * max(abs(s1), abs(s2)), 0.00001);
float gain  = (target1 - target2) / max(abs(den), limit) * clamp(den / limit, -1.0, 1.0);
```

- **Gain is signed.** Swapping the two points must give the inverse gradient. An earlier fix forced gain positive to stop noise inverting the map; with the points swapped that pinned gain at the cap and gave a clamped black-and-white image. Reverted.
- **One guard, relative to the samples.** `Min Separation` replaced the old absolute `Min Separation` plus `Max Gain`. Raw estimator values are large (40, 12...), so absolute thresholds never fired. As a fraction of the samples' own depth (default 0.1) it works at any scale. Below the limit gain fades smoothly through zero instead of snapping.
- **Trade-offs accepted:** no hard contrast cap (gain can reach 16 just above the limit with 0-1 data), and the percentage assumes depth values start near zero.
- **Sampling uses `GL_LINEAR`**, so sub-pixel tracker motion changes the reading smoothly. `GL_NEAREST` made all samples snap together at pixel boundaries and added flicker. No half-pixel offset: it would move reads off pixel centres.

## UI decisions (all at the user's request)

One page, six columns: Points, Solve, Options, Output Range, Near / Far, Range.

- Point 1 and Point 2 are `vec2` axes on rows 0 and 2. Putting them on adjacent rows looked wrong in Flame; a `vec2` needs two rows.
- **Action Coords** reads the points as Action tracker pixels from the image centre. The user pastes tracker data this way, so it must stay. With it on, the on-screen axis icons land off screen (Flame draws them from the raw values); Show Markers shows where the points really are.
- **Show Markers** (row 2) and **Sample Radius** (row 3) sit under Action Coords.
- The output range Mode popup has its own column, so it isn't squeezed between other options.
- Target defaults are 0.9 and 0.1.

## Removed: do not add back

- **Debug dropdown** (Flat Sample 1/2, Markers, Passthrough): replaced by the Show Markers checkbox. This deliberately departs from the project's debugMode convention.
- **Show Original slider and Mix**: the user presses F2 to see the original, and raw estimator values are too large to mix meaningfully.
- **Point Units dropdown**: replaced Action Coords for a round and broke the tracker workflow.
- **Flip Y**: not needed; Flame and Action both measure Y upward.
- **Invert**: replaced by the inverted matte output.
- **Clamp Output, Clamp Min, Clamp Max**: removed to tighten the UI.

## Open items

- None outstanding. Axis icons cannot follow Action Coords from inside the shader; an expression on the channels (`x / width + 0.5`) is the untested workaround if it's ever needed.
