// See gbuffers_unlit.vsh. The including stub defines one of PROG_SKYBASIC, PROG_SKYTEXTURED, PROG_CLOUDS, PROG_BASIC,
// PROG_EMISSIVE (spider eyes, beacon beam), PROG_GLINT, PROG_DAMAGE, PROG_WEATHER.

#include "/lib/common.glsl"
#if (defined PROG_SKYTEXTURED || defined PROG_WEATHER) && defined DIM_OVERWORLD
#include "/lib/atmosphere.glsl"
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#endif

uniform sampler2D gtexture;
uniform int renderStage;

in vec2 texcoord;
in vec2 lightmap;
in vec4 vertexColor;

#if defined PROG_WEATHER
// Rain and snow share the particles' layer (see gbuffers_lit): over water they stay in front of it.
/* RENDERTARGETS: 8 */
#else
/* RENDERTARGETS: 0 */
#endif
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
    // Vanilla starts the stars while the twilight sky is still bright orange; they come out once it has darkened
    // (sun 6 to 17 degrees below the horizon).
    float starNight = smoothstep(-0.1, -0.3, sunElevation());
    outColor = vec4(srgbToLinear(vertexColor.rgb) * 1.5, vertexColor.a * starNight);
    #else
    outColor = vec4(srgbToLinear(vertexColor.rgb), vertexColor.a);
    #endif
#elif defined PROG_SKYTEXTURED
    vec4 color = texture(gtexture, texcoord) * vertexColor;
    #ifdef DIM_OVERWORLD
    // The vanilla (square) sun, as bright and as coloured as the sunlight through the air; the moon as it is.
    if (renderStage == MC_RENDER_STAGE_SUN) {
        // From the texture only its brightness: its yellow edge pixels turned into a saturated yellow frame.
        // Capped, so a low sun keeps its warm hue in the tonemap instead of clipping to a plain white square.
        vec3 disc = sunDiscColor() * 1.2;
        float peak = max(disc.r, max(disc.g, disc.b));
        color.rgb = vec3(luminance(srgbToLinear(color.rgb))) * disc * (min(peak, 4.0) / max(peak, 1e-4));
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
    // Lit like the world around it, so rain curtains darken with a storm instead of glowing in it. A raindrop is a
    // clear lens: it gathers the light of the whole sky and shows brighter than the air behind it - lit like a
    // matte surface (ambient x1.25) the streaks came out darker than the sky and read as dark scratches. Snowflakes
    // are matte and keep the plain sky light.
    float rainy = 1.0 - snowWeather;
    #ifdef DIM_OVERWORLD
    vec3 light = (ambientLightColor() * (1.25 + 1.15 * rainy) + directLightColor() * (0.2 + 0.25 * rainy)) / PI
            * lightmap.y * lightmap.y;
    #else
    vec3 light = vec3(0.3) * lightmap.y;
    #endif
    light += vec3(1.0, 0.7, 0.45) * lightmap.x * lightmap.x * 0.5 + vec3(AMBIENT_MIN);
    // Clear water: the grey-blue of the rain texture half taken out, so a drop shows the light, not a tint.
    vec3 albedo = srgbToLinear(color.rgb);
    albedo = mix(albedo, vec3(luminance(albedo)), 0.5 * rainy);
    outColor = vec4(albedo * light, color.a * 0.8);
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
