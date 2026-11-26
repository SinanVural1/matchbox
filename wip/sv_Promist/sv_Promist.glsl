// sv_Promist
// WORK IN PROGRESS: unfinished, not yet brought up to this repo's current standard. See wip/README.md.
// Copyright (c) 2026 Sinan Vural. MIT License.
// https://github.com/SinanVural1/matchbox/tree/main/wip/sv_Promist

uniform sampler2D front;
uniform float adsk_result_w;
uniform float adsk_result_h;
uniform float blur;
uniform float gain;
uniform float threshold;
uniform int samples;
uniform float mix_percent;

void main(void) {
    vec2 resolution = vec2(adsk_result_w, adsk_result_h);
    vec2 uv = gl_FragCoord.xy / resolution;
    
    vec4 srcColor = texture2D(front, uv);
    
    // Accumulate bloom
    vec3 bloomSum = vec3(0.0);
    float weightSum = 0.0;
    
    // Golden Ratio Spiral Sampling
    float goldenAngle = 2.39996323;
    
    for(int i = 0; i < 1000; i++) {
        if (i >= samples) break;
        
        float r = sqrt(float(i) / float(samples)) * blur;
        float theta = float(i) * goldenAngle;
        
        vec2 offset = vec2(cos(theta), sin(theta)) * r;
        
        // Aspect ratio correction? 
        // adsk_result_w/h usually means we are in pixel space if we divide by resolution.
        // If 'blur' is in pixels, we need to scale offset by (1/w, 1/h).
        vec2 sampleUV = uv + (offset / resolution);
        
        // Clamp to edge to avoid wrapping artifacts?
        // Matchbox default GL_CLAMP_TO_EDGE handles excessive UVs usually.
        
        vec3 sampleCol = texture2D(front, sampleUV).rgb;
        
        // Calculate luminance
        float lum = dot(sampleCol, vec3(0.2126, 0.7152, 0.0722));
        
        // Threshold for Shadows
        float shadowVal = max(threshold - lum, 0.0);
        
        // Gaussian falloff based on radius 'r'?
        // The spiral density is uniform-ish in area.
        // We can apply a weight based on 'r' vs 'blur' radius to soften edges.
        // Normalized radius:
        float normDist = r / max(blur, 0.001);
        float w = exp(-(normDist * normDist) * 2.0);
        
        bloomSum += vec3(shadowVal) * w;
        weightSum += w;
    }
    
    vec3 mist = vec3(0.0);
    if(weightSum > 0.0) {
        mist = bloomSum / weightSum;
    }
    
    // Apply gain to the mist
    mist *= gain;
    
    // Composite
    // "Subtraction rather than addition"
    // Darken the image by subtracting the mist.
    vec3 resultRGB = srcColor.rgb - mist;
    
    // Mix with original based on mix_percent
    float m = mix_percent / 100.0;
    resultRGB = mix(srcColor.rgb, resultRGB, m);
    
    gl_FragColor = vec4(resultRGB, srcColor.a);
}
