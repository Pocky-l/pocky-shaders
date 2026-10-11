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

// block.properties ids (mc_Entity.x); the mod regenerates the file with modded blocks added to the same ids.
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

// Water normal, foam and block light in two 16-bit channels of colortex4: each channel holds 12 bits of the octahedral
// normal, 2 bits of the 4-bit foam amount and 2 bits of the 4-bit block light (both 0..1).
vec2 encodeWaterNormal(vec3 n, float foam, float block) {
    vec2 q = floor(encodeNormal(n) * 4095.0 + 0.5);
    float f = floor(saturate(foam) * 15.0 + 0.5);
    float b = floor(saturate(block) * 15.0 + 0.5);
    vec2 fb = vec2(floor(f / 4.0), f - floor(f / 4.0) * 4.0);
    vec2 bb = vec2(floor(b / 4.0), b - floor(b / 4.0) * 4.0);
    return (q * 16.0 + fb * 4.0 + bb) / 65535.0;
}

vec3 decodeWaterNormal(vec2 data) {
    vec2 v = floor(data * 65535.0 + 0.5);
    return decodeNormal(floor(v / 16.0) / 4095.0);
}

float decodeWaterFoam(vec2 data) {
    vec2 v = floor(data * 65535.0 + 0.5);
    vec2 bits = floor((v - floor(v / 16.0) * 16.0) / 4.0);
    return (bits.x * 4.0 + bits.y) / 15.0;
}

float decodeWaterBlockLight(vec2 data) {
    vec2 v = floor(data * 65535.0 + 0.5);
    vec2 bits = v - floor(v / 4.0) * 4.0;
    return (bits.x * 4.0 + bits.y) / 15.0;
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
