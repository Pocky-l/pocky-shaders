// See gbuffers_unlit.vsh. The including stub defines one of PROG_SKYBASIC, PROG_SKYTEXTURED, PROG_CLOUDS, PROG_BASIC,
// PROG_EMISSIVE (spider eyes, beacon beam), PROG_GLINT, PROG_DAMAGE, PROG_WEATHER.

#include "/lib/common.glsl"
#if defined PROG_SKYTEXTURED && defined DIM_OVERWORLD
#include "/lib/atmosphere.glsl"
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#endif

uniform sampler2D gtexture;
uniform int renderStage;

in vec2 texcoord;
in vec2 lightmap;
in vec4 vertexColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
#if defined PROG_CLOUDS
    discard;
#elif defined PROG_SKYBASIC
    #ifdef DIM_OVERWORLD
    // The sky itself comes from the deferred pass; only the stars are kept.
    if (renderStage != MC_RENDER_STAGE_STARS) {
        discard;
    }
    outColor = vec4(srgbToLinear(vertexColor.rgb) * 1.5, vertexColor.a);
    #else
    outColor = vec4(srgbToLinear(vertexColor.rgb), vertexColor.a);
    #endif
#elif defined PROG_SKYTEXTURED
    vec4 color = texture(gtexture, texcoord) * vertexColor;
    #ifdef DIM_OVERWORLD
    // The vanilla (square) sun, as bright and as coloured as the sunlight through the air; the moon as it is.
    if (renderStage == MC_RENDER_STAGE_SUN) {
        color.rgb = srgbToLinear(color.rgb) * sunDiscColor() * 2.5;
    } else {
        color.rgb = srgbToLinear(color.rgb) * (renderStage == MC_RENDER_STAGE_MOON ? 1.6 : 1.0);
    }
    #else
    color.rgb = srgbToLinear(color.rgb);
    #endif
    outColor = color;
#elif defined PROG_EMISSIVE
    vec4 color = texture(gtexture, texcoord) * vertexColor;
    outColor = vec4(srgbToLinear(color.rgb) * 2.0, color.a);
#elif defined PROG_GLINT
    vec4 color = texture(gtexture, texcoord) * vertexColor;
    outColor = vec4(srgbToLinear(color.rgb), color.a);
#elif defined PROG_DAMAGE
    vec4 color = texture(gtexture, texcoord) * vertexColor;
    outColor = color;
#elif defined PROG_WEATHER
    // Rain and snow (vanilla's and the weather mods' own particles drawn through this program).
    vec4 color = texture(gtexture, texcoord) * vertexColor;
    if (color.a < 0.01) {
        discard;
    }
    float light = 0.35 + 0.65 * lightmap.y + lightmap.x * 0.4;
    outColor = vec4(srgbToLinear(color.rgb) * light, color.a);
#elif defined PROG_BASIC
    outColor = vec4(srgbToLinear(vertexColor.rgb), vertexColor.a);
#else
    vec4 color = texture(gtexture, texcoord) * vertexColor;
    if (color.a < 0.004) {
        discard;
    }
    outColor = vec4(srgbToLinear(color.rgb), color.a);
#endif
}
