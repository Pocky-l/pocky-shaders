// Sunlight scattered towards the eye by the air and the water, with the shadows of the world in it: shafts of light
// through leaves and gaps in the clouds in a hazy morning or a fog, and under water columns of light coming down from
// the waves. Marched with a fixed 4x4 pattern of start offsets; composite averages every 4x4 pixels, so the result is
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

// Scattering in the air at a height above the haze layer's base (see hazeBase), per block: a faint clear-air haze,
// and close to the ground a thicker one - in the cool, humid morning and evening, after a rain, over swamps and
// rivers, around sunrise, and most of all in a morning fog. The sunbeams show in the low layer, not all over the sky.
float airDensity(float y, float base, float sunY) {
    float h = y - base;
    float humid = mix(3.0, 1.0, smoothstep(0.08, 0.45, sunY)) * (1.0 + 1.5 * afterRain()) * (1.0 + mistBiome);
    float clear = 0.00003 * exp(-max(y - 63.0, -20.0) * 0.01);
    float haze = 0.00025 * exp(-max(h, -6.0) * 0.12) * humid;
    float dawn = dawnHaze() * 0.0025 * exp(-max(h, -6.0) * 0.1);
    float fog = foggyMorning() * MORNING_FOG_DENSITY * 0.6 * FOG_DENSITY * exp(-max(h, -6.0) * MORNING_FOG_FALLOFF);
    return (clear + haze + dawn + fog) * (1.0 - 0.85 * rainStrength);
}

vec3 airLight(vec3 dir, float dist, float base, float jitter) {
    vec3 l = lightDirection();
    vec3 light = directLightColor();
    if (dot(light, vec3(1.0)) < 1e-3) {
        return vec3(0.0);
    }
    // Half desaturated: the light scattered in the air is paler than the low sun itself.
    light = mix(vec3(luminance(light)), light, 0.6);
    float mu = dot(dir, l);
    // Mostly forward: the beams show looking towards the sun; to the sides the fog stays a soft, dim veil.
    float phase = 0.75 * miePhase(mu, 0.75) + 0.25 / (4.0 * PI);
    float sunY = sunDirection().y;
    float reach = min(dist, shadowDistance * 0.7);
    const int STEPS = VOLUMETRIC_STEPS;
    vec3 sum = vec3(0.0);
    float opticalDepth = 0.0;
    float prev = 0.0;
    for (int i = 0; i < STEPS; i++) {
        // Closer together near the eye, where the shafts are seen best.
        float f = (float(i) + jitter) / float(STEPS);
        float t = reach * f * f;
        float dt = t - prev;
        prev = t;
        vec3 p = dir * t;
        float density = airDensity(cameraPosition.y + p.y, base, sunY);
        if (density <= 0.0) {
            continue;
        }
        float lit = opaqueShadowAt(p) * cloudShadow(p, l);
        sum += density * lit * exp(-opticalDepth) * dt;
        opticalDepth += density * dt;
    }
    // Like the fog itself, the glow never covers the view: at most about the light of the clear sky's horizon.
    vec3 glow = light * phase * sum * VOLUMETRIC_STRENGTH;
    return glow / (1.0 + luminance(glow) * 1.6);
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
    } else if (isEyeInWater == 0) {
        // Only where the eye sees the sky: no sunbeams inside a cave from the shadow map's edge.
        float eyeSky = smoothstep(0.1, 0.5, float(eyeBrightnessSmooth.y) / 240.0);
        if (eyeSky > 0.0) {
            float base = depth >= 1.0 ? cameraPosition.y - 1.62 : hazeBase(playerPos);
            outLight = vec4(airLight(dir, dist, base, jitter) * eyeSky, 1.0);
        }
    }
#endif
}
