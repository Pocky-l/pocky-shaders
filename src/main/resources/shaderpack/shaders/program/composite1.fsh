// Bloom from the mip chain of colortex5, exposure that follows day, night and caves, then tonemapping.

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

float exposure() {
    float eyeSky = smoothstep(0.0, 0.7, float(eyeBrightnessSmooth.y) / 240.0);
#ifdef DIM_OVERWORLD
    // Scene brightness key of an average lit surface; 1.75 is a clear midday. A lightning flash is left out, so the
    // eye does not adapt to it and the flash shows. Rain and storms aim lower: they should feel gloomy, not like a
    // grey day brightened up to noon.
    float flash = luminance(flashSkyRadiance()) * OVERCAST_IRRADIANCE;
    float key = (luminance(directLightColor()) * 0.6 + max(luminance(ambientLightColor()) - flash, 0.0)) / PI;
    float target = 1.75 * mix(1.0, 0.62, rainStrength) * mix(1.0, 0.75, thunderStrength);
    float outdoor = clamp(pow(target / max(key, 1e-3), 0.5), 0.9, 3.2);
#else
    float outdoor = 1.0;
#endif
    return EXPOSURE * mix(1.0, outdoor, eyeSky);
}

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;
#ifdef BLOOM
    float amount = (0.025 + rainStrength * 0.03 + float(isEyeInWater == 1) * 0.08) * BLOOM_STRENGTH;
    color = mix(color, bloom(texcoord), amount);
#endif
    color *= exposure();
    outColor = vec4(tonemap(color), 1.0);
}
