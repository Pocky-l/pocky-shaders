// Fragment shader of every lit opaque gbuffers program, see gbuffers_lit.vsh.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#ifdef DIM_OVERWORLD
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#define CLOUD_LOOKUP
#include "/lib/clouds.glsl"
#define SHADOW_LOOKUP
#include "/lib/shadow.glsl"
#endif
#include "/lib/lighting.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;
#if defined PROG_ENTITIES
uniform vec4 entityColor;
#endif

in vec2 texcoord;
in vec2 lightmap;
in vec4 vertexColor;
in vec3 playerPos;
in vec3 worldNormal;
flat in int material;
flat in float emissive;

/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outData;

void main() {
    vec4 tex = texture(gtexture, texcoord);
#if defined PROG_TERRAIN
    // separateAo: the vertex alpha carries vanilla ambient occlusion instead of transparency.
    vec4 color = vec4(tex.rgb * vertexColor.rgb, tex.a);
    float ao = vertexColor.a;
#else
    vec4 color = tex * vertexColor;
    float ao = 1.0;
#endif
    if (color.a < alphaTestRef) {
        discard;
    }
#if defined PROG_TERRAIN && defined DISTANT_HORIZONS
    float edgeFade = smoothstep(far - 28.0, far - 4.0, length(playerPos));
    if (edgeFade > 0.0 && hash12(floor(gl_FragCoord.xy)) < edgeFade) {
        discard;
    }
#endif
#if defined PROG_ENTITIES
    color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);
#endif

    vec3 n = normalize(worldNormal);
    if (!gl_FrontFacing && material != MAT_PARTICLE) {
        n = -n;
    }

    Surface s;
    s.albedo = srgbToLinear(color.rgb);
    s.playerPos = playerPos;
    s.normal = n;
    s.lightmap = lightmap;
    s.ao = ao * ao;
    s.material = material;

    vec3 lit = shade(s, frameLights(), dither(gl_FragCoord.xy));
    lit += emission(s.albedo, 6.0, material == MAT_EMISSIVE) * emissive;

    outColor = vec4(lit, color.a);
    vec3 viewNormal = mat3(gbufferModelView) * n;
    float encoded = (float(material) * 256.0 + floor(lightmap.y * 255.0 + 0.5)) / 65535.0;
    outData = vec4(encodeNormal(viewNormal), encoded, 1.0);
}
