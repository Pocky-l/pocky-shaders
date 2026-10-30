// Shared uniforms and small helpers. Included first by every program.

#include "/settings.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;
uniform float thunderStrength;
// Custom uniform (shaders.properties): 1 while it snows at the camera instead of raining, eased over a few seconds.
uniform float snowWeather;
// 1 in swamps, 0.6 at rivers (custom uniform, shaders.properties): ground mist covers them.
uniform float mistBiome;
// Iris: a lightning bolt relative to the camera, w = 1 while one exists.
uniform vec4 lightningBoltPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;
uniform float screenBrightness;

uniform int worldTime;
uniform int worldDay;
uniform int moonPhase;
uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int frameCounter;

uniform ivec2 eyeBrightnessSmooth;

float saturate(float x);
float hash12(vec2 p);
float valueNoise(vec2 p);

// Vanilla's wetness; everything else reads "wetness", which becomes Petrichor's when it is linked (modweather.glsl).
float vanillaWetness() { return wetness; }
#define wetness modWetness()
#include "/lib/modweather.glsl"

const float PI = 3.14159265;

// Material ids written to the gbuffers (stored as id / 255).
const int MAT_DEFAULT = 0;
const int MAT_PLANT = 1;
const int MAT_LEAVES = 2;
const int MAT_EMISSIVE = 3;
const int MAT_WATER = 4;
const int MAT_GLASS = 5;
const int MAT_ENTITY = 6;
const int MAT_HAND = 7;
const int MAT_PARTICLE = 8;

// block.properties ids (mc_Entity.x); modded blocks join them through block tags there.
const int ID_PLANT = 10001;         // single-block plants: grass, flowers, saplings, crops
const int ID_PLANT_LOWER = 10002;   // lower half of tall plants
const int ID_PLANT_UPPER = 10003;   // upper half of tall plants
const int ID_LEAVES = 10004;
const int ID_VINE = 10005;          // hanging plants: vines, glow lichen, cave vines
const int ID_LILY = 10006;          // lily pads and other plants floating on water
const int ID_EMISSIVE = 10010;      // blocks that emit light
const int ID_EMISSIVE_PLANT = 10011;
const int ID_WATER = 10020;
const int ID_FLOWING_WATER = 10024;
const int ID_ICE = 10021;
const int ID_GLASS = 10022;
const int ID_LAVA = 10023;
const int ID_METAL = 10030;         // iron, gold, netherite, fresh copper: blocks and metal parts
const int ID_PATINA = 10031;        // weathered and oxidized copper
const int ID_POLISHED = 10032;      // polished stone, quartz, concrete, glazed terracotta, obsidian
const int ID_GEM = 10033;           // diamond, emerald, amethyst, lapis, redstone blocks
const int ID_GROUND = 10034;        // dirt, sand, gravel, snow, wool: matte through and through

// How a block's surface takes the light: x roughness (0 = mirror, 1 = chalk), y reflectance at normal incidence (F0
// of a dielectric; for a metal the strength of its own coloured reflection), z 1 for metals. The game's textures were
// painted for flat, matte light, so even the shiny blocks stay well short of a real mirror: they catch the sun and
// show the sky and the world faintly, the rest of them keeps its vanilla look.
vec3 blockFinish(int id) {
    if (id == ID_METAL) {
        return vec3(0.42, 0.65, 1.0);
    }
    if (id == ID_PATINA) {
        return vec3(0.72, 0.25, 1.0);
    }
    if (id == ID_POLISHED) {
        return vec3(0.32, 0.04, 0.0);
    }
    if (id == ID_GEM) {
        return vec3(0.26, 0.07, 0.0);
    }
    if (id == ID_GROUND) {
        return vec3(1.0, 0.0, 0.0);
    }
    // Stone, wood, bricks and the rest: rough and matte.
    return vec3(0.9, 0.02, 0.0);
}

// Reflection data for the composite pass in the fourth channel of colortex1: how strongly the surface mirrors its
// surroundings (0..1, 8 bits), its roughness (7 bits) and whether it is a metal (its reflection takes its colour).
float encodeGloss(float weight, float roughness, float metal) {
    return (floor(saturate(weight) * 255.0 + 0.5) * 256.0 + floor(saturate(roughness) * 127.0 + 0.5)
            + step(0.5, metal) * 128.0) / 65535.0;
}

