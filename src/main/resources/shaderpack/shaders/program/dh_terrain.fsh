// See dh_terrain.vsh.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#ifdef DIM_OVERWORLD
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#endif
#include "/lib/lighting.glsl"

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

#ifdef PROG_DH_WATER
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
    Surface s;
    s.albedo = albedo;
    s.playerPos = playerPos;
    s.normal = n;
    s.lightmap = lightmap;
    s.ao = 1.0;
    s.material = dhMaterial == DH_BLOCK_LEAVES ? MAT_LEAVES : MAT_DEFAULT;
    vec3 lit = shade(s, frameLights(), 0.5);
    if (dhMaterial == DH_BLOCK_ILLUMINATED || dhMaterial == DH_BLOCK_LAVA) {
        lit += emission(albedo, 6.0, true) * 0.8;
    }
    outColor = vec4(lit, 1.0);
    float encoded = (float(s.material) * 256.0 + floor(lightmap.y * 255.0 + 0.5)) / 65535.0;
    outData = vec4(encodeNormal(mat3(gbufferModelView) * n), encoded, 1.0);
#endif
}
