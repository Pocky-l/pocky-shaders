// Water surface: gentle rolling waves with finer ripples (more of them in rain).

float waterHeight(vec2 p) {
    float t = frameTimeCounter;
    float h = 0.0;
    h += valueNoise(p * 0.35 + vec2(t * 0.25, t * 0.12)) * 0.55;
    h += valueNoise(mat2(0.8, -0.6, 0.6, 0.8) * p * 0.8 - vec2(t * 0.35, -t * 0.22)) * 0.3;
    h += valueNoise(mat2(0.6, 0.8, -0.8, 0.6) * p * 1.9 + vec2(-t * 0.5, t * 0.45)) * 0.12;
    h += valueNoise(p * 4.3 + vec2(t * 0.9, t * 0.7)) * (0.04 + 0.08 * rainStrength);
    return h;
}

// World-space normal of the water surface at absolute world position xz.
vec3 waterNormal(vec2 worldXZ, float strength) {
    const float e = 0.08;
    float h = waterHeight(worldXZ);
    float hx = waterHeight(worldXZ + vec2(e, 0.0));
    float hz = waterHeight(worldXZ + vec2(0.0, e));
    float s = 0.22 * WATER_WAVE_STRENGTH * strength;
    return normalize(vec3((h - hx) / e * s, 1.0, (h - hz) / e * s));
}
