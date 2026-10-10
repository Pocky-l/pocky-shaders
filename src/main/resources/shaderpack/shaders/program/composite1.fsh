// Bloom from the mip chain of colortex5, exposure that follows day, night and caves, lens flare, then tonemapping.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/tonemap.glsl"
#ifdef DIM_OVERWORLD
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#endif

const bool colortex5MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex5;
#if defined LENS_FLARE && defined DIM_OVERWORLD
#include "/lib/sun_view.glsl"
#endif

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

vec3 bloom(vec2 uv) {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 sum = vec3(0.0);
    float weight = 0.0;
    for (int lod = 2; lod <= 7; lod++) {
        float scale = exp2(float(lod));
        vec2 o = px * scale * 0.75;
        vec3 s = textureLod(colortex5, uv + vec2(o.x, o.y), float(lod)).rgb
               + textureLod(colortex5, uv + vec2(-o.x, o.y), float(lod)).rgb
               + textureLod(colortex5, uv + vec2(o.x, -o.y), float(lod)).rgb
               + textureLod(colortex5, uv + vec2(-o.x, -o.y), float(lod)).rgb;
        float w = 1.0 / (1.0 + float(lod - 2) * 0.35);
        sum += s * 0.25 * w;
        weight += w;
    }
    return sum / weight;
}

#if defined LENS_FLARE && defined DIM_OVERWORLD
// One reflection of the aperture: a soft disc with a slightly brighter rim.
float flareGhost(vec2 uv, vec2 centre, float radius, float aspect) {
    float d = length((uv - centre) * vec2(aspect, 1.0)) / radius;
    return smoothstep(1.0, 0.7, d) * (0.55 + 0.45 * d * d);
}

// Reflections of the sun inside the lens: a row of faint tinted ghosts along the line from the sun through the
// centre of the screen. Added after exposure, so it is as bright at sunset as
// at noon relative to the scene.
vec3 lensFlare(vec2 uv) {
    if (sunPosition.z >= 0.0 || isEyeInWater != 0) {
        return vec3(0.0);
    }
    vec2 sunUv;
    sunOnScreen(sunUv);
    float visible = sunVisibility(sunUv);
    if (visible <= 0.0) {
        return vec3(0.0);
    }
    float aspect = viewWidth / viewHeight;
    vec2 axis = 0.5 - sunUv;
    vec3 ghosts = vec3(1.0, 0.8, 0.55) * 0.5 * flareGhost(uv, sunUv + axis * 0.45, 0.02, aspect)
            + vec3(0.55, 0.9, 0.7) * 0.18 * flareGhost(uv, sunUv + axis * 0.75, 0.05, aspect)
            + vec3(0.75, 0.6, 1.0) * 0.25 * flareGhost(uv, sunUv + axis * 1.2, 0.035, aspect)
            + vec3(0.5, 0.7, 1.0) * 0.1 * flareGhost(uv, sunUv + axis * 1.45, 0.09, aspect)
            + vec3(1.0, 0.7, 0.4) * 0.15 * flareGhost(uv, sunUv + axis * 1.8, 0.06, aspect)
            + vec3(0.6, 0.8, 1.0) * 0.06 * flareGhost(uv, sunUv + axis * 2.1, 0.14, aspect);
    vec3 sun = sunDiscColor() / SUN_ILLUMINANCE;
    return ghosts * 0.12 * sun * visible * LENS_FLARE_STRENGTH;
}
#endif

float exposure() {
    float eyeSky = smoothstep(0.0, 0.7, float(eyeBrightnessSmooth.y) / 240.0);
#ifdef DIM_OVERWORLD
    // Scene brightness key of an average lit surface; 1.75 is a clear midday. A lightning flash is left out, so the
    // eye does not adapt to it and the flash shows. Rain and storms aim lower: they should feel gloomy, not like a
    // grey day brightened up to noon.
    float flash = luminance(flashSkyRadiance()) * OVERCAST_IRRADIANCE;
    float key = (luminance(directLightColor()) * 0.6 + max(luminance(ambientLightColor()) - flash, 0.0)) / PI;
    // Snow keeps the world bright (white ground and air); a thunderstorm in rain is properly dark.
    float target = 1.75 * mix(1.0, 0.62, rainStrength * (1.0 - 0.7 * snowWeather)) * mix(1.0, 0.36, stormDarkness());
    float outdoor = clamp(pow(target / max(key, 1e-3), 0.5), 0.9, 3.2);
#else
    float outdoor = 1.0;
#endif
    // Away from the sky (caves, deep inside buildings) the eye adapts to the dark as well; the Brightness option sets
    // how far.
    float cave = mix(1.5, 2.8, screenBrightness);
    return EXPOSURE * mix(cave, outdoor, eyeSky);
}

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;
#ifdef BLOOM
    float amount = (0.025 + rainStrength * 0.03 + float(isEyeInWater == 1) * 0.08) * BLOOM_STRENGTH;
    color = mix(color, bloom(texcoord), amount);
#endif
    color *= exposure();
#if defined LENS_FLARE && defined DIM_OVERWORLD
    color += lensFlare(texcoord);
#endif
    outColor = vec4(tonemap(color), 1.0);
}
