// Sunlight scattered towards the eye under water, with the shadows of the world in it: columns of light coming down
// from the waves. (No haze in the air: the owner did not like it.) Marched with a fixed 4x4 pattern of start offsets; composite averages every 4x4 pixels, so the result is
// smooth without grain or shimmer (no per-pixel noise without temporal filtering). Overworld only.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#define CLOUD_LOOKUP
#include "/lib/clouds.glsl"
#define SHADOW_LOOKUP
#include "/lib/shadow.glsl"
#include "/lib/water.glsl"

uniform sampler2D depthtex0;

in vec2 texcoord;

/* RENDERTARGETS: 9 */
layout(location = 0) out vec4 outLight;

float bayer4(vec2 p) {
    ivec2 q = ivec2(mod(p, 4.0));
    int i = q.y * 4 + q.x;
    const float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    return (m[i] + 0.5) / 16.0;
}

// Under water: light coming down through the waves into the water, broken into moving columns by the same focusing
// that draws the caustics on the bottom, fading with the depth below the surface and the distance through the water.
vec3 waterLight(vec3 dir, float dist, float jitter) {
    vec3 l = lightDirection();
    vec3 light = directLightColor();
    if (dot(light, vec3(1.0)) < 1e-3 || l.y <= 0.05) {
        return vec3(0.0);
    }
    vec3 absorb = vec3(0.38, 0.09, 0.07) / WATER_CLARITY;
    // Scattering by the water and what floats in it: blue-green.
    vec3 scatter = vec3(0.006, 0.022, 0.03) / WATER_CLARITY;
    float mu = dot(dir, l);
    float phase = 0.5 * miePhase(mu, 0.6) + 0.5 / (4.0 * PI);
    float eyeDepth = eyeWaterDepth();
    float slant = 1.0 / l.y;
    float reach = min(dist, 40.0);
    const int STEPS = VOLUMETRIC_STEPS;
    vec3 sum = vec3(0.0);
    float prev = 0.0;
    for (int i = 0; i < STEPS; i++) {
        float f = (float(i) + jitter) / float(STEPS);
        float t = reach * f * f;
        float dt = t - prev;
        prev = t;
        vec3 p = dir * t;
        float depth = max(eyeDepth - p.y, 0.0);
        // Where the light entered: straight up along the light, at the surface.
        vec2 entry = cameraPosition.xz + p.xz + l.xz * slant * depth;
        float columns = 0.35 + 1.6 * waterCaustics(entry * 0.35);
        vec3 down = exp(-absorb * depth * slant);
        vec3 toEye = exp(-(absorb + scatter) * t);
        sum += scatter * down * toEye * columns * opaqueShadowAt(p) * dt;
    }
    return light * phase * sum * VOLUMETRIC_STRENGTH * 1.5;
}

void main() {
    outLight = vec4(0.0);
#ifdef VOLUMETRIC_LIGHT
    float depth = texture(depthtex0, texcoord).r;
    vec3 viewPos = screenToView(vec3(texcoord, depth));
    vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos;
    float dist = depth >= 1.0 ? 1e4 : length(playerPos);
    vec3 dir = mat3(gbufferModelViewInverse) * normalize(viewPos);
    float jitter = bayer4(gl_FragCoord.xy);
    if (isEyeInWater == 1) {
        outLight = vec4(waterLight(dir, dist, jitter), 1.0);
    }
#endif
}
