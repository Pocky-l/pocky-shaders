// Bakes this frame's sky lookup table, light colours and cloud map into colortex7 (lib/atmosphere.glsl, lib/clouds.glsl).

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/clouds.glsl"

/*
const int colortex7Format = RGBA16F;
const bool colortex7Clear = false;
*/

in vec2 texcoord;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 outSky;

vec3 sunDirectionWorld() {
    return normalize(mat3(gbufferModelViewInverse) * sunPosition);
}

vec3 ambientIrradiance(vec3 sunDir) {
    // Cosine-weighted average over the upper hemisphere; the factor makes up for the missing multiple scattering.
    const int RINGS = 3;
    const int SEGMENTS = 6;
    vec3 sum = vec3(0.0);
    float weight = 0.0;
    for (int r = 0; r < RINGS; r++) {
        float y = (float(r) + 0.5) / float(RINGS);
        float horizontal = sqrt(1.0 - y * y);
        for (int s = 0; s < SEGMENTS; s++) {
            float a = (float(s) + 0.5 * float(r)) / float(SEGMENTS) * 2.0 * PI;
            vec3 dir = vec3(cos(a) * horizontal, y, sin(a) * horizontal);
            sum += skyRadiance(dir, sunDir, 6) * y;
            weight += y;
        }
    }
    return sum / weight * PI * 1.4;
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec3 sunDir = sunDirectionWorld();

    if (pixel.y == 0 && pixel.x < 3) {
        vec3 value;
        if (pixel.x == PIXEL_LIGHT_COLOR.x) {
            vec3 sun = SUN_ILLUMINANCE * directTransmittance(sunDir.y);
            vec3 moon = MOON_ILLUMINANCE * moonPhaseLight() * MOON_TINT * directTransmittance(-sunDir.y);
            value = (sun + moon) * (1.0 - rainStrength * 0.88) * (1.0 - thunderStrength * 0.9);
        } else if (pixel.x == PIXEL_AMBIENT_COLOR.x) {
            value = max(ambientIrradiance(sunDir), vec3(0.05, 0.06, 0.08) * (1.0 + rainStrength * 0.6));
        } else {
            value = SUN_ILLUMINANCE * directTransmittance(sunDir.y) * (1.0 - rainStrength) * (1.0 - thunderStrength);
        }
        outSky = vec4(value, 1.0);
        return;
    }

    ivec2 lutPixel = pixel - ivec2(0, SKY_LUT_ROW);
    if (lutPixel.y >= 0 && lutPixel.y < SKY_LUT_SIZE.y && lutPixel.x < SKY_LUT_SIZE.x) {
        vec2 uv = vec2(lutPixel) / vec2(SKY_LUT_SIZE - 1);
        vec3 dir = skyLutDirection(uv, sunDir);
        outSky = vec4(skyRadiance(dir, sunDir, SKY_STEPS), 1.0);
        return;
    }

#if CLOUDS > 0
    ivec2 mapPixel = pixel - CLOUD_MAP_ORIGIN;
    if (all(greaterThanEqual(mapPixel, ivec2(0))) && all(lessThan(mapPixel, ivec2(CLOUD_MAP_SIZE)))) {
        vec2 local = vec2(mapPixel) / float(CLOUD_MAP_SIZE - 1) - 0.5;
        outSky = vec4(cloudColumn(cloudMapCenter() + local * CLOUD_MAP_SPAN), 0.0, 0.0, 1.0);
        return;
    }
#endif
    discard;
}
