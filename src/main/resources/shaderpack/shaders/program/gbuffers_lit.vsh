// Vertex shader of every lit opaque gbuffers program (terrain, entities, block entities, hand, particles).
// The including stub defines one of PROG_TERRAIN, PROG_ENTITIES, PROG_BLOCK, PROG_HAND, PROG_TEXTURED.

#include "/lib/common.glsl"
#include "/lib/wind.glsl"

in vec4 mc_Entity;
in vec4 at_midBlock;

out vec2 texcoord;
out vec2 lightmap;
out vec4 vertexColor;
out vec3 playerPos;
out vec3 worldNormal;
flat out int material;
flat out float emissive;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightmap = saturate(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 1.0 / 32.0) * 16.0 / 15.0);
    vertexColor = gl_Color;

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
    vec3 viewNormal = gl_NormalMatrix * gl_Normal;
    worldNormal = dot(viewNormal, viewNormal) > 1e-6 ? normalize(mat3(gbufferModelViewInverse) * viewNormal) : vec3(0.0, 1.0, 0.0);

    material = MAT_DEFAULT;
    emissive = 0.0;

#if defined PROG_TERRAIN
    int id = int(mc_Entity.x + 0.5);
    // at_midBlock.w is the block's light emission: every light source glows, modded ones included.
    emissive = at_midBlock.w / 15.0;
    if (id == ID_PLANT || id == ID_PLANT_LOWER || id == ID_PLANT_UPPER || id == ID_EMISSIVE_PLANT || id == ID_LILY) {
        material = MAT_PLANT;
    } else if (id == ID_LEAVES || id == ID_VINE) {
        material = MAT_LEAVES;
    }
    if (id == ID_EMISSIVE || id == ID_LAVA) {
        material = MAT_EMISSIVE;
        emissive = max(emissive, 0.8);
    } else if (id == ID_EMISSIVE_PLANT) {
        emissive = max(emissive, 0.6);
    }

    vec3 worldPos = playerPos + cameraPosition;
    // 0 at the bottom of the block, 1 at its top (at_midBlock points from the vertex to the block centre, in 1/64).
    float height = saturate(0.5 - at_midBlock.y / 64.0);
    float exposed = smoothstep(0.2, 0.7, lightmap.y)
        * (1.0 - smoothstep(ANIMATION_DISTANCE * 0.75, ANIMATION_DISTANCE, length(playerPos)));
    if (exposed > 0.0) {
#ifdef WAVING_PLANTS
    if (id == ID_PLANT || id == ID_EMISSIVE_PLANT) {
        playerPos += windSway(worldPos, 0.09 * height) * exposed;
    } else if (id == ID_PLANT_LOWER) {
        playerPos += windSway(worldPos, 0.06 * height) * exposed;
    } else if (id == ID_PLANT_UPPER) {
        playerPos += windSway(worldPos, 0.06 + 0.08 * height) * exposed;
    }
#endif
#ifdef WAVING_LEAVES
    if (id == ID_LEAVES) {
        playerPos += leafRustle(worldPos, 0.035) * exposed;
    } else if (id == ID_VINE) {
        playerPos += leafRustle(worldPos, 0.03) * exposed * vec3(1.0, 0.3, 1.0);
    }
#endif
    }
#elif defined PROG_ENTITIES || defined PROG_BLOCK
    material = MAT_ENTITY;
#elif defined PROG_HAND
    material = MAT_HAND;
#elif defined PROG_TEXTURED
    material = MAT_PARTICLE;
    worldNormal = -normalize(playerPos + vec3(0.0, 1e-3, 0.0));
#endif

#if defined PROG_HAND
    gl_Position = ftransform();
#else
    gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(playerPos, 1.0);
#endif
}
