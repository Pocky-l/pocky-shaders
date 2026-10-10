// Wind for waving plants and leaves. Strength grows with rain and storms.

float windStrength() {
    return WIND_STRENGTH * (0.55 + rainStrength * 0.85 + wetness * 0.2);
}

// Horizontal sway offset (blocks) of a point on a plant; worldPos is absolute.
vec3 windSway(vec3 worldPos, float amount) {
    float t = frameTimeCounter;
    float strength = windStrength();
    vec2 dir = normalize(vec2(1.0, 0.35));
    // Slow gusts travel across the land along the wind direction.
    float gust = valueNoise(worldPos.xz * 0.045 - dir * t * 0.35) * 0.8 + 0.2;
    float phase = dot(worldPos.xz, vec2(0.37, 0.29));
    float sway = sin(t * 1.6 + phase) * 0.55 + sin(t * 2.7 + phase * 1.7) * 0.25 + sin(t * 4.9 + phase * 3.1) * 0.1;
    float side = sin(t * 2.1 + phase * 1.3 + 1.7) * 0.35;
    vec2 offset = dir * (sway + gust * 0.9) + vec2(-dir.y, dir.x) * side;
    return vec3(offset.x, 0.0, offset.y) * amount * strength * gust;
}

// Small all-direction rustle for leaf blocks.
vec3 leafRustle(vec3 worldPos, float amount) {
    float t = frameTimeCounter;
    float strength = windStrength();
    float gust = valueNoise(worldPos.xz * 0.045 - vec2(1.0, 0.35) * t * 0.35) * 0.8 + 0.2;
    vec3 p = worldPos * 0.7;
    vec3 o = vec3(sin(t * 2.3 + p.x + p.y * 0.6), sin(t * 3.1 + p.z + p.x * 0.4) * 0.5, sin(t * 2.6 + p.z + p.y * 0.7));
    return o * amount * strength * gust;
}
