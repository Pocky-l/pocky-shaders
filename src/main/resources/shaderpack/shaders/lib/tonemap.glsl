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
    // Gentle warm white balance: lifts reds, holds back blues. Rain cools it down and takes some colour out - a
    // warm grade turns a grey storm sickly yellow-green.
    float warmth = WARMTH * (1.0 - 0.85 * rainStrength);
    vec3 warm = vec3(1.0 + 0.04 * warmth, 1.0 + 0.01 * warmth, 1.0 - 0.05 * warmth);
    color *= warm * mix(vec3(1.0), vec3(0.97, 1.0, 1.04), rainStrength);
    float l = luminance(color);
    float saturation = SATURATION * (1.0 - 0.12 * rainStrength - 0.13 * stormDarkness());
#ifdef DIM_OVERWORLD
    // Sunrise and sunset are the most colourful moments of the day.
    saturation *= 1.0 + 0.22 * twilightAmount(sunElevation()) * (1.0 - rainStrength);
#endif
    color = max(mix(vec3(l), color, saturation), 0.0);
    return color;
}

vec3 tonemap(vec3 hdr) {
    return linearToSrgb(filmicCurve(grade(hdr)));
}
