# Testing a shader before Flame

Only Flame can confirm that a shader loads and renders. Before handing it to the user, check it statically and compile and measure it in WebGL, so the Flame round trip finds as little as possible.

## 1. Validator

```bash
python3 .claude/skills/matchbox/scripts/validate_matchbox.py shaders/<name>/<name>
python3 .claude/skills/matchbox/scripts/validate_matchbox.py sv_Hypot        # bare name: looks in shaders/, then wip/
python3 .claude/skills/matchbox/scripts/validate_matchbox.py --all shaders   # every finished shader (--all wip for unfinished)
```

It checks GLSL and XML name agreement, sampler binding, Row/Col/Page collisions, undeclared columns, reserved words and brace balance. It does not compile anything.

Known limits:
- It doesn't parse several names on one line (`uniform int a, b, c;`) and reports them as missing from the GLSL (`sv_Polyhedra`).
- Multi-pass shaders (`name.01.glsl`...) are skipped.
- It treats `Tooltip` as an error. Autodesk's own samples use `Tooltip` and load, so on legacy shaders this most likely means missing tooltips rather than a load failure. Still write `ToolTip` in new work.

## 2. WebGL harness

The browser pane compiles the shader as GLSL ES 1.00, which is stricter than Flame's legacy dialect, and renders it with test images so the maths can be measured.

1. **Build a page:**

   ```bash
   python3 .claude/skills/matchbox/scripts/webgl_harness.py shaders/<name>/<name>.glsl <scratch>/page.html <scratch>/configs.json 512 256
   ```

   Keep W and H powers of two if the shader reads mip levels; WebGL 1 can't build mipmaps otherwise.
2. **Serve it** with `scripts/serve.py <port> <scratch dir>` through the browser pane's launch configuration. `.claude/launch.json` is gitignored because it holds local paths, for example:

   ```json
   {"version": "0.0.1", "configurations": [{"name": "shader-harness",
     "runtimeExecutable": "python3",
     "runtimeArgs": [".claude/skills/matchbox/scripts/serve.py", "8765", "<scratch dir>"],
     "port": 8765}]}
   ```

   `file://` pages can't be scripted from the browser tools, so a server is needed.
3. **Open the page and drive it with JavaScript:** draw test images into `frontImg`, `backImg` and `matteImg`, call `render({name, u})`, read pixels with `gl.readPixels`, and compare.

### Checks worth making

- **Compile:** the page logs `COMPILE ERROR` with the line if GLSL ES rejects it.
- **Identity cases:** settings that should reproduce the input exactly, such as a mosaic with Image fill and no edges against Front, or Progress 0 and 1 of a transition against the untouched mosaic and Back. A max difference of 0 or 1 (8-bit rounding) proves the maths.
- **Conservation:** a flat grey input averaged over many cells, to check brightness compensation.
- **Moire and seams:** block averages over windows a few cells wide should be flat; any speck at points where many shapes meet shows up as a large max difference.
- **Reproduction:** fit or derived parameters against a hand-set case (Digital Screen's Fit to Points).

### Pitfalls

- **Readback is 8-bit and clips at 1.** Values above 1, such as compensated subpixels, read as 255. Scale with a gain control before measuring, then divide it back out.
- **Test images are 8-bit canvases**, so very dark channel values quantise badly; a channel at 4/255 can read 5% off for no fault of the shader.
- **Check the test, not just the shader.** A wrong-looking difference once came from the harness flipping the reference image; the uniform-type map was once built back to front and set nothing. When a result is suspicious, render a debug passthrough first.

## 3. What only Flame can confirm

- The XML loads, the controls appear where expected, and popups, axes and colour pickers behave.
- Inputs arrive (use the shader's Debug passthrough).
- Behaviour WebGL can't reproduce: mipmaps on non-power-of-two inputs, `ResDependent` rescaling, timeline transitions, Action, matte outputs.

Tell the user exactly what to check, and wait for them to confirm before calling a change done.
