// Water surface: gentle rolling waves with finer ripples (more of them in rain), caustics and shore foam.

// detail 1 = every octave, 0 = only the broad waves (far water: fine ripples only alias into sparkling pixels).
float waterHeight(vec2 p, float detail) {
    float t = frameTimeCounter;
    float h = 0.0;
    h += valueNoise(p * 0.35 + vec2(t * 0.25, t * 0.12)) * 0.55;
    h += valueNoise(mat2(0.8, -0.6, 0.6, 0.8) * p * 0.8 - vec2(t * 0.35, -t * 0.22)) * 0.3;
    // A storm raises a long, fast swell.
    h += valueNoise(p * 0.12 + vec2(t * 0.3, t * 0.1)) * 1.6 * thunderStrength;
    if (detail > 0.0) {
        h += valueNoise(mat2(0.6, 0.8, -0.8, 0.6) * p * 1.9 + vec2(-t * 0.5, t * 0.45)) * 0.12 * detail;
        h += valueNoise(p * 4.3 + vec2(t * 0.9, t * 0.7)) * (0.04 + 0.08 * rainStrength) * detail * detail;
    }
    return h;
}

// Rings spreading from rain drops on a still puddle (the same pattern as Petrichor's own puddle shader). One drop per
// half-block cell and cycle, a share of the cells active by how hard it rains; each drop leaves a small dimple and a
// ring that widens to about half a block with a couple of crests, fading as it grows. Returns the surface slope.
vec2 rainRipples(vec2 p, float time, float amount) {
    const float CELL = 0.5;
    vec2 q = p / CELL;
    vec2 cell = floor(q);
    vec2 slope = vec2(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 c = cell + vec2(float(x), float(y));
            float period = 0.8 + hash12(c + 17.0) * 0.7;
            float t = time / period + hash12(c);
            float cycle = floor(t);
            float age = fract(t);
            if (hash12(c + vec2(mod(cycle, 61.0) * 7.0, 3.0)) > amount) {
                continue;
            }
            vec2 center = c + 0.15 + 0.7 * vec2(hash12(c + vec2(mod(cycle, 53.0) * 0.37, 5.0)),
                    hash12(c + vec2(9.0, mod(cycle, 47.0) * 0.53)));
            vec2 d = (q - center) * CELL;
            float dist = length(d);
            float s0 = dist - age * 0.6;
            const float WIDTH = 0.045;
            const float K = 6.2832 / 0.05;
            float bell = exp(-s0 * s0 / (WIDTH * WIDTH));
            float dh = bell * (-2.0 * s0 / (WIDTH * WIDTH) * cos(K * s0) - K * sin(K * s0));
            float fade = (1.0 - age) * (1.0 - age);
            float dimple = exp(-dist * dist / 0.0016) * (1.0 - smoothstep(0.0, 0.12, age)) * -2.0 * dist / 0.0016;
            slope += (dh * 0.0045 * fade + dimple * 0.004) * d / (dist + 1e-4);
        }
    }
    return slope;
}

// How much of the rain lands on an open water surface at this distance and sky light (0 = none, rings off).
float rainRingFade(float dist, float skyLight) {
    return rainStrength * (1.0 - snowWeather) * smoothstep(0.7, 0.95, skyLight) * (1.0 - smoothstep(16.0, 48.0, dist));
}

// Slope of the rain rings on water: one drop per half-block cell and cycle at full rain, and in a downpour or a storm
// a second, offset layer of drops in between - a heavy rain covers the water with rings.
vec2 rainRings(vec2 worldXZ, float fade) {
    float heavy = saturate((rainHeaviness() - 0.6) * 0.8 + thunderStrength * 0.6);
    float amount = saturate(rainStrength * (0.75 + 0.35 * heavy));
    vec2 slope = rainRipples(worldXZ, frameTimeCounter, amount);
    if (heavy > 0.0) {
        slope += rainRipples(worldXZ + vec2(0.25, 0.37), frameTimeCounter * 1.13 + 3.1, amount * heavy);
    }
    return slope * fade;
}

// Normal of a rain puddle: still water, with rings from the drops where rain reaches it. Rings smaller than a pixel
// only shimmer, so they fade out in the distance.
vec3 puddleNormal(vec2 worldXZ, float dist, float skyLight) {
    float fade = rainRingFade(dist, skyLight);
    if (fade <= 0.0) {
        return vec3(0.0, 1.0, 0.0);
    }
    vec2 slope = rainRings(worldXZ, fade);
    return normalize(vec3(-slope.x, 1.0, -slope.y));
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
    float s = 0.22 * WATER_WAVE_STRENGTH * strength * (1.0 + 0.5 * rainStrength + 0.6 * thunderStrength);
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

// Whitecaps: foam breaking on the highest crests of storm waves (0..1). Soft streaks a few blocks long that drift with
// the swell - sharp one-block flecks all over the sea read as noise, not foam.
float waterWhitecaps(vec2 worldXZ) {
    if (thunderStrength <= 0.0) {
        return 0.0;
    }
    float crest = smoothstep(0.7, 0.95, waterHeight(worldXZ, 0.0) / (0.85 + 1.6 * thunderStrength) * 1.5);
    float t = frameTimeCounter * 0.25;
    // Two drifting noises break the crest into small patches.
    float patches = smoothstep(0.5, 0.8, valueNoise(worldXZ * 0.45 + vec2(t, -t * 0.6)))
            * smoothstep(0.35, 0.75, valueNoise(mat2(0.8, -0.6, 0.6, 0.8) * worldXZ * 1.3 - vec2(t * 1.3, t)));
    return crest * patches * thunderStrength * thunderStrength;
}
