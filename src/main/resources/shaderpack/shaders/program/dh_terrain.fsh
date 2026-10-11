// See dh_terrain.vsh.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#ifdef DIM_OVERWORLD
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#ifndef PROG_DH_WATER
#define SHADOW_LOOKUP
#include "/lib/shadow.glsl"
#endif
#define CLOUD_LOOKUP
#include "/lib/clouds.glsl"
#endif
#include "/lib/lighting.glsl"
#ifdef PROG_DH_WATER
#include "/lib/water.glsl"
#endif

// Vanilla depth: DH has its own depth buffer, so it cannot be depth-tested against vanilla chunks.
uniform sampler2D depthtex0;

in vec2 lightmap;
in vec4 vertexColor;
in vec3 playerPos;
in vec3 worldNormal;
flat in int dhMaterial;

#ifdef PROG_DH_WATER
/* RENDERTARGETS: 3,4 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outData;
#else
/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outData;
#endif

void main() {
    // Vanilla chunks cover the near range; DH only fills in beyond them.
    if (length(playerPos) < min(far * 0.8, far - 32.0)) {
        discard;
    }
    // Where vanilla chunks drew anything, they are the authority: LODs drawn over them in the overlap ring (flying
    // high makes it wide) replaced the real sea floor and stacked a second water surface on top of the vanilla one.
    if (texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r < 1.0) {
        discard;
    }
    vec3 n = normalize(worldNormal);
    vec3 albedo = srgbToLinear(vertexColor.rgb);
    float dist = length(playerPos);

#ifdef PROG_DH_WATER
    // Same water as near the player: composite shades it from this normal, tint and sky light.
    vec3 surfaceNormal = n;
    if (abs(n.y) > 0.5) {
        // Broad waves only: fine ripples at LOD distances alias into sparkling pixels.
        // Waves flatten out with distance: smaller than a pixel they would only shimmer.
        float calm = mix(0.35, 0.05, smoothstep(160.0, 480.0, dist));
        surfaceNormal = waterNormal((playerPos + cameraPosition).xz, calm, 0.0);
        surfaceNormal.y *= sign(n.y);
    }
    // LOD water colour is the averaged texture times the biome tint, darker than the vertex tint of vanilla water:
    // keep its hue, bring its brightness to vanilla's (default water tint 0x3F76E4 peaks at 0.89).
    vec3 tint = vertexColor.rgb / max(max(vertexColor.r, max(vertexColor.g, vertexColor.b)), 1e-3) * 0.89;
    outColor = vec4(0.0);
    outData = vec4(encodeWaterNormal(surfaceNormal, 0.0), packWater(tint, max(lightmap.y, 0.8)), 1.0);
#else
    // LODs have one flat colour per block, textures average darker and less saturated: match them, and fake the
    // texel pattern near the player (4 texels per block - finer would only shimmer at this distance).
    bool leaves = dhMaterial == DH_BLOCK_LEAVES;
    if (leaves && max(albedo.r, max(albedo.g, albedo.b)) < 0.01) {
        // Some leaves (birch, with colour handlers wrapped by other mods) reach DH without a colour: use foliage green.
        albedo = srgbToLinear(vec3(0.5, 0.655, 0.333) * 0.6);
    }
    albedo *= leaves ? 0.85 : 0.95;
    float detail = 1.0 - smoothstep(180.0, 420.0, dist);
    vec3 cellPos = playerPos + cameraPosition - n * 0.01;
    float blockVariation = hash13(floor(cellPos)) - 0.5;
    float variation = blockVariation * 0.12 * (1.0 - smoothstep(400.0, 900.0, dist));
    if (detail > 0.0) {
        float texel = hash13(floor(cellPos * 4.0) + 17.0) - 0.5;
        variation += texel * (leaves ? 0.55 : 0.22) * detail;
    }
    albedo *= 1.0 + variation;

    // DH light data is coarse (and missing for some generated LODs): never let open surfaces go black.
    vec2 lm = lightmap;
    lm.y = max(lm.y, mix(0.6, 1.0, saturate(n.y)));

    Surface s;
    s.albedo = albedo;
    s.playerPos = playerPos;
    s.shadowPos = playerPos;
    s.normal = n;
    s.lightmap = lm;
    s.ao = 1.0;
    s.material = leaves ? MAT_LEAVES : MAT_DEFAULT;
    vec3 lit = shade(s, frameLights(), 0.5);
    if (dhMaterial == DH_BLOCK_ILLUMINATED || dhMaterial == DH_BLOCK_LAVA) {
        lit += emission(albedo, 3.0, true) * 0.8;
    }
    outColor = vec4(lit, 1.0);
    float encoded = (float(s.material) * 256.0 + floor(lm.y * 255.0 + 0.5)) / 65535.0;
    outData = vec4(encodeNormal(mat3(gbufferModelView) * n), encoded, 1.0);
#endif
}
