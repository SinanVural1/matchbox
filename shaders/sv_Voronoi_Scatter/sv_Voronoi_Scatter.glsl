// sv_Voronoi_Scatter
// Copyright (c) 2026 Sinan Vural. MIT License.
// https://github.com/SinanVural1/matchbox/tree/main/shaders/sv_Voronoi_Scatter

//*****************************************************************************/
//
// Filename: sv_Voronoi_Scatter.glsl
//
// Voronoi Texture Fill - Partitions screen into polygonal cells and fills them.
// Updated: Input coordinates now treated as Normalized UVs (0-1).
// Updated: Grid supersampling (1, 4, 9 or 16 samples) for smoother borders.
// Updated: Variation and Evolution are separate, per-cell source offset,
//          mirrored fill, and an even-width soft border.
//
//*****************************************************************************/

uniform sampler2D front;
uniform float adsk_result_w;
uniform float adsk_result_h;

// Uniforms
uniform float grid_density;     // Controls cell size
uniform float scatter_amount;   // Jitter of seed
uniform float max_rotation;     // Degrees
uniform float seed;             // Evolution: animates the cell centres
uniform float variation;        // Reshuffles per-cell rotation, scale and offset
uniform float scale_variance;   // Random scale per cell
uniform float source_offset;    // Random offset into the patch per cell
uniform vec2 selection_tl;      // Corner A (Normalized 0-1)
uniform vec2 selection_br;      // Corner B (Normalized 0-1)
uniform bool show_source;       // Debug: Show source patch rectangle
uniform float fill_scale;       // Texture fill scale
uniform int fill_mode;          // 0 mirror | 1 repeat
uniform float border_softness;  // Border soft blend, as a fraction of cell size
uniform int samples;            // Supersamples per pixel: 1, 4, 9 or 16

// Constants
const float PI = 3.14159265359;

