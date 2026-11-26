// sv_Hypot
// WORK IN PROGRESS: unfinished, not yet brought up to this repo's current standard. See wip/README.md.
// Copyright (c) 2026 Sinan Vural. MIT License.
// https://github.com/SinanVural1/matchbox/tree/main/wip/sv_Hypot

uniform sampler2D front;
uniform sampler2D back;
uniform float adsk_result_w;
uniform float adsk_result_h;
uniform float strength;

void main(void) {
    vec2 resolution = vec2(adsk_result_w, adsk_result_h);
    vec2 uv = gl_FragCoord.xy / resolution;
    
    vec4 f = texture2D(front, uv);
    vec4 b = texture2D(back, uv);
    
    // hypot = sqrt(x*x + y*y)
    // We apply this storage-wise (per channel)
    vec3 result = sqrt(f.rgb * f.rgb + b.rgb * b.rgb);
    
    // For alpha, we can either do max, blend, or hypot it as well.
    // Usually blend modes preserve original alpha or operate on it.
    // Let's assume standard over-like behavior or just pass through Front alpha?
    // "Result is the hypot blending of foreground over the background"
    // Let's do hypot on alpha too for consistency unless specified otherwise,
    // or typically matchbox shaders output 1.0 or source alpha. 
    // Given the math nature, let's process alpha same as RGB.
    float resultAlpha = sqrt(f.a * f.a + b.a * b.a);

    vec4 finalResult = vec4(result, resultAlpha);
    
    // Mix based on strength
    // 0 = background (back), 100 = hypot blend
    float mixVal = strength / 100.0;
    gl_FragColor = mix(b, finalResult, mixVal);
}
