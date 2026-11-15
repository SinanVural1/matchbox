//*****************************************************************************/
// 
// Filename: sv_Voronoi_Scatter.glsl
//
// Voronoi Texture Fill - Partitions screen into polygonal cells and fills them.
// Updated: Input coordinates now treated as Normalized UVs (0-1).
// Updated: Added SSAA (Samples) for higher quality borders and textures.
//
//*****************************************************************************/

uniform sampler2D front;
uniform float adsk_result_w;
uniform float adsk_result_h;

// Uniforms
uniform float grid_density;     // Controls cell size
uniform float scatter_amount;   // Jitter of seed
uniform float max_rotation;     // Degrees
uniform float seed;             // Evolution
uniform float scale_variance;   // Random scale per cell
uniform vec2 selection_tl;      // Top-Left (Normalized 0-1)
uniform vec2 selection_br;      // Bottom-Right (Normalized 0-1)
uniform bool show_source;       // Debug: Show source patch rectangle
uniform float fill_scale;       // Texture fill scale
uniform float border_softness;  // Border soft blend
uniform int samples;            // SSAA Samples

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

vec4 getCellColor(vec2 pixelPos, vec2 seedPixel, vec2 cellID, vec2 patchMin, vec2 patchSizeUV, float cellSize) {
    vec2 diff = pixelPos - seedPixel;
    
    vec2 noisePos = cellID; 
    float randRot = hash12(noisePos + 100.0);
    float randScale = hash12(noisePos + 200.0);
    
    float rotDeg = (randRot - 0.5) * 2.0 * max_rotation;
    mat2 rot = getRotMat(-rotDeg);
    vec2 localPos = rot * diff;
    
    float s = 1.0 + (randScale - 0.5) * scale_variance; 
    float scaleFactor = cellSize * fill_scale * s;
    if(scaleFactor < 1.0) scaleFactor = 1.0;
    
    vec2 localUV = localPos / scaleFactor;
    vec2 patchSpaceUV = fract(localUV + 0.5);
    vec2 sampleUV = patchMin + patchSizeUV * patchSpaceUV;
    
    return texture2D(front, sampleUV);
}

// Core Logic per Sample
vec4 getSample(vec2 pixelPos, float cellSize, vec2 patchMin, vec2 patchSizeUV) {
    vec2 gridUV = pixelPos / cellSize;
    vec2 gridID = floor(gridUV);
    
    float dist1 = 1e9;
    float dist2 = 1e9;
    vec2 seed1 = vec2(0.0);
    vec2 seed2 = vec2(0.0);
    vec2 id1 = vec2(0.0);
    vec2 id2 = vec2(0.0);
    
    for(int y = -1; y <= 1; y++) {
        for(int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 currentID = gridID + neighbor;
            
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
                id2 = id1;
                dist1 = dist;
                seed1 = seedPixel;
                id1 = currentID;
            } else if(dist < dist2) {
                dist2 = dist;
                seed2 = seedPixel;
                id2 = currentID;
            }
        }
    }
    
    vec4 col1 = getCellColor(pixelPos, seed1, id1, patchMin, patchSizeUV, cellSize);
    
    if (border_softness > 0.0) {
        vec4 col2 = getCellColor(pixelPos, seed2, id2, patchMin, patchSizeUV, cellSize);
        float diff = (dist2 - dist1) / cellSize;
        float mixVal = smoothstep(0.0, border_softness, diff);
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
    
    int sCount = samples;
    if (sCount < 1) sCount = 1;
    if (sCount > 100) sCount = 100; // Safety cap
    
    vec4 accColor = vec4(0.0);
    
    for(int i=0; i<100; i++) {
        if(i >= sCount) break;
        
        // Jitter Pattern (Standard Stratified or Halton? Random is fine for jitter)
        // Or simple grid jitter?
        // Using Hash based jitter based on pixel + iteration
        vec2 jitter = (hash22(gl_FragCoord.xy + vec2(float(i)*13.0, float(i)*71.0)) - 0.5); 
        // Sub-pixel range (-0.5 to 0.5)
        
        vec2 samplePos = gl_FragCoord.xy + jitter;
        
        accColor += getSample(samplePos, cellSize, patchMin, patchSizeUV);
    }
    
    vec4 finalColor = accColor / float(sCount);
    
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
