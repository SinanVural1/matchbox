uniform sampler2D front;
uniform sampler2D matte;
uniform float adsk_result_w;
uniform float adsk_result_h;
uniform float smear_length;
uniform float smear_angle;
uniform int samples;
uniform float falloff;
uniform float gain;

void main() {
    vec2 resolution = vec2(adsk_result_w, adsk_result_h);
    vec2 uv = gl_FragCoord.xy / resolution;
    
    // Convert angle/length to vector
    float angleRad = radians(smear_angle);
    vec2 direction = vec2(cos(angleRad), sin(angleRad));
    
    // Sample count
    float fSamples = float(samples);
    if (fSamples < 1.0) fSamples = 1.0;
    
    vec2 smearVec = direction * smear_length;
    vec2 step = smearVec / fSamples;

    vec4 color = vec4(0.0);
    
    // We must track the theoretical weight sum of the filter (Kernel)
    // rather than the weight sum of found pixels, to ensure proper decay.
    float totalKernelWeight = 0.0;

    for (int i = 0; i < 100; i++) {
        if (i >= samples) break;
        
        float fi = float(i);
        vec2 samplePos = uv + step * fi;
        
        // Sampling
        vec4 sampleColor = texture2D(front, samplePos);
        float matteVal = texture2D(matte, samplePos).r;
        
        // weighting
        float progress = fi / fSamples; 
        float distWeight = 1.0 - (progress * falloff);
        distWeight = clamp(distWeight, 0.0, 1.0);
        
        // Accumulate Color modulated by Matte
        color += sampleColor * distWeight * matteVal;
        
        // Accumulate Kernel Weight (regardless of Matte presence)
        totalKernelWeight += distWeight;
    }

    if (totalKernelWeight > 0.001) {
        vec4 finalColor = color / totalKernelWeight;
        // Apply Gain
        finalColor.rgb *= gain;
        gl_FragColor = finalColor;
    } else {
        gl_FragColor = texture2D(front, uv);
    }
}
