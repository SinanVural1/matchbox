// sv_Digital_Screen
// Copyright (c) 2026 Sinan Vural. MIT License.
// https://github.com/SinanVural1/matchbox/tree/main/shaders/sv_Digital_Screen

//*****************************************************************************/
//
// Filename: sv_Digital_Screen.glsl
//
// Renders the image as seen on a display up close: every screen pixel is a
// set of red, green and blue emitters laid out as on an LCD, CRT, OLED or LED
// wall.
//
// The subpixel shapes are drawn from signed distance functions with an
// anti-aliasing ramp about a pixel wide, so a pitch that is not a whole
// number of pixels, or a rotated grid, does not shimmer or throw moire.
// Each screen pixel takes its colour from a mipmap level about its own size,
// which averages the image over the pixel instead of point-sampling it.
//
// Back is a reference only, such as a photographed screen to match. It can be
// blended, split or differenced against the result, and two points placed on
// it can set the pixel size and rotation for you.
//
//*****************************************************************************/

#extension GL_ARB_shader_texture_lod : enable

uniform sampler2D front;
uniform sampler2D back;
uniform float adsk_result_w;
uniform float adsk_result_h;

// Screen
uniform int screen_layout;      // 0 stripe | 1 stacked | 2 delta | 3 aperture grille | 4 pentile
                                // 5 diamond | 6 LED wall | 7 quad RGGB | 8 quad RGBW
uniform float pixel_size;       // Pixel pitch in pixels, ResDependent
uniform float pixel_aspect;     // Height over width of a screen pixel
uniform float grid_rotation;    // Degrees
uniform vec2 grid_centre;
uniform bool action_coords;
uniform int colour_mode;        // 0 RGB subpixels | 1 source colour
uniform bool swap_phase;        // Which pixels and rows take turns

// Match
uniform bool fit_points;        // Set pixel size, rotation and origin from two points
uniform vec2 point_a;
uniform vec2 point_b;
uniform float pixels_x;         // Screen pixels from A to B, along a row
uniform float pixels_y;         // and down a column
uniform bool show_guides;
uniform int reference_view;     // 0 off | 1 blend | 2 split | 3 difference
uniform float reference_mix;
uniform float split_position;

// Subpixels
uniform float fill;             // Fraction of its slot each subpixel fills
uniform float roundness;        // 0 square corners, 1 fully round
uniform float softness;         // Edge falloff, fraction of subpixel size
uniform float glow;             // Light bleeding around each subpixel
uniform float glow_size;        // Fraction of pixel size

// Picture
uniform int sampling;           // 0 area | 1 point
uniform float compensation;     // 0 raw mask, 1 keeps the average brightness
uniform float gain;
uniform vec3 gap_colour;

// Imperfections
uniform float dead_pixels;
uniform float stuck_pixels;
uniform float pixel_variation;
uniform float subpixel_variation;
uniform float panel_size;       // Screen pixels per panel side
uniform float panel_variation;
uniform float panel_tint;
uniform float variation;

// Output
uniform int matte_mode;         // 0 coverage | 1 source alpha
uniform int samples;
uniform int debug_mode;         // 0 off | 1 front | 2 pixel colour | 3 mask only

const float PI = 3.14159265359;

