// The sun as the camera sees it. Needs common, atmosphere, sky and the scene in colortex0 (before exposure).

// How much of the sun is in view (0..1): its core should be as bright as the sun itself; terrain, clouds and the
// screen edge take that away. All pixels read the same few texels, so it costs little.
float sunVisibility(vec2 sunUv) {
    float expected = luminance(sunDiscColor()) * 1.1;
    if (expected < 1e-3) {
        return 0.0;
    }
    // A square of 5 x 5 samples inside the sun's core (about 1.3 degrees across).
    vec2 radius = 0.011 * vec2(gbufferProjection[0][0], gbufferProjection[1][1]) * 0.5;
    float sum = 0.0;
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 uv = sunUv + vec2(x, y) * 0.5 * radius;
            if (all(greaterThan(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
                sum += saturate(luminance(texture(colortex0, uv).rgb) / expected);
            }
        }
    }
    return smoothstep(0.3, 0.85, sum / 25.0);
}

// Screen position of the sun, and whether it is in front of the camera at all.
bool sunOnScreen(out vec2 sunUv) {
    sunUv = viewToScreen(sunPosition).xy;
    return sunPosition.z < 0.0 && isEyeInWater == 0;
}
