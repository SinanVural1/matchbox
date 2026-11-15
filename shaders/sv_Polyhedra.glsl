uniform float adsk_time;
uniform float adsk_result_w, adsk_result_h;
uniform float adsk_result_frameratio;

uniform int Type; // default=3, min=3, max=5
uniform float U_bary; // Using U_bary to avoid clash with global U
uniform float V_bary;
uniform float W_bary;
uniform float Mix_Shape;
uniform bool Show_Faces;
uniform bool Show_Segments;
uniform bool Show_Vertices;
uniform vec3 Rotation; // X, Y, Z rotation
uniform float FOV;
uniform float Object_Scale;
uniform float Vertex_Radius;
uniform float Segment_Radius;

// Colors Page Uniforms
uniform vec3 Face_Color_1, Face_Color_2, Face_Color_3;
uniform float Face_Alpha_1, Face_Alpha_2, Face_Alpha_3;
uniform vec3 Edge_Color, Vertex_Color;
uniform float Edge_Alpha, Vertex_Alpha;
// uniform int Blend_Mode; -- Replaced by per-feature blend modes
uniform int Blend_Mode_Face_1, Blend_Mode_Face_2, Blend_Mode_Face_3;
uniform int Blend_Mode_Edge, Blend_Mode_Vertex;

struct MaterialData {
    vec3 color;
    float alpha;
    int blendMode;
};

#define PI	3.14159265359
#define PI2	( PI * 2.0 )

// Global variables for folding
vec3 nc,p,pab,pbc,pca;
// SRadius and VRadius are now uniforms called Segment_Radius and Vertex_Radius

void init_poly() {
    // setup folding planes and vertex
    // Type is int 3..5
    float fType = float(Type);
    
    float cospin = cos(PI/fType);
    float scospin = sqrt(0.75 - cospin*cospin);
    
    nc = vec3(-0.5, -cospin, scospin); // 3rd folding plane
    pab = vec3(0., 0., 1.);
    pbc = vec3(scospin, 0., 0.5);
    pca = vec3(0., scospin, cospin);
    
    p = normalize((U_bary * pab + V_bary * pbc + W_bary * pca));
    pbc = normalize(pbc);
    pca = normalize(pca);
}

vec3 fold(vec3 pos) {
    for(int i=0; i<5; i++){
        pos.xy = abs(pos.xy); // fold about xz and yz planes
        pos -= 2. * min(0., dot(pos, nc)) * nc; // fold about nc plane
    }
    return pos;
}

float D2Planes(vec3 pos) {
    pos -= p;
    float d0 = dot(pos, pab);
    float d1 = dot(pos, pbc);
    float d2 = dot(pos, pca);
    return max(max(d0, d1), d2);
}

float length2(vec3 p) { return dot(p, p); }

float D2Segments(vec3 pos) {
    pos -= p;
    float dla = length2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = length2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = length2(pos - min(0., dot(pos, nc)) * nc);
    return sqrt(min(min(dla, dlb), dlc)) - Segment_Radius / Object_Scale;
}

float D2Vertices(vec3 pos) {
    return length(pos - p) - Vertex_Radius / Object_Scale;
}

float Polyhedron(vec3 pos) {
    pos = fold(pos);
    float d = 10000.;
    if(Show_Faces) d = min(d, D2Planes(pos));
    if(Show_Segments) d = min(d, D2Segments(pos));
    if(Show_Vertices) d = min(d, D2Vertices(pos));
    return d;
}

MaterialData getColor(vec3 pos) {
    MaterialData result = MaterialData(Face_Color_1, Face_Alpha_1, Blend_Mode_Face_1); // Default to Face 1

    pos = fold(pos);
    float df = 1000., dv = 1000., ds = 1000.;
    
    if(Show_Faces) {
        float d0 = dot(pos - p, pab);
        float d1 = dot(pos - p, pbc);
        float d2 = dot(pos - p, pca);
        df = max(max(d0, d1), d2);
    }
    if(Show_Segments) ds = D2Segments(pos);
    if(Show_Vertices) dv = D2Vertices(pos);
    
    float d = min(df, min(ds, dv));
    float eps = 0.0001; // Epsilon for comparisons

    if(abs(d - df) < eps) {
        float d0 = dot(pos - p, pab);
        float d1 = dot(pos - p, pbc);
        float d2 = dot(pos - p, pca);
        
        // d0 default logic above
        if(abs(d - d1) < eps) result = MaterialData(Face_Color_2, Face_Alpha_2, Blend_Mode_Face_2);
        if(abs(d - d2) < eps) result = MaterialData(Face_Color_3, Face_Alpha_3, Blend_Mode_Face_3);
    } 
    
    // Check overlays with epsilon
    if(abs(d - ds) < eps) result = MaterialData(Edge_Color, Edge_Alpha, Blend_Mode_Edge);
    if(abs(d - dv) < eps) result = MaterialData(Vertex_Color, Vertex_Alpha, Blend_Mode_Vertex);
    
    return result;
}

