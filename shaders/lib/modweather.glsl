// Weather of the author's mods - Petrichor (rain types, sun showers, wetness, rainbows, lightning), Hoarfrost (snow
// kinds, blizzards, visibility) and Rustling Leaves (wind and gusts) - so the pack shows the same weather they
// simulate. Each mod publishes its own row of float texels every frame while a shader pack is on (layout in
// docs/shader-data.md of the pack's repository). Every function falls back to vanilla weather when a mod is missing,
// too old to publish or the option is off: Iris then binds its missing texture, which never carries the marker in
// texel 0. Included by common.glsl.

// Before 1.21.5 only (shaders.properties): newer versions get no mod textures, so their weather stays vanilla.
#if MC_VERSION >= 12105
#undef MOD_WEATHER
#endif

uniform sampler2D petrichorData;
uniform sampler2D hoarfrostData;
uniform sampler2D leavesData;

#define PETRICHOR(i) texelFetch(petrichorData, ivec2(i, 0), 0)
#define HOARFROST(i) texelFetch(hoarfrostData, ivec2(i, 0), 0)
#define LEAVES(i) texelFetch(leavesData, ivec2(i, 0), 0)

// Texel 0 of every source: the marker and the format version (1).
bool sourceLinked(vec4 marker) {
    return abs(marker.x - 0.123) < 1e-3 && abs(marker.y - 0.456) < 1e-3 && abs(marker.z - 0.789) < 1e-3 && marker.w > 0.5;
}

bool petrichorLinked() {
#ifdef MOD_WEATHER
    return sourceLinked(PETRICHOR(0));
#else
    return false;
#endif
}

bool hoarfrostLinked() {
#ifdef MOD_WEATHER
    return sourceLinked(HOARFROST(0));
#else
    return false;
#endif
}

bool leavesLinked() {
#ifdef MOD_WEATHER
    return sourceLinked(LEAVES(0));
#else
    return false;
#endif
}

// --- Rain (Petrichor) ---------------------------------------------------------------------------------------------

// How much the sun shines through the rain (a sun shower), 0..1.
float sunShower() {
    return petrichorLinked() ? PETRICHOR(3).z : 0.0;
}

// How much of the sky the rain clouds cover: the rain level, less in a sun shower (blue sky, sunlight, shadows).
// Everything that darkens the sky and the light reads this; what the drops themselves do reads rainStrength.
float overcast() {
    return rainStrength * (1.0 - 0.85 * sunShower());
}

// How thick the rain is next to vanilla's rain (1): a drizzle is a light veil, a downpour a grey wall. Thunder adds its
// own darkness on top (thunderStrength).
float rainHeaviness() {
    if (!petrichorLinked()) {
        return 1.0;
    }
    float level = PETRICHOR(3).y * 3.0;
    return level < 1.0 ? mix(0.55, 1.0, level) : (level < 2.0 ? mix(1.0, 1.6, level - 1.0) : mix(1.6, 1.4, level - 2.0));
}

// Whether Petrichor tags its puddles (mc_Entity.y == 2 on its water cells), so they need not be guessed.
bool petrichorMarksPuddles() {
    return petrichorLinked() && PETRICHOR(5).y > 0.5;
}

// Gusts of the rain right now (1 = steady): heavier and lighter sheets sweep past.
float rainGust() {
    return petrichorLinked() ? PETRICHOR(5).x : 1.0;
}

// Petrichor's wetness: it follows the rain, its puddles fill and dry with it, and the sun dries it after the rain.
float modWetness() {
    return petrichorLinked() ? PETRICHOR(3).w : vanillaWetness();
}

// Wet ground in sunshine after the rain, 0..1: the air is washed clean and the light glistens.
float afterRain() {
    return saturate(modWetness() * 1.4) * (1.0 - smoothstep(0.0, 0.25, rainStrength));
}

// A lightning flash lighting the clouds and the land, from vanilla bolts or Petrichor's strikes and cloud flashes.
float modFlash() {
    return petrichorLinked() ? min(PETRICHOR(4).z, 1.5) : 0.0;
}

// Rainbow: strength 0..1 and the side of the sky the sun is on (1 east, -1 west). Petrichor decides when there is one
// (sun showers, the end of some rains in daylight); without it one may appear while the land dries after a daytime
// rain, on every other day.
vec2 rainbow(vec3 sunDir) {
    if (petrichorLinked()) {
        return PETRICHOR(4).xy;
    }
    float day = floor(float(worldDay) + 0.5);
    float chance = step(0.5, hash12(vec2(day, 3.7)));
    float drying = smoothstep(0.3, 0.6, vanillaWetness()) * (1.0 - smoothstep(0.05, 0.3, rainStrength));
    return vec2(drying * chance * smoothstep(0.0, 0.08, sunDir.y), sunDir.x >= 0.0 ? 1.0 : -1.0);
}

