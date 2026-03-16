#version 430

/*
**MIT License
**
**Copyright (c) 2026
**
**Permission is hereby granted, free of charge, to any person obtaining a copy
**of this software and associated documentation files (the "Software"), to deal
**in the Software without restriction, including without limitation the rights
**to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
**copies of the Software, and to permit persons to whom the Software is
**furnished to do so, subject to the following conditions:
**
**The above copyright notice and this permission notice shall be included in all
**copies or substantial portions of the Software.
**
**THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
**IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
**FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
**AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
**LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
**OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
**SOFTWARE.
*/

layout (location = 0) out vec4 fragColor;

layout (binding = 1) uniform AdskUniformBlock {
    float adsk_result_w, adsk_result_h;
    bool adsk_degrade;
};

layout (binding = 2) uniform UniformBlock {
    uint aa_n;
    uint kernel;
    float sigma;
    bool st;
};

layout (binding = 3) uniform sampler2D front;
layout (binding = 4) uniform sampler2D matte;
layout (binding = 5) uniform sampler2D adsk_results_pass2;

const float gauss_2[] = {.065634503, .434365497};
const float gauss_3[] = {.0109040132, .0547304898, .160252801, .274112696};
const float gauss_4[] = {.00299062441, .00791338883, .0182210823, .0365094075, .0636591827, .0965936183, .127547232, .146565464};
const float gauss_5[] = {.00111100262, .00187962178, .00307044833, .0048429405, .00737551852, .0108455638, .0153988369, .0211105705, .0279439848, .0357151979, .0440751888, .0525184295, .0604234805, .067123752, .0719984597, .0745670039};
const float gauss_6[] = {.000480344139, .000630658485, .000820770493, .00105885129, .00135404766, .00171640067, .00215669707, .00268624343, .00331655597, .00405896255, .0049241186, .0059214452, .00705850412, .0083403328, .00976876895, .0113418016, .01305299, .0148909948, .0168392666, .0188759312, .0209739076, .0231012812, .0252219427, .0272964869, .029283348, .0311401325, .0328250908, .0342986612, .0355250056, .0364734541, .0371197794, .0374472244};

float h;
int o;
float weight;
float weights[64];

vec2 get_coords(const vec2 coords) {
    return texture(adsk_results_pass2, coords / vec2(adsk_result_w, adsk_result_h)).rg;
}

vec4 get_tex(const ivec2 off) {
    const vec2 coords = get_coords(gl_FragCoord.xy + h * (2 * off + o));
    const vec4 color = vec4(texture(front, coords).rgb, texture(matte, coords).b);
    if (bool(kernel))
        return (weights[off.x] * weights[off.y]) * color;
    return weight * color;
}

vec4 get_tex_4() {
    return (get_tex(ivec2(0)) + get_tex(ivec2(1, 0))) + (get_tex(ivec2(0, 1)) + get_tex(ivec2(1)));
}

vec4 get_tex_16() {
    return (((get_tex(ivec2(0)) + get_tex(ivec2(1, 0))) + (get_tex(ivec2(0, 1)) + get_tex(ivec2(1)))) + ((get_tex(ivec2(2, 0)) + get_tex(ivec2(3, 0))) + (get_tex(ivec2(2, 1)) + get_tex(ivec2(3, 1))))) + (((get_tex(ivec2(0, 2)) + get_tex(ivec2(1, 2))) + (get_tex(ivec2(0, 3)) + get_tex(ivec2(1, 3)))) + ((get_tex(ivec2(2)) + get_tex(ivec2(3, 2))) + (get_tex(ivec2(2, 3)) + get_tex(ivec2(3)))));
}

vec4 get_tex_64(const ivec2 off) {
    return (((((get_tex(off) + get_tex(off + ivec2(1, 0))) + (get_tex(off + ivec2(0, 1)) + get_tex(off + 1))) + ((get_tex(off + ivec2(2, 0)) + get_tex(off + ivec2(3, 0))) + (get_tex(off + ivec2(2, 1)) + get_tex(off + ivec2(3, 1))))) + (((get_tex(off + ivec2(0, 2)) + get_tex(off + ivec2(1, 2))) + (get_tex(off + ivec2(0, 3)) + get_tex(off + ivec2(1, 3)))) + ((get_tex(off + 2) + get_tex(off + ivec2(3, 2))) + (get_tex(off + ivec2(2, 3)) + get_tex(off + 3))))) + ((((get_tex(off + ivec2(4, 0)) + get_tex(off + ivec2(5, 0))) + (get_tex(off + ivec2(4, 1)) + get_tex(off + ivec2(5, 1)))) + ((get_tex(off + ivec2(6, 0)) + get_tex(off + ivec2(7, 0))) + (get_tex(off + ivec2(6, 1)) + get_tex(off + ivec2(7, 1))))) + (((get_tex(off + ivec2(4, 2)) + get_tex(off + ivec2(5, 2))) + (get_tex(off + ivec2(4, 3)) + get_tex(off + ivec2(5, 3)))) + ((get_tex(off + ivec2(6, 2)) + get_tex(off + ivec2(7, 2))) + (get_tex(off + ivec2(6, 3)) + get_tex(off + ivec2(7, 3))))))) + (((((get_tex(off + ivec2(0, 4)) + get_tex(off + ivec2(1, 4))) + (get_tex(off + ivec2(0, 5)) + get_tex(off + ivec2(1, 5)))) + ((get_tex(off + ivec2(2, 4)) + get_tex(off + ivec2(3, 4))) + (get_tex(off + ivec2(2, 5)) + get_tex(off + ivec2(3, 5))))) + (((get_tex(off + ivec2(0, 6)) + get_tex(off + ivec2(1, 6))) + (get_tex(off + ivec2(0, 7)) + get_tex(off + ivec2(1, 7)))) + ((get_tex(off + ivec2(2, 6)) + get_tex(off + ivec2(3, 6))) + (get_tex(off + ivec2(2, 7)) + get_tex(off + ivec2(3, 7)))))) + ((((get_tex(off + 4) + get_tex(off + ivec2(5, 4))) + (get_tex(off + ivec2(4, 5)) + get_tex(off + 5))) + ((get_tex(off + ivec2(6, 4)) + get_tex(off + ivec2(7, 4))) + (get_tex(off + ivec2(6, 5)) + get_tex(off + ivec2(7, 5))))) + (((get_tex(off + ivec2(4, 6)) + get_tex(off + ivec2(5, 6))) + (get_tex(off + ivec2(4, 7)) + get_tex(off + ivec2(5, 7)))) + ((get_tex(off + 6) + get_tex(off + ivec2(7, 6))) + (get_tex(off + ivec2(6, 7)) + get_tex(off + 7))))));
}