vec2 rotate(in vec2 p, in float t) {
    return p * cos(-t) + vec2(p.y, -p.x) * sin(-t);
}

float map(in vec3 p) {
    // Apply object scaling
    // d = map(p/scale) * scale
    vec3 p_scaled = p / Object_Scale;
    float d = mix(length(p_scaled) - 1., Polyhedron(p_scaled), Mix_Shape);
    return d * Object_Scale;
}

vec3 blendColors(vec3 dest, vec3 src, int mode) {
    if (mode == 0) return src; // Normal (handled by alpha mix in accumulator)
    if (mode == 1) return dest + src; // Add
    if (mode == 2) { // Overlay
        vec3 res;
        for (int i=0; i<3; i++) {
            res[i] = dest[i] < 0.5 ? (2.0 * dest[i] * src[i]) : (1.0 - 2.0 * (1.0 - dest[i]) * (1.0 - src[i]));
        }
        return res;
    }
    if (mode == 3) return 1.0 - (1.0 - dest) * (1.0 - src); // Screen
    if (mode == 4) return max(vec3(0.0), dest - src); // Subtract
    return src;
}

vec3 calcNormal(in vec3 p) {
    const vec2 e = vec2(0.0001, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)));
}

float march(in vec3 ro, in vec3 rd) {
    const float maxd = 5.0;
    const float precis = 0.001;
    float h = precis * 2.0;
    float t = 0.0;
    float res = -1.0;
    for(int i = 0; i < 128; i++) {
        if(h < precis * t || t > maxd) break;
        h = map(ro + rd * t);
        t += h;
    }
    if(t < maxd) res = t;
    return res;
}

vec3 transform(in vec3 p) {
    p.zx = rotate(p.zx, -Rotation.x * PI / 180.0);
    p.yz = rotate(p.yz, Rotation.y * PI / 180.0);
    p.xy = rotate(p.xy, Rotation.z * PI / 180.0);
    return p;
}

void main(void) {
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 R = vec2(adsk_result_w, adsk_result_h);
    if (R.y < 1.0) { R = vec2(1920.0, 1080.0); } // Fallback to avoid div by zero if uniform not bound yet
    
    vec2 p_coord = (2.0 * fragCoord - R) / R.y;
    vec3 col = vec3(0.3 + p_coord.y * 0.1);
    
    // FOV calculation
    float tanHalfFov = tan(radians(FOV) / 2.0);
    vec3 rd = normalize(vec3(p_coord * tanHalfFov, -1.0));
    
    vec3 ro = vec3(0.0, 0.0, 2.5);
    vec3 li = normalize(vec3(0.5, 0.8, 3.0));
    
    // Apply camera rotation
    ro = transform(ro);
    rd = transform(rd);
    li = transform(li);
    
    init_poly();
    
    // Accumulation variables
    vec3 accColor = vec3(0.0);
    float accAlpha = 0.0;
    
    float t = 0.0;
    const float maxd = 10.0;
    const float precis = 0.001;
    
    // Multi-hit Raymarch Loop for Transparency
    for(int i = 0; i < 128; i++) {
        if(accAlpha >= 0.99 || t > maxd) break;
        
        vec3 p = ro + t * rd;
        float d = map(p);
        
        // If we hit a surface (within precision)
        if(d < precis) {
             vec3 n = calcNormal(p);
             float dif = clamp(dot(n, li), 0.0, 1.0);
             
             // Get material color and alpha
             MaterialData mat = getColor(p / Object_Scale);
             vec3 surfColor = mat.color;
             float surfAlpha = mat.alpha;
             int blendMode = mat.blendMode;
             
             // Apply lighting
             surfColor = surfColor * dif + .5 * pow(dif, 200.);
             surfColor = pow(surfColor, vec3(0.45));
             
             // Accumulated Alpha logic (Front-to-back)
             // a_out = a_in + (1 - a_in) * a_new
             float alphaContribution = (1.0 - accAlpha) * surfAlpha;
             
             // Blend Modes handling
             // Normal blending uses alpha correctly
             // Other modes might need specific handling, effectively operating on the "contribution"
             if (blendMode == 0) { // Normal
                 accColor += surfColor * alphaContribution;
             } else {
                 // For additive/overlay/etc, we treat standard alpha blending as base, 
                 // but mix the color math. 
                 // Simplified: Calculate blended result of (CurrentAcc vs New), then add weighted by alpha
                 vec3 blended = blendColors(accColor, surfColor, blendMode);
                 // This is tricky in forward loop. Standard comp: C_out = C_in + (1-A_in)*C_new*A_new
                 // We will simply modify the added color based on mode
                 if(blendMode == 1) accColor += surfColor * surfAlpha; // Pure Additive ignoring occlusion for glow feels
                 else accColor += blended * alphaContribution; // Fallback for others
             }
             
             accAlpha += alphaContribution;
             
             // Push ray forward to escape surface and find next hit
             t += max(precis * 2.0, 0.02); 
        } else {
            // Standard raymarch step
            t += d;
        }
    }
    
    gl_FragColor = vec4(accColor, accAlpha);
}
