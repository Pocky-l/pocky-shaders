// See dh_terrain.vsh.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#ifdef DIM_OVERWORLD
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#define CLOUD_LOOKUP
#include "/lib/clouds.glsl"
#endif
#include "/lib/lighting.glsl"

#ifdef PROG_DH_WATER
uniform sampler2D depthtex0;
uniform mat4 dhProjectionInverse;
#endif

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
    if (length(playerPos.xz) < min(far * 0.8, far - 32.0)) {
        discard;
    }
    vec3 n = normalize(worldNormal);
    vec3 albedo = srgbToLinear(vertexColor.rgb);
    float dist = length(playerPos);

#ifdef PROG_DH_WATER
    // DH has its own depth buffer: hide its water behind nearer vanilla geometry.
    float vanillaDepth = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r;
    if (vanillaDepth < 1.0) {
        vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
        float vanillaZ = screenToView(vec3(uv, vanillaDepth)).z;
        float dhZ = projectAndDivide(dhProjectionInverse, vec3(uv, gl_FragCoord.z) * 2.0 - 1.0).z;
        if (vanillaZ > dhZ) {
            discard;
        }
    }
    // Same water as near the player: composite shades it from this normal, tint and sky light.
    vec3 surfaceNormal = abs(n.y) > 0.5 ? vec3(0.0, sign(n.y), 0.0) : n;
    outColor = vec4(0.0);
    outData = vec4(encodeNormal(surfaceNormal), packWater(vertexColor.rgb, max(lightmap.y, 0.8)), 1.0);
#else
    // LODs have one flat colour per block, textures average darker and less saturated: match them, and fake the
    // texel pattern near the player (4 texels per block - finer would only shimmer at this distance).
    bool leaves = dhMaterial == DH_BLOCK_LEAVES;
    if (leaves && max(albedo.r, max(albedo.g, albedo.b)) < 0.01) {
        // Some leaves (birch, with colour handlers wrapped by other mods) reach DH without a colour: use foliage green.
        albedo = srgbToLinear(vec3(0.5, 0.65, 0.33));
    }
    albedo = mix(vec3(luminance(albedo)), albedo, 0.85) * (leaves ? 0.62 : 0.85);
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
    s.normal = n;
    s.lightmap = lm;
    s.ao = 1.0;
    s.material = leaves ? MAT_LEAVES : MAT_DEFAULT;
    vec3 lit = shade(s, frameLights(), 0.5);
    if (dhMaterial == DH_BLOCK_ILLUMINATED || dhMaterial == DH_BLOCK_LAVA) {
        lit += emission(albedo, 6.0, true) * 0.8;
    }
    outColor = vec4(lit, 1.0);
    float encoded = (float(s.material) * 256.0 + floor(lm.y * 255.0 + 0.5)) / 65535.0;
    outData = vec4(encodeNormal(mat3(gbufferModelView) * n), encoded, 1.0);
#endif
}
