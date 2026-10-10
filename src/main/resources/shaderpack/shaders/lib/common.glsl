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
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;
uniform float screenBrightness;

uniform int worldTime;
uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int frameCounter;

uniform ivec2 eyeBrightnessSmooth;

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
