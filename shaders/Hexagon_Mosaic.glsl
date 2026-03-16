//*****************************************************************************/
// 
// Filename: Hexagon_Mosaic.glsl
//
// Hexagonal mosaic effect - Robust Axial Rounding Version
// Fixed: Shape Orientation, Overlap Blending, Scaling range.
// Refined: Tiling Radius calibration, Anti-Aliasing logic.
//
//*****************************************************************************/

uniform sampler2D front;
uniform float adsk_result_w;
uniform float adsk_result_h;
uniform float size;         // Radius (outer radius)
uniform float rotation;     // Degrees
uniform float lineThickness;
uniform float lumScale;
uniform float offsetX;
uniform float offsetY;

// Constants
const float SQRT3 = 1.73205080757;
const float GEOM_SCALE = 0.866025404; // sqrt(3)/2 - Corrects Aspect ratio match

float getLuminance(vec3 color) {
    return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
}

// Signed distance to a pointy-topped hexagon of radius r
float sdHexagon(vec2 p, float r) {
    const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
    p = abs(p);
    p -= 2.0*min(dot(k.xy, p), 0.0)*k.xy;
    p -= vec2(clamp(p.x, -k.z*r, k.z*r), r);
    return length(p)*sign(p.y);
}

// -----------------------------------------------------------
// Axial Coordinate System Logic (Red Blob Games standard)
// -----------------------------------------------------------

vec2 pixelToAxial(vec2 p, float r) {
    float q = (sqrt(3.0)/3.0 * p.x - 1.0/3.0 * p.y) / r;
    float R = (2.0/3.0 * p.y) / r;
    return vec2(q, R);
}

vec2 axialToPixel(vec2 hex, float r) {
    float x = r * (sqrt(3.0) * hex.x + sqrt(3.0)/2.0 * hex.y);
    float y = r * (3.0/2.0 * hex.y);
    return vec2(x, y);
}

vec2 hexRound(vec2 hex) {
    float x = hex.x;
    float z = hex.y;       
    float y = -x - z;      
    
    float rx = floor(x + 0.5);
    float rz = floor(z + 0.5);
    float ry = floor(y + 0.5);
    
    float x_diff = abs(rx - x);
    float y_diff = abs(ry - y);
    float z_diff = abs(rz - z);
    
    if (x_diff > y_diff && x_diff > z_diff) {
        rx = -ry - rz;
    } else if (y_diff > z_diff) {
        // ry changed
    } else {
        rz = -rx - ry;
    }
    
    return vec2(rx, rz);
}

void main() {
    float r = size;
    if (r < 1.0) r = 1.0;
    
    vec2 resolution = vec2(adsk_result_w, adsk_result_h);
    vec2 center = resolution * 0.5;
    vec2 pixel = gl_FragCoord.xy;
    
    // 1. Matrix Setup
    float rad = radians(rotation);
    float c = cos(rad);
    float s = sin(rad);
    mat2 rotMat = mat2(c, s, -s, c); 
    
    vec2 pCentered = pixel - center;
    vec2 pOffset = pCentered - vec2(offsetX, offsetY);
    vec2 pGrid = rotMat * pOffset;
    
    // 2. Round to Hex Center
    vec2 axial = pixelToAxial(pGrid, r);
    vec2 axialRounded = hexRound(axial);
    vec2 centerGrid = axialToPixel(axialRounded, r);
    
    // 3. Neighbors in Axial coords
    vec2 neighbors[7];
    neighbors[0] = vec2(0.0, 0.0);
    neighbors[1] = vec2(1.0, 0.0);
    neighbors[2] = vec2(1.0, -1.0);
    neighbors[3] = vec2(0.0, -1.0);
    neighbors[4] = vec2(-1.0, 0.0);
    neighbors[5] = vec2(-1.0, 1.0);
    neighbors[6] = vec2(0.0, 1.0);
    
    vec4 accColor = vec4(0.0);
    float accWeight = 0.0;
    
    for(int i=0; i<7; i++) {
        vec2 candAxial = axialRounded + neighbors[i];
        vec2 candGrid = axialToPixel(candAxial, r);
        
        // Transform back to screen for sampling
        vec2 candOffset = transpose(rotMat) * candGrid;
        vec2 candScreen = candOffset + center + vec2(offsetX, offsetY);
        
        vec2 uv = candScreen / resolution;
        uv = clamp(uv, vec2(0.0), vec2(1.0));
        vec3 col = texture2D(front, uv).rgb;
        
        vec2 diff = pGrid - candGrid;
        
        // SDF Radius Logic
        // Scale r by 0.866 to match Grid Pointy Top spacing convention
        float currentR = r * GEOM_SCALE;
        
        // Luma Scaling Logic
        if (lumScale > 0.0 || lumScale < -0.99) { 
             float lum = getLuminance(col);
             // 1.0 means touching exactly (due to GEOM_SCALE)
             float sizeMultiplier = (0.1 + 0.9 * lum) * (1.0 + lumScale);
             currentR = currentR * sizeMultiplier;
        }
        
        // Pointy Top Orientation (Swap X/Y in SDF)
        float dist = sdHexagon(diff.yx, currentR);
        
        if (lineThickness > 0.0) {
            // lineThickness is percentage of R?
            // User said 13.4 worked initially (which was ~13% of old radius).
            // Now that we fixed radius, small values should open gap.
            float thick = lineThickness * 0.01 * r * GEOM_SCALE;
            dist += thick;
        }
        
        float alpha = 1.0 - smoothstep(-0.5, 0.5, dist);
        
        accColor += vec4(col, 1.0) * alpha;
        accWeight += alpha;
    }
    
    // Normalize Logic for Anti-Aliasing
    // If accWeight is > 1.0 (overlaps), we normalize to average colors.
    // If accWeight is < 1.0 (edges against black background), we DO NOT strengthen it.
    // This preserves standard alpha blending against black.
    // Example: weight 0.5 -> color * 0.5. displayed as semi-transparent over black.
    // If we want it over 'transparent', we would output alpha=0.5.
    // Matchbox usually outputs RGB over black for this type of effect unless Alpha channel is requested.
    // Assuming opaque output:
    
    if (accWeight > 1.0) {
        gl_FragColor = accColor / accWeight;
    } else {
        gl_FragColor = vec4(accColor.rgb, 1.0); 
        // Wait, vec4(col, 1.0) * alpha -> RGB * alpha, Alpha * alpha.
        // accColor.a is sum of alphas.
        // If sum < 1.0, accColor.rgb is premultiplied color.
        // If we output this with alpha=1.0, it looks dark (correct for OVER BLACK).
        // If we output alpha = accColor.a, it is compositable.
        // Let's output RGB premultiplied, and alpha.
        // But traditionally we might just output RGB=accColor.rgb, A=1.0 for view.
    }
    // Simplification:
    if (accWeight > 0.001) {
         // Divisor ensures that if we have 2 full hexagons (weight 2), we avg them.
         // If we have 0.5 hexagon (weight 0.5), we divide by max(1.0, 0.5) = 1.0.
         // So result is col * 0.5. Correct darkness.
         float divisor = max(1.0, accWeight);
         gl_FragColor = accColor / divisor;
    } else {
         gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}
