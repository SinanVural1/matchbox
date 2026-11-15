// sv_Triangle_Mosaic
// Copyright (c) 2026 Sinan Vural. MIT License.
// https://github.com/SinanVural1/matchbox/tree/main/shaders/sv_Triangle_Mosaic

//*****************************************************************************/
// 
// Filename: sv_Triangle_Mosaic.glsl
//
// Triangular mosaic effect - working version with new features
//
//*****************************************************************************/

uniform sampler2D front;
uniform float adsk_result_w;
uniform float adsk_result_h;
uniform float triangleSize;
uniform float rotation;
uniform float lineThickness;
uniform float lumScale;
uniform float offsetX;
uniform float offsetY;
uniform bool showUpward;
uniform bool showDownward;

float getLuminance(vec3 color) {
    return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
}

// Signed distance from point p to line segment v1-v2
// We only use the infinite line distance here
float getSignedDist(vec2 p, vec2 v1, vec2 v2) {
    vec2 edge = v2 - v1;
    vec2 diff = p - v1;
    return (diff.x * edge.y - diff.y * edge.x) / length(edge);
}

// Returns signed distance to triangle boundary (positive inside)
float getTriangleSDF(vec2 p, vec2 v1, vec2 v2, vec2 v3) {
    // Calculate centroid to determine "inside" side
    vec2 c = (v1 + v2 + v3) / 3.0;
    
    float d1 = getSignedDist(p, v1, v2);
    float d2 = getSignedDist(p, v2, v3);
    float d3 = getSignedDist(p, v3, v1);
    
    float cd1 = getSignedDist(c, v1, v2);
    float cd2 = getSignedDist(c, v2, v3);
    float cd3 = getSignedDist(c, v3, v1);
    
    // Flip signs so positive is inside
    d1 *= (cd1 >= 0.0 ? 1.0 : -1.0);
    d2 *= (cd2 >= 0.0 ? 1.0 : -1.0);
    d3 *= (cd3 >= 0.0 ? 1.0 : -1.0);
    
    return min(d1, min(d2, d3));
}

