// See dh_terrain.vsh.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#ifdef DIM_OVERWORLD
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
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
    if (length(playerPos.xz) < far * 0.8) {
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
    vec3 v = -normalize(playerPos);
    float f = fresnelSchlick(dot(v, n), 0.02);
    Lights lights = frameLights();
    vec3 deep = (lights.ambient * 0.6 + lights.direct * 0.15) / PI * lightmap.y * lightmap.y * vec3(0.05, 0.2, 0.24);
    vec3 color = deep;
#ifdef DIM_OVERWORLD
    color = mix(deep, sampleSkyLut(reflect(-v, n), sunDirection()) * smoothstep(0.3, 0.85, lightmap.y), f);
#endif
    outColor = vec4(color, 0.88);
    outData = vec4(0.0);
#else
    // LODs have one flat colour per block, textures average darker and less saturated: match them, and fake the
    // texel pattern near the player (4 texels per block - finer would only shimmer at this distance).
    albedo = mix(vec3(luminance(albedo)), albedo, 0.85) * 0.88;
    bool leaves = dhMaterial == DH_BLOCK_LEAVES;
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
