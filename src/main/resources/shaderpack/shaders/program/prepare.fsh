// Bakes this frame's sky lookup table, and light colours into colortex7 (see lib/atmosphere.glsl).

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"

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
            vec3 sun = SUN_ILLUMINANCE * sunTint(directTransmittance(sunDir.y), sunDir.y) * aboveHorizon(sunDir.y);
            // The low morning sun lights the land with a touch of rose (same luminance).
            vec3 rose = vec3(1.08, 0.9, 0.98);
            sun *= mix(vec3(1.0), rose / luminance(rose), morning() * twilightAmount(sunDir.y) * 0.6);
            vec3 moon = MOON_ILLUMINANCE * moonPhaseLight() * MOON_TINT * directTransmittance(-sunDir.y)
                    * aboveHorizon(-sunDir.y);
            value = (sun + moon) * (1.0 - rainStrength * 0.88) * (1.0 - thunderStrength * 0.9);
        } else if (pixel.x == PIXEL_AMBIENT_COLOR.x) {
            // Single scattering alone makes skylight far too blue (the missing multiple scattering and the light
            // the ground bounces back up are both close to white): shadows would turn cyan.
            vec3 sky = ambientIrradiance(sunDir);
            sky = mix(vec3(luminance(sky)), sky, 0.7);
            // Rainy nights keep a little more light (only at night: by day the overcast deck sets the level).
            float night = smoothstep(0.05, -0.1, sunDir.y);
            value = max(sky, vec3(0.05, 0.06, 0.08) * (1.0 + rainStrength * 0.6 * night));
        } else {
            value = SUN_ILLUMINANCE * sunTint(directTransmittance(sunDir.y), sunDir.y) * (1.0 - rainStrength)
                    * (1.0 - thunderStrength);
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

    discard;
}