void main() {
    vec2 pixel = gl_FragCoord.xy;
    
    // Convert rotation to radians
    float rot = radians(rotation);
    float cosR = cos(rot);
    float sinR = sin(rot);
    
    // Canvas center
    vec2 center = vec2(adsk_result_w, adsk_result_h) * 0.5;
    
    // Triangle dimensions
    float height = triangleSize * sqrt(3.0) / 2.0;
    float rowHeight = height;
    float colWidth = triangleSize / 2.0;
    
    // Apply offset to pixel before inverse rotation
    vec2 offsetPixel = pixel - vec2(offsetX, offsetY);
    
    // Inverse rotate the current pixel
    vec2 pixelFromCenter = offsetPixel - center;
    vec2 unrotatedPixel = vec2(
        pixelFromCenter.x * cosR + pixelFromCenter.y * sinR,
        -pixelFromCenter.x * sinR + pixelFromCenter.y * cosR
    );
    
    // Find approximate grid cell
    float row = floor(unrotatedPixel.y / rowHeight);
    float col = floor(unrotatedPixel.x / colWidth);
    
    vec4 accColor = vec4(0.0);
    float accWeight = 0.0;
    
    // Check neighborhood to accumulate color contributions (Anti-Aliasing)
    for (float r = -1.0; r <= 2.0; r += 1.0) {
        for (float c = -2.0; c <= 2.0; c += 1.0) {
            float testRow = row + r;
            float testCol = col + c;
            
            float baseX = testCol * colWidth;
            float baseY = testRow * rowHeight;
            float offset = (mod(testRow + 1000.0, 2.0) < 1.0) ? 0.0 : colWidth;
            
            bool isUpward = mod(testCol + 1000.0, 2.0) < 1.0;
            
            if (isUpward && !showUpward) continue;
            if (!isUpward && !showDownward) continue;
            
            vec2 v1, v2, v3;
            
            if (isUpward) {
                v1 = vec2(baseX + offset, baseY + height);
                v2 = vec2(baseX + triangleSize / 2.0 + offset, baseY);
                v3 = vec2(baseX + triangleSize + offset, baseY + height);
            } else {
                v1 = vec2(baseX + offset, baseY);
                v2 = vec2(baseX + triangleSize / 2.0 + offset, baseY + height);
                v3 = vec2(baseX + triangleSize + offset, baseY);
            }
            
            // Check bounding box optimization
            vec2 minV = min(v1, min(v2, v3)) - vec2(2.0);
            vec2 maxV = max(v1, max(v2, v3)) + vec2(2.0);
            if (unrotatedPixel.x < minV.x || unrotatedPixel.x > maxV.x ||
                unrotatedPixel.y < minV.y || unrotatedPixel.y > maxV.y) {
                continue;
            }

            // Calculate Grid SDF (for line thickness and base shape)
            float gridSDF = getTriangleSDF(unrotatedPixel, v1, v2, v3);
            
            // Optimization: if far outside, skip
            if (gridSDF < -1.5) continue; 
            
            // Get color from center
            vec2 triCenter = (v1 + v2 + v3) / 3.0;
            vec2 rotatedCenter = center + vec2(
                triCenter.x * cosR - triCenter.y * sinR,
                triCenter.x * sinR + triCenter.y * cosR
            );
            rotatedCenter = rotatedCenter + vec2(offsetX, offsetY);
            
            vec2 sampleCoords = rotatedCenter / vec2(adsk_result_w, adsk_result_h);
            sampleCoords = clamp(sampleCoords, vec2(0.0), vec2(1.0));
            vec3 triColor = texture2D(front, sampleCoords).rgb;
            
            // Base Alpha from shape
            // Start with alpha 1.0 inside
            float finalAlpha = 1.0;
            
            // Apply Lum Scale (modifies shape)
            if (lumScale > 0.0) {
                float lum = getLuminance(triColor);
                float sizeMultiplier = 0.1 + lum * (1.0 + lumScale);
                
                vec2 sv1 = vec2(baseX + offset, isUpward ? baseY + height : baseY); 
                // Wait, need to reconstruct correctly.
                // Re-using v1, v2, v3 helps avoid copy-paste errors
                // But we need to scale relative to center
                
                vec2 scaledCenter = triCenter; // (v1+v2+v3)/3.0
                vec2 s_v1 = scaledCenter + (v1 - scaledCenter) * sizeMultiplier;
                vec2 s_v2 = scaledCenter + (v2 - scaledCenter) * sizeMultiplier;
                vec2 s_v3 = scaledCenter + (v3 - scaledCenter) * sizeMultiplier;
                
                float shapeSDF = getTriangleSDF(unrotatedPixel, s_v1, s_v2, s_v3);
                
                // Combine SDFs?
                // Actually if lumScale is used, the shape IS the scaled shape.
                // The grid lines (if used) are usually cut from the base grid or the shape?
                // Original code: applied lum scale valid check, THEN applied line thickness check (on original?)
                // Line 201 in original used v1, v2, v3 (original).
                // So we intersect the scaled shape with the grid lines.
                
                float shapeAlpha = smoothstep(-0.5, 0.5, shapeSDF);
                finalAlpha *= shapeAlpha;
            } else {
                // Just use grid SDF for main shape edge
                finalAlpha *= smoothstep(-0.5, 0.5, gridSDF);
            }
            
            // Apply Line Thickness (cuts into the shape)
            if (lineThickness > 0.0) {
                // limit = lineThickness * 0.01 * triangleSize ??
                // The original logic: minDist = dist / triangleSize.
                // Check: minDist < lineThickness * 0.01
                // So: dist < lineThickness * 0.01 * triangleSize.
                float cutDist = lineThickness * 0.01 * triangleSize;
                
                // We want to be black if dist < cutDist.
                // Alpha should fade from 0 to 1 around cutDist.
                // SDF decreases as we get closer to edge.
                // We want alpha 0 when gridSDF < cutDist.
                // Smoothstep: edge0 = cutDist - 0.5, edge1 = cutDist + 0.5.
                // value = gridSDF.
                
                float lineAlpha = smoothstep(cutDist - 0.5, cutDist + 0.5, gridSDF);
                finalAlpha *= lineAlpha;
            }
            
            accColor += vec4(triColor, 1.0) * finalAlpha;
            accWeight += finalAlpha;
        }
    }
    
    // Since we are creating a mosaic over black, we just output the accumulated color.
    // However, if we want to support partial coverage (e.g. edges of the whole image), we might care about weight.
    // For standard "black background" mosaic:
    gl_FragColor = vec4(accColor.rgb, 1.0);
}