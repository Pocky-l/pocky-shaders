// Reading the baked sky (colortex7, written by the prepare pass). Needs lib/atmosphere.glsl and colortex7.

vec3 sunDirection() {
    return normalize(mat3(gbufferModelViewInverse) * sunPosition);
}

vec3 lightDirection() {
    return normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
}

vec3 sampleSkyLut(vec3 dir, vec3 sunDir) {
    vec2 uv = skyLutCoord(dir, sunDir);
    vec2 texel = uv * vec2(SKY_LUT_SIZE - 1) + 0.5 + vec2(0.0, float(SKY_LUT_ROW));
    return texture(colortex7, texel / vec2(viewWidth, viewHeight)).rgb;
}

// Direct light colour of the current shadow light (sun by day, moon by night).
vec3 directLightColor() {
    return texelFetch(colortex7, PIXEL_LIGHT_COLOR, 0).rgb;
}

// Irradiance from the whole sky on an upward-facing surface.
vec3 ambientLightColor() {
    return texelFetch(colortex7, PIXEL_AMBIENT_COLOR, 0).rgb;
}

// Colour of the sun disc itself (sun illuminance through the air on the way to the eye).
vec3 sunDiscColor() {
    return texelFetch(colortex7, PIXEL_SUN_COLOR, 0).rgb;
}

// A rainbow opposite the sun (Petrichor decides when there is one, see rainbow() in modweather.glsl): the primary bow
// 42 degrees around the point opposite the sun, red outside; a fainter secondary bow at 51 degrees with the colours
// reversed; the sky inside the primary a little brighter and Alexander's band between them a little darker. As in
// Petrichor the bow stands as if the sun were at most 22 degrees high, so it is seen all day, and keeps its side of the
// sky. Its brightness follows the sky behind it (skyColor). Returns rgb to add to the sky.
vec3 rainbowRadiance(vec3 dir, vec3 sunDir, vec3 skyColor) {
#ifdef RAINBOWS
    vec2 bow = rainbow(sunDir);
    if (bow.x <= 0.0 || dir.y <= 0.0) {
        return vec3(0.0);
    }
    // The bow keeps to the side of the sky the sun was on when it appeared; the tilt of the sun path still counts.
    vec2 toSun = normalize(vec2(bow.y * max(abs(sunDir.x), 0.3), sunDir.z));
    float elevation = radians(min(degrees(asin(clamp(sunDir.y, -1.0, 1.0))), 22.0));
    vec3 anti = vec3(-toSun.x * cos(elevation), -sin(elevation), -toSun.y * cos(elevation));
    float angle = degrees(acos(clamp(dot(dir, anti), -1.0, 1.0)));

    // Spectrum from violet (inner edge) to red (outer edge), the same colours as Petrichor's bow.
    const vec3 SPECTRUM[6] = vec3[6](vec3(0.45, 0.25, 0.85), vec3(0.20, 0.35, 1.00), vec3(0.20, 0.85, 0.45),
            vec3(1.00, 0.95, 0.30), vec3(1.00, 0.55, 0.15), vec3(0.95, 0.15, 0.12));
    const float STOPS[6] = float[6](0.0, 0.18, 0.38, 0.58, 0.78, 1.0);

    vec3 light = vec3(0.0);
    for (int b = 0; b < 2; b++) {
        // Primary 40.4..42.6 degrees, secondary 50.2..53.6 (wider, colours reversed).
        float t = b == 0 ? (angle - 40.4) / 2.2 : 1.0 - (angle - 50.2) / 3.4;
        if (t < -0.1 || t > 1.1) {
            continue;
        }
        float u = saturate(t);
        vec3 c = SPECTRUM[0];
        for (int i = 1; i < 6; i++) {
            c = mix(c, SPECTRUM[i], saturate((u - STOPS[i - 1]) / (STOPS[i] - STOPS[i - 1])));
        }
        float band = smoothstep(-0.1, 0.15, t) * (1.0 - smoothstep(0.85, 1.1, t));
        light += c * band * (b == 0 ? 0.5 : 0.18);
    }
    float inside = (1.0 - smoothstep(30.0, 40.4, angle)) * 0.06;
    float alexander = smoothstep(42.6, 44.0, angle) * (1.0 - smoothstep(48.5, 50.2, angle)) * 0.05;
    // Fades into the horizon haze and with the strength Petrichor gives it.
    float strength = bow.x * smoothstep(0.0, 0.12, dir.y) * (1.0 - stormDarkness());
    float sky = luminance(skyColor);
    return (light * sky + vec3(sky) * (inside - alexander)) * strength;
#else
    return vec3(0.0);
#endif
}