// Random functions
float hash12(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

mat2 getRotMat(float deg) {
    float rad = radians(deg);
    float c = cos(rad);
    float s = sin(rad);
    return mat2(c, s, -s, c);
}

// Mirrored tiling has no jump where one repeat meets the next, so a patch
// smaller than its cell repeats without hard seams.
vec2 tilePatch(vec2 x) {
    if (fill_mode == 1) {
        return fract(x);
    }
    return 1.0 - abs(mod(x, 2.0) - 1.0);
}

vec4 getCellColor(vec2 pixelPos, vec2 seedPixel, vec2 cellKey, vec2 patchMin, vec2 patchSizeUV, float cellSize) {
    vec2 diff = pixelPos - seedPixel;

    float randRot = hash12(cellKey + 100.0);
    float randScale = hash12(cellKey + 200.0);
    vec2 randOffset = hash22(cellKey + 300.0);

    float rotDeg = (randRot - 0.5) * 2.0 * max_rotation;
    mat2 rot = getRotMat(-rotDeg);
    vec2 localPos = rot * diff;

    float s = 1.0 + (randScale - 0.5) * scale_variance;
    float scaleFactor = cellSize * fill_scale * s;
    if(scaleFactor < 1.0) scaleFactor = 1.0;

    // Without an offset every cell starts from the same point in the patch,
    // which reads as one image stamped over and over.
    vec2 localUV = localPos / scaleFactor + 0.5 + randOffset * source_offset;
    vec2 patchSpaceUV = tilePatch(localUV);
    vec2 sampleUV = patchMin + patchSizeUV * patchSpaceUV;

    return texture2D(front, sampleUV);
}

// Core Logic per Sample
vec4 getSample(vec2 pixelPos, float cellSize, vec2 patchMin, vec2 patchSizeUV, vec2 varOffset) {
    vec2 gridUV = pixelPos / cellSize;
    vec2 gridID = floor(gridUV);

    float dist1 = 1e9;
    float dist2 = 1e9;
    vec2 seed1 = vec2(0.0);
    vec2 seed2 = vec2(0.0);
    vec2 key1 = vec2(0.0);
    vec2 key2 = vec2(0.0);

    for(int y = -1; y <= 1; y++) {
        for(int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 currentID = gridID + neighbor;
            // Cell positions hash the grid ID alone, so only Scatter and
            // Evolution move them. The fill's random values hash cellKey,
            // so Variation reshuffles what each cell shows, not its shape.
            vec2 cellKey = currentID + varOffset;

            vec2 phase = hash22(currentID) * 2.0 * PI;
            vec2 cellOrigin = currentID * cellSize;
            vec2 centerOffset = vec2(0.5) * cellSize;
            vec2 jitterUnit = vec2(sin(seed + phase.x), cos(seed + phase.y));
            vec2 jitter = jitterUnit * 0.5 * scatter_amount * cellSize;
            vec2 seedPixel = cellOrigin + centerOffset + jitter;

            float dist = distance(pixelPos, seedPixel);

            if(dist < dist1) {
                dist2 = dist1;
                seed2 = seed1;
                key2 = key1;
                dist1 = dist;
                seed1 = seedPixel;
                key1 = cellKey;
            } else if(dist < dist2) {
                dist2 = dist;
                seed2 = seedPixel;
                key2 = cellKey;
            }
        }
    }

    vec4 col1 = getCellColor(pixelPos, seed1, key1, patchMin, patchSizeUV, cellSize);

    if (border_softness > 0.0) {
        vec4 col2 = getCellColor(pixelPos, seed2, key2, patchMin, patchSizeUV, cellSize);
        // True distance to the edge between the two cells. The simpler
        // dist2 - dist1 is zero on the edge too, but grows at different rates
        // along it, which made the soft band change width.
        float seedGap = max(distance(seed1, seed2), 0.0001);
        float edgeDist = (dist2 * dist2 - dist1 * dist1) / (2.0 * seedGap) / cellSize;
        float mixVal = smoothstep(0.0, border_softness, edgeDist);
        return mix(col2, col1, 0.5 + 0.5 * mixVal);
    }

    return col1;
}

void main() {
    float cellSize = max(adsk_result_w, adsk_result_h) / max(1.0, grid_density);
    vec2 srcTL = selection_tl;
    vec2 srcBR = selection_br;
    vec2 patchMin = min(srcTL, srcBR);
    vec2 patchMax = max(srcTL, srcBR);
    vec2 patchSizeUV = patchMax - patchMin;
    vec2 varOffset = vec2(variation * 127.1, variation * 311.7);

    // An n x n grid of sub-pixel positions. Random offsets per pixel left
    // grain along the borders; a fixed grid gives the same smooth result
    // everywhere. Float maths, as Flame's dialect lacks int clamp.
    float n = clamp(floor(sqrt(max(float(samples), 1.0)) + 0.5), 1.0, 4.0);

    vec4 accColor = vec4(0.0);

    for(int j = 0; j < 4; j++) {
        if (float(j) >= n) break;
        for(int i = 0; i < 4; i++) {
            if (float(i) >= n) break;
            vec2 subPixel = (vec2(float(i), float(j)) + 0.5) / n - 0.5;
            accColor += getSample(gl_FragCoord.xy + subPixel, cellSize, patchMin, patchSizeUV, varOffset);
        }
    }

    vec4 finalColor = accColor / (n * n);

    // Debug Selection (Overlay on top of everything)
    if (show_source) {
       vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
       vec2 border = 1.0 / vec2(adsk_result_w, adsk_result_h);
       if (uv.x >= patchMin.x && uv.x <= patchMax.x && uv.y >= patchMin.y && uv.y <= patchMax.y) {
           if (uv.x < patchMin.x+border.x || uv.x > patchMax.x-border.x ||
               uv.y < patchMin.y+border.y || uv.y > patchMax.y-border.y) {
               finalColor = vec4(1.0, 0.0, 0.0, 1.0);
           }
       }
    }

    gl_FragColor = finalColor;
}
