// Vertex shader of every lit opaque gbuffers program (terrain, entities, block entities, hand, particles).
// The including stub defines one of PROG_TERRAIN, PROG_ENTITIES, PROG_BLOCK, PROG_HAND, PROG_TEXTURED, PROG_COLORWHEEL
// (Colorwheel: Create contraptions and other Flywheel instances; it remaps the gl_* attributes for us).

#include "/lib/common.glsl"
#include "/lib/wind.glsl"

in vec4 mc_Entity;
in vec4 at_midBlock;
in vec2 mc_midTexCoord;

uniform sampler2D gtexture;

out vec2 texcoord;
out vec2 lightmap;
out vec4 vertexColor;
out vec3 playerPos;
out vec3 worldNormal;
flat out int material;
flat out float emissive;
flat out int lava;
// See blockFinish().
flat out vec3 finish;
// The block texture's sprite in the atlas, in atlas texels: xy its first texel, zw its size (generated normals read
// the texels around a fragment and wrap them inside the sprite). zw = 0: no relief for this geometry.
flat out vec4 spriteBounds;

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
    lava = 0;
    finish = blockFinish(0);
    spriteBounds = vec4(0.0);

#if defined PROG_TERRAIN
    int id = int(mc_Entity.x + 0.5);
    // at_midBlock.w is the block's light emission: every light source glows, modded ones included - a faint one
    // (a machine with a little light) only faintly, so the curve is steep.
    // Iris for 26.1.2 hands geometry outside the chunk meshes an integer at_midBlock with w = -1: NaN here.
    vec4 midBlock = at_midBlock;
    emissive = midBlock.w >= 0.0 && midBlock.w <= 15.0 ? midBlock.w / 15.0 : 0.0;
    emissive *= emissive;
    if (id == ID_PLANT || id == ID_PLANT_LOWER || id == ID_PLANT_UPPER || id == ID_EMISSIVE_PLANT || id == ID_LILY) {
        material = MAT_PLANT;
    } else if (id == ID_LEAVES || id == ID_VINE) {
        material = MAT_LEAVES;
    }
    if (id == ID_EMISSIVE || id == ID_LAVA) {
        material = MAT_EMISSIVE;
        emissive = max(emissive, 0.8);
        lava = id == ID_LAVA ? 1 : 0;
    } else if (id == ID_EMISSIVE_PLANT) {
        emissive = max(emissive, 0.6);
    }
    finish = material == MAT_DEFAULT ? blockFinish(id) : vec3(material == MAT_LEAVES ? 0.75 : 1.0, 0.02, 0.0);
    if (material == MAT_PLANT || material == MAT_EMISSIVE) {
        finish.y = 0.0;
    }
#ifdef GENERATED_NORMALS
    if (material == MAT_DEFAULT) {
        // The sprite around mc_midTexCoord: a vertex of a full face sits half a sprite from its centre; vertices of
        // smaller parts (slabs, torches) sit closer, so the size is rounded up to a power of two, at least 16 texels.
        vec2 atlas = vec2(textureSize(gtexture, 0));
        vec2 halfTexels = abs(texcoord - mc_midTexCoord) * atlas;
        float halfSize = max(8.0, exp2(ceil(log2(max(max(halfTexels.x, halfTexels.y), 1.0)) - 0.01)));
        spriteBounds = vec4(floor(mc_midTexCoord * atlas + 0.5) - halfSize, vec2(2.0 * halfSize));
    }
#endif

    vec3 worldPos = playerPos + cameraPosition;
    // 0 at the bottom of the block, 1 at its top (at_midBlock points from the vertex to the block centre, in 1/64).
    float height = abs(midBlock.y) <= 128.0 ? saturate(0.5 - midBlock.y / 64.0) : 0.5;
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
#elif defined PROG_ENTITIES || defined PROG_BLOCK || defined PROG_COLORWHEEL
    material = MAT_ENTITY;
    finish = vec3(0.8, 0.02, 0.0);
#elif defined PROG_HAND
    material = MAT_HAND;
    finish = vec3(0.8, 0.02, 0.0);
#elif defined PROG_TEXTURED
    material = MAT_PARTICLE;
    finish = vec3(1.0, 0.0, 0.0);
    worldNormal = -normalize(playerPos + vec3(0.0, 1e-3, 0.0));
#endif

#if defined PROG_HAND
    gl_Position = ftransform();
#else
    gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(playerPos, 1.0);
#endif
}
