// Distant softening, bloom from the mip chain of colortex5, exposure that follows day, night and caves, then
// tonemapping.

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
#ifdef DISTANT_SOFTENING
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform mat4 dhProjectionInverse;
#endif
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

#ifdef DISTANT_SOFTENING
// How much a pixel is softened (0..1): nothing near the player, full far in the LOD range. Sky: -1.
float softenAmount(vec2 uv) {
    float depth = texture(depthtex0, uv).r;
    float dist = -1.0;
    if (depth < 1.0) {
        dist = length(screenToView(vec3(uv, depth)));
    }
#ifdef DISTANT_HORIZONS
    else {
        float dhDepth = texture(dhDepthTex0, uv).r;
        if (dhDepth < 1.0) {
            dist = length(projectAndDivide(dhProjectionInverse, vec3(uv, dhDepth) * 2.0 - 1.0));
        }
    }
#endif
    return dist < 0.0 ? -1.0 : smoothstep(far * 0.75, far * 3.0, dist);
}

// Far land and water carry more detail than a pixel can show: LOD blocks, sub-pixel waves and their glints flicker.
// Like the slight distance blur of open-world games, average the far scene over a small, fixed disk that grows with
// distance. Near pixels never bleed into it (samples are weighted by their own softness); the sky stays sharp so
// stars and the sun keep their shape, but softens the horizon line a little.
vec3 distantSoftening(vec2 uv, vec3 color) {
    float amount = softenAmount(uv);
    if (amount <= 0.0) {
        return color;
    }
    const int TAPS = SOFTEN_TAPS;
    vec2 radius = amount * 1.6 * DISTANT_SOFTENING_STRENGTH * (viewHeight / 1080.0) / vec2(viewWidth, viewHeight);
    vec3 sum = color;
    float weight = 1.0;
    for (int i = 0; i < TAPS; i++) {
        float r = sqrt((float(i) + 0.5) / float(TAPS));
        float theta = float(i) * 2.39996323;
        vec2 p = uv + r * vec2(cos(theta), sin(theta)) * radius;
        float a = softenAmount(p);
        float w = a < 0.0 ? 0.5 : a;
        sum += texture(colortex0, p).rgb * w;
        weight += w;
    }
    return sum / weight;
}
#endif

float exposure() {
    float eyeSky = smoothstep(0.0, 0.7, float(eyeBrightnessSmooth.y) / 240.0);
#ifdef DIM_OVERWORLD
    // Scene brightness key of an average lit surface; 1.75 is a clear midday.
    float key = (luminance(directLightColor()) * 0.6 + luminance(ambientLightColor())) / PI;
    float outdoor = clamp(pow(1.75 / max(key, 1e-3), 0.5), 0.9, 3.2);
#else
    float outdoor = 1.0;
#endif
    return EXPOSURE * mix(1.0, outdoor, eyeSky);
}

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;
#ifdef DISTANT_SOFTENING
    color = distantSoftening(texcoord, color);
#endif
#ifdef BLOOM
    float amount = (0.025 + rainStrength * 0.03 + float(isEyeInWater == 1) * 0.08) * BLOOM_STRENGTH;
    color = mix(color, bloom(texcoord), amount);
#endif
    color *= exposure();
    outColor = vec4(tonemap(color), 1.0);
}