vec4 get_tex_256(const ivec2 off) {
    vec4 sum = vec4(0.);
    for (int x = 0; x < 9; x += 8) {
        vec4 sum_0 = vec4(0.);
        for (int y = 0; y < 9; y += 8)
            sum_0 += get_tex_64(off + ivec2(x, y));
        sum += sum_0;
    }
    return sum;
}

vec4 get_tex_1024(const ivec2 off) {
    vec4 sum = vec4(0.);
    for (int x = 0; x < 17; x += 16) {
        vec4 sum_0 = vec4(0.);
        for (int y = 0; y < 17; y += 16)
            sum_0 += get_tex_256(off + ivec2(x, y));
        sum += sum_0;
    }
    return sum;
}

vec4 get_tex_4096() {
    vec4 sum = vec4(0.);
    for (int x = 0; x < 33; x += 32) {
        vec4 sum_0 = vec4(0.);
        for (int y = 0; y < 33; y += 32)
            sum_0 += get_tex_1024(ivec2(x, y));
        sum += sum_0;
    }
    return sum;
}

void main() {
    if (st) {
        fragColor = texelFetch(adsk_results_pass2, ivec2(gl_FragCoord.xy), 0);
        return;
    }
    if (aa_n == 0 || adsk_degrade) {
        const vec2 coords = texelFetch(adsk_results_pass2, ivec2(gl_FragCoord.xy), 0).rg;
        fragColor = vec4(texture(front, coords).rgb, texture(matte, coords).b);
        return;
    }
    h = sigma * (bool(kernel) ? 6. : 3.46410162);
    switch (aa_n) {
    case 1:
        h *= .25;
        o = -1;
        if (bool(kernel)) {
            weights[0] = .5;
            weights[1] = .5;
        }
        else
            weight = .25;
        fragColor = get_tex_4();
        return;
    case 2:
        h *= .125;
        o = -3;
        if (bool(kernel)) {
            weights[0] = gauss_2[0];
            weights[1] = gauss_2[1];
            weights[2] = gauss_2[1];
            weights[3] = gauss_2[0];
        }
        else
            weight = .0625;
        fragColor = get_tex_16();
        return;
    case 3:
        h *= .0625;
        o = -7;
        if (bool(kernel)) {
            for (uint i = 0; i < 4; ++i)
                weights[i] = gauss_3[i];
            for (uint i = 4; i < 8; ++i)
                weights[i] = gauss_3[7 - i];
        }
        else
            weight = .015625;
        fragColor = get_tex_64(ivec2(0));
        return;
    case 4:
        h *= .03125;
        o = -15;
        if (bool(kernel)) {
            for (uint i = 0; i < 8; ++i)
                weights[i] = gauss_4[i];
            for (uint i = 8; i < 16; ++i)
                weights[i] = gauss_4[15 - i];
        }
        else
            weight = .00390625;
        fragColor = get_tex_256(ivec2(0));
        return;
    case 5:
        h *= .015625;
        o = -31;
        if (bool(kernel)) {
            for (uint i = 0; i < 16; ++i)
                weights[i] = gauss_5[i];
            for (uint i = 16; i < 32; ++i)
                weights[i] = gauss_5[31 - i];
        }
        else
            weight = .0009765625;
        fragColor = get_tex_1024(ivec2(0));
        return;
    }
    h *= .0078125;
    o = -63;
    if (bool(kernel)) {
        for (uint i = 0; i < 32; ++i)
            weights[i] = gauss_6[i];
        for (uint i = 32; i < 64; ++i)
            weights[i] = gauss_6[63 - i];
    }
    else
        weight = .000244140625;
    fragColor = get_tex_4096();
}
