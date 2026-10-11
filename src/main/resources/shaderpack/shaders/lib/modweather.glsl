// Weather of the author's other mods - Petrichor (rain types, sun showers, wetness, rainbows, lightning), Hoarfrost
// (snow kinds, blizzards, visibility) and Rustling Leaves (wind and gusts) - so the pack shows the same weather they
// simulate. The mod writes it every frame into a row of float texels (client/weather/ModWeather.java has the layout).
// Every function falls back to vanilla weather when a mod is missing, the option is off or the pack runs without the
// mod (Iris then binds its missing texture, which never carries the marker in texel 7). Included by common.glsl.

uniform sampler2D modWeather;

vec4 modTexel(int i) {
    return texelFetch(modWeather, ivec2(i, 0), 0);
}

bool modWeatherLinked() {
#ifdef MOD_WEATHER
    vec4 marker = modTexel(7);
    return abs(marker.x - 0.123) < 1e-3 && abs(marker.y - 0.456) < 1e-3 && abs(marker.z - 0.789) < 1e-3;
#else
    return false;
#endif
}

bool petrichorLinked() { return modWeatherLinked() && modTexel(0).x > 0.5; }
bool hoarfrostLinked() { return modWeatherLinked() && modTexel(3).x > 0.5; }

// --- Rain (Petrichor) ---------------------------------------------------------------------------------------------

// How much the sun shines through the rain (a sun shower), 0..1.
float sunShower() {
    return petrichorLinked() ? modTexel(0).w : 0.0;
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
    float level = modTexel(0).z * 3.0;
    return level < 1.0 ? mix(0.55, 1.0, level) : (level < 2.0 ? mix(1.0, 1.6, level - 1.0) : mix(1.6, 1.4, level - 2.0));
}

// Gusts of the rain right now (1 = steady): heavier and lighter sheets sweep past.
float rainGust() {
    return petrichorLinked() ? modTexel(2).x : 1.0;
}

// Petrichor's wetness: it follows the rain, its puddles fill and dry with it, and the sun dries it after the rain.
float modWetness() {
    return petrichorLinked() ? modTexel(1).x : vanillaWetness();
}

// Wet ground in sunshine after the rain, 0..1: the air is washed clean and the light glistens.
float afterRain() {
    return saturate(modWetness() * 1.4) * (1.0 - smoothstep(0.0, 0.25, rainStrength));
}

// A lightning flash lighting the clouds and the land, from vanilla bolts or Petrichor's strikes and cloud flashes.
float modFlash() {
    return petrichorLinked() ? min(modTexel(1).w, 1.5) : 0.0;
}

// Rainbow: strength 0..1 and the side of the sky the sun is on (1 east, -1 west). Petrichor decides when there is one
// (sun showers, the end of some rains in daylight); without it one may appear while the land dries after a daytime
// rain, on every other day.
vec2 rainbow(vec3 sunDir) {
    if (petrichorLinked()) {
        vec4 t = modTexel(1);
        return vec2(t.y, t.z);
    }
    float day = floor(float(worldDay) + 0.5);
    float chance = step(0.5, hash12(vec2(day, 3.7)));
    float drying = smoothstep(0.3, 0.6, vanillaWetness()) * (1.0 - smoothstep(0.05, 0.3, rainStrength));
    return vec2(drying * chance * smoothstep(0.0, 0.08, sunDir.y), sunDir.x >= 0.0 ? 1.0 : -1.0);
}

// --- Snow (Hoarfrost) ---------------------------------------------------------------------------------------------

// How hard it snows around the camera, 0..1.
float snowAmount() {
    return hoarfrostLinked() ? modTexel(3).y : rainStrength * snowWeather;
}

// How much of a blizzard it is, 0..1: how much of Hoarfrost's snow streams in the wind (its blizzard kinds), otherwise
// a thunderstorm in snow.
float blizzard() {
    return hoarfrostLinked() ? saturate(modTexel(3).z * modTexel(3).y * 1.2) : snowWeather * thunderStrength;
}

// Hoarfrost's visibility in the snow, in blocks (0 = unknown: the pack's own snow fog).
float snowVisibility() {
    return hoarfrostLinked() && modTexel(3).y > 0.001 ? modTexel(3).w : 0.0;
}

// --- Wind ---------------------------------------------------------------------------------------------------------

bool modWindLinked() { return modWeatherLinked() && modTexel(5).x > 0.5; }

// Horizontal direction the wind blows to: the rain's, the snow's or the leaves' wind, so plants bend the way the rain
// slants and the leaves fly.
vec2 windDirection() {
    return modWindLinked() ? modTexel(5).yz : normalize(vec2(1.0, 0.35));
}

// Strength of the wind for waving plants (about 0.55 in calm weather).
float windAmount() {
    if (modWindLinked()) {
        // Blocks per tick: 0.028 is the leaves' calm breeze, a storm blows 2-3 times as hard, a blizzard far more.
        return clamp(0.55 * pow(modTexel(5).w / 0.028, 0.6), 0.25, 3.0);
    }
    return 0.55 + rainStrength * 0.85 + vanillaWetness() * 0.2;
}

// Gust strength (0.2 .. 1) at a world position. Gust waves travel across the land along the wind; with Rustling
// Leaves they are its very gust waves, so the grass bends exactly when its leaves are blown off.
float windGust(vec2 worldXZ) {
    vec2 dir = windDirection();
    float own;
    if (modWindLinked()) {
        // Carried by the air the mods move (their drift, never "speed x time", which jumps when the wind changes).
        own = valueNoise((worldXZ - modTexel(6).xy * 8.0) * 0.045) * 0.8 + 0.2;
        float leaves = modTexel(6).z;
        if (leaves > 0.0) {
            float s = modTexel(6).w - dot(worldXZ, dir) * 0.05;
            float wave = saturate(0.5 + 0.32 * sin(s) + 0.18 * sin(s * 2.7 + 1.1));
            own = mix(own, 0.2 + 0.8 * wave, leaves);
        }
    } else {
        own = valueNoise(worldXZ * 0.045 - dir * frameTimeCounter * 0.35) * 0.8 + 0.2;
    }
    return own;
}

// How far the air has moved (blocks): mist, rain sheets and blowing snow drift with it.
vec2 windDrift() {
    return modWindLinked() ? modTexel(6).xy : windDirection() * frameTimeCounter;
}