vec2 gRes;
vec2 gCell;          // Screen pixel size in image pixels
vec2 gCentre;
mat2 gRot;
mat2 gRotInv;
float gLod;
float gAA;
vec4 gGain;          // Brightness compensation per channel: R, G, B, W
float gGainAll;      // Compensation when every subpixel shows the full colour
vec2 gPointA;
vec2 gPointB;
vec2 gVar;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 hash32(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

mat2 rot2(float rad) {
    float c = cos(rad);
    float s = sin(rad);
    return mat2(c, s, -s, c);
}

// Delta rows are offset by half a pixel, which is what turns three dots per
// pixel into the interlocking triads of a shadow mask.
float rowShift(float row) {
    if (screen_layout == 2) return 0.5 * mod(row + (swap_phase ? 1.0 : 0.0), 2.0);
    return 0.0;
}

// Subpixel k of a screen pixel: centre and half size in pixel units (0-1
// across the pixel), the channel it emits (0 R, 1 G, 2 B, 3 W), and whether it
// is turned 45 degrees. False when the layout has fewer subpixels than k.
bool subpixel(float k, vec2 cell, out vec2 c, out vec2 hs, out float ch, out float turned) {
    // Swap Phase flips which pixels take the red and which the blue, to match
    // a reference whatever pixel Point A landed on.
    float par = mod(cell.x + cell.y + (swap_phase ? 1.0 : 0.0), 2.0);
    turned = 0.0;
    if (screen_layout == 0 || screen_layout == 3) {
        if (k > 2.5) return false;
        c = vec2((2.0 * k + 1.0) / 6.0, 0.5);
        // The grille runs unbroken from top to bottom; the stripe has a gap.
        // Exactly half a pixel tall, so the anti-aliasing ramps of the
        // stripes above and below meet at 0.5 each and sum to one: no seam.
        hs = screen_layout == 3 ? vec2(fill / 6.0, 0.5) : vec2(1.0 / 6.0, 0.5) * fill;
        ch = k;
    } else if (screen_layout == 1) {
        if (k > 2.5) return false;
        c = vec2(0.5, (5.0 - 2.0 * k) / 6.0);
        hs = vec2(0.5, 1.0 / 6.0) * fill;
        ch = k;
    } else if (screen_layout == 2) {
        if (k > 2.5) return false;
        if (k < 0.5)      c = vec2(0.25, 0.27);
        else if (k < 1.5) c = vec2(0.75, 0.27);
        else              c = vec2(0.5, 0.73);
        hs = vec2(0.25) * fill;
        ch = k;
    } else if (screen_layout == 4) {
        // PenTile: every pixel has a green, and red and blue take turns.
        if (k > 1.5) return false;
        if (k < 0.5) { c = vec2(0.32, 0.5); hs = vec2(0.26, 0.42) * fill; ch = par < 0.5 ? 0.0 : 2.0; }
        else         { c = vec2(0.80, 0.5); hs = vec2(0.14, 0.30) * fill; ch = 1.0; }
    } else if (screen_layout == 5) {
        // Diamond: large red and blue diamonds take turns, small greens between.
        if (k > 1.5) return false;
        if (k < 0.5) { c = vec2(0.32, 0.32); hs = vec2(0.24) * fill; ch = par < 0.5 ? 0.0 : 2.0; turned = 1.0; }
        else         { c = vec2(0.78, 0.78); hs = vec2(0.14) * fill; ch = 1.0; }
    } else if (screen_layout == 6) {
        // LED wall: three small dies in a dark package.
        if (k > 2.5) return false;
        if (k < 0.5)      c = vec2(0.36, 0.42);
        else if (k < 1.5) c = vec2(0.64, 0.42);
        else              c = vec2(0.5, 0.66);
        hs = vec2(0.11) * fill;
        ch = k;
    } else {
        // Quad: a 2x2 block per pixel. Top row R G, bottom row G B, or W B.
        float kx = mod(k, 2.0);
        float ky = floor(k / 2.0);
        c = vec2(0.25 + 0.5 * kx, 0.75 - 0.5 * ky);
        hs = vec2(0.25) * fill;
        if (k < 0.5)      ch = 0.0;
        else if (k < 1.5) ch = 1.0;
        else if (k < 2.5) ch = screen_layout == 8 ? 3.0 : 1.0;
        else              ch = 2.0;
    }
    return true;
}

// Signed distance to a rounded rectangle, negative inside, in image pixels.
float boxSDF(vec2 d, vec2 h, float r) {
    vec2 q = abs(d) - h + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// The grille's stripes join end to end, so rounding their ends would cut
// gaps into them.
float cornerRadius(vec2 h) {
    if (screen_layout == 3) return 0.0;
    return clamp(roundness, 0.0, 1.0) * min(h.x, h.y);
}

vec3 channelColour(float ch) {
    if (ch < 0.5) return vec3(1.0, 0.0, 0.0);
    if (ch < 1.5) return vec3(0.0, 1.0, 0.0);
    if (ch < 2.5) return vec3(0.0, 0.0, 1.0);
    return vec3(1.0);
}

float channelGain(float ch) {
    if (ch < 0.5) return gGain.x;
    if (ch < 1.5) return gGain.y;
    if (ch < 2.5) return gGain.z;
    return gGain.w;
}

// The share of a pixel's area each channel lights, averaged over two
// neighbouring pixels so that PenTile and Diamond, which alternate red and
// blue, count each at half. Compensation divides by this so the screen keeps
// the picture's average brightness however much of it is gap.
void computeGain() {
    vec4 area = vec4(0.0);
    for (int p = 0; p < 2; p++) {
        for (int k = 0; k < 4; k++) {
            vec2 c; vec2 hs; float ch; float turned;
            if (!subpixel(float(k), vec2(float(p), 0.0), c, hs, ch, turned)) break;
            vec2 h = hs * gCell;
            if (turned > 0.5) h *= 0.70710678;
            float r = cornerRadius(h);
            // The anti-aliasing ramp adds pi * w^2 / 12 to any convex shape's
            // lit area (the perimeter terms of the inner and outer halves
            // cancel), which matters for dots only a pixel or two wide.
            float w = gAA + max(softness, 0.0) * min(h.x, h.y);
            float a = (4.0 * h.x * h.y - (4.0 - PI) * r * r + PI * w * w / 12.0) / (gCell.x * gCell.y);
            if (ch < 0.5) area.x += a;
            else if (ch < 1.5) area.y += a;
            else if (ch < 2.5) area.z += a;
            else area.w += a;
        }
    }
    area *= 0.5;
    float comp = clamp(compensation, 0.0, 1.0);
    vec4 inv = 1.0 / max(area, vec4(0.005));
    gGain = mix(vec4(1.0), inv, comp);
    gGain = mix(vec4(1.0), gGain, step(0.0001, area));
    // In Source Colour every subpixel shows the whole colour, so it is the
    // total lit area that has to make up for the gaps.
    float total = area.x + area.y + area.z + area.w;
    gGainAll = mix(1.0, 1.0 / max(total, 0.005), comp);
}

// Colour a screen pixel shows: the image averaged over the pixel, then its
// imperfections.
vec3 cellColour(vec2 cell, vec2 gridPos) {
    vec2 uv = (gCentre + gRot * gridPos) / gRes;
    vec3 col = debug_mode == 3 ? vec3(1.0) : texture2DLod(front, uv, gLod).rgb;

    vec2 key = cell + gVar;
    if (pixel_variation > 0.0) {
        col *= max(1.0 + (hash12(key + 21.0) - 0.5) * 2.0 * pixel_variation, 0.0);
    }
    if (subpixel_variation > 0.0) {
        col *= max(1.0 + (hash32(key + 31.0) - 0.5) * 2.0 * subpixel_variation, 0.0);
    }
    if (panel_variation > 0.0 || panel_tint > 0.0) {
        vec2 panel = floor(cell / max(panel_size, 1.0)) + gVar;
        col *= max(1.0 + (hash12(panel + 41.0) - 0.5) * 2.0 * panel_variation, 0.0);
        col *= max(1.0 + (hash32(panel + 51.0) - 0.5) * 2.0 * panel_tint, 0.0);
    }
    if (stuck_pixels > 0.0 && hash12(key + 61.0) < stuck_pixels) {
        float which = floor(hash12(key + 71.0) * 3.0);
        if (which < 0.5) col.r = 1.0;
        else if (which < 1.5) col.g = 1.0;
        else col.b = 1.0;
    }
    if (dead_pixels > 0.0 && hash12(key + 81.0) < dead_pixels) col = vec3(0.0);
    return col;
}

// Light arriving at point s from this pixel and its eight neighbours, so soft
// edges and glow can spill across pixel borders. Alpha is the subpixel
// coverage.
vec4 renderPoint(vec2 s) {
    vec2 q = (gRotInv * (s - gCentre)) / gCell;
    float row0 = floor(q.y);
    vec3 light = vec3(0.0);
    float cov = 0.0;
    float glowR = max(glow_size, 0.001) * min(gCell.x, gCell.y);

    for (int j = -1; j <= 1; j++) {
        float row = row0 + float(j);
        float shift = rowShift(row);
        float col0 = floor(q.x - shift);
        for (int i = -1; i <= 1; i++) {
            vec2 cell = vec2(col0 + float(i), row);
            vec2 local = vec2(q.x - shift - cell.x, q.y - row);
            vec3 cc = cellColour(cell, (cell + vec2(shift + 0.5, 0.5)) * gCell);
            float w = min(cc.r, min(cc.g, cc.b));
            for (int k = 0; k < 4; k++) {
                vec2 c; vec2 hs; float ch; float turned;
                if (!subpixel(float(k), cell, c, hs, ch, turned)) break;
                vec2 d = (local - c) * gCell;
                vec2 h = hs * gCell;
                if (turned > 0.5) {
                    // A diamond is a square turned 45 degrees; h is its half
                    // diagonal, so the square's half side is h / sqrt(2).
                    d = rot2(0.25 * PI) * d;
                    h *= 0.70710678;
                }
                float r = cornerRadius(h);
                float sd = boxSDF(d, h, r);
                if (sd > glowR * 8.0 + 2.0) continue;

                // A ramp about a pixel wide keeps the shapes smooth at any
                // size; Softness widens it.
                float wid = gAA + max(softness, 0.0) * min(h.x, h.y);
                float a = clamp(0.5 - sd / wid, 0.0, 1.0);

                // RGBW: the white subpixel carries what the three share, and
                // the colour subpixels only the rest.
                float glowE = glow > 0.0 ? glow * exp(-max(sd, 0.0) / glowR) : 0.0;
                if (colour_mode == 1) {
                    // Source Colour: the layout only shapes the light; every
                    // subpixel shows the pixel's own colour, untinted.
                    light += cc * (a * gGainAll + glowE);
                } else {
                    float drive;
                    if (ch > 2.5) drive = w;
                    else if (ch < 0.5) drive = cc.r;
                    else if (ch < 1.5) drive = cc.g;
                    else drive = cc.b;
                    if (screen_layout == 8 && ch < 2.5) drive -= w;
                    // Glow follows the picture, not the compensated drive:
                    // small dots in big gaps are boosted many times over, and
                    // a glow boosted with them would swamp the screen.
                    light += channelColour(ch) * drive * (a * channelGain(ch) + glowE);
                }
                cov += a;
            }
        }
    }
    cov = clamp(cov, 0.0, 1.0);
    return vec4(light + gap_colour * (1.0 - cov), cov);
}

// Overlay for lining the grid up with a reference: thin outlines of every
// screen pixel, and rings at Point A and B joined by a line.
vec3 drawGuides(vec3 col) {
    vec3 ink = vec3(1.0, 0.85, 0.0);
    vec2 p = gl_FragCoord.xy;

    vec2 q = (gRotInv * (p - gCentre)) / gCell;
    float qx = q.x - rowShift(floor(q.y));
    vec2 toLine = abs(vec2(qx, q.y) - floor(vec2(qx, q.y) + 0.5)) * gCell;
    float grid = 1.0 - smoothstep(0.25, 0.9, min(toLine.x, toLine.y));
    col = mix(col, ink, 0.45 * grid);

    vec2 ab = gPointB - gPointA;
    float t = clamp(dot(p - gPointA, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
    float seg = 1.0 - smoothstep(0.5, 1.2, distance(p, gPointA + t * ab));
    float ra = abs(distance(p, gPointA) - 7.0);
    float rb = abs(distance(p, gPointB) - 7.0);
    float rings = 1.0 - smoothstep(0.6, 1.5, min(ra, rb));
    return mix(col, ink, max(seg * 0.8, rings));
}

void main() {
    gRes = vec2(adsk_result_w, adsk_result_h);
    vec2 uv0 = gl_FragCoord.xy / gRes;
    vec4 src = texture2D(front, uv0);
    if (debug_mode == 1) { gl_FragColor = src; return; }

    float aspect = max(pixel_aspect, 0.05);
    float ps = max(pixel_size, 1.0);
    float gr = radians(grid_rotation);
    // Action tracker data is in pixels from the image centre.
    gCentre = action_coords ? grid_centre + 0.5 * gRes : grid_centre * gRes;
    gPointA = action_coords ? point_a + 0.5 * gRes : point_a * gRes;
    gPointB = action_coords ? point_b + 0.5 * gRes : point_b * gRes;

    if (fit_points) {
        // A and B sit on the same spot of two screen pixels, pixels_x along a
        // row and pixels_y down a column apart. Unrotated, that offset is
        // (nx * size, ny * size * aspect); its length gives the size and the
        // angle between it and A->B gives the rotation.
        vec2 ab = gPointB - gPointA;
        vec2 cells = vec2(pixels_x, pixels_y * aspect);
        float span = length(cells);
        if (span > 0.0001 && length(ab) > 0.0001) {
            ps = max(length(ab) / span, 1.0);
            gr = atan(ab.y, ab.x) - atan(cells.y, cells.x);
        }
    }

    gCell = vec2(ps, ps * aspect);
    gRot = rot2(gr);
    gRotInv = rot2(-gr);
    // Put Point A at the centre of a screen pixel.
    if (fit_points) gCentre = gPointA - gRot * (0.5 * gCell);
    gVar = vec2(variation * 127.1, variation * 311.7);
    // The mip level a screen pixel wide, less half a level since linear
    // mipmap filtering already reaches into the next texel.
    gLod = sampling == 0 ? max(log2(max(gCell.x, gCell.y)) - 0.5, 0.0) : 0.0;

    if (debug_mode == 2) {
        vec2 q = (gRotInv * (gl_FragCoord.xy - gCentre)) / gCell;
        float row = floor(q.y);
        float shift = rowShift(row);
        vec2 cell = vec2(floor(q.x - shift), row);
        gl_FragColor = vec4(cellColour(cell, (cell + vec2(shift + 0.5, 0.5)) * gCell), 1.0);
        return;
    }

    // An n x n grid of sub-pixel positions. Float maths, as Flame's dialect
    // lacks int clamp.
    float n = clamp(floor(sqrt(max(float(samples), 1.0)) + 0.5), 1.0, 4.0);
    gAA = 1.0 / n;
    computeGain();
    vec4 acc = vec4(0.0);
    for (int sj = 0; sj < 4; sj++) {
        if (float(sj) >= n) break;
        for (int si = 0; si < 4; si++) {
            if (float(si) >= n) break;
            vec2 sub = (vec2(float(si), float(sj)) + 0.5) / n - 0.5;
            acc += renderPoint(gl_FragCoord.xy + sub);
        }
    }
    acc /= n * n;

    vec3 col = acc.rgb * gain;
    float m = matte_mode == 1 ? src.a : acc.a;

    // Reference views compare the result with Back. They change only what is
    // seen, so turn them off before rendering.
    if (reference_view > 0) {
        vec3 ref = texture2D(back, uv0).rgb;
        if (reference_view == 1) {
            col = mix(col, ref, clamp(reference_mix, 0.0, 1.0));
        } else if (reference_view == 2) {
            float sx = split_position * gRes.x;
            if (gl_FragCoord.x > sx) col = ref;
            if (abs(gl_FragCoord.x - sx) < 1.0) col = vec3(1.0, 0.85, 0.0);
        } else {
            col = abs(col - ref);
        }
    }

    if (show_guides) col = drawGuides(col);
    gl_FragColor = vec4(col, m);
}
