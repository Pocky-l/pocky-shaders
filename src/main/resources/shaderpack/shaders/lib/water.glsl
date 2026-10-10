// Water surface: gentle rolling waves with finer ripples (more of them in rain), caustics and shore foam.

// detail 1 = every octave, 0 = only the broad waves (far water: fine ripples only alias into sparkling pixels).
float waterHeight(vec2 p, float detail) {
    float t = frameTimeCounter;
    float h = 0.0;
    h += valueNoise(p * 0.35 + vec2(t * 0.25, t * 0.12)) * 0.55;
    h += valueNoise(mat2(0.8, -0.6, 0.6, 0.8) * p * 0.8 - vec2(t * 0.35, -t * 0.22)) * 0.3;
    if (detail > 0.0) {
        h += valueNoise(mat2(0.6, 0.8, -0.8, 0.6) * p * 1.9 + vec2(-t * 0.5, t * 0.45)) * 0.12 * detail;
        h += valueNoise(p * 4.3 + vec2(t * 0.9, t * 0.7)) * (0.04 + 0.08 * rainStrength) * detail * detail;
    }
    return h;
}

// Share of the fine ripples kept at a distance from the camera.
float waterDetail(float dist) {
    return 1.0 - smoothstep(16.0, 72.0, dist);
}

// World-space normal of the water surface at absolute world position xz.
vec3 waterNormal(vec2 worldXZ, float strength, float detail) {
    const float e = 0.08;
    float h = waterHeight(worldXZ, detail);
    float hx = waterHeight(worldXZ + vec2(e, 0.0), detail);
    float hz = waterHeight(worldXZ + vec2(0.0, e), detail);
    float s = 0.22 * WATER_WAVE_STRENGTH * strength;
    return normalize(vec3((h - hx) / e * s, 1.0, (h - hz) / e * s));
}

// Bright wavy lines of sunlight focused by the waves onto the bottom (0..1).
float waterCaustics(vec2 worldXZ) {
    float t = frameTimeCounter * 0.5;
    vec2 p = worldXZ * 0.9;
    float a = valueNoise(p + vec2(t, t * 0.6));
    float b = valueNoise(mat2(0.8, -0.6, 0.6, 0.8) * p * 1.3 - vec2(t * 0.7, -t * 0.4) + 7.0);
    // Where the two moving fields cross, a thin bright vein appears.
    float veins = 1.0 - saturate(abs(a - b) * 5.0);
    return veins * veins * veins;
}

// Broken streaks of foam on very shallow water (0..1).
float waterFoam(vec2 worldXZ) {
    float t = frameTimeCounter * 0.3;
    float n = valueNoise(worldXZ * 1.6 + vec2(t, -t * 0.7)) * 0.65 + valueNoise(worldXZ * 4.1 - vec2(t * 1.3, t)) * 0.35;
    return smoothstep(0.52, 0.72, n);
}
