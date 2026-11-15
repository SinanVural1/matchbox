// sv_Lightning
// Copyright (c) 2026 Sinan Vural. MIT License.
// https://github.com/SinanVural1/matchbox/tree/main/shaders/sv_Lightning

uniform float adsk_result_w, adsk_result_h;
uniform float adsk_time;
uniform vec2 p1; // Source (Normalized)
uniform vec2 p2; // Target (Normalized)

// Attributes
uniform int widthProfile; // Curve widget
uniform float width; // Base width pixels
uniform float glow; // Softness
uniform float wiggleSpeed;
uniform float wiggleAmp; // Pixels
uniform float detail; // Noise freq
uniform int branchCount;
uniform float branchLen;
uniform float branchAngle;

// API
float adskEvalDynCurves( int curve, float x );

// Maths
#define PI 3.14159265359

float hash(float n) { return fract(sin(n) * 753.5453123); }

float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash(i), hash(i + 1.0), f);
}

float fbm(float x) {
    float v = 0.0;
    float a = 0.5;
    float shift = float(100);
    for (int i = 0; i < 5; ++i) {
        v += a * noise(x);
        x = x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

// Distance to line segment
float sdSegment(in vec2 p, in vec2 a, in vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

vec2 getBezierPoint(vec2 a, vec2 b, vec2 c, float t) {
    return mix(mix(a, c, t), mix(c, b, t), t);
}

// Derivative of quadratic bezier for normal
vec2 getBezierDerivative(vec2 a, vec2 b, vec2 c, float t) {
    return 2.0 * (1.0 - t) * (c - a) + 2.0 * t * (b - c);
}

// Calculate position on the "Noisy Bolt" at parameter t
vec2 getBoltPos(vec2 A, vec2 B, vec2 C, float t, float shakeTime) {
    vec2 pos = getBezierPoint(A, B, C, t);
    vec2 tangent = normalize(getBezierDerivative(A, B, C, t));
    vec2 normal = vec2(-tangent.y, tangent.x);
    
    // Noise based on t
    float n = fbm(t * detail * 10.0 - shakeTime);
    return pos + normal * (n - 0.5) * wiggleAmp;
}

void main() {
    vec2 res = vec2(adsk_result_w, adsk_result_h);
    vec2 pixel = gl_FragCoord.xy;
    
    vec2 p1_px = p1 * res;
    vec2 p2_px = p2 * res;
    
    // Implicit control point at midpoint (Straight line)
    // To restore curvature later, we'd add the control uniform back.
    vec2 c_px = (p1_px + p2_px) * 0.5;
    
    float time = adsk_time * wiggleSpeed;
    
    float minSurfaceDist = 1e5; // Distance to the surface of the lightning (d - radius)
    
    // Main Bolt Loop
    // Adaptive segments? 
    // Distance p1-p2
    float len = distance(p1_px, p2_px);
    int segments = int(max(10.0, len / 10.0)); // 1 segment per 10 pixels roughly?
    if (segments > 200) segments = 200; // Cap
    
    vec2 prevPos = getBoltPos(p1_px, p2_px, c_px, 0.0, time);
    
    for (int i = 1; i <= segments; i++) {
        float t = float(i) / float(segments);
        vec2 currPos = getBoltPos(p1_px, p2_px, c_px, t, time);
        
        float d_seg = sdSegment(pixel, prevPos, currPos);
        
        // Width at this segment
        // Sample curve at midpoint of t
        float t_mid = (float(i) - 0.5) / float(segments);
        
        // Curve input is usually 0-1.
        float curveVal = adskEvalDynCurves(widthProfile, t_mid);
        float radius = width * 0.5 * curveVal;
        if (radius < 0.0) radius = 0.0;
        
        minSurfaceDist = min(minSurfaceDist, d_seg - radius);
        
        prevPos = currPos;
    }
    
    // Branches
    for (int b = 0; b < branchCount; b++) {
        float seed = float(b) * 12.345;
        float branchT = fract(sin(seed) * 456.78);
        
        vec2 startP = getBoltPos(p1_px, p2_px, c_px, branchT, time);
        
        // Calculate Branch Direction
        vec2 baseT = normalize(getBezierDerivative(p1_px, p2_px, c_px, branchT));
        float angleV = (fract(sin(seed + 1.0) * 100.0) - 0.5) * 2.0; 
        float rads = radians(branchAngle * angleV);
        float c = cos(rads);
        float s = sin(rads);
        vec2 branchDir = vec2(baseT.x * c - baseT.y * s, baseT.x * s + baseT.y * c);
        
        float bLen = branchLen * (0.5 + 0.5 * fract(sin(seed + 2.0) * 100.0));
        vec2 targetEndP = startP + branchDir * bLen;
        
        // Subdivide branch
        int bSegments = 20;
        vec2 bPrev = startP;
        
        for (int j = 1; j <= bSegments; j++) {
            float t = float(j) / float(bSegments);
            vec2 spinePos = mix(startP, targetEndP, t);
            
            // Add noise to branch
            vec2 bNormal = vec2(-branchDir.y, branchDir.x);
            float n = fbm(t * detail * 5.0 + seed * 10.0 - time);
            vec2 currPos = spinePos + bNormal * (n - 0.5) * wiggleAmp * 0.5; // Less amp for branches
            
            float d_seg = sdSegment(pixel, bPrev, currPos);
            
            // Linear taper for branches
            float radius = (width * 0.5 * (1.0 - t)) * 0.5; 
            
            minSurfaceDist = min(minSurfaceDist, d_seg - radius);
            
            bPrev = currPos;
        }
    }
    
    // Rendering
    float core = 1.0 - smoothstep(-0.5, 0.5, minSurfaceDist); // Hard edge core
    
    float gd = max(minSurfaceDist, 0.0);
    float glowVal = glow * width / (gd + 1.0); // Simple falloff
    
    vec3 col = vec3(1.0) * (core + glowVal * 0.3);
    col = clamp(col, 0.0, 1.0);
    
    gl_FragColor = vec4(col, col.r);
}
