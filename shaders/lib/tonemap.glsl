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
// display range keeps its hue too, and its excess spills into the weaker channels the way fire burns from red through
// orange to yellow. Spilling towards grey lifted the blue of every bright red-orange: lava and sunsets turned pink.
vec3 hueKeepingCurve(vec3 x) {
    float l = luminance(x);
    float mapped = filmicCurve(vec3(l)).x;
    vec3 c = x * (mapped / max(l, 1e-6));
    float peak = max(c.r, max(c.g, c.b));
    if (peak > 1.0) {
        c /= peak;
        c += (1.0 - c) * c * (0.6 - 0.6 / peak);
    }
    return c;
}

vec3 grade(vec3 color) {
    // Gentle warm white balance: lifts reds, holds back blues. Rain cools it down and takes some colour out - a
    // warm grade turns a grey storm sickly yellow-green.
    float cover = overcast();
#ifdef WEATHER_GRADING
    // Each weather has its own light, all of it close to the game's colours:
    //  - a sun shower: golden sunlight through the rain, a little warmer and richer;
    //  - after the rain: the air washed clean, colours a touch fuller;
    //  - snowy land: a crisp, slightly cool white balance; a blizzard drains the colour out of the white-out.
    float shower = sunShower() * rainStrength;
    float washed = afterRain();
    float white = blizzard();
    float snowLight = snowWeather * (1.0 - 0.5 * cover);
#else
    float shower = 0.0;
    float washed = 0.0;
    float white = 0.0;
    float snowLight = 0.0;
#endif
    float warmth = WARMTH * (1.0 - 0.85 * cover) * (1.0 + 0.6 * shower) * (1.0 - 0.5 * snowLight);
    vec3 warm = vec3(1.0 + 0.015 * warmth, 1.0 + 0.003 * warmth, 1.0 - 0.02 * warmth);
    color *= warm * mix(vec3(1.0), vec3(0.97, 1.0, 1.04), cover) * mix(vec3(1.0), vec3(0.985, 1.0, 1.03), snowLight);
    float l = luminance(color);
    float saturation = SATURATION * (1.0 - 0.12 * cover - 0.13 * stormDarkness() - 0.12 * white)
            * (1.0 + 0.06 * washed + 0.08 * shower);
#ifdef DIM_OVERWORLD
    // Sunrise and sunset are the most colourful moments of the day.
    saturation *= 1.0 + 0.12 * twilightAmount(sunElevation()) * (1.0 - cover);
#endif
    color = max(mix(vec3(l), color, saturation), 0.0);
    return color;
}

vec3 tonemap(vec3 hdr) {
    vec3 graded = grade(hdr);
    return linearToSrgb(saturate(mix(filmicCurve(graded), hueKeepingCurve(graded), 0.75)));
}
