// HDR -> display. A filmic curve (Narkowicz' fit of the ACES reference curve) with soft, warm grading on top.

vec3 filmicCurve(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

vec3 grade(vec3 color) {
    // Gentle warm white balance: lifts reds, holds back blues.
    vec3 warm = vec3(1.0 + 0.04 * WARMTH, 1.0 + 0.01 * WARMTH, 1.0 - 0.05 * WARMTH);
    color *= warm;
    float l = luminance(color);
    color = max(mix(vec3(l), color, SATURATION), 0.0);
    return color;
}

vec3 tonemap(vec3 hdr) {
    return linearToSrgb(filmicCurve(grade(hdr)));
}