vec3 decodeGloss(float data) {
    float v = floor(data * 65535.0 + 0.5);
    float low = mod(v, 256.0);
    return vec3(floor(v / 256.0) / 255.0, mod(low, 128.0) / 127.0, step(128.0, low));
}

// Beyond these distances (blocks) effects nobody can make out are skipped.
const float ANIMATION_DISTANCE = 64.0;
const float DETAIL_DISTANCE = 64.0;

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec2 saturate(vec2 x) { return clamp(x, 0.0, 1.0); }
vec3 saturate(vec3 x) { return clamp(x, 0.0, 1.0); }
vec4 saturate(vec4 x) { return clamp(x, 0.0, 1.0); }
float sqr(float x) { return x * x; }

// How dark the weather is: a thunderstorm in rain is dark; the same weather in snow is a blizzard, a bright white-out.
float stormDarkness() { return thunderStrength * (1.0 - snowWeather); }

// The game's Brightness option (0 = Moody, 0.5 = default, 1 = Bright) as a factor on the darkest light: like vanilla
// it lifts dark places, from about half to about twice the default.
float brightnessLift() { return mix(0.5, 2.0, screenBrightness) / 1.25; }

// How clearly the sun (or moon) disc itself shows: highlights mirror the disc, and behind a rain or storm deck there is
// none to mirror - only the dim light that comes through the clouds, which lights surfaces but makes no glints.
float discClarity() { return (1.0 - overcast()) * (1.0 - thunderStrength); }

// 1 in the morning half of the day (midnight to noon: sunrise), 0 in the evening half (sunset). worldTime 0 is 6:00.
float morning() {
    return (worldTime >= 18000 || worldTime < 6000) ? 1.0 : 0.0;
}

// Sine of the sun's elevation (world space).
float sunElevation() {
    return normalize(mat3(gbufferModelViewInverse) * sunPosition).y;
}

// The dawn haze: about an in-game hour around sunrise (6:00, worldTime 0) it builds up, lies over the whole world and
// clears again, all smoothly. Rain brings its own fog instead.
float dawnHaze() {
    float ticks = mod(float(worldTime) + 1000.0, 24000.0) - 1000.0;
    return smoothstep(-750.0, -300.0, ticks) * (1.0 - smoothstep(250.0, 750.0, ticks)) * (1.0 - rainStrength);
}

// Foggy mornings: on some days (about one in four, every other day after a rain) a thick, low fog lies over the land
// from the small hours and burns off by mid-morning. 0..1.
float foggyMorning() {
    // The night before belongs to the morning it leads to.
    float day = float(worldDay) + (worldTime >= 18000 ? 1.0 : 0.0);
    float chance = 0.25 + 0.25 * saturate(wetness * 2.0);
    float foggy = step(hash12(vec2(day, 4.17)), chance);
    // Ticks from 6:00 (sunrise), from -6000 (0:00) to 18000.
    float ticks = mod(float(worldTime) + 6000.0, 24000.0) - 6000.0;
    float time = smoothstep(-4500.0, -2000.0, ticks) * (1.0 - smoothstep(1500.0, 3800.0, ticks));
    return foggy * time * (1.0 - rainStrength);
}

// The morning fog lies low: thick on the ground and in the valleys, thin a dozen blocks up, gone over the hills.
const float MORNING_FOG_DENSITY = 0.03;
const float MORNING_FOG_FALLOFF = 0.085;

// Optical depth of the morning fog along a ray from the camera to playerPos (exact integral of its height profile).
float morningFogDepth(vec3 playerPos) {
    float fog = foggyMorning();
    if (fog <= 0.0) {
        return 0.0;
    }
    float dy = playerPos.y * MORNING_FOG_FALLOFF;
    float height = exp(-max(cameraPosition.y - 63.0, -8.0) * MORNING_FOG_FALLOFF)
            * (abs(dy) > 1e-3 ? (1.0 - exp(-dy)) / dy : 1.0);
    return length(playerPos) * fog * MORNING_FOG_DENSITY * clamp(height, 0.0, 2.2) * FOG_DENSITY;
}

