// HDR -> display. A filmic curve (Narkowicz' fit of the ACES reference curve) with a lifted toe, applied mostly to
// luminance so colours keep their hue like in vanilla, with soft, slightly warm grading on top.

vec3 filmicCurve(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    // The plain fit crushes the darks (slope 0.2 at black); vanilla keeps shaded places and dim light readable.
    vec3 toe = 0.3 * x * exp(-6.0 * x);
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e) + toe);
}

// Per channel, the curve shifts hues as channels saturate: an orange low sun turned lemon yellow and saturated greens
// went yellowish. Scaling the colour by the curve of its luminance keeps the hue; a colour that would leave the
// display range keeps its hue too, with a little desaturation towards white.
vec3 hueKeepingCurve(vec3 x) {
    float l = luminance(x);
    float mapped = filmicCurve(vec3(l)).x;
    vec3 c = x * (mapped / max(l, 1e-6));
    float peak = max(c.r, max(c.g, c.b));
    if (peak > 1.0) {
        vec3 desaturated = mix(c, vec3(mapped), (peak - 1.0) / max(peak - mapped, 1e-6));
        c = mix(c / peak, desaturated, 0.4);
    }
    return c;
}

vec3 grade(vec3 color) {
    // Gentle warm white balance: lifts reds, holds back blues. Rain cools it down and takes some colour out - a
    // warm grade turns a grey storm sickly yellow-green.
    float warmth = WARMTH * (1.0 - 0.85 * rainStrength);
    vec3 warm = vec3(1.0 + 0.015 * warmth, 1.0 + 0.003 * warmth, 1.0 - 0.02 * warmth);
    color *= warm * mix(vec3(1.0), vec3(0.97, 1.0, 1.04), rainStrength);
    float l = luminance(color);
    float saturation = SATURATION * (1.0 - 0.12 * rainStrength - 0.13 * stormDarkness());
#ifdef DIM_OVERWORLD
    // Sunrise and sunset are the most colourful moments of the day.
    saturation *= 1.0 + 0.12 * twilightAmount(sunElevation()) * (1.0 - rainStrength);
#endif
    color = max(mix(vec3(l), color, saturation), 0.0);
    return color;
}

vec3 tonemap(vec3 hdr) {
    vec3 graded = grade(hdr);
    return linearToSrgb(saturate(mix(filmicCurve(graded), hueKeepingCurve(graded), 0.75)));
}
