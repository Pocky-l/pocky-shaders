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
flat in int lava;

#if defined PROG_TERRAIN && SHADOW_STYLE == 1
// Position of the centre of the texture texel this fragment belongs to (found through the screen-space derivatives of
// the position and the texture coordinate, exact within a flat triangle). Shadows looked up there are pixelated like
// the textures and stay attached to them: on a swaying grass blade or leaf the pixel pattern moves with it instead of
// flickering. Taken outside any branch (derivatives).
vec3 texelCentre(vec3 pos, vec2 uv) {
    vec2 size = vec2(textureSize(gtexture, 0));
    vec2 t = uv * size;
    vec2 delta = floor(t) + 0.5 - t;
    vec2 tx = dFdx(t);
    vec2 ty = dFdy(t);
    vec3 px = dFdx(pos);
    vec3 py = dFdy(pos);
    float det = tx.x * ty.y - tx.y * ty.x;
    if (abs(det) < 1e-8) {
        return pos;
    }
    float a = (delta.x * ty.y - delta.y * ty.x) / det;
    float b = (tx.x * delta.y - tx.y * delta.x) / det;
    vec3 offset = a * px + b * py;
    // Grazing views: the derivatives get unreliable, a texel is never this far off.
    return dot(offset, offset) < 0.04 ? pos + offset : pos;
}
#endif

#if defined PROG_TEXTURED
// Particles go to their own layer, laid over the finished scene at the end of composite: drawn straight into the
// scene, the water shading there treated smoke in front of a river as part of the riverbed and the water showed
// through it.
/* RENDERTARGETS: 8 */
layout(location = 0) out vec4 outColor;
#else
/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outData;
#endif

void main() {
    vec4 tex = texture(gtexture, texcoord);
#if defined PROG_TERRAIN && SHADOW_STYLE == 1
    vec3 shadowPos = texelCentre(playerPos, texcoord);
#else
    vec3 shadowPos = playerPos;
#endif
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
    s.shadowPos = shadowPos;
    s.normal = n;
    s.lightmap = lightmap;
    // Vanilla's corner occlusion is strong inside a canopy of full leaf blocks; squared, it turned tree crowns into
    // dark, flat masses.
    s.ao = material == MAT_LEAVES ? mix(1.0, ao, 0.6) : ao * ao;
#if defined PROG_TEXTURED
    // Some particles (modded ones especially) come without a usable sky light and turned black in the open: they are
    // never darker than the sky light around the player.
    s.lightmap.y = max(s.lightmap.y, float(eyeBrightnessSmooth.y) / 240.0);
#endif
    s.material = material;

    vec3 lit = shade(s, frameLights(), dither(gl_FragCoord.xy));
    if (lava == 1) {
        // Molten rock lit by daylight looked like orange paint: it is almost all its own glow.
        lit = lit * 0.15 + lavaGlow(s.albedo, playerPos + cameraPosition);
    } else {
        lit += emission(s.albedo, 3.0, material == MAT_EMISSIVE) * emissive;
    }

    outColor = vec4(lit, color.a);
#if !defined PROG_TEXTURED
    vec3 viewNormal = mat3(gbufferModelView) * n;
    float encoded = (float(material) * 256.0 + floor(lightmap.y * 255.0 + 0.5)) / 65535.0;
    outData = vec4(encodeNormal(viewNormal), encoded, 1.0);
#endif
}