// How many blocks of water lie above the eye while under water, from the sky light that reaches it (water dims the
// sky light by one level per block).
float eyeWaterDepth() {
    return (1.0 - float(eyeBrightnessSmooth.y) / 240.0) * 15.0;
}

// How hard it snows (0 in rain).
float snowfall() { return rainStrength * snowWeather; }
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

vec3 projectAndDivide(mat4 m, vec3 p) {
    vec4 h = m * vec4(p, 1.0);
    return h.xyz / h.w;
}

vec3 screenToView(vec3 screenPos) {
    return projectAndDivide(gbufferProjectionInverse, screenPos * 2.0 - 1.0);
}

vec3 viewToScreen(vec3 viewPos) {
    return projectAndDivide(gbufferProjection, viewPos) * 0.5 + 0.5;
}

float linearizeDepth(float depth) {
    return (2.0 * near * far) / (far + near - (depth * 2.0 - 1.0) * (far - near));
}

// Octahedral normal encoding into [0, 1]^2.
vec2 encodeNormal(vec3 n) {
    n /= abs(n.x) + abs(n.y) + abs(n.z);
    vec2 e = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    return e * 0.5 + 0.5;
}

vec3 decodeNormal(vec2 e) {
    e = e * 2.0 - 1.0;
    vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
    float t = saturate(-n.z);
    n.xy += vec2(n.x >= 0.0 ? -t : t, n.y >= 0.0 ? -t : t);
    return normalize(n);
}

// Interleaved gradient noise: cheap per-pixel dither that varies smoothly between frames.
float dither(vec2 fragCoord) {
    return fract(52.9829189 * fract(dot(fragCoord + float(frameCounter % 64) * 5.588238, vec2(0.06711056, 0.00583715))));
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Water normal, foam and block light in two 16-bit channels of colortex4: each channel holds 11 bits of the octahedral
// normal, 2 bits of the 4-bit foam amount and 3 bits of the 6-bit block light (both 0..1). Block light needs the finer
// steps: with 4 bits the glow of a lamp in the water broke into hard bands.
vec2 encodeWaterNormal(vec3 n, float foam, float block) {
    vec2 q = floor(encodeNormal(n) * 2047.0 + 0.5);
    float f = floor(saturate(foam) * 15.0 + 0.5);
    float b = floor(saturate(block) * 63.0 + 0.5);
    vec2 fb = vec2(floor(f / 4.0), f - floor(f / 4.0) * 4.0);
    vec2 bb = vec2(floor(b / 8.0), b - floor(b / 8.0) * 8.0);
    return (q * 32.0 + fb * 8.0 + bb) / 65535.0;
}

vec3 decodeWaterNormal(vec2 data) {
    vec2 v = floor(data * 65535.0 + 0.5);
    return decodeNormal(floor(v / 32.0) / 2047.0);
}

float decodeWaterFoam(vec2 data) {
    vec2 v = floor(data * 65535.0 + 0.5);
    vec2 bits = floor((v - floor(v / 32.0) * 32.0) / 8.0);
    return (bits.x * 4.0 + bits.y) / 15.0;
}

float decodeWaterBlockLight(vec2 data) {
    vec2 v = floor(data * 65535.0 + 0.5);
    vec2 bits = v - floor(v / 8.0) * 8.0;
    return (bits.x * 8.0 + bits.y) / 63.0;
}

// Water tint and sky light packed into one 16-bit channel (4 bits each) of colortex4.
float packWater(vec3 tint, float sky) {
    vec4 q = floor(saturate(vec4(tint, sky)) * 15.0 + 0.5);
    return (q.r * 4096.0 + q.g * 256.0 + q.b * 16.0 + q.a) / 65535.0;
}

vec3 srgbToLinearApprox(vec3 c) {
    return c * c;
}

vec3 linearToSrgb(vec3 c) {
    vec3 lo = c * 12.92;
    vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
    return mix(hi, lo, step(c, vec3(0.0031308)));
}

vec3 srgbToLinear(vec3 c) {
    vec3 lo = c / 12.92;
    vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
    return mix(hi, lo, step(c, vec3(0.04045)));
}