// --- Snow (Hoarfrost) ---------------------------------------------------------------------------------------------

// How hard it snows around the camera, 0..1.
float snowAmount() {
    return hoarfrostLinked() ? HOARFROST(3).x : rainStrength * snowWeather;
}

// How much of a blizzard it is, 0..1: how much of Hoarfrost's snow streams in the wind (its blizzard kinds), otherwise
// a thunderstorm in snow.
float blizzard() {
    return hoarfrostLinked() ? saturate(HOARFROST(3).y * HOARFROST(3).x * 1.2) : snowWeather * thunderStrength;
}

// Hoarfrost's visibility in the snow, in blocks (0 = unknown: the pack's own snow fog).
float snowVisibility() {
    return hoarfrostLinked() && HOARFROST(3).x > 0.001 ? HOARFROST(3).z : 0.0;
}

// Gusts of the snow right now (1 = steady).
float snowGust() {
    return hoarfrostLinked() ? HOARFROST(4).y : 1.0;
}

// --- Wind ---------------------------------------------------------------------------------------------------------
// Each mod blows its own wind and covers a share of the weather: Petrichor the rain, Hoarfrost the snow, Rustling Leaves
// the calm (a missing mod's share goes to one that is there), so the shares of the linked sources add up to 1.
// Texel 1: direction, speed (blocks per tick) and share; texel 2: how far the share-weighted wind has carried the air.

bool modWindLinked() { return petrichorLinked() || hoarfrostLinked() || leavesLinked(); }

// Share-weighted sum of the linked winds: xy = direction (not normalised), z = speed.
vec3 modWind() {
    vec3 sum = vec3(0.0);
    if (petrichorLinked()) {
        vec4 w = PETRICHOR(1);
        sum += w.w * vec3(w.xy, w.z);
    }
    if (hoarfrostLinked()) {
        vec4 w = HOARFROST(1);
        sum += w.w * vec3(w.xy, w.z);
    }
    if (leavesLinked()) {
        vec4 w = LEAVES(1);
        sum += w.w * vec3(w.xy, w.z);
    }
    return sum;
}

// Horizontal direction the wind blows to: the rain's, the snow's or the leaves' wind, so plants bend the way the rain
// slants and the leaves fly.
vec2 windDirection() {
    vec2 calm = normalize(vec2(1.0, 0.35));
    // A tiny calm share keeps the direction defined while two opposite winds hand over.
    return modWindLinked() ? normalize(modWind().xy + calm * 1e-3) : calm;
}

// Strength of the wind for waving plants (about 0.55 in calm weather).
float windAmount() {
    if (modWindLinked()) {
        // Blocks per tick: 0.028 is the leaves' calm breeze, a storm blows 2-3 times as hard, a blizzard far more.
        return clamp(0.55 * pow(max(modWind().z, 0.0) / 0.028, 0.6), 0.25, 3.0);
    }
    return 0.55 + rainStrength * 0.85 + vanillaWetness() * 0.2;
}

// How far the air has moved (blocks): mist, rain sheets and blowing snow drift with it. Each source carries its share,
// so the sum moves smoothly when the weather changes (never "speed x time", which jumps when the wind changes).
vec2 windDrift() {
    if (!modWindLinked()) {
        return windDirection() * frameTimeCounter;
    }
    vec2 drift = vec2(0.0);
    if (petrichorLinked()) {
        drift += PETRICHOR(2).xy;
    }
    if (hoarfrostLinked()) {
        drift += HOARFROST(2).xy;
    }
    if (leavesLinked()) {
        drift += LEAVES(2).xy;
    }
    return drift;
}

// Gust strength (0.2 .. 1) at a world position. Gust waves travel across the land along the wind; with Rustling
// Leaves they are its very gust waves, so the grass bends exactly when its leaves are blown off.
float windGust(vec2 worldXZ) {
    vec2 dir = windDirection();
    float own;
    if (modWindLinked()) {
        own = valueNoise((worldXZ - windDrift() * 8.0) * 0.045) * 0.8 + 0.2;
        float leaves = leavesLinked() ? LEAVES(1).w : 0.0;
        if (leaves > 0.0) {
            float s = LEAVES(3).x - dot(worldXZ, dir) * 0.05;
            float wave = saturate(0.5 + 0.32 * sin(s) + 0.18 * sin(s * 2.7 + 1.1));
            own = mix(own, 0.2 + 0.8 * wave, leaves);
        }
    } else {
        own = valueNoise(worldXZ * 0.045 - dir * frameTimeCounter * 0.35) * 0.8 + 0.2;
    }
    return own;
}
